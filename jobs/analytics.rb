require 'google/api_client'
require 'date'
require 'active_support/core_ext/date/calculations' # Help parsing dates
require 'soundcloud'

opts = YAML.load_file(File.expand_path("../../lib/google_config.yml", __FILE__))

# Get the Google API client
client = Google::APIClient.new(
  :application_name => opts['application_name'],
  :application_version => opts['application_version'])

# Load your credentials for the service account
if ENV['RACK_ENV']=="production"
  key = OpenSSL::PKey::RSA.new ENV["GOOGLE_KEY_JSON"], opts['key_secret']
  # key = Google::APIClient::KeyUtils.load_from_pkcs12(ENV['GOOGLE_KEY_P12'], opts['key_secret'])
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
SCHEDULER.every '10m', :first_in => 0 do

  # SETUP FOR ALL QUERIES
  # Request a token for our service account
  client.authorization.fetch_access_token!
  # Get the analytics API
  analytics = client.discovered_api('analytics','v3')

  # # START AND END DATES FOR CURRENT MONTH
  # thisMonthStartDate = Date.today.beginning_of_month.to_s # first day of current month
  # thisMonthEndDate = Date.today.to_s  # now
  # # How many days so far this month, for comparison to last month?
  # daysElapsedThisMonth = (Date.today - Date.today.beginning_of_month).to_i
  # # Start and end dates for last month
  # lastMonthStartDate = Date.today.beginning_of_month.last_month.to_s # first day of the previous month
  # lastMonthEndDate = (Date.today.beginning_of_month.last_month + daysElapsedThisMonth).to_s # for comparison, same number of days elapsed last month

  # START AND END DATES FOR LAST 30, 60 DAYS
  thisMonthStartDate = (Date.today - 30).to_s # 30 days ago
  thisMonthEndDate = Date.today.to_s  # today
  # Start and end dates for last month
  lastMonthStartDate = (Date.today - 60).to_s # 60 days ago
  lastMonthEndDate = (Date.today - 30).to_s # 30 days ago

  # VISIT COUNT QUERY
  thisMonthVisitData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => thisMonthStartDate,
    'end-date' => thisMonthEndDate,
    # 'dimensions' => "ga:month",
    'metrics' => "ga:visitors",
    # 'sort' => "ga:month"
  })
  lastMonthVisitData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => lastMonthStartDate,
    'end-date' => lastMonthEndDate,
    # 'dimensions' => "ga:month",
    'metrics' => "ga:visitors",
    # 'sort' => "ga:month"
  })
  # puts lastMonthVisitData.data.inspect
  # puts thisMonthVisitData.data.rows[0][0].to_i
  thisMonthActiveUsers = thisMonthVisitData.data.rows[0][0].to_i
  lastMonthActiveUsers = lastMonthVisitData.data.rows[0][0].to_i

  # REFERRALS QUERY
  referralData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => thisMonthStartDate,
    'end-date' => thisMonthEndDate,
    'metrics' => "ga:users",
    'sort' => "-ga:users",
    'dimensions' => "ga:sourceMedium",
    'filters' => "ga:medium==referral",
    'max-results' => 15
  })
  referralList = []
  referralData.data.rows.each do |referral|
    referralList.push({
      'label' => referral[0].gsub(' / referral', ''),
      'value' => referral[1],
      'url' => "http://#{referral[0].gsub(' / referral', '')}"})
  end

  # COUNTRIES QUERY
  countryData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => thisMonthStartDate,
    'end-date' => thisMonthEndDate,
    'metrics' => "ga:users",
    'sort' => "-ga:users",
    'dimensions' => "ga:country",
    'max-results' => 7
  })
  countryList = []
  countryData.data.rows.each do |country|
    countryList.push({ 'label' => country[0], 'value' => country[1] })
  end

  # PERCENT NEW USERS QUERY
  newUsersData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => thisMonthStartDate,
    'end-date' => thisMonthEndDate,
    'metrics' => "ga:percentNewSessions"
  })
  newUsers = newUsersData.data.rows[0][0].to_i

  # TOP GOOGLE ANALYTICS EVENTS
  eventData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => thisMonthStartDate,
    'end-date' => thisMonthEndDate,
    'metrics' => "ga:totalEvents",
    'sort' => "-ga:totalEvents",
    'dimensions' => "ga:eventCategory"
  })
  eventList = []
  eventData.data.rows.each do |country|
    next if country[0] == 'Error'
    next if country[0] == 'SoundCloud'
    next if country[0] == 'undefined'
    eventList.push({ 'label' => country[0], 'value' => country[1] })
  end

  # AVERAGE TIME ON SITE
  thisMonthAvgSessionDurationData = client.execute(:api_method => analytics.data.ga.get, :parameters => {
    'ids' => "ga:" + opts['profileID'].to_s,
    'start-date' => thisMonthStartDate,
    'end-date' => thisMonthEndDate,
    'metrics' => "ga:avgSessionDuration"
  })
  thisMonthAvgSessionDuration = thisMonthAvgSessionDurationData.data.rows[0][0].to_i / 60

  # UPDATE THE DASHBOARD
  send_event('active_users',      { current: thisMonthActiveUsers,
                                    last: lastMonthActiveUsers })
  send_event('referrals',         { items: referralList })
  send_event('countries',         { items: countryList })
  send_event('new_users',         { value: newUsers })
  send_event('events',            { items: eventList })
  send_event('session_duration',  { current: thisMonthAvgSessionDuration,
                                    last: 5 })
end
