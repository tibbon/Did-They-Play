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