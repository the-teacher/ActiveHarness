module ActiveHarness
  # Executes a model request against a fallback chain.
  # Returns a ModelResponse on the first successful attempt.
  class FallbackRunner
    RETRYABLE_ERRORS = [
      Errors::TimeoutError,
      Errors::RateLimitError,
      Errors::ProviderUnavailableError,
      Errors::ServerError
    ].freeze

    STOP_ERRORS = [
      Errors::InvalidRequestError,
      Errors::InvalidApiKeyError,
      Errors::SafetyBlockedError,
      Errors::SchemaValidationError
    ].freeze

    RETRYABLE_STATUS = {
      Errors::TimeoutError             => :timeout,
      Errors::RateLimitError           => :rate_limit,
      Errors::ProviderUnavailableError => :provider_unavailable,
      Errors::ServerError              => :server_error
    }.freeze

    attr_reader :attempts

    def initialize(model_config)
      @model_config = model_config
      @attempts     = []
    end

    # @param request [ModelRequest]  — template; provider/model will be overridden per entry
    # @return [ModelResponse]
    def run(request)
      chain.each do |entry|
        provider = ProviderRegistry.find(entry[:provider])
        req      = adapt(request, entry)

        begin
          ActiveHarness.config.on_model_attempt&.call(entry[:provider], entry[:model])
          response = provider.call(req)
          @attempts << { provider: entry[:provider], model: entry[:model], status: :success }
          return response
        rescue *STOP_ERRORS => e
          @attempts << { provider: entry[:provider], model: entry[:model], status: :stop, error: e.message }
          raise
        rescue *RETRYABLE_ERRORS => e
          status = RETRYABLE_STATUS.fetch(e.class, :error)
          @attempts << { provider: entry[:provider], model: entry[:model], status: status, error: e.message }
          ActiveHarness.config.on_model_failure&.call(entry[:provider], entry[:model], status, e.message)
          next
        end
      end

      raise Errors::ProviderError, "All providers failed. Attempts: #{@attempts.inspect}"
    end

    private

    def chain
      [@model_config[:use]] + Array(@model_config[:fallbacks])
    end

    def adapt(original, entry)
      ModelRequest.new(
        provider:        entry[:provider],
        model:           entry[:model],
        messages:        original.messages,
        temperature:     original.temperature,
        timeout:         original.timeout,
        response_format: original.response_format
      )
    end
  end
end
