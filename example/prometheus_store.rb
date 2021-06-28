# frozen_string_literal: true

require 'fileutils'
FileUtils.rm_rf('/tmp/prometheus')

require 'yabeda/prometheus'
data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: '/tmp/prometheus')
Prometheus::Client.config.data_store = data_store
