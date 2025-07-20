# frozen_string_literal: true

require 'logger'

module FiberJob
  # Configuration class for FiberJob library settings.
  # Manages Redis connection, worker concurrency, queue configuration,
  # and logging settings. Supports both global and per-queue configuration.
  #
  # @example Basic configuration
  #   FiberJob.configure do |config|
  #     config.redis_url = 'redis://localhost:6379/0'
  #     config.concurrency = 5
  #     config.queues = [:default, :high, :low]
  #     config.log_level = :debug
  #   end
  #
  # @example Per-queue concurrency
  #   FiberJob.configure do |config|
  #     config.queue_concurrency = {
  #       default: 5,
  #       high: 10,
  #       low: 2
  #     }
  #   end
  #
  class Config
    # @!attribute [rw] redis_url
    #   @return [String] Redis connection URL
    # @!attribute [rw] concurrency
    #   @return [Integer] Global default concurrency level
    # @!attribute [rw] queues
    #   @return [Array<Symbol>] List of queue names to process
    # @!attribute [rw] queue_concurrency
    #   @return [Hash] Per-queue concurrency settings
    # @!attribute [rw] logger
    #   @return [Logger] Logger instance for application logging
    # @!attribute [rw] log_level
    #   @return [Symbol] Logging level (:debug, :info, :warn, :error)
    attr_accessor :redis_url, :concurrency, :queues, :queue_concurrency, :logger, :log_level

    # Initializes configuration with sensible defaults.
    # Values can be overridden through environment variables or configuration blocks.
    #
    # @return [void]
    #
    # Environment variables:
    # - REDIS_URL: Redis connection URL (default: redis://localhost:6379)
    # - FIBER_JOB_LOG_LEVEL: Logging level (default: info)
    def initialize
      @redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379'
      @concurrency = 2  # Global default fallback
      @queues = [:default]
      @queue_concurrency = { default: 2 }  # Per-queue concurrency
      @log_level = ENV['FIBER_JOB_LOG_LEVEL']&.to_sym || :info
      @logger = ::Logger.new($stdout)
      @logger.level = ::Logger.const_get(@log_level.to_s.upcase)
    end

    # Returns the concurrency setting for a specific queue.
    # Falls back to the global concurrency setting if no queue-specific
    # setting is configured.
    #
    # @param queue_name [String, Symbol] Name of the queue
    # @return [Integer] Concurrency level for the specified queue
    #
    # @example Get queue concurrency
    #   config.concurrency_for_queue(:high)  # => 10
    #   config.concurrency_for_queue(:unknown)  # => 2 (global default)
    def concurrency_for_queue(queue_name)
      @queue_concurrency[queue_name.to_sym] || @concurrency
    end
  end
end
