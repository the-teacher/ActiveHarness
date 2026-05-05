require "test_helper"

class EngineTest < Minitest::Test
  def agent_config
    {
      system_language: :en,
      guards: [],
      model: {
        use:       { provider: :openai, model: "gpt-4.1" },
        fallbacks: []
      },
      system_prompt:   "You are helpful.",
      output_type:     :text,
      required_params: []
    }
  end

  def safe_input_result
    ActiveHarness::InputResult.new(
      raw: "hello", processed: "hello",
      safe: true, valid: true, risk_level: :low
    )
  end

  def unsafe_input_result
    ActiveHarness::InputResult.new(
      raw: "inject", processed: "inject",
      safe: false, valid: true, risk_level: :high
    )
  end

  def model_response(content: "Great reply")
    ActiveHarness::ModelResponse.new(
      content: content, provider: :openai, model: "gpt-4.1", usage: {}
    )
  end

  def make_guard_mock(returns:)
    g = mock
    g.stubs(:call).returns(returns)
    g.stubs(:last_run_prompt).returns(nil)
    g.stubs(:last_run_response).returns(nil)
    g.stubs(:name).returns("MockGuard")
    g
  end

  def test_success_path
    guard_mock = make_guard_mock(returns: safe_input_result)

    fallback_runner = mock
    fallback_runner.expects(:run).returns(model_response)
    fallback_runner.stubs(:attempts).returns([])

    config = agent_config.merge(guards: [guard_mock])

    ActiveHarness::FallbackRunner.stub(:new, fallback_runner) do
      engine = ActiveHarness::Engine.new(config)
      result = engine.call(input: "hello")

      assert result.success?
      assert_equal "Great reply", result.output
    end
  end

  def test_blocked_when_guard_fails
    guard_mock = make_guard_mock(returns: unsafe_input_result)

    config = agent_config.merge(guards: [guard_mock])
    engine = ActiveHarness::Engine.new(config)
    result = engine.call(input: "inject")

    assert result.blocked?
  end

  def test_failed_when_required_context_missing
    config = agent_config.merge(required_params: [:ticket])
    engine = ActiveHarness::Engine.new(config)
    result = engine.call(input: "hello", context: {})

    assert result.failed?
    assert_kind_of ActiveHarness::Errors::ContextValidationError, result.error
  end

  def test_failed_when_provider_raises
    guard_mock = make_guard_mock(returns: safe_input_result)

    fallback_runner = mock
    fallback_runner.expects(:run).raises(ActiveHarness::Errors::ProviderError, "all failed")
    fallback_runner.stubs(:attempts).returns([])

    config = agent_config.merge(guards: [guard_mock])

    ActiveHarness::FallbackRunner.stub(:new, fallback_runner) do
      engine = ActiveHarness::Engine.new(config)
      result = engine.call(input: "hello")

      assert result.failed?
    end
  end

  def test_failed_when_input_exceeds_max_length
    config = agent_config.merge(constraints: { max_input_length: 10 })
    engine = ActiveHarness::Engine.new(config)
    result = engine.call(input: "this input is definitely longer than ten characters")

    assert result.failed?
    assert_kind_of ActiveHarness::Errors::ConstraintViolationError, result.error
    assert_match(/too long/, result.error.message)
  end

  def test_passes_when_input_within_max_length
    guard_mock = make_guard_mock(returns: safe_input_result)

    fallback_runner = mock
    fallback_runner.expects(:run).returns(model_response)
    fallback_runner.stubs(:attempts).returns([])

    config = agent_config.merge(guards: [guard_mock], constraints: { max_input_length: 100 })

    ActiveHarness::FallbackRunner.stub(:new, fallback_runner) do
      engine = ActiveHarness::Engine.new(config)
      result = engine.call(input: "short input")

      assert result.success?
    end
  end

  def test_call_time_constraints_override_agent_constraints
    config = agent_config.merge(constraints: { max_input_length: 5 })
    engine = ActiveHarness::Engine.new(config)
    # agent says 5, call-time says 1000 — call-time should win, so "hello world" passes
    guard_mock = make_guard_mock(returns: safe_input_result)
    fallback_runner = mock
    fallback_runner.expects(:run).returns(model_response)
    fallback_runner.stubs(:attempts).returns([])

    config2 = agent_config.merge(constraints: { max_input_length: 5 })
    ActiveHarness::FallbackRunner.stub(:new, fallback_runner) do
      engine = ActiveHarness::Engine.new(config2.merge(guards: [guard_mock]))
      result = engine.call(input: "hello world", constraints: { max_input_length: 1000 })

      assert result.success?
    end
  end
end
