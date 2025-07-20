# frozen_string_literal: true

module FiberJob
  # Logger provides structured logging for FiberJob operations.
  # Wraps the configured logger and provides level-based filtering
  # and FiberJob-specific formatting.
  #
  # The logger respects the configured log level and only outputs
  # messages at or above the current threshold.
  #
  # @example Using the logger
  #   FiberJob.logger.info("Job processing started")
  #   FiberJob.logger.error("Job failed: #{error.message}")
  #   FiberJob.logger.debug("Processing queue: #{queue_name}")
  #
  # @see FiberJob::Config
  class Logger
    # Log level hierarchy for filtering messages.
    # Lower numbers indicate more verbose logging.
    LOG_LEVELS = {
      debug: 0,
      info: 1,
      warn: 2,
      error: 3,
      fatal: 4
    }.freeze

    # Initializes the logger with configuration settings.
    #
    # @param config [FiberJob::Config] Configuration object containing log level and logger instance
    def initialize(config)
      @config = config
      @level = LOG_LEVELS[@config.log_level.to_sym] || LOG_LEVELS[:info]
    end

    # Logs a debug message if debug level is enabled.
    # Used for detailed diagnostic information.
    #
    # @param message [String] The message to log
    # @return [void]
    #
    # @example Debug logging
    #   FiberJob.logger.debug("Processing job #{job.class.name} with args: #{args.inspect}")
    def debug(message)
      log(:debug, message)
    end

    # Logs an info message if info level is enabled.
    # Used for general operational messages.
    #
    # @param message [String] The message to log
    # @return [void]
    #
    # @example Info logging
    #   FiberJob.logger.info("Worker started processing queue: #{queue_name}")
    def info(message)
      log(:info, message)
    end

    # Logs a warning message if warn level is enabled.
    # Used for concerning but non-fatal conditions.
    #
    # @param message [String] The message to log
    # @return [void]
    #
    # @example Warning logging
    #   FiberJob.logger.warn("Queue #{queue_name} is getting full")
    def warn(message)
      log(:warn, message)
    end

    # Logs an error message if error level is enabled.
    # Used for error conditions and exceptions.
    #
    # @param message [String] The message to log
    # @return [void]
    #
    # @example Error logging
    #   FiberJob.logger.error("Job failed: #{error.class.name} - #{error.message}")
    def error(message)
      log(:error, message)
    end

    # Logs a fatal message if fatal level is enabled.
    # Used for severe error conditions that may terminate the process.
    #
    # @param message [String] The message to log
    # @return [void]
    #
    # @example Fatal logging
    #   FiberJob.logger.fatal("Unable to connect to Redis, shutting down")
    def fatal(message)
      log(:fatal, message)
    end

    private

    # Internal logging method that checks level and delegates to configured logger.
    #
    # @param level [Symbol] The log level
    # @param message [String] The message to log
    # @return [void]
    def log(level, message)
      return unless should_log?(level)

      @config.logger.send(level, message)
    end

    # Determines if a message should be logged based on current log level.
    #
    # @param level [Symbol] The level to check
    # @return [Boolean] Whether the message should be logged
    def should_log?(level)
      LOG_LEVELS[level] >= @level
    end
  end
end
