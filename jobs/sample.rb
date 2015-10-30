current_valuation = 0
current_karma = 0

SCHEDULER.every '10s' do
  last_valuation = current_valuation
  last_karma     = current_karma
  current_valuation = rand(100)
  current_karma     = rand(200000)

  send_event('valuation', { current: current_valuation, last: last_valuation })
  send_event('karma', { current: current_karma, last: last_karma })
  send_event('synergy',   { value: rand(100) })

  # data = [
  #   { "x" => "United States", "y" => 1230 },
  #   { "x" => "Argentina", "y" => 300 },
  #   { "x" => "Mexico", "y" => 576 }
  # ]
  data = [
    { "name" => "United States", "data" => 1230 },
    { "name" => "Argentina", "data" => 300 },
    { "name" => "Mexico", "data" => 576 }
  ]
  send_event('sample_graph', { points: data })

end
