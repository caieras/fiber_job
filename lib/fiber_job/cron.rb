# frozen_string_literal: true

module FiberJob
  class Cron
    def self.redis
      @redis ||= Redis.new(url: FiberJob.config.redis_url)
    end

    def self.register(cron_job_class)
      job_name = cron_job_class.name
      cron_expression = cron_job_class.cron_expression

      redis.hset('cron:jobs', job_name, JSON.dump({ 'class' => job_name,
                                                    'cron' => cron_expression,
                                                    'queue' => cron_job_class.new.queue,
                                                    'registered_at' => Time.now.to_f }))

      unless redis.exists?("cron:next_run:#{job_name}")
        next_time = cron_job_class.next_run_time
        schedule_job(cron_job_class, next_time)
      end

      FiberJob.logger.info "Registered cron job: #{job_name} (#{cron_expression})"
    end

    def self.schedule_job(cron_job_class, run_time)
      job_name = cron_job_class.name

      # Set next run time
      redis.set("cron:next_run:#{job_name}", run_time.to_f)

      # Add to sorted set for efficient scanning
      redis.zadd('cron:schedule', run_time.to_f, job_name)

      FiberJob.logger.debug "Scheduled #{job_name} for #{run_time}"
    end

    def self.due_jobs(current_time = Time.now)
      job_names = redis.zrangebyscore('cron:schedule', 0, current_time.to_f)

      job_names.map do |job_name|
        job_data = JSON.parse(redis.hget('cron:jobs', job_name))
        next unless job_data

        redis.zrem('cron:schedule', job_name)

        job_data
      end.compact
    end

    def self.registered_jobs
      jobs = redis.hgetall('cron:jobs')
      jobs.transform_values { |data| JSON.parse(data) }
    end

    def self.clear_all
      redis.del('cron:jobs', 'cron:schedule')
      redis.keys('cron:next_run:*').each { |key| redis.del(key) }
    end
  end
end
