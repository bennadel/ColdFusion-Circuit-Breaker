
# ColdFusion Circuit Breaker

by [Ben Nadel][1] (on [Google+][2])

This is a **ColdFusion** implementation of the **Circuit Breaker** pattern as popularized 
in [Michael T. Nygard's book - Release It!][release-it]. The Circuit Breaker is intended 
to proxy the consumption of upstream resources such that failures in the upstream resource
propagate to the current system in a predictable manner. To be clear, the Circuit Breaker
doesn't prevent failures; rather, it helps your application manage failure proactively, 
failing fast and providing fallback values when possible.

In my implementation, each instance of a Circuit Breaker is tied to a specific resource.
And, each instance of a Circuit Breaker is powered by a unique instance of a Circuit 
Breaker State object. The Circuit Breaker is a generic control flow proxy that manages
the consumption of a given resource based on the insight offered by the Circuit Breaker
State object. As such, it wouldn't make any sense for either the Circuit Breaker or the
Circuit Breaker State instances to be shared across resources.

While the Circuit Breaker is generic, the underlying Circuit Breaker State object can be
customized either through configuration or through implementation. This project ships 
with a `DefaultState.cfc` implementation which can be configured with different threshold
values. Or, you can create your own implementation that adheres to the 
`ICircuitBreakerState.cfc` interface.

## `CircuitBreaker.cfc`

The Circuit Breaker has the following proxy methods:

* `execute( target [, fallback ] )` :: any
* `executeMethod( target, methodName [, methodArguments [, fallback ] ] )` :: any

In either case, the optional `fallback` value can be a static value or an invocable value 
(ie, a Function or a Closure reference). The `fallback` value will only be used when the 
proxy invocation of the target fails (including "failing fast" due to an Open circuit). 
If no `fallback` value is provided, errors will simply propagate up the call stack.

### Proxy to a Function Evaluation

The `.execute()` method is designed to proxy the evaluation of an invocable reference 
(ie, either a Function or a Closure reference). Here, you can see it being used with the
`DefaultState.cfc` implementation:

```cfc
// Create an instance of the Circuit Breaker using the Default state implementation.
var circuitBreaker = new lib.CircuitBreaker(
	new lib.state.DefaultState(
		failedRequestThreshold = 2,
		activeRequestThreshold = 2,
		timerDurationInMilliseconds = 20
	)
);

// With the fallback as a function.
var result = circuitBreaker.execute(
	function() {
		return( "Hello from a closure." );
	},
	function() {
		return( "I am the fallback value." );
	}
);

// With the fallback as a static value.
var result = circuitBreaker.execute(
	function() {
		return( "Hello from a closure." );
	},
	"I am the fallback value."
);

// With NO FALLBACKB value - errors will propagate.
var result = circuitBreaker.execute(
	function() {
		return( "Hello from a closure." );
	}
);
```

### Proxy to an Instance Method Evaluation

The `.executeMethod()` method is designed to proxy the evaluation of an instance method 
on a component that communicates with a brittle service (such as a 3rd-party API). Here,
you can see it being used with the `DefaultState.cfc` implementation:

```cfc
// Create an instance of the Circuit Breaker using the Default state implementation.
var circuitBreaker = new lib.CircuitBreaker(
	new lib.state.DefaultState(
		failedRequestThreshold = 2,
		activeRequestThreshold = 2,
		timerDurationInMilliseconds = 20
	)
);

// With the fallback as a function.
var result = circuitBreaker.executeMethod( 
	ipInfoGateway,
	"getIpInfo",
	[ requestIpAddress ],
	function() {
		return( "I am the fallback value." );
	}
);

// With the fallback as a static value.
var result = circuitBreaker.executeMethod(
	ipInfoGateway,
	"getIpInfo",
	[ requestIpAddress ],
	"I am the fallback value."
);

// With NO FALLBACKB value - errors will propagate.
var result = circuitBreaker.executeMethod(
	ipInfoGateway,
	"getIpInfo",
	[ requestIpAddress ]
);
```

When using the `.executeMethod()` method, the `methodArguments` have to be provided if
you are going to provide a fallback value. If you are not providing a fallback value, the
`methodArguments` are optional. When provided, the `methodArguments` can be defined as an
Array or a Struct.

## `ICircuitBreakerState.cfc`

The Circuit Breaker was designed as a generic control flow proxy that relies upon a 
separate state management object. These two concerns were separated in order to keep 
the Circuit Breaker generic and allow different state management implementations to be 
created (such as those that might use Redis as a state store). This also allows each 
state implementation to be tested independently of the Circuit Breaker.

Each state management component must implement the `ICircuitBreakerState.cfc` interface:

```cfc
interface 
	hint = "I define the interface for the state management of a CircuitBreaker."
	{

	// NOTE: All calls to the Circuit Breaker State are being synchronized / locked by 
	// the Circuit Breaker itself. As such, there is no need to worry about 
	// synchronization within the state unless it is going to be consumed from elsewhere.

	/**
	* I determine if an open circuit is ready to perform a health check (in order to 
	* see if the target has returned to a healthy state).
	* 
	* @output false
	*/
	public boolean function canPerformHealthCheck();


	/**
	* I return a summary of the state of the Circuit Breaker. This is consumed by the
	* Circuit Breaker when throwing errors (the summary will be included as part of the 
	* error's "extendedInfo" property).
	* 
	* @output false
	*/
	public string function getSummary();


	/**
	* I determine if the Circuit Breaker is currently closed and can accept requests.
	* 
	* @output false
	*/
	public boolean function isClosed();


	/**
	* I determine if the Circuit Breaker is currently opened and cannot accept requests.
	* 
	* @output false
	*/
	public boolean function isOpened();


	/**
	* I reset the Circuit Breaker State, rolling back all counters and timers to a 
	* healthy state. This should close the circuit if it is currently open.
	* 
	* @output false
	*/
	public void function reset();


	/**
	* I track the use of a fallback value during a failed action in the Circuit Breaker.
	* 
	* NOTE: Unlike the trackRequestFailure() method, which is not intended to log the 
	* provided error, you may want to log the error during the trackRequestFallback()
	* method since it is an error that will not propagate up in the application (which is
	* the intent of the fallback value).
	* 
	* @error I am the error that was thrown during the request action.
	* @output false
	*/
	public void function trackRequestFallback( required any error );


	/**
	* I track a failed action in the Circuit Breaker. 
	* 
	* NOTE: The associated error is being passed into the failure method in case any 
	* additional logic needs to be implemented based on error type. You should not be 
	* logging this error internally to the state - let the rethrown error be handled by 
	* your application's higher-level error handling.
	* 
	* @requestToken I am the token returned from the "start" method.
	* @error I am the error that was thrown during the request execution.
	* @output false
	*/
	public void function trackRequestFailure(
		required any requestToken,
		required any error 
	);


	/**
	* I track the start of an action in the Circuit Breaker. Every "start" should be 
	* followed by either a request resolution in "success" or in "failure".
	* 
	* This method is expected to return some sort of value. It doesn't matter what type
	* of value (numeric, struct, etc.); but, this value will be passed back into the
	* state using either the trackRequestSuccess() or trachRequestFailure() methods. The
	* return value can be used to correlate start and resolution events.
	* 
	* @output false
	*/
	public any function trackRequestStart();


	/**
	* I track a successful action in the Circuit Breaker.
	* 
	* @requestToken I am the token returned from "start" method.
	* @output false
	*/
	public void function trackRequestSuccess( required any requestToken );

}
```

As you can see, nothing about this interface speaks to the underlying implementation
details; the state API simply "tells the story" of the state, which the Circuit Breaker
will read when routing requests.

This library ships with a `DefaultState.cfc` implementation that can be configured with
the following constructor arguments:

* `failedRequestThreshold` -- I am the number of requests that can fail (in the current timer) before the circuit is opened.
* `activeRequestThreshold` -- I am the number of parallel requests that can be concurrently active before the circuit is opened.
* `timerDurationInMilliseconds` -- I am the timer duration (in milliseconds) that the circuit will use for tracking and cool-down.
* `monitor` -- I am the optional state change monitor.

The Circuit Breaker uses server-instance level locking when interacting with the state
management implementation. As such, the state management doesn't have to worry about 
synchronization or race conditions. Unless, of course, the state implementation consumes
resources that are shared across servers. In that case, special considerations may need 
to be taken into account, depending on the type of resources being shared.

_**WARNING**: It's best for your state management implementation to avoid making remote
calls. Not only will these add overhead to every single request, they also introduce a
new point of failure._

## `ICircuitBreakerMonitor.cfc`

This `DefaultState.cfc` implementation takes an optional Monitor which adheres to the 
`ICircuitBreakerMonitor.cfc` interface:

```cfc
interface
	hint = "I define the interface for Circuit Breaker State monitoring."
	{

	// The Circuit Breaker itself doesn't actually know anything about monitoring - all
	// monitoring is consumed by the state management. As such, this "Interface" is 
	// really only implemented by the monitors provided by this library. If you implement
	// your own State, your monitor (if you have one) doesn't have to adhere to this.

	/**
	* I log the changing of the Circuit Breaker state to Closed.
	* 
	* @output false
	*/
	public void function logClosed();


	/**
	* I log the given error that was swallowed during request processing (ie, not 
	* allowed to propagate up through the application). This will only ever be called
	* when a fallback value was provided by the calling context and consumed by the 
	* Circuit Breaker.
	* 
	* @error I am the error that was thrown (and caught) during request processing.
	* @output false
	*/
	public void function logError( required any error );


	/**
	* I log a failure to fulfill a request in the Circuit Breaker.
	* 
	* @durationInMilliseconds I am duration (in milliseconds) of the failed request.
	* @output false
	*/
	public void function logFailure( required numeric durationInMilliseconds );


	/**
	* I log the changing of the Circuit Breaker state to Opened.
	* 
	* @output false
	*/
	public void function logOpened();


	/**
	* I log a successful request fulfillment in the Circuit Breaker.
	* 
	* @durationInMilliseconds I am duration (in milliseconds) of the successful request.
	* @output false
	*/
	public void function logSuccess( required numeric durationInMilliseconds );

}
```

This library ships with Monitors that are used for internal testing; however, you can 
create your own Monitor implementations that do things like log request times and 
failures to **StatsD**. You can use the provided `DefaultState.cfc` implementation with
a custom `ICircuitBreakerMonitor.cfc` implementation.




[1]: http://www.bennadel.com
[2]: https://plus.google.com/108976367067760160494?rel=author
[release-it]: https://www.bennadel.com/blog/3162-release-it-design-and-deploy-production-ready-software-by-michael-t-nygard.htm