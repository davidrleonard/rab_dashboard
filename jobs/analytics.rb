require 'google/api_client'
require 'date'

opts = YAML.load_file(File.expand_path("../../lib/google_config.yml", __FILE__))

# Get the Google API client
client = Google::APIClient.new(
  :application_name => opts['application_name'],
  :application_version => opts['application_version'])

# Load your credentials for the service account
if ENV['RACK_ENV']=="production"
  key = Google::APIClient::KeyUtils.load_from_pkcs12(ENV['GOOGLE_KEY_P12'], opts['key_secret'])
else
  key = Google::APIClient::KeyUtils.load_from_pkcs12(File.expand_path("../../lib/#{opts['key_file']}", __FILE__), opts['key_secret'])
end
client.authorization = Signet::OAuth2::Client.new(
  :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
  :audience => 'https://accounts.google.com/o/oauth2/token',
  :scope => 'https://www.googleapis.com/auth/analytics.readonly',
  :issuer => opts['service_account_email'],
  :signing_key => key)

# Start the scheduler
SCHEDULER.every '1m', :first_in => 0 do

  # SETUP FOR ALL QUERIES
  # Request a token for our service account
  client.authorization.fetch_access_token!
  # Get the analytics API
  analytics = client.discovered_api('analytics','v3')
  # Start and end dates
  startDate = DateTime.now.strftime("%Y-%m-01") # first day of current month
  endDate = DateTime.now.strftime("%Y-%m-%d")  # now

  # VISIT COUNT QUERY
  visitData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => startDate,
    'end-date' => endDate,
    # 'dimensions' => "ga:month",
    'metrics' => "ga:visitors",
    # 'sort' => "ga:month"
  })
  # puts visitData.data.inspect
  # puts visitData.data.rows[0][0].to_i
  visitCount = visitData.data.rows[0][0].to_i

  # REFERRALS QUERY
  referralData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => startDate,
    'end-date' => endDate,
    'metrics' => "ga:users",
    'sort' => "-ga:users",
    'dimensions' => "ga:sourceMedium",
    'filters' => "ga:medium==referral",
    'max-results' => 15
  })
  referralList = []
  referralData.data.rows.each do |referral|
    referralList.push({ 'label' => referral[0].gsub(' / referral', ''), 'value' => referral[1] })
  end

  # COUNTRIES QUERY
  countryData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => startDate,
    'end-date' => endDate,
    'metrics' => "ga:users",
    'sort' => "-ga:users",
    'dimensions' => "ga:country",
    'max-results' => 7
  })
  countryList = []
  countryData.data.rows.each do |country|
    countryList.push({ 'label' => country[0], 'value' => country[1] })
  end

  # UPDATE THE DASHBOARD
  send_event('visitor_count',   { current: visitCount })
  send_event('referrals',       { items: referralList })
  send_event('countries',       { items: countryList })
end
