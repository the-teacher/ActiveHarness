module ActiveHarness
  module RateLimit
    # Progressive hold-back for users who repeatedly submit risky requests.
    #
    # Every RISKY_THRESHOLD blocked requests trigger a hold. The hold duration
    # escalates with each offense:
    #
    #   Offense 1 (3rd  risky request) →  5 minutes
    #   Offense 2 (6th  risky request) → 30 minutes
    #   Offense 3+ (9th+ risky request) →  2 hours
    #
    # Storage is in-memory (per-process). Thread-safe via Mutex.
    #
    # Usage:
    #   holdback = RiskHoldback.new
    #   holdback.check!(user_id)           # before each request; raises if held
    #   holdback.record_risky!(user_id)    # after guard blocks a request
    #
    class RiskHoldback
      RISKY_THRESHOLD = 3
      HOLD_SCHEDULE   = [5 * 60, 30 * 60, 2 * 60 * 60].freeze  # 5 min / 30 min / 2 h

      # @param risky_threshold [Integer]  number of risky requests before a hold is applied
      def initialize(risky_threshold: RISKY_THRESHOLD)
        @risky_threshold = risky_threshold
        @state           = {}
        @mutex           = Mutex.new
      end

      # Records a risky (guard-blocked) request for the user.
      # Applies a hold when the count reaches the next threshold multiple.
      # @param user_id [String, Integer, nil]  nil is a no-op
      def record_risky!(user_id)
        return if user_id.nil?

        key = user_id.to_s
        @mutex.synchronize do
          s = @state[key] ||= { risky_count: 0, offense_count: 0, held_until: nil }
          s[:risky_count] += 1

          if (s[:risky_count] % @risky_threshold).zero?
            offense_idx      = [s[:offense_count], HOLD_SCHEDULE.size - 1].min
            s[:held_until]   = Time.now.to_f + HOLD_SCHEDULE[offense_idx]
            s[:offense_count] += 1
          end
        end
      end

      # Raises if the user is currently held back due to risky behaviour.
      # @param user_id [String, Integer, nil]  nil disables the check
      # @raise [Errors::UserHoldbackError]
      def check!(user_id)
        return if user_id.nil?

        key = user_id.to_s
        @mutex.synchronize do
          s = @state[key]
          return unless s&.dig(:held_until)
          return if Time.now.to_f >= s[:held_until]

          remaining = (s[:held_until] - Time.now.to_f).ceil
          raise Errors::UserHoldbackError,
            "Requests paused due to repeated safety violations. " \
            "Retry in #{remaining}s (user: #{key})"
        end
      end
    end
  end
end
