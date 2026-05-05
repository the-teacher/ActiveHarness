module ActiveHarness
  module Providers
    class Base
      # @param request [ModelRequest]
      # @return [ModelResponse]
      def call(request)
        raise NotImplementedError, "#{self.class}#call not implemented"
      end

      private

      def build_response(content:, provider:, model:, usage: {}, raw: nil)
        ModelResponse.new(
          content:  content,
          provider: provider,
          model:    model,
          usage:    usage,
          raw:      raw
        )
      end
    end
  end
end
