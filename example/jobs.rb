class RandomJob
  def call
    sleep(rand(5000) / 1000.0)
  end
end

class RandomFailJob
  def call
    raise StandardError.new if (rand(100) % 3) == 0
  end
end
