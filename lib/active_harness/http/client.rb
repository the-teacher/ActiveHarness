require "net/http"
require "json"

module ActiveHarness
  module Http
    # Thin HTTP POST adapter backed by Net::HTTP.
    #
    # To swap in Faraday (or any other client), assign a compatible object to
    # ActiveHarness.config.http_client:
    #
    #   class FaradayClient
    #     def post(url, headers:, body:, timeout:) = ...
    #   end
    #
    #   ActiveHarness.configure { |c| c.http_client = FaradayClient.new }
    #
    class Client
      # @param url     [URI]
      # @param headers [Hash{String => String}]
      # @param body    [String]   serialized request body
      # @param timeout [Integer]  seconds for both open and read timeout
      # @return        [String]   raw response body
      def post(url, headers:, body:, timeout:)
        http              = Net::HTTP.new(url.host, url.port)
        http.use_ssl      = true
        http.read_timeout = timeout
        http.open_timeout = timeout

        req      = Net::HTTP::Post.new(url)
        headers.each { |k, v| req[k] = v }
        req.body = body

        http.request(req).body
      rescue Net::ReadTimeout, Net::OpenTimeout
        raise Errors::TimeoutError, "Request timed out (#{url.host})"
      rescue => e
        raise Errors::ProviderUnavailableError, "#{url.host} unreachable: #{e.message}"
      end
    end
  end
end
