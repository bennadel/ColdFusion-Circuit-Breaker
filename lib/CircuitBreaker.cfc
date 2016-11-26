component
	output = false
	hint = "I marshal the invocation of actions, providing circuit-breaker protection with the given state strategy."
	{

	/**
	* I initialize the Circuit Breaker with the given state strategy.
	* 
	* @state I am the Circuit Breaker State with which the Circuit Breaker is making decisions.
	* @output false
	*/
	public any function init( required state.ICircuitBreakerState circuitBreakerState ) {

		// Store the properties.
		state = circuitBreakerState;
		
		// All access to the shared state of the circuit breaker will be synchronized 
		// using these locking properties. The state itself is not inherently synchronized.
		lockAttributes = {
			name: "CircuitBreaker-#createUUID()#",
			type: "exclusive",
			timeout: 1,
			throwOnTimeout: true 
		};

		return( this );

	}


	// ---
	// PUBLIC METHODS.
	// ---


	/**
	* I marshal the given action inside the Circuit Breaker.
	* 
	* @target I am the function or closure to be invoked.
	* @fallback I am the value to be evaluated if the action fails to complete successfully.
	* @output false
	*/
	public any function execute( 
		required any target,
		any fallback
		) {

		try {

			return( run( target ) );

		} catch ( any error ) {

			// If a fallback has been provided, return the fallback instead of letting
			// the error propagate to the calling context.
			if ( structKeyExists( arguments, "fallback" ) ) {

				state.trackRequestFallback( error );

				return( evaluateFallback( fallback ) );

			}

			rethrow;

		}

	}


	/**
	* I marshal the given action inside the Circuit Breaker.
	* 
	* @target I am the component receiving the message.
	* @methodName I am the message being sent to the target.
	* @methodArguments I am the message arguments being sent to the target.
	* @fallback I am the value to be evaluated if the action fails to complete successfully.
	* @output false
	*/
	public any function executeMethod( 
		required any target,
		required string methodName,
		any methodArguments = [],
		any fallback
		) {

		try {

			return( run( target, methodName, methodArguments ) );

		} catch ( any error ) {

			// If a fallback has been provided, return the fallback instead of letting
			// the error propagate to the calling context.
			if ( structKeyExists( arguments, "fallback" ) ) {

				state.trackRequestFallback( error );

				return( evaluateFallback( fallback ) );

			}

			rethrow;

		}

	}


	/**
	* I determine if the Circuit Breaker is in a closed state.
	* 
	* @output false
	*/
	public boolean function isClosed() {

		return( state.isClosed() );

	}


	/**
	* I determine if the Circuit Breaker is in an open state.
	* 
	* @output false
	*/
	public boolean function isOpened() {

		return( state.isOpened() );

	}


	// ---
	// PRIVATE METHODS.
	// ---


	/**
	* I evaluate the given fallback input to produce an output. If the fallback is a
	* function or closure, it will be invoked; otherwise, it will be returned as-is.
	* 
	* @fallback I am the fallback producer being evaluated.
	* @output false
	*/
	private any function evaluateFallback( required any fallback ) {

		if ( isCustomFunction( fallback ) || isClosure( fallback ) ) {

			return( fallback() );

		} else {

			return( fallback );

		}

	}


	/**
	* I proxy the execution / invocation of the given action.
	* 
	* @target I am the function or component being executed.
	* @methodName I am the message being sent to the target (if it's a component).
	* @methodArguments I am the message arguments being sent to the target (if it's a component).
	* @output false
	*/
	public any function run( 
		required any target,
		string methodName,
		any methodArguments
		) {

		// CAUTION: Since the Circuit Breaker is expecting to handle many concurrent
		// requests, all reading-from and writing-to the shared state of the Circuit 
		// Breaker is being SYNCHRONIZED with exclusive locking. The state object 
		// itself does not perform any inherent locking.

		lock attributeCollection = lockAttributes {

			if ( state.isOpened() ) {

				// If the Circuit Breaker is open, the general idea is to "fail fast."
				// However, if the circuit has been open for some period of time, it 
				// might be ready to send a health check request to the target to see
				// if the target has become healthy.
				if ( ! state.canPerformHealthCheck() ) {

					throw(
						type = "CircuitBreakerOpen",
						message = "Target invocation failing fast due to open circuit breaker.",
						detail = "The circuit is open and therefore the requested action could not be executed.",
						extendedInfo = state.getSummary()
					);

				}

			}

			var requestToken = state.trackRequestStart();

		} // END: Lock.

		try {

			// Try to execute the requested action.
			var result = ( isClosure( target ) || isCustomFunction( target ) )
				? target()
				: invoke( target, methodName, methodArguments )
			;

			lock attributeCollection = lockAttributes {

				state.trackRequestSuccess( requestToken );

			} // END: Lock.

			// The target method may not return a defined value, even in a successful 
			// invocation. As such, we have to check to see if the result exists before 
			// we try to return the result upstream.
			if ( structKeyExists( local, "result" ) ) {

				return( result );

			} else {

				return; // void.

			}

		} catch ( any error ) {

			lock attributeCollection = lockAttributes {

				state.trackRequestFailure( requestToken, error );

			} // END: Lock.

			rethrow;

		} // END: Catch.

	}

}
