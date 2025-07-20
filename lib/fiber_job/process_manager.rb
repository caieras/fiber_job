# frozen_string_literal: true

module FiberJob
  # ProcessManager is responsible for managing the lifecycle of workers
  # and ensuring they run with the correct configuration.
  class ProcessManager
    def self.start_worker(queues: nil, concurrency: nil)
      queues ||= FiberJob.config.queues
      concurrency ||= FiberJob.config.concurrency
      worker = Worker.new(queues: queues, concurrency: concurrency)

      trap('INT') { worker.stop }
      trap('TERM') { worker.stop }

      worker.start
    end
  end
end
