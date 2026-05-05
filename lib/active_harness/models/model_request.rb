module ActiveHarness
  class ModelRequest
    attr_reader :provider, :model, :messages, :temperature, :timeout, :response_format

    def initialize(provider:, model:, messages:, temperature: nil, timeout: nil, response_format: nil)
      @provider        = provider
      @model           = model
      @messages        = messages
      @temperature     = temperature || ActiveHarness.config.default_temperature
      @timeout         = timeout     || ActiveHarness.config.default_timeout
      @response_format = response_format
    end
  end
end
