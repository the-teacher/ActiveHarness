require "active_harness/core/version"
require "active_harness/core/errors"
require "active_harness/core/configuration"
require "active_harness/payload"

require "active_harness/http/client"
require "active_harness/http/retry_policy"

require "active_harness/rate_limit/request_limiter"
require "active_harness/rate_limit/risk_holdback"

require "active_harness/models/model_request"
require "active_harness/models/model_response"
require "active_harness/results/input_result"
require "active_harness/results/debug_result"
require "active_harness/results/result"

require "active_harness/providers/base"
require "active_harness/providers/openai"
require "active_harness/providers/openrouter"
require "active_harness/providers/anthropic"
require "active_harness/providers/google"

require "active_harness/prompts/guard_system_prompt"

require "active_harness/pipeline/provider_registry"
require "active_harness/pipeline/prompt_builder"
require "active_harness/pipeline/output_parser"
require "active_harness/pipeline/fallback_runner"
require "active_harness/pipeline/guard_runner"
require "active_harness/pipeline/engine"
require "active_harness/agent"

module ActiveHarness
  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end
    alias config configuration

    def reset!
      @configuration = nil
    end
  end
end
