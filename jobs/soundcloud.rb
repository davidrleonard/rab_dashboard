require 'date'
require 'active_support/core_ext/date/calculations' # Help parsing dates
require 'soundcloud'

if File.exists? (File.expand_path("../../lib/soundcloud_secrets.yml", __FILE__))
  SC_CONFIG = YAML.load_file(File.expand_path("../../lib/soundcloud_secrets.yml", __FILE__))
else
  SC_CONFIG = {}
  SC_CONFIG['client_id'] = ENV['SC_CLIENT_ID']
  SC_CONFIG['client_secret'] = ENV['SC_CLIENT_SECRET']
  SC_CONFIG['username'] = ENV['SC_USERNAME']
  SC_CONFIG['password'] = ENV['SC_PASSWORD']
end

puts 'CONFIG\n'
puts SC_CONFIG

# Get the Soundcloud API client
client = Soundcloud.new(
  :client_id => SC_CONFIG['client_id'],
  :client_secret => SC_CONFIG['client_secret'],
  :username => SC_CONFIG['username'],
  :password => SC_CONFIG['password'])

# Start the scheduler
SCHEDULER.every '60m', :first_in => 0 do
  # GET INFO ABOUT ACCOUNT
  account = client.get('/me')

  # GET ALL TRACKS, LOOP OVER THEM FOR A TOTAL PLAY COUNT LIFETIME
  plays = 0
  tracks = client.get('/me/tracks')
  tracks.each do |track|
    plays += track['playback_count'].to_i
  end

  # UPDATE THE DASHBOARD
  send_event('soundcloud_plays',  { current: plays,
                                    last: 0 })
end
