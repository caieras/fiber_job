#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/fiber_job'

# Configure FiberJob
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

# Example job
class EmailJob < FiberJob::Job
  def perform(user_id, message)
    puts "Sending email to user #{user_id}: #{message}"
    sleep(0.1) # Simulate work
    FiberJob.logger.info "Email sent to user #{user_id}"
  end
end

# Example cron job
class DailyReportJob < FiberJob::CronJob
  cron '0 9 * * *'  # Every day at 9 AM

  def execute_cron_job
    puts "Generating daily report..."
    sleep(0.5) # Simulate work
    FiberJob.logger.info "Daily report generated"
  end
end

# Enqueue some jobs
puts "Enqueueing jobs..."
EmailJob.perform_async(123, "Welcome to FiberJob!")
EmailJob.perform_in(5, 456, "Follow-up email")
EmailJob.perform_at(Time.now + 10, 789, "Delayed welcome")

puts "Starting worker..."
puts "Press Ctrl+C to stop"

# Start worker
worker = FiberJob::Worker.new
worker.start