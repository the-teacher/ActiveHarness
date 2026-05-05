module ActiveHarness
  # Holds the result of the guard (input safety) layer.
  class InputResult
    attr_reader :raw, :processed, :errors, :risk_level, :intent, :reason

    def initialize(raw:, processed:, safe:, valid:,
                   risk_level: :low, errors: [],
                   intent: nil, reason: nil)
      @raw        = raw
      @processed  = processed
      @safe       = safe
      @valid      = valid
      @risk_level = risk_level
      @errors     = errors
      @intent     = intent
      @reason     = reason
    end

    def safe?
      @safe
    end

    def valid?
      @valid
    end
  end
end
