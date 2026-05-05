require "test_helper"

class FallbackRunnerTest < Minitest::Test
  def model_config
    {
      use:       { provider: :openai,     model: "gpt-4.1" },
      fallbacks: [{ provider: :openrouter, model: "openai/gpt-4.1" }]
    }
  end

  def dummy_request
    ActiveHarness::ModelRequest.new(
      provider: :openai, model: "gpt-4.1",
      messages: [{ role: "user", content: "hi" }]
    )
  end

  def dummy_response(provider: :openai)
    ActiveHarness::ModelResponse.new(
      content: "reply", provider: provider, model: "gpt-4.1"
    )
  end

  def test_returns_first_successful_response
    provider = mock
    provider.expects(:call).returns(dummy_response)
    ActiveHarness::ProviderRegistry.stub(:find, ->(_p) { provider }) do
      runner   = ActiveHarness::FallbackRunner.new(model_config)
      response = runner.run(dummy_request)
      assert_equal "reply", response.content
    end
  end

  def test_falls_back_on_timeout
    failing  = mock
    success  = mock
    failing.expects(:call).raises(ActiveHarness::Errors::TimeoutError)
    success.expects(:call).returns(dummy_response(provider: :openrouter))

    call_count = 0
    ActiveHarness::ProviderRegistry.stub(:find, ->(_p) { call_count.zero? ? (call_count += 1; failing) : success }) do
      runner   = ActiveHarness::FallbackRunner.new(model_config)
      response = runner.run(dummy_request)
      assert_equal :openrouter, response.provider
      assert_equal 2, runner.attempts.size
      assert_equal :timeout, runner.attempts.first[:status]
      assert_equal :success, runner.attempts.last[:status]
    end
  end

  def test_stops_on_invalid_api_key
    provider = mock
    provider.expects(:call).raises(ActiveHarness::Errors::InvalidApiKeyError)

    ActiveHarness::ProviderRegistry.stub(:find, ->(_p) { provider }) do
      runner = ActiveHarness::FallbackRunner.new(model_config)
      assert_raises(ActiveHarness::Errors::InvalidApiKeyError) do
        runner.run(dummy_request)
      end
      assert_equal :stop, runner.attempts.first[:status]
    end
  end

  def test_raises_provider_error_when_all_fail
    provider = mock
    provider.stubs(:call).raises(ActiveHarness::Errors::TimeoutError)

    ActiveHarness::ProviderRegistry.stub(:find, ->(_p) { provider }) do
      runner = ActiveHarness::FallbackRunner.new(model_config)
      assert_raises(ActiveHarness::Errors::ProviderError) do
        runner.run(dummy_request)
      end
    end
  end
end
