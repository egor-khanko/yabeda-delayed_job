# frozen_string_literal: true

require 'benchmark'

module Yabeda
  module DelayedJob
    class Plugin < ::Delayed::Plugin
      callbacks do |lifecycle|
        lifecycle.after(:enqueue) do |job|
          labels = ::Yabeda::DelayedJob.labelize(job)
          ::Yabeda.delayed_job.jobs_enqueued_total.increment(labels)
        end

        lifecycle.after(:failure) do |_worker, job|
          labels = ::Yabeda::DelayedJob.labelize(job)
          ::Yabeda.delayed_job.jobs_failed_total.increment(labels)
        end

        lifecycle.after(:error) do |_worker, job|
          labels = ::Yabeda::DelayedJob.labelize(job)
          ::Yabeda.delayed_job.jobs_errored_total.increment(labels)
        end

        lifecycle.around(:perform) do |worker, job, &block|
          begin
            labels = ::Yabeda::DelayedJob.labelize(job)

            Process.clock_gettime(Process::CLOCK_MONOTONIC).tap do |start|
              Yabeda::DelayedJob.jobs_started_at[labels][job.id] = start

              block.call(worker)

              Yabeda.delayed_job.job_runtime.measure(
                labels,
                ::Yabeda::DelayedJob.elapsed(start)
              )
            end
          ensure
            Yabeda::DelayedJob.jobs_started_at[labels].delete(job.id)
          end
        end
      end
    end
  end
end
