# encoding: utf-8
require 'net/http'
require 'discordrb'
require 'similar_text'

def youtube(query)
  dardar = Net::HTTP.get(URI("https://www.youtube.com/results?search_query=#{query}"))
  
  if dardar =~ /<a href="(\/watch\?v=.*?)"/
    "https://www.youtube.com#{$1}"
  else
    nil
  end
end

def wikipedia(query)
  puts "-" * 70
  
  uri = URI("https://en.wikipedia.org/w/api.php?action=query&redirects&format=xml&titles=#{query}")
  doota = Net::HTTP.get(uri)
  
  idx = -1
  title = ""
  if doota =~ /_idx="(\d*?)"/
    idx = $1.to_i
  end
  if doota =~ /title="(.*?)"/
    title = $1.gsub(' ', '_')
  end
  
  return "Not found." if idx == -1
  
  return "https://en.wikipedia.org/wiki/" + title
end

def loadApps
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

def refreshDB
  puts "#{Time.now}: Attempting refresh..."
  data = Net::HTTP.get(URI("http://api.steampowered.com/ISteamApps/GetAppList/v2"))
  if data.size == 0
    puts "Refresh failed!"
    return false
  end
  open("applist.txt", "wb") { |f| f.write(data) }
  puts "Success."
  loadApps
  return true
end

def loadCredentials
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
end

##########################################

startup

bot = Discordrb::Commands::CommandBot.new token: $token, application_id: $appid, prefix: '!'
puts "This bot's invite URL is: \n#{bot.invite_url}"
puts "-" * 75

bot.command(:anime, { :description => "Searches MAL for your query. (Ex: !anime haruhi)" }) do |event, *args|
  if event.channel.name == "botdev"
    derta = Net::HTTP.get(URI("http://myanimelist.net/anime.php?q=#{args.join('%20')}"))
    if derta =~ /id\=\"sarea(\d*?)\"/
      aid = $1
      event.respond("http://myanimelist.net/anime/" + aid)
    else
      event.respond("Not found.")
    end
  else
    nil
  end
end

bot.command(:wiki, { :description => "Searches Wikipedia for your query. [improvements pending] (Ex: !wiki the internet)" }) do |event, *args|
  if event.channel.name == "botdev"
    event.respond(wikipedia(args.join('_')))
  else
    nil
  end
end

bot.command(:google, { :description => "Provides a google search link. (Ex: !google cat videos)" }) do |event, *args|
  if event.channel.name == "botdev"
    event.respond("https://www.google.com/search?q=" + args.join('%20'))
  else
    nil
  end
end

bot.command(:steam, { :description => "Searches Steam for a title. (Ex: !steam crosscode)" }) do |event, *args|
  if Time.now > (File.mtime("applist.txt") + (60 * 60 * 12))
    event.respond("Attempting DB refresh.") if event.channel.name == "botdev"
    if refreshDB
      event.respond("OK.") if event.channel.name == "botdev"
    else
      event.respond("Failed.") if event.channel.name == "botdev"
    end
  end
  if event.channel.name == "botdev"
    searchApps(args.join(' '))
  else
    nil
  end
end

bot.command(:play, { :help_available => false }) do |event, *args|
  if event.author.id == $adminID
    bot.game = args.join(' ')
    event.respond("OK.") if event.channel.name == "botdev"
  else
    event.respond("You are not authorized.") if event.channel.name == "botdev"
  end
  nil
end

bot.command(:refresh, { :help_available => false }) do |event|
  if event.author.id == $adminID
    event.respond("Attempting DB refresh.") if event.channel.name == "botdev"
    if refreshDB
      event.respond("OK.") if event.channel.name == "botdev"
    else
      event.respond("Failed.") if event.channel.name == "botdev"
    end
  else
    event.respond("You are not authorized.") if event.channel.name == "botdev"
  end
  nil
end

bot.command(:youtube, { :description => "Return top search result from Youtube. (ex: !youtube dramatic chipmunk)" }) do |event, *args|
  if event.channel.name == "botdev"
    youtube(args.join('%20'))
  else
    nil
  end
end

bot.run :async
bot.game = "!help for commands"
bot.sync

