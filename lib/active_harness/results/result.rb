module ActiveHarness
  class Result
    SUCCESS = :success
    FAILED  = :failed
    BLOCKED = :blocked

    attr_reader :input, :output, :raw_response,
                :provider, :model, :usage, :attempts,
                :debug, :error

    def initialize(status:, input: nil, output: nil, raw_response: nil,
                   provider: nil, model: nil, usage: {}, attempts: [],
                   debug: nil, error: nil)
      @status       = status
      @input        = input
      @output       = output
      @raw_response = raw_response
      @provider     = provider
      @model        = model
      @usage        = usage
      @attempts     = attempts
      @debug        = debug
      @error        = error
    end

    def success?
      @status == SUCCESS
    end

    def failed?
      @status == FAILED
    end

    def blocked?
      @status == BLOCKED
    end

    # Factory helpers

    def self.success(input:, output:, raw_response:, provider:, model:,
                     usage:, attempts:, debug: nil)
      new(status: SUCCESS, input: input, output: output,
          raw_response: raw_response, provider: provider,
          model: model, usage: usage, attempts: attempts, debug: debug)
    end

    def self.blocked(input:, output: nil, debug: nil)
      new(status: BLOCKED, input: input, output: output, debug: debug)
    end

    def self.failed(error: nil, input: nil, debug: nil)
      new(status: FAILED, error: error, input: input, debug: debug)
    end
  end
end
