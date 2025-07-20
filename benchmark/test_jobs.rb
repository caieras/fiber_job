# frozen_string_literal: true

# Test job classes for FiberJob testing
# These can be shared between worker and client scripts

# Test job classes
class TestEmailJob < FiberJob::Job
  def initialize
    super
    @queue = :default
    @max_retries = 3
  end

  def perform(user_id, message, enqueued_at = nil)
    start_time = Time.now
    duration = rand(0.5..2.0)  # Random work duration
    
    puts "📧 Processing EmailJob for user #{user_id}: #{message}"
    puts "   ⏰ Enqueued at: #{Time.at(enqueued_at)} (#{(start_time.to_f - enqueued_at).round(2)}s ago)" if enqueued_at
    puts "   🔧 Working for #{duration.round(2)}s..."
    
    sleep(duration)
    
    # 10% chance of failure for testing retries
    if rand < 0.1
      raise "Random failure for testing retries!"
    end
    
    puts "   ✅ Email sent successfully! (took #{(Time.now - start_time).round(2)}s)"
    FiberJob.logger.info "EmailJob completed for user #{user_id}"
  end
end

class TestReportJob < FiberJob::Job
  def initialize
    super
    @queue = :high
    @max_retries = 2
    @timeout = 10
  end

  def perform(report_type, data_size = 100, enqueued_at = nil)
    start_time = Time.now
    duration = data_size / 1000.0  # Simulate processing based on data size
    
    puts "📊 Processing ReportJob: #{report_type} (#{data_size} records)"
    puts "   ⏰ Enqueued at: #{Time.at(enqueued_at)} (#{(start_time.to_f - enqueued_at).round(2)}s ago)" if enqueued_at
    puts "   🔧 Processing #{data_size} records..."
    
    sleep(duration)
    
    puts "   ✅ Report generated! (took #{(Time.now - start_time).round(2)}s)"
    FiberJob.logger.info "ReportJob completed: #{report_type}"
  end
end

class TestCleanupJob < FiberJob::Job
  def initialize
    super
    @queue = :low
    @max_retries = 1
  end

  def perform(cleanup_type, enqueued_at = nil)
    start_time = Time.now
    duration = rand(1.0..3.0)
    
    puts "🧹 Processing CleanupJob: #{cleanup_type}"
    puts "   ⏰ Enqueued at: #{Time.at(enqueued_at)} (#{(start_time.to_f - enqueued_at).round(2)}s ago)" if enqueued_at
    puts "   🔧 Cleaning up..."
    
    sleep(duration)
    
    puts "   ✅ Cleanup completed! (took #{(Time.now - start_time).round(2)}s)"
    FiberJob.logger.info "CleanupJob completed: #{cleanup_type}"
  end
end

# Test cron job
class TestDailyCronJob < FiberJob::CronJob
  cron '*/30 * * * * *'  # Every 30 seconds for testing

  def execute_cron_job
    puts "⏰ CRON: Daily maintenance running at #{Time.now}"
    sleep(1)
    puts "⏰ CRON: Daily maintenance completed"
    FiberJob.logger.info "Daily cron job executed"
  end
end

# Performance test job
class PerfTestJob < FiberJob::Job
  def initialize
    super
    @queue = :perf_test
    @max_retries = 0  # No retries for clean perf testing
  end

  def perform(job_id, work_duration = 0.01, enqueued_at = nil)
    start_time = Time.now
    
    # Simulate work
    sleep(work_duration)
    
    # Calculate timing
    if enqueued_at
      queue_time = start_time.to_f - enqueued_at
      processing_time = Time.now - start_time
      
      # Store results in Redis for analysis
      FiberJob::Queue.redis.lpush("perf_results", JSON.dump({
        job_id: job_id,
        enqueued_at: enqueued_at,
        started_at: start_time.to_f,
        completed_at: Time.now.to_f,
        queue_time: queue_time,
        processing_time: processing_time.to_f
      }))
    end
  end
end