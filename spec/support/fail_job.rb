# frozen_string_literal: true

class FailJob
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def call
    raise StandardError
  end
end
