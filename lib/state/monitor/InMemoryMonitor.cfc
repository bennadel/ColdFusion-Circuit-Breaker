component 
	implements = "ICircuitBreakerMonitor"
	output = false
	hint = "I log Circuit Breaker events to an in-memory event log (primarily for testing)."
	{

	/**
	* I initialize the in-memory monitor.
	* 
	* @output false
	*/
	public any function init() {

		events = [];

	}


	// ---
	// PUBLIC METHODS.
	// ---


	/**
	* I return the recorded Circuit Breaker events.
	* 
	* @output false
	*/
	public array function getEvents() {

		return( events );

	}


	/**
	* I log the changing of the Circuit Breaker state to Closed.
	* 
	* @output false
	*/
	public void function logClosed() {
		
		arrayAppend( events, "Circuit breaker moved to CLOSED state." );

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

		arrayAppend( events, "Error logged during fallback [#error.type#: #error.message#]." );

	}


	/**
	* I log a failure to fulfill a request in the Circuit Breaker.
	* 
	* @durationInMilliseconds I am duration (in milliseconds) of the failed request.
	* @output false
	*/
	public void function logFailure( required numeric durationInMilliseconds ) {
		
		arrayAppend( events, "Action executed in failure [in #durationInMilliseconds# ms]." );

	}


	/**
	* I log the changing of the Circuit Breaker state to Opened.
	* 
	* @output false
	*/
	public void function logOpened() {
		
		arrayAppend( events, "Circuit breaker moved to OPENED state." );

	}


	/**
	* I log a successful request fulfillment in the Circuit Breaker.
	* 
	* @durationInMilliseconds I am duration (in milliseconds) of the successful request.
	* @output false
	*/
	public void function logSuccess( required numeric durationInMilliseconds ) {
		
		arrayAppend( events, "Action executed in success [in #durationInMilliseconds# ms]." );

	}

}
