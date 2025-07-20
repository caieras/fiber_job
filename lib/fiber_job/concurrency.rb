# frozen_string_literal: true

require 'async'
require 'async/semaphore'

module FiberJob
  # The ConcurrencyManager class is a lightweight wrapper around Async::Semaphore that
  # controls how many jobs can execute simultaneously within each queue
  class ConcurrencyManager
    def initialize(max_concurrency: 5)
      @semaphore = Async::Semaphore.new(max_concurrency)
    end

    def execute(&block)
      @semaphore.async(&block)
    end
  end
end
