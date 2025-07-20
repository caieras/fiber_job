# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-07-20

### Added
- Initial release of FiberJob
- Hybrid Redis + Async::Queue architecture for optimal performance
- Fiber-based job processing with async/await patterns
- Job scheduling with delayed and scheduled execution
- Cron job support with standard cron expressions
- Built-in retry logic with exponential backoff
- Priority queue support
- Per-queue concurrency control with semaphores
- Comprehensive failure tracking and monitoring
- Production-ready logging system
- Full YARD documentation coverage

### Features
- **Core**: Job enqueueing, processing, and lifecycle management
- **Scheduling**: Immediate, delayed, and cron-based job execution
- **Concurrency**: Advanced fiber pools with semaphore control
- **Persistence**: Redis-backed job storage with atomic operations
- **Monitoring**: Queue statistics and failed job inspection
- **Configuration**: Flexible per-queue and global settings