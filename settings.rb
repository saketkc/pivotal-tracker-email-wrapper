# settings.rb
# Run this file once to configure Pivotal Tracker Tokens
# Parameters required : Username and Password
#require 'config'
#require 'requirements'
require 'net/https'
require 'net/http'
require 'uri'
require 'pp'
require 'hpricot'
def net_http(uri)
    h = Net::HTTP.new(uri.host, uri.port)
    h.use_ssl = true
    h
    
  end
print "Enter path(absolute) where config.rb resides: "
file_path=gets.chomp
print "Enter Pivotal Email : "
pivotal_email=gets.chomp
print "Enter Pivotal Username(case sensitive) : "
username=gets.chomp
print "Enter password : "
password = gets.chomp
file_path=file_path.chomp("/")+"/"+"config.rb"
@base_url="https://www.pivotaltracker.com/services/v3/tokens/active"
resource_uri = URI.parse("#{@base_url}")
data="username=#{pivotal_email}&password=#{password}"
response = net_http(resource_uri).start do |http|
      http.use_ssl = true
      http.post(resource_uri.path,data)#{"username" => "#{username}" , "password" => "#{password}"},"")
    end
   rsp=Hpricot.XML(response.body)
   if (rsp/"guid").innerHTML.empty?
   raise "Password and username dont match"
   else
   token=(rsp/"guid").innerHTML
if File.open("#{file_path}", 'a+') do |file|  
  
  
  file.puts "$TOKEN[\"#{pivotal_email}\"]={\"username\"=>\"#{username}\",\"token\" => \"#{token}\"}    "
  #file.puts "$TOKEN[\"#{pivotal_email}\"][\"token\"]=\"#{token}\""
  puts "Succesfully Generated Token"
  file.close
end  

end
end
