#!/usr/bin/env ruby

require 'active_record'
require 'delayed_job'
require 'delayed_job_active_record'
require_relative 'jobs'

ActiveRecord::Base.establish_connection(
  url: ENV.fetch('DATABASE_URL')
)
require '/gem/spec/support/migrations'
require 'delayed/command'

require 'yabeda/delayed_job'
::Yabeda.configure!

require_relative 'prometheus_store'

::Yabeda::Prometheus::Exporter.start_metrics_server!

Delayed::Worker.logger = Logger.new(STDOUT)
Delayed::Command.new(['run']).daemonize
