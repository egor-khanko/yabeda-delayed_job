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
                                         comment: "How long currently running jobs are running (useful for detection of hung jobs)"

      collect do
        Yabeda::DelayedJob.track_max_job_runtime if ::Yabeda::DelayedJob.server?
      end
    end

    class << self
      def server?
        require 'delayed/command'
        ObjectSpace.each_object(Delayed::Command).any?
      end

      def labelize(job)
        result = { queue: job.queue, worker: job.name }
        result.merge!(error: job.error.class.name) if job.error
        result
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
