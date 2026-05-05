module ActiveHarness
  # Orchestrates the full agent execution pipeline:
  #   validate_context → check_rate_limits → [guard chain] → build_prompt → run_with_fallback → parse_output → result
  class Engine
    def initialize(agent_config)
      @agent_config = agent_config
    end

    # @param input       [String]
    # @param context     [Hash]
    # @param constraints [Hash]
    # @param language    [Symbol, String, nil]  language hint forwarded to guards
    # @param translate   [#call, nil]           translation callable
    # @return [Result]
    def call(input:, context: {}, constraints: {}, language: nil, translate: nil)
      debug_data = {}

      validate_context!(context)
      check_rate_limits!(context[:user_id])

      # Build the unified payload and run the agent's setup hook (if any).
      payload = Payload.new(input: input, context: context, language: language, translate: translate)
      if (setup_block = @agent_config[:setup])
        payload = setup_block.call(payload)
      end

      # Constraint validation — runs after setup so stripped/normalized input is measured.
      merged_constraints = (@agent_config[:constraints] || {}).merge(constraints)
      validate_constraints!(payload.input, merged_constraints)

      # Guard phase — callbacks receive (payload, current_value) → new_current_value
      payload.input = run_callbacks(:before_guards, payload, payload.input, debug_data)
      guard_result  = run_guards(payload, debug_data)
      guard_result  = run_callbacks(:after_guards,  payload, guard_result,  debug_data)

      if blocked_by_guard?(guard_result)
        record_risky!(context[:user_id])
        answer = @agent_config[:default_error_answer]
        answer = answer.call(payload) if answer.respond_to?(:call)
        return Result.blocked(
          input:  guard_result,
          output: answer,
          debug:  build_debug(debug_data)
        )
      end

      # Request phase
      prompt   = build_prompt_hash(guard_result, payload.context, constraints, debug_data, language: payload.language)
      prompt   = run_callbacks(:before_request, payload, prompt,   debug_data)
      runner   = run_primary(prompt)
      response = runner[:response]
      response = run_callbacks(:after_request,  payload, response, debug_data)
      attempts = runner[:attempts]

      output   = parse_output(response.content)

      Result.success(
        input:        guard_result,
        output:       output,
        raw_response: response.content,
        provider:     response.provider,
        model:        response.model,
        usage:        response.usage,
        attempts:     attempts,
        debug:        build_debug(debug_data)
      )
    rescue Errors::ContextValidationError => e
      Result.failed(error: e, debug: build_debug(debug_data))
    rescue Errors::ConstraintViolationError => e
      Result.failed(error: e, debug: build_debug(debug_data))
    rescue Errors::ThrottleError => e
      Result.failed(error: e, debug: build_debug(debug_data))
    rescue Errors::ProviderError, Errors::SchemaValidationError => e
      Result.failed(error: e, debug: build_debug(debug_data))
    end

    private

    RISK_LEVELS = { low: 0, medium: 1, high: 2 }.freeze

    # Runs each callback as cb.(payload, current) → new_current.
    # The payload is the stable request context; current is the value being transformed.
    def run_callbacks(hook, payload, current, debug_data = {})
      callbacks = (@agent_config.dig(:callbacks, hook) || [])
      return current if callbacks.empty?

      callbacks.reduce(current) do |val, cb|
        result = cb.call(payload, val)
        if ActiveHarness.config.debug
          debug_data[:callback_log] ||= []
          debug_data[:callback_log] << {
            hook:   hook,
            before: summarize(val),
            after:  summarize(result)
          }
        end
        result
      end
    end

    def summarize(obj)
      case obj
      when String        then obj.length > 120 ? "#{obj.slice(0, 120)}..." : obj
      when Hash          then obj.transform_values { |v| v.to_s.slice(0, 80) }
      when InputResult   then "InputResult(safe=#{obj.safe?}, valid=#{obj.valid?}, risk=#{obj.risk_level}, processed=#{obj.processed.to_s.slice(0, 60)})"
      when ModelResponse then "ModelResponse(provider=#{obj.provider}, model=#{obj.model}, content=#{obj.content.to_s.slice(0, 60)})"
      else               obj.class.name
      end
    end

    def blocked_by_guard?(guard_result)
      return true unless guard_result.valid?
      return false if guard_result.safe?

      tolerance = @agent_config[:risk_tolerance] || :low
      level     = guard_result.risk_level

      (RISK_LEVELS[level.to_sym] || 0) >= (RISK_LEVELS[tolerance.to_sym] || 0)
    end

    def validate_context!(context)
      required = Array(@agent_config[:required_params])
      required.each do |param|
        raise Errors::ContextValidationError, "Missing required context param: #{param}" unless context.key?(param)
      end
    end

    def validate_constraints!(input, constraints)
      return if constraints.empty?
      if (max = constraints[:max_input_length])
        len = input.to_s.length
        if len > max
          raise Errors::ConstraintViolationError,
                "Input too long: #{len} chars (max #{max})"
        end
      end
    end

    def check_rate_limits!(user_id)
      ActiveHarness.config.request_limiter&.check!(user_id)
      ActiveHarness.config.risk_holdback&.check!(user_id)
    end

    def record_risky!(user_id)
      ActiveHarness.config.risk_holdback&.record_risky!(user_id)
    end

    # Runs every registered guard in sequence.
    # Each guard receives its own Payload (built from the parent payload + guard options).
    # The main agent's before/after_guard_:name callbacks wrap each individual guard call.
    # Stops as soon as a guard returns safe: false or valid: false.
    #
    # Guard entries can be:
    #   { klass: MyGuard, name: :injection_guard, options: { … } }  — registered via DSL
    #   MyGuard                                                      — plain class (test/manual use)
    def run_guards(payload, debug_data)
      guard_entries = Array(@agent_config[:guards])
      debug_data[:guard_runs] = []

      if guard_entries.empty?
        return pass_through_input(payload.input)
      end

      guard_result = nil
      guard_entries.each do |entry|
        guard_class   = entry.is_a?(Hash) ? entry[:klass]   : entry
        guard_options = entry.is_a?(Hash) ? entry[:options] : {}
        guard_name    = entry.is_a?(Hash) ? entry[:name]    : guard_class.name.to_sym

        # String that will be sent to this guard
        current_input = guard_result.nil? ? payload.input : guard_result.processed

        # Main agent's before_guard_:name: (payload, String) → String
        current_input = run_callbacks(:"before_guard_#{guard_name}", payload, current_input, debug_data)

        # Build a per-guard payload so the guard's own setup/callbacks see the right options
        guard_payload = Payload.new(
          input:     current_input,
          context:   payload.context,
          language:  payload.language,
          translate: payload.translate,
          options:   guard_options,
          meta:      payload.meta.dup
        )

        # Call the guard — returns InputResult
        guard_result = guard_class.call(guard_payload)

        # Main agent's after_guard_:name: (payload, InputResult) → InputResult
        guard_result = run_callbacks(:"after_guard_#{guard_name}", payload, guard_result, debug_data)

        debug_data[:guard_runs] << {
          guard:    guard_class.name,
          name:     guard_name,
          options:  guard_options,
          prompt:   guard_class.last_run_prompt,
          response: guard_class.last_run_response
        }

        break unless guard_result.safe? && guard_result.valid?
      end

      guard_result
    end

    def pass_through_input(raw_input)
      InputResult.new(
        raw: raw_input, processed: raw_input,
        safe: true, valid: true, risk_level: :low
      )
    end

    def build_prompt_hash(guard_result, context, constraints, debug_data, language: nil)
      prompt = PromptBuilder.new(@agent_config).build(guard_result, context, constraints, language: language)
      debug_data[:system_prompt] = prompt[:system]
      prompt
    end

    def run_primary(prompt)
      use_entry = @agent_config.dig(:model, :use)
      request   = ModelRequest.new(
        provider: use_entry[:provider],
        model:    use_entry[:model],
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user",   content: prompt[:user]   }
        ]
      )
      runner   = FallbackRunner.new(@agent_config[:model])
      response = runner.run(request)
      { response: response, attempts: runner.attempts }
    end

    def parse_output(content)
      OutputParser.new(
        @agent_config[:output_type]   || :text,
        schema: @agent_config[:output_schema]
      ).parse(content)
    end

    def build_debug(debug_data)
      return nil unless ActiveHarness.config.debug

      DebugResult.new(
        system_prompt: debug_data[:system_prompt],
        guard_runs:    debug_data[:guard_runs] || [],
        callback_log:  debug_data[:callback_log] || []
      )
    end
  end
end
