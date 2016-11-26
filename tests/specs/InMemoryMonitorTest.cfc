component
	extends = "TestCase"
	output = false
	hint = "I test the InMemoryMonitor implementation."
	{

	public void function test_that_all_methods_log_events() {

		var monitor = new lib.state.monitor.InMemoryMonitor();
		
		monitor.logOpened();
		monitor.logClosed();
		monitor.logSuccess( 0 );
		monitor.logFailure( 0 );
		monitor.logError({ type: "Foo", message: "Bar" });

		// Log events again to ensure no side-effects.
		monitor.logOpened();
		monitor.logClosed();
		monitor.logSuccess( 0 );
		monitor.logFailure( 0 );
		monitor.logError({ type: "Foo", message: "Bar" });

		var events = monitor.getEvents();

		assert( events[ 1 ] == "Circuit breaker moved to OPENED state." );
		assert( events[ 2 ] == "Circuit breaker moved to CLOSED state." );
		assert( events[ 3 ] == "Action executed in success [in 0 ms]." );
		assert( events[ 4 ] == "Action executed in failure [in 0 ms]." );
		assert( events[ 5 ] == "Error logged during fallback [Foo: Bar]." );

		assert( events[ 6 ] == "Circuit breaker moved to OPENED state." );
		assert( events[ 7 ] == "Circuit breaker moved to CLOSED state." );
		assert( events[ 8 ] == "Action executed in success [in 0 ms]." );
		assert( events[ 9 ] == "Action executed in failure [in 0 ms]." );
		assert( events[ 10 ] == "Error logged during fallback [Foo: Bar]." );
		
	}

}
