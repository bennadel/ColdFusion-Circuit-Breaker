component 
	implements = "ICircuitBreakerState"
	output = false
	hint = "I provide a default implementation of the Circuit Breaker State."
	{

	/**
	* I initialize the Circuit Breaker State strategy. This state component is meant
	* to help drive the control flow of a Circuit Breaker.
	* 
	* CAUTION: The default values provided for the arguments are not based on any 
	* meaningful research. Meaningful values will depend on the type of actions that the
	* associated Circuit Breaker is managing.
	* 
	* @failedRequestThreshold I am the number of requests that can fail (in the current timer) before the circuit is opened.
	* @activeRequestThreshold I am the number of parallel requests that can be concurrently active before the circuit is opened.
	* @timerDurationInMilliseconds I am the timer duration (in milliseconds) that the circuit will use for tracking and cool-down.
	* @monitor I am the optional state change monitor.
	* @output false
	*/
	public any function init(
		numeric failedRequestThreshold = 10,
		numeric activeRequestThreshold = 10,
		numeric timerDurationInMilliseconds = ( 60 * 1000 ),
		monitor.ICircuitBreakerMonitor monitor
		) {

		// Store the properties.
		variables.failedRequestThreshold = arguments.failedRequestThreshold;
		variables.activeRequestThreshold = arguments.activeRequestThreshold;
		variables.timerDurationInMilliseconds = arguments.timerDurationInMilliseconds;

		// In order to make the monitoring easier to consume, we'll use a no-op monitor
		// if no monitor was explicitly provided.
		variables.monitor = structKeyExists( arguments, "monitor" )
			? arguments.monitor
			: new monitor.NoOpMonitor()
		;

		// NOTE: There is no "half-open" state (like there is with other Circuit Breaker
		// implementation). The half-open pseudo-state will be entered into by a single
		// request in which a full state change isn't necessary (see the 
		// canPerformHealthCheck() method)
		states = {
			CLOSED: "CLOSED",
			OPENED: "OPENED"
		};

		// Default to a closed (ie, flowing) state.
		state = states.CLOSED;

		// Initialize the counters.
		activeRequestCount = 0;
		failedRequestCount = 0;

		// Initialize the timers - each of these store UTC millisecond values.
		checkTargetHealthAtTick = 0;
		lastFailedRequestAtTick = 0;

	}


	// ---
	// PUBLIC METHODS.
	// ---


	/**
	* I determine if an open circuit is ready to perform a health check (in order to 
	* see if the target has returned to a healthy state).
	* 
	* @output false
	*/
	public boolean function canPerformHealthCheck() {

		return( ! isAtCapacity() && ! isWaitingForTargetToRecover() );

	}


	/**
	* I return a summary of the state of the Circuit Breaker. This is consumed by the
	* Circuit Breaker when throwing errors (the summary will be included as part of the
	* error's "extendedInfo" property).
	* 
	* @output false
	*/
	public string function getSummary() {

		return(
			( isOpened() ? "State: OPENED, " : "State: CLOSED, " ) &
			"Active request count: [#activeRequestCount#], " &
			"Failed request count: [#failedRequestCount#]." 
		);

	}


	/**
	* I determine if the Circuit Breaker is currently closed and can accept requests.
	* 
	* @output false
	*/
	public boolean function isClosed() {

		return( state != states.OPENED );

	}


	/**
	* I determine if the Circuit Breaker is currently opened and cannot accept requests.
	* 
	* @output false
	*/
	public boolean function isOpened() {

		return( state == states.OPENED );

	}


	/**
	* I reset the Circuit Breaker State, rolling back all counters and timers to a 
	* healthy state. This should close the circuit if it is currently open.
	* 
	* @output false
	*/
	public void function reset() {

		// Revert to a closed (ie, flowing) state.
		state = states.CLOSED;

		// Reset the counters.
		activeRequestCount = 0;
		failedRequestCount = 0;

		// Reset the timers.
		checkTargetHealthAtTick = 0;
		lastFailedRequestAtTick = 0;

		// Even though we are not sure if the original state (pre-reset) was Opened, 
		// let's log this reset as a state-change.
		monitor.logClosed();

	}


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
	public void function trackRequestFallback( required any error ) {

		monitor.logError( error );

	}


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
		) {

		activeRequestCount--;

		// Check to see if the current failure count is still relevant. Since we are 
		// tracking errors in a rolling window, it might be time to reset the count
		// before we track the current failure.
		if ( isClosed() && isNewErrorWindow() ) {

			failedRequestCount = 0;

		}

		var currentTickCount = getTickCount();

		failedRequestCount++;
		lastFailedRequestAtTick = currentTickCount;
		
		// NOTE: In this implementation, the requestToken was the start-tick of the 
		// Circuit Breaker request.
		monitor.logFailure( currentTickCount - requestToken );

		// Check to see if the current failure exceeded the allowable failure rate for 
		// the Circuit Breaker. If so, we'll have to trip it open.
		if ( isClosed() && isFailing() ) {

			state = states.OPENED;
			checkTargetHealthAtTick = ( currentTickCount + timerDurationInMilliseconds );

			monitor.logOpened();

		// Check to see if the completion of the request, even in failure, brought the
		// active request threshold down without putting the circuit into a failing state.
		} else if ( isOpened() && ! isAtCapacity() && ! isFailing() ) {

			state = states.CLOSED;

			monitor.logClosed();

		}

	}


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
	public any function trackRequestStart() {

		// If a request is being initiated while the circuit is tripped open, it must be
		// a health check. Since the ability to accept a health check is, in part, driven
		// by the timer duration, in order to prevent parallel requests from also 
		// initiating a health check request, let's bump out the timer. This will also
		// implicitly "reset" the timeout, for all intents and purposes, if the health 
		// check fails.
		if ( isOpened() ) {

			checkTargetHealthAtTick = ( getTickCount() + timerDurationInMilliseconds );

		}

		activeRequestCount++;

		// If the current request just exhausted the request pool, open the circuit so
		// that no more requests can be initiated.
		if ( isClosed() && isAtCapacity() ) {

			state = states.OPENED;

			// NOTE: Since this "trip" is based on capacity and not on error rate, there
			// is no need to adjust the health-timer. We want the circuit to re-close as
			// pending requests complete.

			monitor.logOpened();

		}

		// Each request needs to be associated with some type of token (that will be 
		// passed back into the success / failure tracking methods). In this case,
		// we're just going to use the current UTC milliseconds so that we can roughly
		// correlate each request with a duration.
		return( getTickCount() );

	}


	/**
	* I track a successful action in the Circuit Breaker.
	* 
	* @requestToken I am the token returned from "start" method.
	* @output false
	*/
	public void function trackRequestSuccess( required any requestToken ) {

		activeRequestCount--;

		// NOTE: In this implementation, the requestToken was the start-tick of the 
		// Circuit Breaker request.
		monitor.logSuccess( getTickCount() - requestToken );

		// Any successful request that returns while the Circuit Breaker is open will 
		// move the circuit back into a closed, flowing state. This may be the "health 
		// check" request; or, it may be a previously long-running request that finally
		// returned some time after the circuit was tripped open; or, it may be an 
		// "at capacity" request that has completed, releasing a slot in the request 
		// pool. At this point, there is no differentiating between the various types 
		// of successful returns.
		if ( isOpened() && ! isAtCapacity() ) {

			state = states.CLOSED;

			// Reset failure tracking.
			failedRequestCount = 0;
			lastFailedRequestAtTick = 0;
			checkTargetHealthAtTick = 0;

			monitor.logClosed();

		}

	}


	// ---
	// PRIVATE METHODS.
	// ---


	/**
	* I determine if the Circuit Breaker has exhausted its request pool and should no 
	* longer accept any requests until pending requests have completed.
	* 
	* @output false
	*/
	private boolean function isAtCapacity() {

		return( activeRequestCount >= activeRequestThreshold );

	}


	/**
	* I determine if the Circuit Breaker is failing based on the failed request threshold.
	* 
	* @output false
	*/
	private boolean function isFailing() {

		return( failedRequestCount >= failedRequestThreshold );

	}


	/**
	* I determine if a new error-tracking window should be initiated. Errors are tracked
	* in a rolling window so that infrequent errors don't eventually trip the Circuit 
	* Breaker unnecessarily.
	* 
	* @output false 
	*/
	private boolean function isNewErrorWindow() {

		return( ( lastFailedRequestAtTick + timerDurationInMilliseconds ) < getTickCount() );

	}


	/**
	* I determine if the OPEN Circuit Breaker is currently waiting before attempting to
	* check the health of the target (ie, whether or not it is yet appropriate to check 
	* the health of the target).
	* 
	* @output false
	*/
	private boolean function isWaitingForTargetToRecover() {

		return( checkTargetHealthAtTick > getTickCount() );

	}

}
