module ActiveHarness
  # Available only when ActiveHarness.config.debug == true
  class DebugResult
    attr_reader :system_prompt,
                :guard_runs,
                :callback_log

    def initialize(system_prompt: nil,
                   guard_runs: [], callback_log: [])
      @system_prompt = system_prompt
      @guard_runs    = guard_runs
      @callback_log  = callback_log
    end

    def full_prompt
      @system_prompt.to_s
    end
  end
end
