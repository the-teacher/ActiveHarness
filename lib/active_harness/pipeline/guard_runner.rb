require "json"

module ActiveHarness
  # Sends a single guard check request to the model and parses the response.
  # Instantiated and called by GuardAgent.call — not used directly from the pipeline.
  class GuardRunner
    # Required top-level fields in every guard JSON response.
    REQUIRED_FIELDS = %w[safe valid risk_level processed].freeze

    attr_reader :last_guard_prompt, :last_guard_response

    # @param guard_agent_class [Class]   subclass of Agent used in guard mode
    # @param payload           [Payload] the per-guard payload (input, context, language, options, …)
    def initialize(guard_agent_class, payload:)
      @guard_agent_class = guard_agent_class
      @payload           = payload
    end

    # @param raw       [String]  original, untransformed input
    # @param processed [String]  (possibly transformed) string to send to the model
    # @return [InputResult]
    def run(raw:, processed:)
      max_retries = @guard_agent_class.agent_config.fetch(:guard_retries) {
        ActiveHarness.config.guard_retries
      }

      system_msg    = build_system_message
      messages      = [system_msg, { role: "user", content: processed }]
      last_error    = nil

      (max_retries + 1).times do |attempt|
        if attempt > 0
          # Tell the model exactly what was wrong with its previous response.
          messages << { role: "assistant", content: @last_guard_response.to_s }
          messages << {
            role:    "user",
            content: "Your previous response was invalid: #{last_error}. " \
                     "Respond ONLY with valid JSON matching the required schema. " \
                     "Required fields: #{REQUIRED_FIELDS.join(', ')}."
          }
        end

        @last_guard_prompt = messages.dup

        model_cfg = @guard_agent_class.agent_config[:model]
        use_entry = model_cfg[:use]
        request   = ModelRequest.new(
          provider:        use_entry[:provider],
          model:           use_entry[:model],
          messages:        messages,
          response_format: :json
        )

        runner   = FallbackRunner.new(model_cfg)
        response = runner.run(request)

        @last_guard_response = response.content

        begin
          return parse_guard_response(raw, response.content)
        rescue Errors::GuardResponseError => e
          last_error = e.message
          # loop continues
        end
      end

      # All attempts exhausted — fail safe: treat as blocked.
      InputResult.new(
        raw:        raw,
        processed:  raw,
        safe:       false,
        valid:      false,
        risk_level: :high,
        errors:     ["Guard validation failed after #{max_retries + 1} attempt(s): #{last_error}"]
      )
    end

    private

    def build_system_message
      cfg    = @guard_agent_class.agent_config
      # Runtime language (from payload) takes priority over static system_language config,
      # which in turn takes priority over the global ActiveHarness.config.default_language.
      lang   = @payload.language || cfg[:system_language] || ActiveHarness.config.default_language || :en
      source = cfg[:system_prompt]

      prompt_text = if source.nil?
        Prompts::GuardSystemPrompt.prompt
      elsif source.respond_to?(:call)
        # Lambda / proc: ->(context, options) { ... }
        source.call(@payload.context, @payload.options)
      elsif source.is_a?(Module) && source.respond_to?(:prompt)
        # Class-based: .prompt or .prompt(context, options)
        source.method(:prompt).arity == 0 ? source.prompt : source.prompt(@payload.context, @payload.options)
      else
        source.to_s
      end

      { role: "system", content: "#{prompt_text}\nSystem language for 'processed' field: #{lang}" }
    end

    def parse_guard_response(raw_input, content)
      data = JSON.parse(content)

      missing = REQUIRED_FIELDS.reject { |f| data.key?(f) }
      unless missing.empty?
        raise Errors::GuardResponseError,
              "Missing required fields: #{missing.join(', ')}"
      end

      InputResult.new(
        raw:        raw_input,
        processed:  data["processed"],
        safe:       data["safe"] != false,
        valid:      data["valid"] != false,
        risk_level: (data["risk_level"] || "low").to_sym,
        errors:     Array(data["errors"]),
        intent:     data["intent"],
        reason:     data["reason"]
      )
    rescue JSON::ParserError => e
      raise Errors::GuardResponseError, "Invalid JSON: #{e.message}"
    end
  end
end
