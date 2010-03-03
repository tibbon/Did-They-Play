require "rubygems"
require "sequel"
require "sqlite3"
require 'simple-rss'
require 'open-uri'
require 'pp'
require 'tlsmail'
require 'time'
require 'mysql'

settings = YAML::load_file('configuration.yaml')
database_username = settings["mysql_settings"]["username"]
database_password = settings["mysql_settings"]["password"]
database_location = settings["mysql_settings"]["server"]
database_name = settings["mysql_settings"]["database"]

EmailUsername = settings["email_settings"]["username"]
EmailPassword = settings["email_settings"]["password"]

DB = Sequel.mysql(database_name, 
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
  #index   [:username, :server], :unique => true
end

$player_dataset = DB[:player]

def update_database
  $player_dataset.each do |player|
    user = player[:username]
    server_cgi = CGI.escape(player[:server])
    email = player[:email_address]
    rss = SimpleRSS.parse open("http://www.wowarmory.com/character-feed.atom?r=#{server_cgi}&cn=#{user}")
    
    activity = rss.feed.items.first.title
    activity_time = rss.feed.items.first.updated
    if update_is_new(player[:id], activity, activity_time)
      update_user(player[:id], activity, activity_time)
      sendmail(player[:username], player[:server], activity, activity_time, email)
    end
  end
end

def update_user(player_id, activity, activity_time)
  $player_dataset.filter(:id => player_id).update(:last_activity => activity, :last_played => activity_time)
end

def update_is_new(player_id, activity, time)
  last_activity = $player_dataset.filter(:id => player_id).first[:last_activity]
  last_time = $player_dataset.filter(:id => player_id).first[:last_played].to_s
  
  time = time.to_s

  if ((last_activity == activity) && (last_time == time))
    return false
  else
    return true
  end
end

def sendmail(username, server, activity, time, email)
  username = username.capitalize
  
message = <<MESSAGE_END
From: #{EmailUsername}
To: #{email}
Subject: #{username} played World of Warcraft.
Date: #{Time.now.rfc2822}
Seems #{username} played World of Warcraft recently on the #{server} server. 
According to server logs #{username} #{activity} around #{time}.

If you wish to no longer recieve these emails, please just email me back and I'll remove you from the database. I haven't built a system yet for easy auto-removal. 
MESSAGE_END

 
  Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
  Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com',EmailUsername ,EmailPassword, :login) do |smtp|
    smtp.send_message(message, EmailUsername, email)
    p "Emailed about #{username}"
  end
  sleep(5)
end


def notify_new()
  sendmail(username, server, activity, Time.now())
  p "This is a new update. Email someone about it!"
end

update_database




