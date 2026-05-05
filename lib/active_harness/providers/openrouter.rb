require "json"

module ActiveHarness
  module Providers
    # OpenRouter proxies many models (OpenAI, Anthropic, etc.) through a single API.
    # API is OpenAI-compatible with an extra "HTTP-Referer" header.
    class OpenRouter < Base
      API_URL = URI("https://openrouter.ai/api/v1/chat/completions")

      def call(request)
        body = build_body(request)
        raw  = post(body, request.timeout)
        data = JSON.parse(raw)

        handle_error!(data)

        content = data.dig("choices", 0, "message", "content").to_s.strip
        usage   = data["usage"] || {}

        build_response(
          content:  content,
          provider: :openrouter,
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
            "Authorization" => "Bearer #{api_key}",
            "HTTP-Referer"  => "https://github.com/the-teacher/ActiveHarness"
          },
          body:    body,
          timeout: timeout
        )
      end

      def handle_error!(data)
        return unless data["error"]

        error   = data["error"]
        message = error["message"].to_s
        code    = error["code"].to_s
        meta    = error.reject { |k, _| k == "message" }
        full    = meta.empty? ? message : "#{message} | #{meta.inspect}"

        case code
        when "401"
          raise Errors::InvalidApiKeyError, full
        when "429"
          raise Errors::RateLimitError, full
        else
          raise Errors::InvalidRequestError, full
        end
      end

      def api_key
        key = ActiveHarness.config.openrouter_api_key
        raise Errors::InvalidApiKeyError, "OPENROUTER_API_KEY not configured" if key.nil? || key.empty?
        key
      end
    end
  end
end
