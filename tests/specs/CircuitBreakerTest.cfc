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

		variables.breaker = new lib.CircuitBreaker( state );

		variables.badClosure = function() {

			throw( "Meh" );

		};

		variables.goodClosure = function() {

			return( "Good closure" );

		};

	}


	// ---
	// Instance Methods (For Target Testing).
	// ---


	public string function good_target_method() {

		return( "hello" );

	}


	public string function bad_target_method() {

		throw( "Meh" );

	}


	// ---
	// TEST METHODS.
	// ---


	public void function test_that_closures_return() {

		var valueToReturn = "woot";
		var value = breaker.execute(
			function() {

				return( valueToReturn );

			}
		);
		assert( value == valueToReturn );

	}


	public void function test_that_methods_return() {

		var value = breaker.executeMethod( this, "good_target_method" );
		assert( value == "hello" );

	}


	public void function test_that_closure_fallback_works() {

		var value = breaker.execute( badClosure, "static value" );
		assert( value == "static value" );

		var value = breaker.execute( badClosure, goodClosure );
		assert( value == "Good closure" );

	}


	public void function test_that_method_vallback_works() {

		var value = breaker.executeMethod(
			this,
			"bad_target_method",
			[],
			"static value"
		);
		assert( value == "static value" );

		var value = breaker.executeMethod(
			this,
			"bad_target_method",
			[],
			goodClosure
		);
		assert( value == "Good closure" );

	}


	public void function test_that_failing_circuit_shorts() {

		var value = breaker.execute( badClosure, "Fallback value" );
		var value = breaker.execute( badClosure, "Fallback value" );
		assert( breaker.isOpened() );

		var value = breaker.execute( goodClosure, "Shortcircuit value" );
		assert( value == "Shortcircuit value" );
		assert( breaker.isOpened() );

		sleep( 21 );
		assert( breaker.isOpened() );

		var value = breaker.execute( goodClosure, "Shortcircuit value" );
		assert( value == "Good closure" );
		assert( breaker.isClosed() );

	}

}
