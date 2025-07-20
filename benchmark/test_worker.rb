#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to start a FiberJob worker
# Usage: ruby test/test_worker.rb

require_relative '../lib/fiber_job'

# Configure FiberJob
FiberJob.configure do |config|
  config.redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/2'  # Use DB 1 for testing
  config.queues = [:default, :high, :low, :perf_test]  # Added perf_test queue
  config.queue_concurrency = {
    default: 3,
    high: 5,
    low: 1,
    perf_test: 50 # High concurrency for performance testing
  }
  config.log_level = :info
end

# Load shared test job classes
require_relative 'test_jobs'

puts "🚀 Starting FiberJob Worker..."
puts "📊 Configuration:"
puts "   Redis: #{FiberJob.config.redis_url}"
puts "   Queues: #{FiberJob.config.queues.join(', ')}"
puts "   Concurrency: #{FiberJob.config.queue_concurrency}"
puts "   Log Level: #{FiberJob.config.log_level}"
puts
puts "📋 Available Job Classes:"
puts "   - TestEmailJob (queue: default, max_retries: 3)"
puts "   - TestReportJob (queue: high, max_retries: 2)"  
puts "   - TestCleanupJob (queue: low, max_retries: 1)"
puts "   - TestDailyCronJob (cron: every 30 seconds)"
puts
puts "🎯 Worker will process jobs from: #{FiberJob.config.queues.join(', ')}"
puts "   (Includes perf_test queue for performance testing)"
puts "💡 Use Ctrl+C to stop"
puts "=" * 60

# Start the worker
begin
  worker = FiberJob::Worker.new
  worker.start
rescue Interrupt
  puts "\n👋 Shutting down worker..."
  exit 0
end