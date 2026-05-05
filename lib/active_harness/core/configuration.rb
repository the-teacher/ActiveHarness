module ActiveHarness
  class Configuration
    attr_accessor :openai_api_key,
                  :openrouter_api_key,
                  :anthropic_api_key,
                  :google_api_key,
                  :default_timeout,
                  :default_temperature,
                  :default_language,
                  :guard_retries,
                  :log_requests,
                  :log_responses,
                  :debug,
                  :on_model_attempt,
                  :on_model_failure

    def initialize
      @openai_api_key      = ENV["OPENAI_API_KEY"]
      @openrouter_api_key  = ENV["OPENROUTER_API_KEY"]
      @anthropic_api_key   = ENV["ANTHROPIC_API_KEY"]
      @google_api_key      = ENV["GOOGLE_API_KEY"]

      @default_timeout     = 20
      @default_temperature = 0.2
      @default_language    = :en
      @guard_retries       = 2   # up to 3 total attempts (1 initial + 2 retries)

      @log_requests  = true
      @log_responses = false
      @debug         = false
    end

    # HTTP transport. Swap for a Faraday-backed client if needed:
    #   config.http_client = MyFaradayClient.new
    # Set to nil to let providers manage their own transport.
    def http_client
      @http_client ||= Http::Client.new
    end
    attr_writer :http_client

    # Sliding-window rate limiter (10 req/min per user_id by default).
    # Set to nil to disable.
    def request_limiter
      @request_limiter ||= RateLimit::RequestLimiter.new
    end
    attr_writer :request_limiter

    # Progressive hold-back after repeated risky requests.
    # Set to nil to disable.
    def risk_holdback
      @risk_holdback ||= RateLimit::RiskHoldback.new
    end
    attr_writer :risk_holdback
  end
end
