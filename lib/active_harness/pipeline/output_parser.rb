require "json"

module ActiveHarness
  # Parses the raw model response into the declared output type.
  class OutputParser
    def initialize(output_type, schema: nil)
      @output_type = output_type
      @schema      = schema
    end

    # @param content [String]
    # @return [String | Hash]
    def parse(content)
      case @output_type
      when :text then parse_text(content)
      when :json then parse_json(content)
      else raise Errors::ConfigurationError, "Unknown output type: #{@output_type.inspect}"
      end
    end

    private

    def parse_text(content)
      content.to_s
    end

    def parse_json(content)
      data = JSON.parse(content)
      validate_schema!(data) if @schema
      data
    rescue JSON::ParserError => e
      raise Errors::SchemaValidationError, "Model returned invalid JSON: #{e.message}"
    end

    def validate_schema!(data)
      @schema.each_key do |key|
        unless data.key?(key.to_s) || data.key?(key.to_sym)
          raise Errors::SchemaValidationError, "Missing required key in JSON output: #{key}"
        end
      end
    end
  end
end
