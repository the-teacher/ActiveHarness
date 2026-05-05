# ActiveHarness

ActiveHarness is a lightweight framework for building production-ready AI agents in Ruby and Rails.

Instead of relying on complex orchestration frameworks, ActiveHarness provides a simple and transparent DSL to define agents as plain Ruby classes.

Key features:

• Agent-based architecture (Rails-style DSL)
• Built-in guard layer (prompt injection protection)
• Cheap + expensive model pipeline
• Multi-provider support (OpenAI, Anthropic, Google, OpenRouter)
• Automatic fallback between providers
• Structured outputs (text / JSON with schema validation)
• Debug mode with full prompt visibility
• Minimal magic, maximum control

ActiveHarness is designed for engineers who want to use AI in production without losing control over behavior, cost, and safety.
