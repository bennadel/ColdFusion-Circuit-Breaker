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
