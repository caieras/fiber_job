# frozen_string_literal: true

require 'async'
require 'async/queue'

module FiberJob
  class Worker
    def initialize(queues: nil, concurrency: nil)
      @queues = queues || FiberJob.config.queues
      @concurrency = concurrency || FiberJob.config.concurrency
      @running = false
      @managers = {}
      @job_queues = {} # In-memory Async::Queue per Redis queue
    end

    def start
      @running = true

      Sync do |task|
        # Initialize all queues first
        @queues.each do |queue_name|
          @job_queues[queue_name] = Async::Queue.new
          queue_concurrency = FiberJob.config.concurrency_for_queue(queue_name)
          @managers[queue_name] = ConcurrencyManager.new(max_concurrency: queue_concurrency)
        end

        # Start independent pollers for each queue
        @queues.each do |queue_name|
          task.async do
            poll_redis_queue(queue_name)
          end
        end

        # Start independent worker pools for each queue
        @queues.each do |queue_name|
          queue_concurrency = FiberJob.config.concurrency_for_queue(queue_name)
          queue_concurrency.times do
            task.async do
              process_job_queue(queue_name)
            end
          end
        end

        # Global support fibers
        task.async do
          process_scheduled_jobs
        end

        task.async do
          process_cron_jobs
        end
      end
    end

    def stop
      @running = false

      # Close all in-memory queues to signal completion to workers
      @job_queues.each_value(&:close)
    end

    private

    # Single poller fiber that fetches jobs from Redis and distributes to workers
    # This eliminates Redis brpop contention by having only one fiber per queue accessing Redis
    def poll_redis_queue(queue_name)
      # Create dedicated Redis connection for this poller to avoid blocking other pollers
      redis_conn = Queue.redis_connection
      while @running
        begin
          # Use longer timeout since we're the only poller - no contention
          job_data = Queue.pop(queue_name, timeout: 1.0, redis_conn: redis_conn)

          if job_data
            # Push to in-memory queue for worker fibers to process
            @job_queues[queue_name].push(job_data)
          end
        rescue StandardError => e
          FiberJob.logger.error "Redis polling error for queue #{queue_name}: #{e.message}"
          sleep(1) # Brief pause on error
        end
      end
    end

    # Worker fibers process jobs from the fast in-memory queue
    # Multiple workers can process concurrently without Redis contention
    def process_job_queue(queue_name)
      while @running
        begin
          # Fast in-memory dequeue operation
          job_data = @job_queues[queue_name].dequeue

          if job_data
            # Use semaphore to control actual job execution concurrency
            @managers[queue_name].execute do
              execute_job(job_data)
            end
          end
        rescue Async::Queue::ClosedError
          # Queue closed during shutdown - exit gracefully
          break
        rescue StandardError => e
          FiberJob.logger.error "Job processing error for queue #{queue_name}: #{e.message}"
        end
      end
    end

    def execute_job(job_data)
      job_class = Object.const_get(job_data['class'])
      job = job_class.new

      job.retry_count = job_data['retry_count'] || 0

      # if job.retry_count > 0
      #   FiberJob.logger.info "Executing #{job_class} (retry #{job.retry_count}/#{job.max_retries})"
      # end

      begin
        Timeout.timeout(job.timeout) do
          args = (job_data['args'] || []).dup
          args << job_data['enqueued_at'] if job_data['enqueued_at']
          job.perform(*args)
        end
      rescue => e
        handle_failure(job, job_data, e)
      end
    end

    def execute_cron_job(job_data)
      job_class = Object.const_get(job_data['class'])
      job = job_class.new

      begin
        Timeout.timeout(job.timeout) do
          job.perform
        end
      rescue => e
        FiberJob.logger.error "Cron job #{job_data['class']} failed: #{e.message}"
        FiberJob.logger.error e.backtrace.join("\n")

        next_time = job_class.next_run_time
        Cron.schedule_job(job_class, next_time)
      end
    end

    def handle_failure(job, job_data, error)
      if job.retry_count < job.max_retries
        job.retry_count += 1
        delay = job.retry_delay(job.retry_count)

        retry_job_data = job_data.dup
        retry_job_data['retry_count'] = job.retry_count

        message = "#{job.class} failed: #{error.message}. "
        message += "Retrying in #{delay.round(1)}s (attempt #{job.retry_count}/#{job.max_retries})"
        FiberJob.logger.warn message

        if job.priority_retry?
          Queue.schedule_priority(job.queue, retry_job_data, Time.now.to_f + delay)
        else
          Queue.schedule(job.queue, retry_job_data, Time.now.to_f + delay)
        end
      else
        FiberJob.logger.error "#{job.class} permanently failed after #{job.max_retries} retries: #{error.message}"
        Queue.store_failed_job(job_data, error)
      end
    end

    def process_scheduled_jobs
      while @running
        @queues.each do |queue_name|
          Queue.scheduled_jobs(queue_name)
        end

        sleep(1)
      end
    end

    def process_cron_jobs
      while @running
        due_jobs = Cron.due_jobs

        due_jobs.each do |job_data|
          queue_name = job_data['queue']

          next unless @queues.include?(queue_name)

          @managers[queue_name].execute { execute_cron_job(job_data) }
        end

        sleep(1)
      end
    end
  end
end
