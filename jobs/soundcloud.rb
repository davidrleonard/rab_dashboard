require 'date'
require 'active_support/core_ext/date/calculations' # Help parsing dates
require 'soundcloud'
require 'http'
require 'json'

# if File.exists? (File.expand_path("../../lib/soundcloud_secrets.yml", __FILE__))
#   SC_CONFIG = YAML.load_file(File.expand_path("../../lib/soundcloud_secrets.yml", __FILE__))
# else
#   SC_CONFIG = {}
#   SC_CONFIG['client_id'] = ENV['SC_CLIENT_ID']
#   SC_CONFIG['client_secret'] = ENV['SC_CLIENT_SECRET']
#   SC_CONFIG['username'] = ENV['SC_USERNAME']
#   SC_CONFIG['password'] = ENV['SC_PASSWORD']
# end
#
# # Get the Soundcloud API client
# client = Soundcloud.new(
#   :client_id => SC_CONFIG['client_id'],
#   :client_secret => SC_CONFIG['client_secret'],
#   :username => SC_CONFIG['username'],
#   :password => SC_CONFIG['password'])

# Start the scheduler
SCHEDULER.every '60m', :first_in => 0 do
  # # GET INFO ABOUT ACCOUNT
  # account = client.get('/me')
  #
  # # GET ALL TRACKS, LOOP OVER THEM FOR A TOTAL PLAY COUNT LIFETIME
  # plays = 0
  # tracks = client.get('/me/tracks', :limit => 1000) # arbitrarily limit the number of tracks to 1000... we're in the 120's now
  # tracks.each do |track|
  #   plays += track['playback_count'].to_i
  # end
  #
  # # UPDATE THE DASHBOARD
  # send_event('soundcloud_plays',  { current: plays,
  #                                   last: 0 })

  # Get the data from our mini-API for Soundcloud analytics
  raw_api_data = HTTP.headers(:accept => "application/json").get('http://sc.radioambulante.org/api/1/plays.json')
  api_data = JSON.parse(raw_api_data.to_s)

  # UPDATE THE DASHBOARD
  send_event('soundcloud_plays_monthly',  { current: api_data['play_count']['this_month'],
                                            last: api_data['play_count']['last_month'] })
  send_event('soundcloud_plays_all',  { current: api_data['all_time_plays']['today'],
                                        last: api_data['all_time_plays']['thirty_days_ago'] })
end
