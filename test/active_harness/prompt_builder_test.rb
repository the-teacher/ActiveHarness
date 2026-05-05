require "test_helper"

class PromptBuilderTest < Minitest::Test
  def safe_input
    ActiveHarness::InputResult.new(
      raw: "original", processed: "normalized input",
      safe: true, valid: true
    )
  end

  def test_builds_system_prompt_from_string
    config  = { system_prompt: "You are helpful.", output_type: :text }
    builder = ActiveHarness::PromptBuilder.new(config)
    prompt  = builder.build(safe_input)

    assert_equal "You are helpful.", prompt[:system]
  end

  def test_builds_system_prompt_from_class
    klass = Module.new do
      def self.prompt
        "You are a class-based assistant."
      end
    end

    config  = { system_prompt: klass }
    builder = ActiveHarness::PromptBuilder.new(config)
    prompt  = builder.build(safe_input)

    assert_equal "You are a class-based assistant.", prompt[:system]
  end

  def test_user_message_is_processed_input
    config  = { system_prompt: "sys" }
    builder = ActiveHarness::PromptBuilder.new(config)
    prompt  = builder.build(safe_input)

    assert_equal "normalized input", prompt[:user]
  end

  def test_appends_respond_in_language_when_given
    config  = { system_prompt: "You are helpful." }
    builder = ActiveHarness::PromptBuilder.new(config)
    prompt  = builder.build(safe_input, language: :ru)

    assert_includes prompt[:system], "You are helpful."
    assert_includes prompt[:system], "Respond in the following language: ru."
  end

  def test_no_language_instruction_when_language_nil
    config  = { system_prompt: "You are helpful." }
    builder = ActiveHarness::PromptBuilder.new(config)
    prompt  = builder.build(safe_input)

    refute_includes prompt[:system], "Respond in"
  end
end
