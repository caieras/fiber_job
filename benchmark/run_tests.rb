#!/usr/bin/env ruby
# frozen_string_literal: true

# Test runner for FiberJob - manages worker and client processes
# Usage: ruby test/run_tests.rb [worker|client|both]

require 'optparse'

def print_banner
  puts <<~BANNER
    ╔═══════════════════════════════════════════════════════════════╗
    ║                      🚀 FiberJob Test Suite                   ║
    ╚═══════════════════════════════════════════════════════════════╝
  BANNER
end

def check_redis
  require 'redis'
  redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/1'
  
  begin
    redis = Redis.new(url: redis_url)
    redis.ping
    puts "✅ Redis connection successful (#{redis_url})"
    true
  rescue => e
    puts "❌ Redis connection failed: #{e.message}"
    puts "   Please start Redis server first:"
    puts "   $ redis-server"
    puts "   Or set REDIS_URL environment variable"
    false
  end
end

def run_worker
  puts "\n🔄 Starting FiberJob Worker..."
  puts "   (Use Ctrl+C to stop)"
  puts "   Logs will appear below:"
  puts "-" * 60
  
  exec("ruby", File.join(__dir__, "test_worker.rb"))
end

def run_client
  puts "\n🎛️  Starting FiberJob Test Client..."
  puts "   Use the interactive menu to enqueue jobs"
  puts "-" * 60
  
  exec("ruby", File.join(__dir__, "test_client.rb"))
end

def run_both
  puts "\n🔄 Starting both Worker and Client..."
  puts "   Worker will run in background"
  puts "   Client will start interactive mode"
  puts "-" * 60
  
  # Start worker in background
  worker_pid = fork do
    exec("ruby", File.join(__dir__, "test_worker.rb"))
  end
  
  # Give worker time to start
  sleep(2)
  
  # Start client in foreground
  begin
    exec("ruby", File.join(__dir__, "test_client.rb"))
  ensure
    # Clean up worker process
    Process.kill("TERM", worker_pid) if worker_pid
    Process.wait(worker_pid) if worker_pid
  end
end

def show_help
  puts <<~HELP
    FiberJob Test Suite
    
    Usage:
      ruby test/run_tests.rb [command]
    
    Commands:
      worker    Start only the worker process
      client    Start only the client (for enqueueing jobs)
      both      Start worker in background + client in foreground (default)
      help      Show this help message
    
    Environment Variables:
      REDIS_URL         Redis connection string (default: redis://localhost:6379/1)
      FIBER_JOB_LOG_LEVEL  Log level: debug, info, warn, error (default: info)
    
    Examples:
      ruby test/run_tests.rb                    # Start both worker and client
      ruby test/run_tests.rb worker             # Start only worker
      ruby test/run_tests.rb client             # Start only client
      REDIS_URL=redis://localhost:6379/2 ruby test/run_tests.rb worker
  HELP
end

# Parse command line arguments
command = ARGV[0] || 'both'

print_banner

case command
when 'worker'
  exit 1 unless check_redis
  run_worker
when 'client'
  exit 1 unless check_redis
  run_client
when 'both', 'all'
  exit 1 unless check_redis
  run_both
when 'help', '--help', '-h'
  show_help
else
  puts "❌ Unknown command: #{command}"
  puts "   Run 'ruby test/run_tests.rb help' for usage information"
  exit 1
end