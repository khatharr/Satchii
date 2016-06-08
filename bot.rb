# encoding: utf-8
require 'net/http'
require 'discordrb'
require 'similar_text'

def youtube(query)
  url = "https://www.youtube.com/results?search_query=#{query}"
  
  if Net::HTTP.get(URI(url)) =~ /<a href="(\/watch\?v=.*?)"/
    return "https://www.youtube.com#{$1}"
  end
  
  return nil
end

def wikipedia(query)
  url = "https://en.wikipedia.org/w/api.php?action=query&redirects&format=xml&titles=#{query}"

  data = Net::HTTP.get(URI(url))
  
  idx = -1
  title = ""
  if data =~ /_idx="(\d*?)"/
    idx = $1.to_i
  end
  if data =~ /title="(.*?)"/
    title = $1.gsub(' ', '_')
  end
  
  return "Not found." if idx == -1
  
  return "https://en.wikipedia.org/wiki/#{title}"
end

def loadApps
  puts "Loading DB."
  data = File.read('applist.txt', :encoding => 'UTF-8')
  lines = data.split("\n")

  $apps = {}
  id = 0
  for line in lines
    if line =~ /appid\"\:\s(.*?)\,/
      id = $1.to_i
    elsif line =~ /\"name\"\:\s\"(.*?)\"/
      $apps[id] = $1
      id = -1
    end
  end
end

def searchApps(query)
  score = 0
  winner = -1
  for k,v in $apps
    sc = v.downcase.similar(query.downcase)
    if sc > score
      score = sc
      winner = k
      break if score == 100
    end
  end
  
  if winner == -1
    return "Not found."
  end
  
  return "http://store.steampowered.com/app/#{winner}"
end

def searchMAL(query)
  url = "http://myanimelist.net/anime.php?q=#{query}"
  
  if Net::HTTP.get(URI(url)) =~ /id\=\"sarea(\d*?)\"/
    return "http://myanimelist.net/anime/#{$1}"
  end
  
  return "Not found."
end

def google(query)
  return "https://www.google.com/search?q=#{query}&ie=utf-8&oe=utf-8"
end

def refreshDB(event)
  puts "#{Time.now}: Attempting refresh..."
  event.respond("Attempting DB refresh.") if event.channel.name == "botdev"
  data = Net::HTTP.get(URI("http://api.steampowered.com/ISteamApps/GetAppList/v2"))
  if data.size == 0
    puts "Refresh failed!"
    event.respond("Refresh failed!") if event.channel.name == "botdev"
    return false
  end
  open("applist.txt", "wb") { |f| f.write(data) }
  puts "Success."
  event.respond("Success.") if event.channel.name == "botdev"
  event.respond("Reloading DB.") if event.channel.name == "botdev"
  loadApps
  return true
end

def loadCredentials
  puts "Loading credentials."
  lines = []
  open("credentials.dat", "rb") { |f| lines = f.readlines }
  for line in lines
    line.chomp!
  end
  $token = lines[0]
  $appid = lines[1].to_i
  $adminID = lines[2].to_i
end

def startup
  loadCredentials
  loadApps
  
  bot = Discordrb::Commands::CommandBot.new token: $token, application_id: $appid, prefix: '!'
  bot.set_user_permission($adminID, 10)
  
  puts "This bot's invite URL is: \n#{bot.invite_url}"
  puts "-" * 75
  return bot
end

##########################################

bot = startup

bot.command(:anime, { :description => "Searches MAL for your query. (Ex: !anime haruhi)" }) do |event, *args|
  event.respond(searchMAL(args.join('%20'))) if event.channel.name == "botdev"
  nil
end

bot.command(:wiki, { :description => "Searches Wikipedia for your query. (Ex: !wiki the internet)" }) do |event, *args|
  event.respond(wikipedia(args.join('_'))) if event.channel.name == "botdev"
  nil
end

bot.command(:google, { :description => "Provides a google search link. (Ex: !google cat videos)" }) do |event, *args|
  event.respond(google(args.join('%20'))) if event.channel.name == "botdev"
  nil
end

bot.command(:steam, { :description => "Searches Steam for a title. (Ex: !steam crosscode)" }) do |event, *args|
  refreshDB(event) if Time.now > (File.mtime("applist.txt") + (60 * 60 * 12))
  event.respond(searchApps(args.join(' '))) if event.channel.name == "botdev"
  nil
end

bot.command(:youtube, { :description => "Return top search result from Youtube. (ex: !youtube dramatic chipmunk)" }) do |event, *args|
  event.respond(youtube(args.join('%20'))) if event.channel.name == "botdev"
  nil
end

bot.command(:play, { :help_available => false,  :permission_level => 10 }) do |event, *args|
  bot.game = args.join(' ')
  nil
end

bot.command(:refresh, { :help_available => false,  :permission_level => 10 }) do |event|
  refreshDB(event)
  nil
end

bot.run :async
bot.game = "!help for commands"
bot.sync

