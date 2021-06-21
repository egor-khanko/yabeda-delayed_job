# frozen_string_literal: true

require 'bundler/setup'
require 'yabeda/delayed_job'
require 'byebug'

require 'active_record'
require 'delayed_job_active_record'

ActiveRecord::Base.establish_connection(
  url: ENV.fetch('DATABASE_URL')
)
require_relative 'support/migrations'
require_relative 'support/job'
require_relative 'support/fail_job'

::Yabeda.configure!

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
