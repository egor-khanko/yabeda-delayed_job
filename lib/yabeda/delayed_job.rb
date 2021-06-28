# frozen_string_literal: true

require 'yabeda/delayed_job/version'
require 'delayed_job'
require 'yabeda'
require 'yabeda/delayed_job/plugin'

module Yabeda
  module DelayedJob
    class Error < StandardError; end

    LONG_RUNNING_JOB_RUNTIME_BUCKETS = [
      0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, # standard (from Prometheus)
      30, 60, 120, 300, 1800, 3600, 21_600 # DelayedJob tasks may be very long-running
    ].freeze

    ::Yabeda.configure do
      group :delayed_job

      counter :jobs_enqueued_total, tags: %i[queue worker], comment: 'A counter of the total number of jobs enqueued.'
      counter :jobs_failed_total, tags: %i[queue worker error], comment: 'asdf'
      counter :jobs_errored_total, tags: %i[queue worker error], comment: 'asdf'

      histogram :job_runtime, comment: 'A histogram of the job execution time.',
                              unit: :seconds, per: :job,
                              tags: %i[queue worker],
                              buckets: LONG_RUNNING_JOB_RUNTIME_BUCKETS
      gauge :running_job_runtime, tags: %i[queue worker], aggregation: :max, unit: :seconds,
                                  comment: 'How long currently running jobs are running ' \
                                           '(useful for detection of hung jobs)'
      gauge     :jobs_waiting_count,   tags: %i[queue], comment: 'The number of jobs waiting to process in sidekiq.'
      gauge     :queue_latency,        tags: %i[queue],
                                       comment: 'The queue latency, the difference in seconds since the oldest ' \
                                                'job in the queue was enqueued'

      collect do
        Yabeda::DelayedJob.track_max_job_runtime if ::Yabeda::DelayedJob.server?
        puts ::Yabeda::DelayedJob.active_record_adapter?
        ::Yabeda::DelayedJob.track_database_metrics if ::Yabeda::DelayedJob.active_record_adapter?
      end
    end

    class << self
      def server?
        require 'delayed/command'
        @server ||= ObjectSpace.each_object(Delayed::Command).any?
      end

      def labelize(job)
        result = { queue: job.queue, worker: job.name }
        result.merge!(error: job.error.class.name) if job.error
        result
      end

      def track_database_metrics
        job_scope.select(:queue).count.each do |queue, count|
          Yabeda.delayed_job.jobs_waiting_count.set({ queue: queue }, count)
        end
        job_scope.select('max(NOW() - run_at)').each do |job|
          Yabeda.delayed_job.queue_latency.set({ queue: job.queue }, job.latency)
        end
      end

      def job_scope
        db_time_now = ::Delayed::Worker.backend.db_time_now
        ::Delayed::Worker.backend.where(
          '(run_at <= ? AND (locked_at IS NULL OR locked_at < ?)) AND failed_at IS NULL',
          db_time_now,
          db_time_now - ::Delayed::Worker.max_run_time
        ).group(:queue)
      end

      def active_record_adapter?
        defined?(Delayed::Backend::ActiveRecord::Job) &&
          Delayed::Worker.backend.name == Delayed::Backend::ActiveRecord::Job.name
      end

      # Hash of hashes containing all currently running jobs' start timestamps
      # to calculate maximum durations of currently running not yet completed jobs
      # { { queue: "default", worker: "SomeJob" } => { "jid1" => 100500, "jid2" => 424242 } }
      attr_accessor :jobs_started_at

      def track_max_job_runtime
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ::Yabeda::DelayedJob.jobs_started_at.each do |labels, jobs|
          oldest_job_started_at = jobs.values.min
          oldest_job_duration = oldest_job_started_at ? (now - oldest_job_started_at).round(3) : 0
          Yabeda.delayed_job.running_job_runtime.set(labels, oldest_job_duration)
        end
      end

      def elapsed(start)
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(3)
      end
    end

    self.jobs_started_at = Concurrent::Hash.new { |hash, key| hash[key] = Concurrent::Hash.new }

    Delayed::Worker.plugins << ::Yabeda::DelayedJob::Plugin
  end
end
