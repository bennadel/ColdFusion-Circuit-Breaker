component 
	implements = "ICircuitBreakerMonitor"
	output = false
	hint = "I provide a no-operation (no-op) Circuit Breaker event logging implementation."
	{

	/**
	* I initialize the no-op monitor.
	* 
	* @output false
	*/
	public any function init() {

		eventCount = 0;

	}


	// ---
	// PUBLIC METHODS.
	// ---


	/**
	* I return the number of events that have been logged.
	* 
	* @output false
	*/
	public numeric function getEventCount() {

		return( eventCount );

	}


	/**
	* I log the changing of the Circuit Breaker state to Closed.
	* 
	* @output false
	*/
	public void function logClosed() {
		
		eventCount++;

	}


	/**
	* I log the given error that was swallowed during request processing (ie, not 
	* allowed to propagate up through the application). This will only ever be called
	* when a fallback value was provided by the calling context and consumed by the 
	* Circuit Breaker.
	* 
	* @error I am the error that was thrown (and caught) during request processing.
	* @output false
	*/
	public void function logError( required any error ) {

		eventCount++;

	}


	/**
	* I log a failure to fulfill a request in the Circuit Breaker.
	* 
	* @durationInMilliseconds I am duration (in milliseconds) of the failed request.
	* @output false
	*/
	public void function logFailure( required numeric durationInMilliseconds ) {
		
		eventCount++;

	}


	/**
	* I log the changing of the Circuit Breaker state to Opened.
	* 
	* @output false
	*/
	public void function logOpened() {
		
		eventCount++;

	}


	/**
	* I log a successful request fulfillment in the Circuit Breaker.
	* 
	* @durationInMilliseconds I am duration (in milliseconds) of the successful request.
	* @output false
	*/
	public void function logSuccess( required numeric durationInMilliseconds ) {
		
		eventCount++;

	}

}
