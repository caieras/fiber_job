# FiberJob Benchmark Suite

Test scripts for validating and benchmarking your FiberJob gem locally.

## Prerequisites

1. **Redis Server**: Make sure Redis is running
   ```bash
   redis-server
   ```

2. **Install Dependencies**:
   ```bash
   bundle install
   ```

## Test Scripts

### 🚀 Quick Start

**Start both worker and client** (recommended for first test):
```bash
ruby benchmark/run_tests.rb
```

This will:
- Start a worker in the background
- Start an interactive client for enqueueing jobs
- Use Redis database 1 for testing

### 🔄 Individual Components

**Start only worker** (in terminal 1):
```bash
ruby benchmark/run_tests.rb worker
# or directly:
ruby benchmark/test_worker.rb
```

**Start only client** (in terminal 2):
```bash
ruby benchmark/run_tests.rb client
# or directly:
ruby benchmark/test_client.rb
```

### ⚡ Performance Testing

**Run performance benchmark**:
```bash
# Test with 1000 jobs, 0.01s work each
ruby benchmark/performance_test.rb 1000 0.01

# Quick test with 100 jobs
ruby benchmark/performance_test.rb 100

# Stress test with 5000 jobs
ruby benchmark/performance_test.rb 5000 0.005
```

**Note**: Make sure a worker is running before performance testing!

## Test Features

### 📧 Test Jobs Available

1. **TestEmailJob** (queue: default)
   - Simulates email sending
   - Random work duration: 0.5-2.0s
   - 10% random failure rate (for retry testing)
   - Max retries: 3

2. **TestReportJob** (queue: high)
   - Simulates report generation
   - Work duration based on data size
   - Max retries: 2
   - Timeout: 10s

3. **TestCleanupJob** (queue: low)
   - Simulates cleanup operations
   - Random work duration: 1.0-3.0s
   - Max retries: 1

4. **TestDailyCronJob** (cron: every 30 seconds)
   - Tests cron job functionality
   - Runs automatically when worker is active

### 🎛️ Interactive Client Features

- Enqueue individual jobs
- Bulk job enqueueing
- View queue statistics
- View failed jobs
- Stress testing (100 jobs)
- Delayed and scheduled jobs

### 📊 Performance Metrics

The performance test measures:
- **Enqueue rate**: Jobs/second during enqueueing
- **Throughput**: Jobs/second overall processing
- **Queue time**: Time waiting in Redis
- **Processing time**: Actual job execution time
- **Percentiles**: P95 timing statistics

## Configuration

### Environment Variables

```bash
# Use different Redis database
REDIS_URL=redis://localhost:6379/3 ruby test/test_worker.rb

# Change log level
FIBER_JOB_LOG_LEVEL=debug ruby test/test_worker.rb

# Custom Redis URL
REDIS_URL=redis://192.168.1.100:6379/0 ruby test/run_tests.rb
```

### Test Configuration

The tests use these settings:
- **Redis Database**: 1 (functional tests), 2 (performance tests)
- **Queues**: `[:default, :high, :low]` (functional), `[:perf_test]` (performance)
- **Concurrency**: `{default: 3, high: 5, low: 1}` (functional), `{perf_test: 10}` (performance)

## Expected Results

### 🎯 Functional Testing

You should see:
- Jobs being processed across different queues
- Retry logic working for failed jobs
- Cron jobs executing every 30 seconds
- Real-time queue statistics
- Sub-second job pickup times

## Troubleshooting

### Redis Connection Issues
```bash
# Check Redis status
redis-cli ping

# Start Redis if not running
redis-server

# Check Redis logs
tail -f /usr/local/var/log/redis.log
```

### No Jobs Processing
- Make sure worker is running: `ruby test/test_worker.rb`
- Check Redis connection in both worker and client
- Verify queue names match between worker and client

### Performance Issues
- Try different concurrency settings
- Monitor Redis memory usage: `redis-cli info memory`
- Check system resources: `top` or `htop`

## Examples

### Typical Test Session

1. **Terminal 1**: Start worker
   ```bash
   ruby benchmark/test_worker.rb
   ```

2. **Terminal 2**: Run client tests
   ```bash
   ruby benchmark/test_client.rb
   # Choose option 1 to enqueue test jobs
   # Choose option 2 to see queue stats
   ```

3. **Terminal 3**: Run performance test
   ```bash
   ruby benchmark/performance_test.rb 500
   ```