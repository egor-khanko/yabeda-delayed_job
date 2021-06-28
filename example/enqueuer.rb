#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_record'
require 'delayed_job'
require 'delayed_job_active_record'
require_relative 'jobs'

ActiveRecord::Base.establish_connection(
  url: ENV.fetch('DATABASE_URL')
)
require '/gem/spec/support/migrations'

require 'yabeda/delayed_job'
::Yabeda.configure!

require_relative 'prometheus_store'
::Yabeda::Prometheus::Exporter.start_metrics_server!

loop do
  sample = [RandomJob, RandomFailJob].sample
  queue = %i[queue1 queue2 queue3].sample

  puts "Enqueue #{sample.name} job into #{queue} queue"
  sample.new.delay(queue: queue).call
  sleep(0.1)
end
