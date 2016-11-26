<cfscript>

	// Create an instance of our in-memory monitor. This will keep track of the Circuit 
	// Breaker events in an in-memory event log.	
	monitor = new state.monitor.InMemoryMonitor();

	// Pass the in-memory monitor instance to our Circuit Breaker state.
	state = new state.DefaultState( 
		failedRequestThreshold = 2,
		activeRequestThreshold = 2,
		openStateTimeout = 1000,
		monitor = monitor
	);

	breaker = new CircuitBreaker( state );
	
	// ------------------------------------------------------------------------------- //
	// ------------------------------------------------------------------------------- //

	// Execute quick success.
	breaker.execute(
		function() {

			return( "Woot!" );

		}
	);

	// Execute slow success.
	breaker.execute(
		function() {

			sleep( 52 );
			return( "Wooty!" );

		}
	);

	// Execute quick failure.
	breaker.execute(
		function() {

			throw( "meh" );

		},
		"I am a fallback value"
	);

	// Execute slow failure.
	breaker.execute(
		function() {

			sleep( 38 );
			throw( "meh" );

		},
		"I am a fallback value"
	);

	// Log-out the events monitored by the Circuit Breaker state.
	writeDump( var = monitor.getEvents(), format = "text" );

</cfscript>