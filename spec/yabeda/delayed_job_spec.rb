# frozen_string_literal: true

# rubocop: disable Metrics/BlockLength
RSpec.describe Yabeda::DelayedJob do
  it 'has a version number' do
    expect(Yabeda::DelayedJob::VERSION).not_to be nil
  end

  describe 'log enqueues and job runtime' do
    it do
      expect { Job.new({ asdf: 'asdf' }).delay(queue: :q).call }.to change {
                                                                      ::Yabeda.delayed_job.jobs_enqueued_total.values[{
                                                                        queue: 'q', worker: 'Job#call'
                                                                      }]
                                                                    }.by(1)

      expect { ::Delayed::Worker.new.work_off }.to change {
                                                     ::Yabeda.delayed_job.job_runtime.values[{ queue: 'q',
                                                                                               worker: 'Job#call' }]
                                                   }.from(nil)
    end
  end

  describe 'log errors and failures' do
    it do
      FailJob.new(some: :data).delay(queue: :fail_queue).call

      expect { ::Delayed::Worker.new.work_off(1) }.to change {
        ::Yabeda.delayed_job.jobs_errored_total.values[{ queue: 'fail_queue', worker: 'FailJob#call',
                                                         error: 'StandardError' }]
      }.by(1)
      ::Delayed::Backend::ActiveRecord::Job.destroy_all
    end
  end

  describe 'collect' do
    it do
      FailJob.new(some: :data).delay(queue: :fail_queue).call

      expect { Yabeda.collectors.each(&:call) }.not_to raise_error
      ::Delayed::Backend::ActiveRecord::Job.destroy_all
    end
  end
end
# rubocop: enable Metrics/BlockLength
