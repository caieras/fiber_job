#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to enqueue jobs for FiberJob worker testing
# Usage: ruby test/test_client.rb

require_relative '../lib/fiber_job'

# Configure FiberJob (same as worker)
FiberJob.configure do |config|
  config.redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/1'  # Use DB 1 for testing
  config.queues = [:default, :high, :low, :perf_test]  # Added perf_test queue
  config.queue_concurrency = {
    default: 3,
    high: 5,
    low: 1,
    perf_test: 10  # High concurrency for performance testing
  }
  config.log_level = :info
end

# Load shared test job classes  
require_relative 'test_jobs'

def print_queue_stats
  puts "\n📊 Queue Statistics:"
  FiberJob.config.queues.each do |queue|
    stats = FiberJob::Queue.stats(queue)
    puts "   #{queue}: #{stats[:size]} pending, #{stats[:scheduled]} scheduled"
  end
  
  failed = FiberJob::Queue.failed_jobs
  puts "   failed: #{failed.size} jobs"
  puts
end

def enqueue_test_jobs
  puts "🚀 Enqueueing test jobs..."
  
  # Immediate jobs
  puts "\n📧 Enqueueing Email Jobs (immediate):"
  5.times do |i|
    TestEmailJob.perform_async(100 + i, "Welcome email #{i + 1}")
    puts "   ✓ EmailJob #{i + 1} enqueued"
  end
  
  # High priority jobs  
  puts "\n📊 Enqueueing Report Jobs (high priority):"
  3.times do |i|
    TestReportJob.perform_async("monthly_report_#{i + 1}", rand(500..2000))
    puts "   ✓ ReportJob #{i + 1} enqueued"
  end
  
  # Low priority jobs
  puts "\n🧹 Enqueueing Cleanup Jobs (low priority):"
  2.times do |i|
    TestCleanupJob.perform_async("temp_files_#{i + 1}")
    puts "   ✓ CleanupJob #{i + 1} enqueued"
  end
  
  # Delayed jobs
  puts "\n⏰ Enqueueing Delayed Jobs:"
  TestEmailJob.perform_in(5, 200, "Delayed welcome email (5s)")
  puts "   ✓ Delayed EmailJob (5 seconds)"
  
  TestReportJob.perform_in(10, "delayed_report", 1500)
  puts "   ✓ Delayed ReportJob (10 seconds)"
  
  # Scheduled jobs
  puts "\n📅 Enqueueing Scheduled Jobs:"
  TestEmailJob.perform_at(Time.now + 15, 300, "Scheduled welcome email")
  puts "   ✓ Scheduled EmailJob (15 seconds from now)"
  
  puts "\n✅ All jobs enqueued!"
end

def show_failed_jobs
  failed = FiberJob::Queue.failed_jobs
  if failed.empty?
    puts "✅ No failed jobs"
  else
    puts "❌ Failed jobs:"
    failed.each_with_index do |job, i|
      puts "   #{i + 1}. #{job['class']} - #{job['error']}"
      puts "      Failed at: #{Time.at(job['failed_at'])}"
    end
  end
end

def interactive_menu
  loop do
    puts "\n" + "=" * 60
    puts "🎛️  FiberJob Test Client"
    puts "=" * 60
    puts "1. Enqueue test jobs"
    puts "2. Show queue statistics"
    puts "3. Show failed jobs"
    puts "4. Enqueue single email job"
    puts "5. Enqueue high-priority report job"
    puts "6. Enqueue delayed job (10s)"
    puts "7. Stress test (100 jobs)"
    puts "0. Exit"
    puts "=" * 60
    print "Choose an option: "
    
    choice = gets.chomp
    
    case choice
    when '1'
      enqueue_test_jobs
      print_queue_stats
    when '2'
      print_queue_stats
    when '3'
      show_failed_jobs
    when '4'
      user_id = rand(1000..9999)
      TestEmailJob.perform_async(user_id, "Single test email")
      puts "✓ Single EmailJob enqueued for user #{user_id}"
    when '5'
      TestReportJob.perform_async("urgent_report", rand(1000..5000))
      puts "✓ High-priority ReportJob enqueued"
    when '6'
      TestEmailJob.perform_in(10, rand(1000..9999), "Delayed test email (10s)")
      puts "✓ Delayed EmailJob enqueued (10 seconds)"
    when '7'
      puts "🔥 Stress test: Enqueueing 100 jobs..."
      start_time = Time.now
      100.times do |i|
        case i % 3
        when 0
          TestEmailJob.perform_async(i, "Stress test email #{i}")
        when 1
          TestReportJob.perform_async("stress_report_#{i}", rand(100..1000))
        when 2
          TestCleanupJob.perform_async("stress_cleanup_#{i}")
        end
      end
      duration = Time.now - start_time
      puts "✅ 100 jobs enqueued in #{duration.round(3)}s (#{(100/duration).round(1)} jobs/sec)"
      print_queue_stats
    when '0'
      puts "👋 Goodbye!"
      break
    else
      puts "❌ Invalid option. Please try again."
    end
  end
end

# Check if Redis is available
begin
  FiberJob::Queue.redis.ping
  puts "✅ Redis connection successful"
rescue => e
  puts "❌ Redis connection failed: #{e.message}"
  puts "   Make sure Redis is running on #{FiberJob.config.redis_url}"
  exit 1
end

puts "🎯 FiberJob Test Client"
puts "📊 Connected to Redis: #{FiberJob.config.redis_url}"

# Show initial stats
print_queue_stats

# Start interactive menu
interactive_menu