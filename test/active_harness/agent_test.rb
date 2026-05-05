require "test_helper"

class AgentTest < Minitest::Test
  # A minimal concrete agent used across tests
  class EchoAgent < ActiveHarness::Agent
    system_language :en

    model do
      use provider: :openai, model: "gpt-4.1"
    end

    system_prompt "You are a helpful assistant."

    output :text
  end

  def test_call_delegates_to_engine
    engine = mock
    engine.expects(:call).with(
      input:     "hello",
      context:   {},
      constraints: {},
      language:  nil,
      translate: nil
    ).returns(stub(success?: true))

    ActiveHarness::Engine.stub(:new, ->(_cfg) { engine }) do
      EchoAgent.call(input: "hello")
    end
  end

  def test_agent_config_is_isolated_per_subclass
    class_a = Class.new(ActiveHarness::Agent) { system_prompt "A" }
    class_b = Class.new(ActiveHarness::Agent) { system_prompt "B" }

    refute_equal class_a.send(:agent_config), class_b.send(:agent_config)
  end

  def test_param_registers_required_params
    klass = Class.new(ActiveHarness::Agent) do
      param :ticket,  required: true
      param :user,    required: false
    end

    config = klass.send(:agent_config)
    assert_includes config[:required_params], :ticket
    refute_includes config[:required_params], :user
  end

  def test_output_stores_type_and_schema
    klass = Class.new(ActiveHarness::Agent) do
      output :json, schema: { category: "string" }
    end

    config = klass.send(:agent_config)
    assert_equal :json, config[:output_type]
    assert_equal({ category: "string" }, config[:output_schema])
  end
end
