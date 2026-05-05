module ActiveHarness
  module Http
    # Wraps a block with automatic retry on transient errors.
    # Uses exponential backoff: delay doubles after each failed attempt.
    #
    # Example:
    #   RetryPolicy.new(max_attempts: 3, base_delay: 0.5).run do
    #     http_client.post(...)
    #   end
    #
    # Custom errors:
    #   RetryPolicy.new(errors: [MyTransientError]).run { ... }
    #
    class RetryPolicy
      DEFAULT_ERRORS = [
        Errors::TimeoutError,
        Errors::RateLimitError,
        Errors::ProviderUnavailableError,
        Errors::ServerError
      ].freeze

      # @param max_attempts [Integer]  total number of attempts (first + retries)
      # @param base_delay   [Float]    delay before 1st retry in seconds; doubles each round
      # @param errors       [Array]    error classes that trigger a retry
      def initialize(max_attempts: 3, base_delay: 1.0, errors: DEFAULT_ERRORS)
        @max_attempts = max_attempts
        @base_delay   = base_delay
        @errors       = errors
      end

      # @yieldreturn [Object] result of the block on success
      # @raise last error after all attempts are exhausted
      def run
        attempt = 0
        begin
          attempt += 1
          yield
        rescue *@errors
          raise if attempt >= @max_attempts

          sleep(@base_delay * (2**(attempt - 1)))
          retry
        end
      end
    end
  end
end
