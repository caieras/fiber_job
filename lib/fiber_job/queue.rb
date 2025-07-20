# frozen_string_literal: true

require 'redis'

module FiberJob
  # Queue provides Redis-based queue operations for job storage and retrieval.
  # Handles immediate execution queues, scheduled jobs, priority handling,
  # and failure tracking using Redis data structures.
  #
  # The queue system uses Redis lists for immediate jobs, sorted sets for
  # scheduled jobs, and separate lists for failed job tracking.
  #
  # @example Basic queue operations
  #   # Push a job to queue
  #   FiberJob::Queue.push(:default, job_data)
  #
  #   # Pop a job from queue
  #   job = FiberJob::Queue.pop(:default, timeout: 1.0)
  #
  #   # Schedule a job for later
  #   FiberJob::Queue.schedule(:default, job_data, Time.now.to_f + 3600)
  #
  # @example Queue statistics
  #   stats = FiberJob::Queue.stats(:default)
  #   puts "Queue size: #{stats[:size]}"
  #   puts "Scheduled jobs: #{stats[:scheduled]}"
  #
  # @see FiberJob::Worker
  class Queue
    # Returns the shared Redis connection instance.
    # Creates a new connection if one doesn't exist.
    #
    # @return [Redis] The shared Redis connection
    def self.redis
      @redis ||= Redis.new(url: FiberJob.config.redis_url)
    end

    # Creates a new Redis connection for fiber-safe operations.
    # Used when concurrent operations need separate connections.
    #
    # @return [Redis] A new Redis connection instance
    def self.redis_connection
      # Create a new Redis connection for fiber-safe operations
      Redis.new(url: FiberJob.config.redis_url)
    end

    # Adds a job to the specified queue for immediate processing.
    # Jobs are added to the left side of the list (LPUSH) and processed
    # from the right side (BRPOP) implementing FIFO behavior.
    #
    # @param queue_name [String, Symbol] Name of the target queue
    # @param payload [Hash] Job data including class, args, and metadata
    # @return [Integer] The length of the queue after push
    #
    # @example Push a job
    #   payload = { 'class' => 'EmailJob', 'args' => [123, 'message'] }
    #   FiberJob::Queue.push(:default, payload)
    def self.push(queue_name, payload)
      redis.lpush("queue:#{queue_name}", JSON.dump(payload))
    end

    # Adds a job to the head of the queue for priority processing.
    # Priority jobs are processed before regular jobs in the same queue.
    #
    # @param queue_name [String, Symbol] Name of the target queue
    # @param payload [Hash] Job data including class, args, and metadata
    # @return [Integer] The length of the queue after push
    #
    # @example Push priority job
    #   FiberJob::Queue.push_priority(:default, urgent_job_data)
    def self.push_priority(queue_name, payload)
      # Add to the head of the queue for priority execution
      redis.rpush("queue:#{queue_name}", JSON.dump(payload))
    end

    # Removes and returns a job from the specified queue.
    # Blocks for the specified timeout waiting for jobs to become available.
    #
    # @param queue_name [String, Symbol] Name of the source queue
    # @param timeout [Float] Maximum time to wait for a job (default: 0.1)
    # @param redis_conn [Redis, nil] Optional Redis connection to use
    # @return [Hash, nil] Job data hash or nil if timeout reached
    #
    # @example Pop from queue with timeout
    #   job = FiberJob::Queue.pop(:default, timeout: 5.0)
    #   if job
    #     puts "Processing job: #{job['class']}"
    #   end
    def self.pop(queue_name, timeout: 0.1, redis_conn: nil)
      conn = redis_conn || redis
      data = conn.brpop("queue:#{queue_name}", timeout: timeout)
      data ? JSON.parse(data[1]) : nil
    end

    # Schedules a job for execution at a specific time.
    # Uses Redis sorted sets with timestamp as score for efficient
    # time-based retrieval.
    #
    # @param queue_name [String, Symbol] Name of the target queue
    # @param payload [Hash] Job data including class, args, and metadata
    # @param scheduled_at [Float] Unix timestamp for execution
    # @return [Boolean] True if job was added to schedule
    #
    # @example Schedule a job
    #   future_time = Time.now.to_f + 3600  # 1 hour from now
    #   FiberJob::Queue.schedule(:default, job_data, future_time)
    def self.schedule(queue_name, payload, scheduled_at)
      redis.zadd("schedule:#{queue_name}", scheduled_at, JSON.dump(payload))
    end

    # Schedules a job with priority for execution at a specific time.
    # Priority scheduled jobs are moved to the head of the queue when ready.
    #
    # @param queue_name [String, Symbol] Name of the target queue
    # @param payload [Hash] Job data including class, args, and metadata
    # @param scheduled_at [Float] Unix timestamp for execution
    # @return [Boolean] True if job was added to schedule
    def self.schedule_priority(queue_name, payload, scheduled_at)
      # Mark as priority retry for head-of-queue execution
      priority_payload = payload.merge('priority_retry' => true)
      redis.zadd("schedule:#{queue_name}", scheduled_at, JSON.dump(priority_payload))
    end

    # Processes scheduled jobs that are ready for execution.
    # Moves jobs from the scheduled set to the appropriate queue
    # when their scheduled time has arrived.
    #
    # @param queue_name [String, Symbol] Name of the queue to process
    # @return [void]
    #
    # @example Process scheduled jobs
    #   FiberJob::Queue.scheduled_jobs(:default)  # Called by workers
    def self.scheduled_jobs(queue_name)
      now = Time.now.to_f
      jobs = redis.zrangebyscore("schedule:#{queue_name}", 0, now)

      jobs.each do |job_json|
        redis.zrem("schedule:#{queue_name}", job_json)
        job_data = JSON.parse(job_json)

        # Use priority queue for retries
        if job_data['priority_retry']
          job_data.delete('priority_retry') # Clean up the flag
          push_priority(queue_name, job_data)
        else
          push(queue_name, job_data)
        end
      end
    end

    # Returns statistics for the specified queue.
    # Provides insight into queue depth, scheduled jobs, and processing status.
    #
    # @param queue_name [String, Symbol] Name of the queue
    # @return [Hash] Statistics hash with :size, :scheduled, and :processing keys
    #
    # @example Get queue statistics
    #   stats = FiberJob::Queue.stats(:default)
    #   puts "Pending: #{stats[:size]}, Scheduled: #{stats[:scheduled]}"
    def self.stats(queue_name)
      {
        size: redis.llen("queue:#{queue_name}"),
        scheduled: redis.zcard("schedule:#{queue_name}"),
        processing: redis.get("processing:#{queue_name}").to_i
      }
    end

    # Stores a failed job with error information for later analysis.
    # Failed jobs are stored with original job data plus failure metadata.
    #
    # @param job_data [Hash] Original job data
    # @param error [Exception] The error that caused the failure
    # @return [Integer] Length of failed jobs list after storage
    #
    # @example Store failed job
    #   begin
    #     job.perform
    #   rescue => e
    #     FiberJob::Queue.store_failed_job(job_data, e)
    #   end
    def self.store_failed_job(job_data, error)
      failed_job_data = job_data.merge({
        'failed_at' => Time.now.to_f,
        'error' => error.message,
        'backtrace' => error.backtrace&.first(10)
      })
      redis.lpush("failed", JSON.dump(failed_job_data))
    end

    # Retrieves all failed jobs for inspection and debugging.
    #
    # @return [Array<Hash>] Array of failed job data hashes
    #
    # @example Get failed jobs
    #   failed = FiberJob::Queue.failed_jobs
    #   failed.each { |job| puts "Failed: #{job['class']} - #{job['error']}" }
    def self.failed_jobs
      redis.lrange("failed", 0, -1).map { |job_json| JSON.parse(job_json) }
    end
  end
end
