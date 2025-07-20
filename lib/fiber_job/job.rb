# frozen_string_literal: true

module FiberJob
  # Base class for all background jobs in the FiberJob system.
  # Provides interface for job execution, retry logic, and scheduling capabilities.
  #
  # All job classes should inherit from this class and implement the {#perform} method
  # to define their specific behavior.
  #
  # @example Basic job definition
  #   class EmailJob < FiberJob::Job
  #     def perform(user_id, message)
  #       user = User.find(user_id)
  #       UserMailer.notification(user, message).deliver_now
  #     end
  #   end
  #
  # @example Job with custom configuration
  #   class ComplexJob < FiberJob::Job
  #     def initialize
  #       super
  #       @queue = :high_priority
  #       @max_retries = 5
  #       @timeout = 600  # 10 minutes
  #     end
  #
  #     def perform(data)
  #       # Complex processing logic
  #     end
  #
  #     def retry_delay(attempt)
  #       attempt * 60  # Linear backoff: 1min, 2min, 3min...
  #     end
  #   end
  class Job
    # @!attribute [rw] queue
    #   @return [Symbol] The queue name where this job will be processed
    # @!attribute [rw] retry_count
    #   @return [Integer] Current number of retry attempts
    # @!attribute [rw] max_retries
    #   @return [Integer] Maximum number of retry attempts before giving up
    # @!attribute [rw] priority
    #   @return [Integer] Job priority (higher numbers = higher priority)
    # @!attribute [rw] timeout
    #   @return [Integer] Maximum execution time in seconds before timeout
    attr_accessor :queue, :retry_count, :max_retries, :priority, :timeout

    # Initializes a new job instance with default configuration.
    # Sets reasonable defaults for queue, retries, and timeout values.
    #
    # @return [void]
    def initialize
      @queue = :default
      @retry_count = 0
      @max_retries = 3
      @priority = 0
      @timeout = 300 # 5 minutes
    end

    # Executes the job with the provided arguments.
    # This method must be implemented by all job subclasses.
    #
    # @param args [Array] Arguments passed to the job
    # @raise [NotImplementedError] When called on the base Job class
    # @return [void]
    # @abstract Subclasses must implement this method
    #
    # @example Implementation in subclass
    #   def perform(user_id, message)
    #     user = User.find(user_id)
    #     # Process the job...
    #   end
    def perform(*args)
      raise NotImplementedError, 'Subclasses must implement perform'
    end

    # Calculates the delay before retrying a failed job.
    # Uses exponential backoff with random jitter by default.
    #
    # @param attempt [Integer] The current retry attempt number (0-based)
    # @return [Integer] Delay in seconds before retry
    #
    # @example Custom retry delay
    #   def retry_delay(attempt)
    #     [30, 60, 120, 300][attempt] || 300  # Fixed intervals
    #   end
    def retry_delay(attempt)
      # Default exponential backoff: 2^attempt + random jitter
      (2 ** attempt) + rand(10)
    end

    # Determines if failed jobs should be retried with priority.
    # Priority retries are processed before regular jobs in the queue.
    #
    # @return [Boolean] Whether to use priority retry queue
    def priority_retry?
      true
    end

    # Returns the queue name for this job class.
    # Creates a temporary instance to get the configured queue name.
    #
    # @return [Symbol] The queue name where jobs of this class will be processed
    def self.queue
      new.queue
    end

    # Enqueues the job for immediate asynchronous execution.
    #
    # @param args [Array] Arguments to pass to the job's perform method
    # @return [String] Job ID for tracking
    #
    # @example Enqueue a job
    #   EmailJob.perform_async(user.id, "Welcome message")
    def self.perform_async(*args)
      Client.enqueue(self, *args)
    end

    # Enqueues the job for execution after a specified delay.
    #
    # @param delay [Numeric] Delay in seconds before execution
    # @param args [Array] Arguments to pass to the job's perform method
    # @return [String] Job ID for tracking
    #
    # @example Enqueue with delay
    #   EmailJob.perform_in(3600, user.id, "Reminder message")  # 1 hour delay
    def self.perform_in(delay, *args)
      Client.enqueue_in(delay, self, *args)
    end

    # Enqueues the job for execution at a specific time.
    #
    # @param time [Time, Integer] Specific time or timestamp for execution
    # @param args [Array] Arguments to pass to the job's perform method
    # @return [String] Job ID for tracking
    #
    # @example Enqueue at specific time
    #   EmailJob.perform_at(tomorrow_9am, user.id, "Daily summary")
    def self.perform_at(time, *args)
      Client.enqueue_at(time, self, *args)
    end
  end
end
