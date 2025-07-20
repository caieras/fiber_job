# frozen_string_literal: true

module FiberJob
  # Client handles job enqueueing and scheduling operations.
  # Provides the core interface for adding jobs to queues with immediate,
  # delayed, or scheduled execution.
  #
  # This class is used internally by {FiberJob::Job} class methods and can also
  # be used directly for advanced job management scenarios.
  #
  # @example Direct usage
  #   FiberJob::Client.enqueue(MyJob, arg1, arg2)
  #   FiberJob::Client.enqueue_in(3600, MyJob, arg1, arg2)  # 1 hour delay
  #   FiberJob::Client.enqueue_at(Time.parse("2024-01-01"), MyJob, arg1)
  #
  # @author FiberJob Team
  # @since 1.0.0
  # @see FiberJob::Job
  # @see FiberJob::Queue
  class Client
    # Enqueues a job for immediate execution.
    # The job will be added to the appropriate queue and processed
    # by the next available worker.
    #
    # @param job_class [Class] The job class to execute (must inherit from FiberJob::Job)
    # @param args [Array] Arguments to pass to the job's perform method
    # @return [String] Unique job identifier
    #
    # @example Enqueue a job immediately
    #   FiberJob::Client.enqueue(EmailJob, user.id, "Welcome!")
    #
    # @raise [ArgumentError] If job_class is not a valid job class
    def self.enqueue(job_class, *args)
      payload = {
        'class' => job_class.name,
        'args' => args,
        'enqueued_at' => Time.now.to_f
      }

      queue_name = job_class.queue
      Queue.push(queue_name, payload)

      FiberJob.logger.info "Enqueued #{job_class.name} with args: #{args.inspect}"
    end

    # Enqueues a job for execution after a specified delay.
    # The job will be scheduled for future execution and moved to the
    # regular queue when the delay period expires.
    #
    # @param delay_seconds [Numeric] Number of seconds to delay execution
    # @param job_class [Class] The job class to execute (must inherit from FiberJob::Job)
    # @param args [Array] Arguments to pass to the job's perform method
    # @return [String] Unique job identifier
    #
    # @example Enqueue with delay
    #   FiberJob::Client.enqueue_in(300, EmailJob, user.id, "5 minute reminder")
    #   FiberJob::Client.enqueue_in(1.hour, ReportJob, date: Date.today)
    #
    # @raise [ArgumentError] If delay_seconds is negative or job_class is invalid
    def self.enqueue_in(delay_seconds, job_class, *args)
      scheduled_at = Time.now.to_f + delay_seconds
      payload = {
        'class' => job_class.name,
        'args' => args,
        'enqueued_at' => Time.now.to_f
      }

      queue_name = job_class.queue
      Queue.schedule(queue_name, payload, scheduled_at)

      FiberJob.logger.info "Scheduled #{job_class.name} to run in #{delay_seconds}s"
    end

    # Enqueues a job for execution at a specific time.
    # The job will be scheduled and executed when the specified time is reached.
    #
    # @param timestamp [Time, Integer] Specific time or Unix timestamp for execution
    # @param job_class [Class] The job class to execute (must inherit from FiberJob::Job)
    # @param args [Array] Arguments to pass to the job's perform method
    # @return [String] Unique job identifier
    #
    # @example Enqueue at specific time
    #   tomorrow_9am = Time.parse("2024-01-02 09:00:00")
    #   FiberJob::Client.enqueue_at(tomorrow_9am, DailyReportJob, date: Date.today)
    #
    #   # Using Unix timestamp
    #   FiberJob::Client.enqueue_at(1672531200, MaintenanceJob, type: "cleanup")
    #
    # @raise [ArgumentError] If timestamp is in the past or job_class is invalid
    def self.enqueue_at(timestamp, job_class, *args)
      payload = {
        'class' => job_class.name,
        'args' => args,
        'enqueued_at' => Time.now.to_f
      }

      queue_name = job_class.queue
      Queue.schedule(queue_name, payload, timestamp.to_f)

      FiberJob.logger.info "Scheduled #{job_class.name} to run at #{Time.at(timestamp)}"
    end
  end
end
