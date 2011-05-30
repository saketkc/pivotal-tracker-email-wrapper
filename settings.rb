# settings.rb
# Run this file once to configure Pivotal Tracker Tokens
# Parameters required : Username,Useremail and Password
require 'net/https'
require 'net/http'
require 'uri'
require 'hpricot'
#@params[uri]= Parsed URL
#function returns a new HTTP/HTTPS connection to the specified url parameter
def net_http(uri)
    h = Net::HTTP.new(uri.host, uri.port)
    h.use_ssl = true
    h
end

print "Enter path(absolute) where config.rb resides(Press Enter for Defualt): "
file_path=gets.chomp #Get file path of Config.rb

print "Enter Pivotal Email : "
pivotal_email=gets.chomp #Get Pivotal Email
print "Enter Pivotal Username(case sensitive) : "
username=gets.chomp #Get Pivotal username
print "Enter password : "
password = gets.chomp #Get Password
if file_path.empty?
file_path=Dir.pwd() +"/" +"config.rb"
else
file_path=file_path.chomp("/")+"/"+"config.rb"
end
@base_url="https://www.pivotaltracker.com/services/v3/tokens/active"
resource_uri = URI.parse("#{@base_url}")
data="username=#{pivotal_email}&password=#{password}" #to be used to obtain Token
response = net_http(resource_uri).start do |http|
      http.use_ssl = true
      http.post(resource_uri.path,data)
  end
rsp=Hpricot.XML(response.body)
if (rsp/"guid").innerHTML.empty? #Search for the token
raise "Password and username dont match"
else
token=(rsp/"guid").innerHTML
if File.open("#{file_path}", 'a+') do |file|  
  file.puts "$TOKEN[\"#{pivotal_email}\"]={\"username\"=>\"#{username}\",\"token\" => \"#{token}\"}    " # Add token to the config.rb file
  puts "Succesfully Generated Token"
  file.close
end  

end
end
