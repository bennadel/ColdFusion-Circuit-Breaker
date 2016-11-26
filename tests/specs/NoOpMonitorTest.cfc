component
	extends = "TestCase"
	output = false
	hint = "I test the NoOpMonitor implementation."
	{

	public void function test_that_all_methods_increment_event_count() {

		var monitor = new lib.state.monitor.NoOpMonitor();
		var eventCount = 0;

		assert( monitor.getEventCount() == eventCount++ );
		
		monitor.logOpened();
		assert( monitor.getEventCount() == eventCount++ );
		
		monitor.logClosed();
		assert( monitor.getEventCount() == eventCount++ );
		
		monitor.logError( true );
		assert( monitor.getEventCount() == eventCount++ );

		monitor.logSuccess( 0 );
		assert( monitor.getEventCount() == eventCount++ );

		monitor.logFailure( 0 );
		assert( monitor.getEventCount() == eventCount++ );

		// Log events again to ensure no side-effects.
		monitor.logOpened();
		assert( monitor.getEventCount() == eventCount++ );
		
		monitor.logClosed();
		assert( monitor.getEventCount() == eventCount++ );
		
		monitor.logError( true );
		assert( monitor.getEventCount() == eventCount++ );

		monitor.logSuccess( 0 );
		assert( monitor.getEventCount() == eventCount++ );

		monitor.logFailure( 0 );
		assert( monitor.getEventCount() == eventCount++ );

	}

}
