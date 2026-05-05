module ActiveHarness
  module Errors
    # Base
    class Error < StandardError; end

    # Configuration
    class ConfigurationError < Error; end
    class ContextValidationError < Error; end

    # Provider — retryable (fallback chain continues)
    class ProviderError < Error; end
    class TimeoutError              < ProviderError; end
    class RateLimitError            < ProviderError; end
    class ProviderUnavailableError  < ProviderError; end
    class ServerError               < ProviderError; end

    # Provider — terminal (fallback chain stops)
    class InvalidRequestError       < ProviderError; end
    class InvalidApiKeyError        < ProviderError; end
    class SafetyBlockedError        < ProviderError; end

    # Output
    class SchemaValidationError < Error; end
    class OutputParsingError    < Error; end

    # Guard — raised when the guard model returns unparseable or schema-invalid JSON.
    # Triggers the retry loop inside GuardRunner.
    class GuardResponseError < Error; end

    # Input constraints (max_input_length, etc.)
    class ConstraintViolationError < Error; end

    # Throttling (application-level, not provider-level)
    class ThrottleError          < Error; end
    class RequestThrottledError  < ThrottleError; end  # sliding-window rate limit
    class UserHoldbackError      < ThrottleError; end  # progressive risk hold-back
  end
end
