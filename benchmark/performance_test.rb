#!/usr/bin/env ruby
# frozen_string_literal: true

# Performance test for FiberJob
# Usage: ruby benchmark/performance_test.rb [job_count]

require_relative '../lib/fiber_job'

# # Configure for performance testing
FiberJob.configure do |config|
  config.redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/2'  # Use DB 2 for perf tests
  config.queues = [:perf_test]
  config.queue_concurrency = { perf_test: 50 }  # High concurrency
  config.log_level = :warn  # Reduce logging for performance
end

# Load shared test job classes
require_relative 'test_jobs'

def clear_results
  FiberJob::Queue.redis.del("perf_results")
  puts "🧹 Cleared previous results"
end

def enqueue_jobs(count, work_duration = 0.01)
  puts "🚀 Enqueueing #{count} jobs with #{work_duration}s work each..."
  
  start_time = Time.now
  
  count.times do |i|
    PerfTestJob.perform_async(i + 1, work_duration)
  end
  
  enqueue_duration = Time.now - start_time
  enqueue_rate = count / enqueue_duration
  
  puts "✅ Enqueued #{count} jobs in #{enqueue_duration.round(3)}s"
  puts "📊 Enqueue rate: #{enqueue_rate.round(1)} jobs/second"
  
  enqueue_duration
end

def wait_for_completion(expected_count)
  puts "\n⏳ Waiting for jobs to complete..."
  
  start_time = Time.now
  last_count = 0
  
  loop do
    completed = FiberJob::Queue.redis.llen("perf_results")
    
    if completed != last_count
      puts "   Progress: #{completed}/#{expected_count} completed"
      last_count = completed
    end
    
    break if completed >= expected_count
    
    # Timeout after 5 minutes
    if Time.now - start_time > 300
      puts "⚠️  Timeout after 5 minutes"
      break
    end
    
    sleep(0.5)
  end
  
  Time.now - start_time
end

def analyze_results
  results_json = FiberJob::Queue.redis.lrange("perf_results", 0, -1)
  
  if results_json.empty?
    puts "❌ No results found"
    return
  end
  
  results = results_json.map { |json| JSON.parse(json) }
  
  # Calculate statistics
  queue_times = results.map { |r| r['queue_time'] }
  processing_times = results.map { |r| r['processing_time'] }
  
  first_enqueue = results.map { |r| r['enqueued_at'] }.min
  last_complete = results.map { |r| r['completed_at'] }.max
  total_duration = last_complete - first_enqueue
  
  throughput = results.size / total_duration
  
  puts "\n📊 Performance Results:"
  puts "=" * 50
  puts "Jobs completed: #{results.size}"
  puts "Total duration: #{total_duration.round(3)}s"
  puts "Throughput: #{throughput.round(1)} jobs/second"
  puts
  puts "Queue Time (time waiting in Redis):"
  puts "  Average: #{(queue_times.sum / queue_times.size).round(4)}s"
  puts "  Min: #{queue_times.min.round(4)}s"
  puts "  Max: #{queue_times.max.round(4)}s"
  puts "  P95: #{queue_times.sort[(queue_times.size * 0.95).to_i].round(4)}s"
  puts
  puts "Processing Time (actual job execution):"
  puts "  Average: #{(processing_times.sum / processing_times.size).round(4)}s"
  puts "  Min: #{processing_times.min.round(4)}s"
  puts "  Max: #{processing_times.max.round(4)}s"
  puts "  P95: #{processing_times.sort[(processing_times.size * 0.95).to_i].round(4)}s"
end

def run_performance_test(job_count, work_duration = 0.01)
  puts "🎯 FiberJob Performance Test"
  puts "=" * 50
  puts "Jobs to enqueue: #{job_count}"
  puts "Work duration per job: #{work_duration}s"
  puts "Queue concurrency: #{FiberJob.config.queue_concurrency[:perf_test]}"
  puts "Redis: #{FiberJob.config.redis_url}"
  puts "=" * 50
  
  # Clear previous results
  clear_results
  
  # Enqueue jobs
  enqueue_duration = enqueue_jobs(job_count, work_duration)
  
  # Wait for completion
  processing_duration = wait_for_completion(job_count)
  
  # Analyze results
  analyze_results
  
  puts "\n⏱️  Summary:"
  puts "Enqueue phase: #{enqueue_duration.round(3)}s"
  puts "Processing phase: #{processing_duration.round(3)}s"
  puts "Total test time: #{(enqueue_duration + processing_duration).round(3)}s"
end

# Parse arguments
job_count = (ARGV[0] || '100').to_i
work_duration = (ARGV[1] || '0.01').to_f

if job_count <= 0
  puts "❌ Invalid job count: #{ARGV[0]}"
  puts "Usage: ruby benchmark/performance_test.rb [job_count] [work_duration]"
  puts "Example: ruby benchmark/performance_test.rb 1000 0.005"
  exit 1
end

# Check Redis connection
begin
  FiberJob::Queue.redis.ping
rescue => e
  puts "❌ Redis connection failed: #{e.message}"
  puts "   Make sure Redis is running and start a worker:"
  puts "   $ ruby benchmark/test_worker.rb"
  exit 1
end

# Check if worker is processing
queue_size_before = FiberJob::Queue.stats(:perf_test)[:size]
PerfTestJob.perform_async(0, 0.001)  # Test job
sleep(2)
queue_size_after = FiberJob::Queue.stats(:perf_test)[:size]

if queue_size_after >= queue_size_before
  puts "⚠️  Warning: No worker seems to be processing jobs"
  puts "   Start a worker in another terminal:"
  puts "   $ ruby benchmark/test_worker.rb"
  puts "   Or:"
  puts "   $ ruby benchmark/run_tests.rb worker"
  puts
  print "Continue anyway? (y/N): "
  response = STDIN.gets.chomp.downcase
  exit 1 unless response == 'y'
end

run_performance_test(job_count, work_duration)