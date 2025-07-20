# frozen_string_literal: true

module FiberJob
  # Simple cron parser - supports basic patterns
  # Format: [second] minute hour day month weekday
  # Examples: "*/30 * * * * *" (every 30 sec), "0 2 * * *" (daily 2am)
  class CronParser
    def self.next_run(cron_expression, from_time = Time.now)
      fields = cron_expression.split

      if fields.length == 6
        # 6-field format: second minute hour day month weekday
        second, minute, hour, day, month, weekday = fields
        current = from_time + 1 # Start from next second
        current = Time.new(current.year, current.month, current.day, current.hour, current.min, current.sec)
        increment = 1
        max_iterations = 86_400 # 24 hours in seconds
      elsif fields.length == 5
        # 5-field format: minute hour day month weekday
        minute, hour, day, month, weekday = fields
        second = nil
        current = from_time + 60 # Start from next minute
        current = Time.new(current.year, current.month, current.day, current.hour, current.min, 0)
        increment = 60
        max_iterations = 1440 # 24 hours in minutes
      else
        raise "Invalid cron expression: #{cron_expression}. Must have 5 or 6 fields."
      end

      # Simple implementation - find next matching time
      max_iterations.times do
        if matches?(current, second, minute, hour, day, month, weekday)
          return current
        end
        current += increment
      end

      raise "No matching time found for cron expression: #{cron_expression}"
    end

    private

    def self.matches?(time, second, minute, hour, day, month, weekday)
      (second.nil? || match_field?(time.sec, second)) &&
        match_field?(time.min, minute) &&
        match_field?(time.hour, hour) &&
        match_field?(time.day, day) &&
        match_field?(time.month, month) &&
        match_field?(time.wday, weekday)
    end

    def self.match_field?(value, pattern)
      return true if pattern == '*'

      if pattern.start_with?('*/')
        # Handle */5 pattern
        interval = pattern[2..-1].to_i
        return (value % interval) == 0
      end

      # Handle exact match
      return value == pattern.to_i
    end
  end
end
