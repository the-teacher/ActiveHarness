module ActiveHarness
  # DSL base class for agents and guard agents — one class, two roles.
  #
  # Main agent (class-method style — one-liner):
  #   SupportAgent.call(input: "hi", context: {})
  #
  # Main agent (instance style — store params, call later):
  #   agent  = SupportAgent.new(input: "hi", language: :ru, context: {})
  #   result = agent.call
  #   result = agent.call(constraints: { max_input_length: 200 })  # merge extra params
  #
  # Guard agent (same class, called positionally by the engine guard chain):
  #   class InjectionGuard < ActiveHarness::Agent
  #     model { use provider: :openai, model: "gpt-4.1-mini" }
  #     system_prompt MyGuardPrompt
  #     system_language :en
  #   end
  class Agent
    class << self
      # Entry point.
      #
      # Main mode:  MyAgent.call(input: "...", context: {}, language: :en, translate: fn)
      # Guard mode: MyGuard.call(payload)            — called by the engine guard chain
      #             MyGuard.call("raw string")        — manual / test use
      #             MyGuard.call(prev_input_result)   — manual / test use
      def call(*args, input: nil, context: {}, constraints: {}, language: nil, translate: nil, options: {})
        if args.any?
          first   = args.first
          payload = first.is_a?(Payload) ? first : Payload.new(
            input:     first.is_a?(InputResult) ? first.processed : first.to_s,
            context:   context,
            language:  language,
            translate: translate,
            options:   options
          )
          call_as_guard(payload)
        else
          Engine.new(agent_config).call(
            input: input, context: context, constraints: constraints,
            language: language, translate: translate
          )
        end
      end

      # DSL -------------------------------------------------------------------

      def system_language(lang)
        agent_config[:system_language] = lang
      end

      # Registers a guard class for the safety chain (main agent only).
      # Optional per-registration options are forwarded to the guard at call time.
      # If name: is not given, defaults to the class name as a symbol (e.g., :InjectionGuard).
      #
      # Examples:
      #   guard InjectionGuard
      #   guard InjectionGuard, name: :injection_guard
      #   guard TopicGuard, name: :topic, allowed_topics: [:ruby, :programming]
      def guard(klass, name: nil, **options)
        guard_name = (name || klass.name).to_sym
        agent_config[:guards] ||= []
        agent_config[:guards] << { klass: klass, options: options, name: guard_name }
      end

      def model(&block)
        config = ModelConfig.new
        config.instance_eval(&block)
        agent_config[:model] = config.to_h
      end

      def param(name, required: false)
        agent_config[:params]          ||= []
        agent_config[:required_params] ||= []
        agent_config[:params] << { name: name, required: required }
        agent_config[:required_params] << name if required
      end

      def system_prompt(text)
        agent_config[:system_prompt] = text
      end
      alias prompt system_prompt

      def output(type, schema: nil)
        agent_config[:output_type]   = type
        agent_config[:output_schema] = schema
      end

      def risk_tolerance(level)
        agent_config[:risk_tolerance] = level
      end

      # Declares a default constraint for this agent.
      # Call-time constraints (passed to .call) override agent-level defaults.
      #
      # Supported constraints:
      #   constraint :max_input_length, 500   # reject inputs longer than 500 chars
      def constraint(name, value)
        agent_config[:constraints]       ||= {}
        agent_config[:constraints][name]   = value
      end

      # How many times to retry when a guard returns invalid/unparseable JSON.
      # Overrides ActiveHarness.config.guard_retries for this specific guard.
      def guard_retries(n)
        agent_config[:guard_retries] = n
      end

      # Accepts a String or a callable (proc/lambda).
      # When a callable is given, it is called with the Payload at block time:
      #   default_error_answer ->(payload) { payload.translate&.call("my.key") || "Fallback text" }
      def default_error_answer(text_or_callable)
        agent_config[:default_error_answer] = text_or_callable
      end

      # Initializer hook — runs once before the pipeline starts.
      # Receives the Payload and must return it (optionally modified).
      #
      # Example:
      #   setup do |payload|
      #     payload.meta[:started_at] = Time.now
      #     payload.context[:locale]  = determine_locale(payload.language)
      #     payload
      #   end
      def setup(&block)
        agent_config[:setup] = block
      end

      # Callbacks ------------------------------------------------------------
      # All callbacks receive TWO arguments — (payload, current_value) — and
      # must return the new current_value.  The payload is read-only context;
      # current_value is what gets threaded through the pipeline stage.
      #
      # Main-agent pipeline hooks:
      #   before(:guards)  { |payload, input|    input.strip   }  # String  → String
      #   after(:guards)   { |payload, result|   result        }  # InputResult → InputResult
      #   before(:guard, :injection_guard) { |payload, input| input.downcase }
      #   after(:guard,  :injection_guard) { |payload, result| result }
      #   before(:request) { |payload, prompt|   prompt        }  # Hash → Hash
      #   after(:request)  { |payload, response| response      }  # ModelResponse → ModelResponse
      #
      # Guard-mode hooks (when *this* class acts as a guard):
      #   before { |payload, input|  input.strip  }  # String → String
      #   after  { |payload, result| result        }  # InputResult → InputResult
      def before(hook = nil, guard_name = nil, &block)
        if hook
          key = (hook == :guard && guard_name) ? :"before_guard_#{guard_name}" : :"before_#{hook}"
          agent_config[:callbacks] ||= {}
          agent_config[:callbacks][key] ||= []
          agent_config[:callbacks][key] << block
        else
          agent_config[:guard_before_callbacks] ||= []
          agent_config[:guard_before_callbacks] << block
        end
      end

      def after(hook = nil, guard_name = nil, &block)
        if hook
          key = (hook == :guard && guard_name) ? :"after_guard_#{guard_name}" : :"after_#{hook}"
          agent_config[:callbacks] ||= {}
          agent_config[:callbacks][key] ||= []
          agent_config[:callbacks][key] << block
        else
          agent_config[:guard_after_callbacks] ||= []
          agent_config[:guard_after_callbacks] << block
        end
      end

      # Debug info from the most recent guard-mode .call (class-level).
      attr_reader :last_run_prompt, :last_run_response

      # Each subclass gets its own isolated config hash.
      def agent_config
        @agent_config ||= {}
      end

      private

      def call_as_guard(payload)
        # Run the guard's own setup hook (if defined)
        setup_block = agent_config[:setup]
        payload     = setup_block.call(payload) if setup_block

        raw = payload.input

        # Guard-mode before callbacks: (payload, String) → String
        processed = run_guard_callbacks(agent_config[:guard_before_callbacks], payload, raw)

        runner             = GuardRunner.new(self, payload: payload)
        result             = runner.run(raw: raw, processed: processed)
        @last_run_prompt   = runner.last_guard_prompt
        @last_run_response = runner.last_guard_response

        # Guard-mode after callbacks: (payload, InputResult) → InputResult
        run_guard_callbacks(agent_config[:guard_after_callbacks], payload, result)
      end

      # Threads +current+ through each callback as (payload, current) → new_current.
      def run_guard_callbacks(callbacks, payload, current)
        Array(callbacks).reduce(current) { |val, cb| cb.call(payload, val) }
      end
    end

    # -------------------------------------------------------------------------
    # Instance API
    # -------------------------------------------------------------------------

    # Build an agent instance with preset call parameters.
    # Any keyword accepted by .call is valid here.
    #
    #   agent  = SupportAgent.new(input: "hello", language: :ru)
    #   result = agent.call                              # use stored params
    #   result = agent.call(constraints: { max_input_length: 200 })  # merge overrides
    def initialize(input: nil, context: {}, constraints: {}, language: nil,
                   translate: nil, options: {})
      @stored_params = {
        input:       input,
        context:     context,
        constraints: constraints,
        language:    language,
        translate:   translate,
        options:     options
      }
    end

    # Execute the agent.  +overrides+ is merged into the stored params —
    # any key present in overrides wins.
    def call(**overrides)
      params = @stored_params.merge(overrides) do |_key, stored, override|
        # For Hash values (context, constraints) do a shallow merge so callers
        # can add keys without replacing the whole hash.
        (stored.is_a?(Hash) && override.is_a?(Hash)) ? stored.merge(override) : override
      end
      self.class.call(**params)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helper — collects the `use` + `fallback` entries inside a `model` block.
  # ---------------------------------------------------------------------------
  class ModelConfig
    def initialize
      @config = { fallbacks: [] }
    end

    def use(provider:, model:)
      @config[:use] = { provider: provider, model: model }
    end

    def fallback(provider:, model:)
      @config[:fallbacks] << { provider: provider, model: model }
    end

    def to_h
      @config
    end
  end
end
