require "json"

module ActiveHarness
  module Providers
    class OpenAI < Base
      API_URL = URI("https://api.openai.com/v1/chat/completions")

      def call(request)
        body     = build_body(request)
        raw      = post(body, request.timeout)
        data     = JSON.parse(raw)

        handle_error!(data)

        content = data.dig("choices", 0, "message", "content").to_s.strip
        usage   = data["usage"] || {}

        build_response(
          content:  content,
          provider: :openai,
          model:    data["model"] || request.model,
          usage:    { prompt: usage["prompt_tokens"], completion: usage["completion_tokens"] },
          raw:      raw
        )
      end

      private

      def build_body(request)
        body = {
          model:       request.model,
          messages:    request.messages,
          temperature: request.temperature
        }
        body[:response_format] = { type: "json_object" } if request.response_format == :json
        body.to_json
      end

      def post(body, timeout)
        ActiveHarness.config.http_client.post(
          API_URL,
          headers: {
            "Content-Type"  => "application/json",
            "Authorization" => "Bearer #{api_key}"
          },
          body:    body,
          timeout: timeout
        )
      end

      def handle_error!(data)
        return unless data["error"]

        message = data.dig("error", "message").to_s
        code    = data.dig("error", "code").to_s

        case code
        when "invalid_api_key", "unauthorized"
          raise Errors::InvalidApiKeyError, message
        when "rate_limit_exceeded"
          raise Errors::RateLimitError, message
        when "content_filter"
          raise Errors::SafetyBlockedError, message
        else
          raise Errors::InvalidRequestError, message
        end
      end

      def api_key
        key = ActiveHarness.config.openai_api_key
        raise Errors::InvalidApiKeyError, "OPENAI_API_KEY not configured" if key.nil? || key.empty?
        key
      end
    end
  end
end
