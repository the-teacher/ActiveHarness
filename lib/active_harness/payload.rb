module ActiveHarness
  # Unified request context — the single object available in every hook.
  #
  # Passed as the first argument to ALL before/after callbacks and to +setup+:
  #
  #   setup do |payload|
  #     payload.meta[:started_at] = Time.now
  #     payload                               # must return payload
  #   end
  #
  #   before :guards do |payload, input|      # input = String
  #     input.strip                           # return new String
  #   end
  #
  #   after  :guards do |payload, result|     # result = InputResult
  #     result                                # return InputResult
  #   end
  #
  #   before :request do |payload, prompt|    # prompt = { system:, user: }
  #     prompt                                # return Hash
  #   end
  #
  #   after  :request do |payload, response|  # response = ModelResponse
  #     response                              # return ModelResponse
  #   end
  #
  # Fields:
  #   input     — raw input text; can be modified in +setup+
  #   context   — runtime context Hash (e.g. user_id, session data)
  #   language  — language hint for guards / responses (e.g. :ru, :en)
  #   translate — callable: translate.(key) → localized string; key format: "scope.agent.message"
  #               typically built by an I18n module: Playground::I18n.translator(locale: language)
  #   options   — per-guard static options set at registration time
  #   meta      — free-form Hash for user-defined data (timestamps, flags, …)
  class Payload
    attr_accessor :input, :context, :language, :translate, :options, :meta

    def initialize(input:, context: {}, language: nil, translate: nil, options: {}, meta: {})
      @input     = input
      @context   = context
      @language  = language
      @translate = translate
      @options   = options
      @meta      = meta
    end
  end
end
