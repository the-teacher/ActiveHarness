module ActiveHarness
  class ModelResponse
    attr_reader :content, :provider, :model, :usage, :raw

    def initialize(content:, provider:, model:, usage: {}, raw: nil)
      @content  = content
      @provider = provider
      @model    = model
      @usage    = usage
      @raw      = raw
    end
  end
end
