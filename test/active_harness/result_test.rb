require "test_helper"

class ResultTest < Minitest::Test
  def test_success_result
    result = ActiveHarness::Result.success(
      input: :input, output: "ok", raw_response: "ok",
      provider: :openai, model: "gpt-4.1",
      usage: {}, attempts: []
    )

    assert result.success?
    refute result.failed?
    refute result.blocked?
    assert_equal "ok", result.output
  end

  def test_blocked_result
    result = ActiveHarness::Result.blocked(input: :guard_result)

    assert result.blocked?
    refute result.success?
    refute result.failed?
  end

  def test_failed_result
    error  = StandardError.new("boom")
    result = ActiveHarness::Result.failed(error: error)

    assert result.failed?
    refute result.success?
    refute result.blocked?
    assert_equal error, result.error
  end
end
