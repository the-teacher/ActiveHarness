module ActiveHarness
  module Providers
    # Phase 2 — Anthropic (Claude) adapter
    class Anthropic < Base
      def call(_request)
        # TODO: implement Anthropic Messages API
        raise NotImplementedError, "Anthropic adapter is planned for phase 2"
      end
    end
  end
end
