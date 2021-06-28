# frozen_string_literal: true

class RandomJob
  def call
    sleep(rand(5000) / 1000.0)
  end
end

class RandomFailJob
  def call
    raise StandardError if (rand(100) % 3).zero?
  end
end
