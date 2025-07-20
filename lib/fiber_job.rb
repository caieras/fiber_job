# frozen_string_literal: true

require_relative 'fiber_job/version'
require_relative 'fiber_job/config'
require_relative 'fiber_job/logger'
require_relative 'fiber_job/job'
require_relative 'fiber_job/queue'
require_relative 'fiber_job/worker'
require_relative 'fiber_job/concurrency'
require_relative 'fiber_job/process_manager'
require_relative 'fiber_job/client'
require_relative 'fiber_job/cron_parser'
require_relative 'fiber_job/cron'
require_relative 'fiber_job/cron_job'

# FiberJob is a high-performance, Redis-based background job processing library for Ruby
# built on modern fiber-based concurrency. It combines the persistence of Redis with the
# speed of async fibers to deliver exceptional performance and reliability.
#
# @example Basic usage
#   # Configure the library
#   FiberJob.configure do |config|
#     config.redis_url = 'redis://localhost:6379/0'
#     config.queues = { default: 5, high: 10 }
#   end
#
#   # Define a job
#   class EmailJob < FiberJob::Job
#     def perform(user_id, message)
#       # Send email logic here
#     end
#   end
#
#   # Enqueue a job
#   EmailJob.perform_async(123, "Welcome!")
#
# @example Starting a worker
#   worker = FiberJob::Worker.new(queues: ['default', 'high'])
#   worker.start
#
module FiberJob
  class << self
    # Configures the FiberJob library with custom settings.
    # Yields the configuration object to the provided block for customization.
    #
    # @example Basic configuration
    #   FiberJob.configure do |config|
    #     config.redis_url = 'redis://localhost:6379/0'
    #     config.queues = { default: 5, high: 10, low: 2 }
    #     config.log_level = :info
    #   end
    #
    # @yield [config] Configuration object for customization
    # @yieldparam config [FiberJob::Config] The configuration instance
    # @return [void]
    # @see FiberJob::Config
    def configure
      yield(config)
    end

    # Returns the current configuration instance.
    # Creates a new configuration if one doesn't exist.
    #
    # @example Accessing configuration
    #   redis_url = FiberJob.config.redis_url
    #   queues = FiberJob.config.queues
    #
    # @return [FiberJob::Config] The current configuration instance
    # @see FiberJob::Config
    def config
      @config ||= Config.new
    end

    # Returns the current logger instance.
    # Creates a new logger with the current configuration if one doesn't exist.
    #
    # @example Logging messages
    #   FiberJob.logger.info("Job completed successfully")
    #   FiberJob.logger.error("Job failed: #{error.message}")
    #
    # @return [FiberJob::Logger] The current logger instance
    # @see FiberJob::Logger
    def logger
      @logger ||= FiberJob::Logger.new(config)
    end

    # Automatically discovers and registers all cron job classes.
    # Scans ObjectSpace for classes that inherit from FiberJob::CronJob
    # and registers them for scheduling.
    #
    # @example Manual registration
    #   class DailySummaryJob < FiberJob::CronJob
    #     cron '0 9 * * *'  # Every day at 9 AM
    #   end
    #
    #   FiberJob.register_cron_jobs
    #
    # @return [void]
    # @see FiberJob::CronJob
    # @see FiberJob::Cron
    def register_cron_jobs
      ObjectSpace.each_object(Class).select { |klass| klass < FiberJob::CronJob }.each(&:register)
    end
  end
end

# Register cron jobs after module is fully loaded
FiberJob.register_cron_jobs