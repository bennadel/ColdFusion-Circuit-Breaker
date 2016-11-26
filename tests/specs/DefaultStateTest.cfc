component
	extends = "TestCase"
	output = false
	hint = "I test the NoOpMonitor implementation."
	{

	public void function setup() {

		variables.monitor = new lib.state.monitor.InMemoryMonitor();

		variables.state = new lib.state.DefaultState(
			failedRequestThreshold = 2,
			activeRequestThreshold = 2,
			timerDurationInMilliseconds = 20,
			monitor = monitor
		);

		variables.errorStruct = {
			type: "Foo",
			message: "Bar"
		};

	}


	// ---
	// TEST METHODS.
	// ---


	public void function test_that_active_threshold_will_open_circuit() {

		assert( state.isClosed() );

		state.trackRequestStart();
		assert( state.isClosed() );

		state.trackRequestStart();
		assert( state.isOpened() );
		assert( ! state.canPerformHealthCheck() ); // Cannot test health when at capacity.

		state.trackRequestSuccess( getTickCount() - 1 );
		assert( state.isClosed() );	
		
	}


	public void function test_that_failure_threshold_will_open_circuit() {

		assert( state.isClosed() );

		state.trackRequestFailure( state.trackRequestStart(), errorStruct );
		assert( state.isClosed() );

		state.trackRequestFailure( state.trackRequestStart(), errorStruct );
		assert( state.isOpened() );
		assert( ! state.canPerformHealthCheck() ); // Need to wait for new window to check health.

		sleep( 21 );

		assert( state.canPerformHealthCheck() );
		assert( state.isOpened() );

		state.trackRequestSuccess( state.trackRequestStart() );
		assert( state.isClosed() );
		
	}


	public void function test_that_failed_health_check_keeps_circuit_open() {

		state.trackRequestFailure( state.trackRequestStart(), errorStruct );
		state.trackRequestFailure( state.trackRequestStart(), errorStruct );

		sleep( 21 );

		assert( state.canPerformHealthCheck() );

		state.trackRequestFailure( state.trackRequestStart(), errorStruct );
		assert( state.isOpened() );
		assert( ! state.canPerformHealthCheck() );

		sleep( 21 );
		assert( state.canPerformHealthCheck() );

		state.trackRequestSuccess( state.trackRequestStart() );
		assert( state.isClosed() );

	}


	public void function test_that_monitor_is_tracking_events() {

		var eventCount = 0;

		assert( arrayLen( monitor.getEvents() ) == 0 );

		state.trackRequestSuccess( state.trackRequestStart() );
		assert( arrayLen( monitor.getEvents() ) == 1 ); // Success.

		state.trackRequestStart();
		state.trackRequestStart();
		assert( arrayLen( monitor.getEvents() ) == 2 ); // Opened.

		state.trackRequestFailure( ( getTickCount() - 1 ), errorStruct );
		assert( arrayLen( monitor.getEvents() ) == 4 ); // Failure, Closed.

	}


	public void function test_that_failed_requests_can_lower_active_count() {

		state.trackRequestStart();
		state.trackRequestStart();
		assert( state.isOpened() );

		state.trackRequestFailure( ( getTickCount() - 1 ), errorStruct );
		assert( state.isClosed() );

	}


	public void function test_summary_returns() {

		state.trackRequestStart();
		assert( len( state.getSummary() ) );

	}


	public void function test_that_fallback_is_tracked() {

		state.trackRequestFailure( ( getTickCount() - 1 ), errorStruct );
		assert( arrayLen( monitor.getEvents() ) == 1 ); // Failure.

		state.trackRequestFallback( errorStruct );
		assert( arrayLen( monitor.getEvents() ) == 2 ); // Fallback.

	}


	public void function test_that_reset_resets_values() {

		state.trackRequestFailure( ( getTickCount() - 1 ), errorStruct );
		state.trackRequestFailure( ( getTickCount() - 1 ), errorStruct );
		assert( state.isOpened() );
		assert( ! state.canPerformHealthCheck() );

		state.reset();
		assert( state.isClosed() );
		assert( ! state.isOpened() );
		
		state.trackRequestStart();
		assert( state.isClosed() );

		state.trackRequestStart();
		assert( state.isOpened() );


	}

}
