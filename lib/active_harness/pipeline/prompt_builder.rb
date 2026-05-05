module ActiveHarness
  # Assembles system and user messages from agent DSL config.
  #
  # system_prompt accepts:
  #   - String
  #   - Class/module with .prompt -> String
  #
  # The user message is always safe_input.processed (the guard-normalized input).
  class PromptBuilder
    def initialize(agent_config)
      @agent_config = agent_config
    end

    # @param safe_input  [InputResult]
    # @param language     [Symbol, String, nil]  response language (e.g. :ru, :ko)
    # @return [Hash]  { system: String, user: String }
    def build(safe_input, _context = {}, _constraints = {}, language: nil)
      {
        system: build_system(language),
        user:   safe_input.processed
      }
    end

    private

    def build_system(language = nil)
      source = @agent_config[:system_prompt]
      text   = if source.nil?
        ""
      elsif prompt_class?(source)
        source.prompt
      else
        source.to_s
      end

      # Append explicit response-language instruction so the LLM always replies
      # in the user's language regardless of what language the system prompt is in.
      text += "\n\nRespond in the following language: #{language}." if language
      text
    end

    def prompt_class?(obj)
      obj.is_a?(Module) && obj.respond_to?(:prompt)
    end
  end
end
