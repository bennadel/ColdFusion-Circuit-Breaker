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
