require "test_helper"

class CallbacksTest < Minitest::Test
  def base_config
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

  def safe_input_result(processed: "hello")
    ActiveHarness::InputResult.new(
      raw: processed, processed: processed,
      safe: true, valid: true, risk_level: :low
    )
  end

  def model_response(content: "reply")
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

  def test_before_guards_transforms_input
    log = []
    received_payload = nil

    guard_mock = mock
    guard_mock.stubs(:call).with { |*args, **_| received_payload = args.first; true }.returns(safe_input_result)
    guard_mock.stubs(:last_run_prompt).returns(nil)
    guard_mock.stubs(:last_run_response).returns(nil)
    guard_mock.stubs(:name).returns("MockGuard")

    config = base_config.merge(
      guards: [guard_mock],
      callbacks: {
        before_guards: [
          ->(payload, s) { log << "before_guards_1:#{s}"; s.upcase },
          ->(payload, s) { log << "before_guards_2:#{s}"; s.strip  }
        ]
      }
    )

    fallback_runner = mock
    fallback_runner.expects(:run).returns(model_response)
    fallback_runner.stubs(:attempts).returns([])

    ActiveHarness::FallbackRunner.stub(:new, ->(_) { fallback_runner }) do
      ActiveHarness::Engine.new(config).call(input: "hello")
    end

    assert_equal "HELLO", received_payload.input
    assert_equal ["before_guards_1:hello", "before_guards_2:HELLO"], log
  end

  def test_after_guards_transforms_result
    new_result = safe_input_result(processed: "normalized")

    guard_mock = mock
    guard_mock.stubs(:call).returns(safe_input_result(processed: "original"))
    guard_mock.stubs(:last_run_prompt).returns(nil)
    guard_mock.stubs(:last_run_response).returns(nil)
    guard_mock.stubs(:name).returns("MockGuard")

    config = base_config.merge(
      guards: [guard_mock],
      callbacks: {
        after_guards: [->(payload, r) { new_result }]
      }
    )

    received_prompt = nil
    fallback_runner = mock
    fallback_runner.expects(:run).with { |req| received_prompt = req.messages.last[:content]; true }
                   .returns(model_response)
    fallback_runner.stubs(:attempts).returns([])

    ActiveHarness::FallbackRunner.stub(:new, ->(_) { fallback_runner }) do
      ActiveHarness::Engine.new(config).call(input: "original")
    end

    assert_equal "normalized", received_prompt
  end

  def test_before_request_transforms_prompt
    config = base_config.merge(
      guards: [make_guard_mock(returns: safe_input_result)],
      callbacks: {
        before_request: [
          ->(payload, prompt) { prompt.merge(user: "[PREFIX] #{prompt[:user]}") }
        ]
      }
    )

    received_user = nil
    fallback_runner = mock
    fallback_runner.expects(:run).with { |req| received_user = req.messages.last[:content]; true }
                   .returns(model_response)
    fallback_runner.stubs(:attempts).returns([])

    ActiveHarness::FallbackRunner.stub(:new, ->(_) { fallback_runner }) do
      ActiveHarness::Engine.new(config).call(input: "hello")
    end

    assert_match(/\[PREFIX\]/, received_user)
  end

  def test_after_request_transforms_response
    patched = model_response(content: "patched content")
    config = base_config.merge(
      guards: [make_guard_mock(returns: safe_input_result)],
      callbacks: {
        after_request: [->(payload, resp) { patched }]
      }
    )

    fallback_runner = mock
    fallback_runner.expects(:run).returns(model_response(content: "original content"))
    fallback_runner.stubs(:attempts).returns([])

    ActiveHarness::FallbackRunner.stub(:new, ->(_) { fallback_runner }) do
      result = ActiveHarness::Engine.new(config).call(input: "hello")
      assert_equal "patched content", result.output
    end
  end

  def test_multiple_callbacks_chain_in_order
    log = []
    config = base_config.merge(
      guards: [make_guard_mock(returns: safe_input_result)],
      callbacks: {
        before_guards: [
          ->(payload, s) { log << 1; s },
          ->(payload, s) { log << 2; s },
          ->(payload, s) { log << 3; s }
        ]
      }
    )

    fallback_runner = mock
    fallback_runner.expects(:run).returns(model_response)
    fallback_runner.stubs(:attempts).returns([])

    ActiveHarness::FallbackRunner.stub(:new, ->(_) { fallback_runner }) do
      ActiveHarness::Engine.new(config).call(input: "hello")
    end

    assert_equal [1, 2, 3], log
  end
end
