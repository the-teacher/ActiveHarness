module ActiveHarness
  module RateLimit
    # Sliding-window rate limiter. Tracks request timestamps per user_id
    # and raises if the limit is exceeded within the rolling time window.
    #
    # Storage is in-memory (per-process). For multi-process environments,
    # replace with a shared backend (Redis, Memcached, etc.) by subclassing
    # and overriding #timestamps_for / #record_timestamp.
    #
    # Usage:
    #   limiter = RequestLimiter.new(max_requests: 10, window_seconds: 60)
    #   limiter.check!(user_id)   # call before each request; raises if over limit
    #
    class RequestLimiter
      DEFAULT_MAX    = 10
      DEFAULT_WINDOW = 60  # seconds

      # @param max_requests   [Integer]  maximum allowed requests per window
      # @param window_seconds [Integer]  length of the sliding window in seconds
      def initialize(max_requests: DEFAULT_MAX, window_seconds: DEFAULT_WINDOW)
        @max_requests   = max_requests
        @window_seconds = window_seconds
        @log            = Hash.new { |h, k| h[k] = [] }
        @mutex          = Mutex.new
      end

      # Records this request and raises if the limit has been reached.
      # @param user_id [String, Integer, nil]  nil disables the check
      # @raise [Errors::RequestThrottledError]
      def check!(user_id)
        return if user_id.nil?

        key    = user_id.to_s
        now    = Time.now.to_f
        cutoff = now - @window_seconds

        @mutex.synchronize do
          @log[key].reject! { |t| t < cutoff }

          if @log[key].size >= @max_requests
            raise Errors::RequestThrottledError,
              "Rate limit exceeded: #{@max_requests} requests/#{@window_seconds}s (user: #{key})"
          end

          @log[key] << now
        end
      end
    end
  end
end
