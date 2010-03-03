require 'rubygems'
require 'sinatra'
require 'erb'
require 'sequel'
require 'simple-rss'
require 'open-uri'
require 'mysql'
settings = YAML::load_file('configuration.yaml')
database_username = settings["mysql_settings"]["username"]
database_password = settings["mysql_settings"]["password"]
database_location = settings["mysql_settings"]["server"]
database_name = settings["mysql_settings"]["database"]
# MODEL

#We need mySQL because sqlite3 doesn't support multiple opens of a db, which is lame.
#I'd use Postgres, because it rocks more, but my server already has mySQL installed and is low on memory.
DB = Sequel.mysql(  database_name, 
                    :user => database_username, 
                    :password => database_password, 
                    :host => database_location)

DB.create_table? :player do
  primary_key :id
  String  :username
  String  :server
  String  :last_activity
  Time    :last_played
  String  :email_address
end

$player_dataset = DB[:player]

#Enables Cookie sessions
enable :sessions

# CONTROLLERS

get '/' do
  @title = "home"
  @select_class = "class='active'"
  render :erb, :index
end

get '/faq' do
  @title = "faq"
  @select_class = "class='active'"
  render :erb, :faq
end

get '/contact' do
  @title = "contact"
  @select_class = "class='active'"
  render :erb, :contact
end

get '/no_user' do
  @title = "error"
  @player_name = session["player_name"].capitalize
  #@select_class = "class='active'"
  render :erb, :no_user
end

post '/new_player' do
  @player_name = params['post']['playername']
  session["player_name"] = @player_name
  @server = params['post']['server']
  session["server"] = @server
  @server_cgi = CGI.escape(session["server"])
  @email = params['post']['email']
  @fail_string = "There are no entries that match the filter parameters."
  
  if (@email.empty? or @player_name.empty? or @server.empty?)
    redirect '/no_user'
  end
  
  
  @rss = SimpleRSS.parse open("http://www.wowarmory.com/character-feed.atom?r=#{@server_cgi}&cn=#{@player_name}")
  if @rss.feed.items.first.title == @fail_string
    redirect '/no_user'
  else
    $player_dataset.insert(:username => @player_name, :server => @server, :email_address => @email)
    redirect '/confirm_player'
end
  
end

get '/confirm_player' do
  @player_name = session["player_name"].capitalize
  @server_cgi = CGI.escape(session["server"])
  @server = session["server"]
  @rss = SimpleRSS.parse open("http://www.wowarmory.com/character-feed.atom?r=#{@server_cgi}&cn=#{@player_name}")
  @activity = @rss.feed.items.first.title
  @activity_time = @rss.feed.items.first.updated 
  
  erb :confirm
end