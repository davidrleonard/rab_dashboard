require 'dashing'

configure do
  if ENV['RACK_ENV']=="production"
    set :auth_token, ENV['DASHING_AUTH_TOKEN']
  else
    set :auth_token, 'BLAH_BLAH_BLAH'
  end

  helpers do
    def protected!
      # Put any authentication code you want in here.
      # This method is run before accessing any resource.
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', 'ambulante123']
    end
  end

end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application
