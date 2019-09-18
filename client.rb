require 'sinatra'
require 'open-uri'
require 'net/http'
require 'json'
require 'pry'
require 'oauth2'
require 'httparty'

# This application is the bare minimum to authorize with OAuth 2.0
# using the authorization grant scheme. No error handling included.
# The application is both a client and a resource server.
# Start it by using 'ruby <file>' and navigate to http://localhost:4567
#
# The application also needs the oauth-server written in Java.
# See https://github.com/comoyo/oauth-server
# Start it with 'mvn jetty:run' for now.

configure do
  set client_id: "b7UYp6aGcb3EAjjBWWj0PxqkX8H2GuT06449lq36PnU"
  set client_secret: "9X5oXjPrDmEizLV6DEq5unrJt9IXFO7fNSksOfSrrPk"
  set oauth_host: "http://localhost:3000"
end

# Global variables. So much ugly...
@@access_token = ""
@@redirect_uri = 'http://localhost:4567/oauth/callback'

# Client paths

# Root path. Begin here.
get '/' do
  "<h1>OAuth Client</h1><p>This is a lightweight OAuth client for the purposes of demoing connecting to 10,000ft and making an authorized API request to show projects.</p><p><a href='/oauth/redirect'>Authorize this app.</a></p>"
end

# The button on the main page takes the user here.
# Here, we build a redirect uri to the authorization server with
# the client id, state, redirect_uri to our callback and more.
get '/oauth/redirect' do
  code = params[:code]
  grant_type = "authorization_code"
  redirect_uri = @@redirect_uri

  client = OAuth2::Client.new(settings.client_id, settings.client_secret, site: 'http://localhost:3000', scope: 'project_index')
  uri = client.auth_code.authorize_url(redirect_uri: @@redirect_uri)
  # Send a 302 Temporary Redirect to the user-agent.
  # This will redirect the user to the Authorization server.
  redirect "#{uri}&scope=project_index"
end

# The user-agent is redirected here by the oauth-server after the app was given authorization.
# Here, we extract the authorization code and do an internal request to the token endpoint
# to retrieve the access token and optional refresh token.
get '/oauth/callback' do
  code = params[:code]

  response = HTTParty.post("#{settings.oauth_host}/oauth/token?code=#{code}&client_id=#{settings.client_id}&client_secret=#{settings.client_secret}&grant_type=authorization_code&redirect_uri=#{@@redirect_uri}&scope=project_index")


  # Extract the access token from the json response.
  @@access_token = response['access_token']

  # Redirect the user to another url to hide the ugly authcode url.
  redirect to('/oauth/finish')
end

# The user has now authorized our app, and the client has procured an access token.
# Here, we just present the user with a simple message and a prompt to fetch a protected resource.
# In reality, the client doesn't need user action to use the access token during the lifetime of the token.
get '/oauth/finish' do
  "Authorized. Access token is #{@@access_token}. <a href='/projects/show'>Fetch projects</a>"
end

get '/projects/show' do
  response = HTTParty.get("#{settings.oauth_host}/api/v1/projects?access_token=#{@@access_token}")
  @projects = JSON.parse(response.body)['data']
  markup = @projects.map { |p| '<li>' + p['name'] + '</li>' }.join('')
  return "Project names are <ul>#{markup}</ul>"
end
