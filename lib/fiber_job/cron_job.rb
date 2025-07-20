# frozen_string_literal: true

require_relative 'cron_parser'

module FiberJob
  class CronJob < Job
    def self.cron(cron_expression)
      @cron_expression = cron_expression
    end

    def self.cron_expression
      @cron_expression || raise("No cron expression defined for #{name}")
    end

    def self.next_run_time(from_time = Time.now)
      CronParser.next_run(@cron_expression, from_time)
    end

    def self.register
      Cron.register(self)
    end

    # Override perform to add automatic rescheduling
    def perform(*args)
      execute_cron_job(*args)
      schedule_next_run
    end

    # Subclasses implement this instead of perform
    def execute_cron_job(*args)
      raise NotImplementedError, 'Subclasses must implement execute_cron_job'
    end

    private

    def schedule_next_run
      next_time = self.class.next_run_time
      Cron.schedule_job(self.class, next_time)
    end
  end
end
