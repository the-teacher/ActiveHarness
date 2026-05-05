require "test_helper"

class OutputParserTest < Minitest::Test
  def test_text_passthrough
    parser = ActiveHarness::OutputParser.new(:text)
    assert_equal "hello world", parser.parse("hello world")
  end

  def test_json_parsing
    parser = ActiveHarness::OutputParser.new(:json)
    result = parser.parse('{"key":"value"}')
    assert_equal({ "key" => "value" }, result)
  end

  def test_json_schema_validation_passes
    parser = ActiveHarness::OutputParser.new(:json, schema: { category: "string" })
    assert_equal({ "category" => "support" }, parser.parse('{"category":"support"}'))
  end

  def test_json_schema_validation_fails_on_missing_key
    parser = ActiveHarness::OutputParser.new(:json, schema: { category: "string" })
    assert_raises(ActiveHarness::Errors::SchemaValidationError) do
      parser.parse('{"other":"value"}')
    end
  end

  def test_invalid_json_raises_schema_error
    parser = ActiveHarness::OutputParser.new(:json)
    assert_raises(ActiveHarness::Errors::SchemaValidationError) do
      parser.parse("not json")
    end
  end

  def test_unknown_type_raises_configuration_error
    parser = ActiveHarness::OutputParser.new(:xml)
    assert_raises(ActiveHarness::Errors::ConfigurationError) do
      parser.parse("<root/>")
    end
  end
end
