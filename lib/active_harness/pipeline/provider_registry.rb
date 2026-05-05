module ActiveHarness
  class ProviderRegistry
    PROVIDERS = {
      openai:      Providers::OpenAI,
      openrouter:  Providers::OpenRouter,
      anthropic:   Providers::Anthropic,
      google:      Providers::Google
    }.freeze

    def self.find(provider_name)
      klass = PROVIDERS[provider_name.to_sym]
      raise Errors::ConfigurationError, "Unknown provider: #{provider_name}" unless klass
      klass.new
    end
  end
end
