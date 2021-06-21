# frozen_string_literal: true

ActiveRecord::Base.connection.tap do |conn|
  break if conn.table_exists? :delayed_jobs

  conn.create_table :delayed_jobs do |table|
    table.integer :priority, default: 0, null: false
    table.integer :attempts, default: 0, null: false
    table.text :handler,                 null: false
    table.text :last_error
    table.datetime :run_at
    table.datetime :locked_at
    table.datetime :failed_at
    table.string :locked_by
    table.string :queue
    table.timestamps null: true
  end

  conn.add_index :delayed_jobs, %i[priority run_at], name: 'delayed_jobs_priority'
end
