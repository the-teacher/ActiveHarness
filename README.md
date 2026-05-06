# ActiveHarness

ActiveHarness is a lightweight framework for building production-ready AI agents in Ruby and Rails.

Instead of relying on complex orchestration frameworks, ActiveHarness provides a simple and transparent DSL to define agents as plain Ruby classes.

## Features

- Agent-based architecture (Rails-style DSL)
- Built-in guard layer (prompt injection, toxicity, relevance checks)
- Multi-provider support: OpenAI, Anthropic, Google, OpenRouter
- Automatic fallback between models and providers
- Per-call language and translation support
- Structured outputs (text / JSON with schema validation)
- Input constraints (e.g. `max_input_length`)
- Debug mode with full prompt visibility
- Minimal dependencies, no magic

## Installation

```ruby
# Gemfile
gem "active_harness"
```

```bash
bundle install
```

Or install directly:

```bash
gem install active_harness
```

## Quick Start

### 1. Configure

```ruby
ActiveHarness.configure do |config|
  config.openai_api_key      = ENV["OPENAI_API_KEY"]
  config.openrouter_api_key  = ENV["OPENROUTER_API_KEY"]
  config.default_temperature = 0.2
  config.default_timeout     = 30
end
```

### 2. Define an agent

```ruby
class SupportAgent < ActiveHarness::Agent
  guard InjectionGuard

  model do
    use      provider: :openai,     model: "gpt-4.1-mini"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
  end

  system_prompt "You are a helpful support assistant."
  output :text
end
```

### 3. Call it

```ruby
# One-liner
result = SupportAgent.call(input: "How do I get started?")

# Instance style
agent  = SupportAgent.new(input: "How do I get started?", language: :ru)
result = agent.call

puts result.output  if result.success?
puts result.output  if result.blocked?   # default_error_answer
```

## Guards

Guards run before the main request and can block it:

```ruby
class InjectionGuard < ActiveHarness::Agent
  model { use provider: :openai, model: "gpt-4.1-mini" }
  system_language :en
  risk_tolerance  :low
end

# Register on the main agent:
guard InjectionGuard, name: :injection_guard
guard ToxicityGuard,  name: :toxicity_guard
```

## Result API

```ruby
result.success?   # true / false
result.blocked?   # true / false  (guard rejected)
result.failed?    # true / false  (error / timeout)
result.output     # String
result.model      # "gpt-4.1-mini"
result.provider   # :openai
```

## Requirements

- Ruby >= 2.6
- API key for at least one supported provider (OpenAI, Anthropic, Google, OpenRouter)

## License

MIT — see [LICENSE](LICENSE).
