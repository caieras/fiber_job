# FiberJob

A high-performance, Redis-based background job processing library for Ruby built on modern fiber-based concurrency. FiberJob combines the persistence of Redis with the speed of async fibers to deliver exceptional performance and reliability.

## Requirements

- Ruby 3.1+
- Redis 5.0+

## Features

- **Fiber-Based Job Processing**: Execute jobs using modern Ruby async/fiber concurrency
- **Hybrid Queue Architecture**: Redis persistence + in-memory async queues for optimal performance
- **Job Scheduling**: Schedule jobs for future execution with precise timing
- **Cron Jobs**: Define recurring jobs with cron expressions
- **Retry Logic**: Built-in exponential backoff with configurable retry policies
- **Priority Queues**: Support for high-priority job execution
- **Advanced Concurrency**: Per-queue fiber pools with semaphore-controlled execution
- **Failure Tracking**: Store and inspect failed jobs for debugging
- **Redis Integration**: Optimized Redis usage with connection pooling and atomic operations

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fiber_job'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install fiber_job
```

## Quick Start

### 1. Configuration

```ruby
require 'fiber_job'

FiberJob.configure do |config|
  config.redis_url = 'redis://localhost:6379/0'
  config.queues = [:default, :high, :low]
  config.queue_concurrency = {
    default: 5,
    high: 10,
    low: 2
  }
  config.log_level = :info
end
```

### 2. Define a Job

```ruby
class EmailJob < FiberJob::Job
  def perform(user_id, message)
    user = User.find(user_id)
    UserMailer.notification(user, message).deliver_now
    FiberJob.logger.info "Email sent to user #{user_id}"
  end
end
```

### 3. Enqueue Jobs

```ruby
# Immediate execution
EmailJob.perform_async(123, "Welcome to our platform!")

# Delayed execution
EmailJob.perform_in(1.hour, 456, "Don't forget to complete your profile")

# Scheduled execution
EmailJob.perform_at(Date.tomorrow.beginning_of_day, 789, "Daily newsletter")
```

### 4. Start Workers

```ruby
# Start a worker for all configured queues
worker = FiberJob::Worker.new
worker.start

# Start a worker for specific queues
worker = FiberJob::Worker.new(queues: [:high, :default])
worker.start
```

## How the Hybrid Architecture Works

FiberJob's unique architecture combines Redis persistence with fiber-based in-memory processing:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Redis Queue   │───▶│  Polling Fiber  │───▶│ Async::Queue    │
│   (Persistent)  │    │  (Single/Queue) │    │ (In-Memory)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                              ┌─────────────────┐
                                              │ Processing Pool │
                                              │ (Fiber Pool +   │
                                              │  Semaphore)     │
                                              └─────────────────┘
```

### Fiber Pool Architecture

```ruby
# Each queue gets its own fiber ecosystem
Sync do |task|
  @queues.each do |queue_name|
    # 1. Single polling fiber per queue (minimal Redis load)
    task.async { poll_redis_queue(queue_name) }

    # 2. Multiple processing fibers per queue (parallel execution)
    concurrency.times do
      task.async { process_job_queue(queue_name) }
    end
  end
end

# Jobs flow: Redis → Polling Fiber → Async::Queue → Processing Fiber Pool
def poll_redis_queue(queue_name)
  while @running
    job_data = Queue.pop(queue_name, timeout: 1.0)  # Redis operation
    @job_queues[queue_name].enqueue(job_data) if job_data  # Fast async queue
  end
end

def process_job_queue(queue_name)
  while @running
    job_data = @job_queues[queue_name].dequeue  # Instant fiber operation
    @managers[queue_name].execute { execute_job(job_data) }  # Semaphore-controlled
  end
end
```

### Performance Benefits

- **Sub-millisecond job pickup**: Jobs are instantly available in `Async::Queue`
- **Reduced Redis load**: One polling fiber per queue instead of multiple workers competing
- **Optimal concurrency**: Semaphore ensures exact concurrency limits without oversubscription
- **Zero blocking**: All operations use async/await patterns for maximum throughput

## Job Configuration

### Custom Job Settings

```ruby
class ComplexJob < FiberJob::Job
  def initialize
    super
    @queue = :high_priority
    @max_retries = 5
    @timeout = 600  # 10 minutes
  end

  def perform(data)
    # Complex processing logic
  end

  def retry_delay(attempt)
    # Custom retry strategy: linear backoff
    attempt * 60  # 1min, 2min, 3min...
  end
end
```

### Priority Retry

```ruby
class CriticalJob < FiberJob::Job
  def priority_retry?
    true  # Failed jobs go to front of queue on retry
  end
end
```

## Cron Jobs

Define recurring jobs with cron expressions:

```ruby
class DailyReportJob < FiberJob::CronJob
  cron '0 9 * * *'  # Every day at 9 AM

  def execute_cron_job
    # Generate and send daily reports
    Report.generate_daily
    FiberJob.logger.info "Daily report generated"
  end
end

class HourlyCleanupJob < FiberJob::CronJob
  cron '0 * * * *'  # Every hour

  def execute_cron_job
    # Cleanup old data
    TempData.cleanup_old_records
  end
end

# Register cron jobs (automatically done on startup)
FiberJob.register_cron_jobs
```

## Queue Management

### Queue Statistics

```ruby
stats = FiberJob::Queue.stats(:default)
puts "Queue size: #{stats[:size]}"
puts "Scheduled jobs: #{stats[:scheduled]}"
puts "Processing: #{stats[:processing]}"
```

### Failed Jobs

```ruby
# View failed jobs
failed_jobs = FiberJob::Queue.failed_jobs
failed_jobs.each do |job|
  puts "Failed: #{job['class']} - #{job['error']}"
end

# Note: clear_failed_jobs method was removed as it was unused
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `redis_url` | `redis://localhost:6379` | Redis connection URL |
| `concurrency` | `2` | Global default concurrency |
| `queues` | `[:default]` | List of queues to process |
| `queue_concurrency` | `{default: 2}` | Per-queue concurrency settings |
| `log_level` | `:info` | Logging level (debug, info, warn, error, fatal) |

## Environment Variables

- `REDIS_URL`: Redis connection URL
- `FIBER_JOB_LOG_LEVEL`: Logging level

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Roadmap

- [ ] Middleware support for job lifecycle hooks
- [ ] Dead letter queue for permanently failed jobs
- [ ] Metrics and monitoring integration
- [ ] ActiveJob adapter
- [ ] Web UI for job monitoring and management

## Support

- Create an issue on GitHub for bug reports or feature requests
- Check existing issues for solutions to common problems
- Review the documentation for detailed API information