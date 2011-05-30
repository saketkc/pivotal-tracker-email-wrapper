require 'requirements'

imap_server='imap.gmail.com'
username=''
password=''
#def initialize(imap_server='imap.gmail.com',username,password)
CONFIG = {
  :host     => "#{imap_server}",
  :username => "#{username}",
  :password => "#{password}",
  :port     => 993,
  :ssl      => true
}

@imap = Net::IMAP.new( CONFIG[:host], CONFIG[:port], CONFIG[:ssl] )
@imap.login( CONFIG[:username], CONFIG[:password] )
@imap.select('INBOX')
project=""
@imap.search(["NOT","SEEN"]).each do |message_id|
@mailbox = @imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE'].to[0].mailbox
@mailbox = @mailbox.gsub(/([_\-\.])+/, ' ').downcase
@mailbox.gsub!(/\b([a-z])/) { $1.capitalize }
@msg = @imap.fetch(message_id,'RFC822')[0].attr['RFC822']
attrs, email = {}, TMail::Mail.parse(@msg)
attrs[:subject]   = email.subject.blank? ? '' : email.subject.capitalize
attrs[:assignedby]= email.from
attr  = (email.body.gsub!(/[\r]+/," "))
attrs[:body]=attr.gsub!(/[\n]+/," ")
attrs[:cc]= email.cc
attrs[:project]=  email.body.scan(/Project# (.*)/).flatten.first.gsub!(/[\r]+/,"")
project=attrs[:project]
attrs[:typeof]= email.body.scan(/Type# (.*)/).flatten.first.gsub!(/[\r]+/,"")

pp attrs
#while


end
@imap.logout
def net_http(uri)
    h = Net::HTTP.new(uri.host, uri.port)
    
  end
def build_project_xml(project)
project_xml="<project><name>#{project}</name><iteration_length type=\"integer\">2</iteration_length><point_scale>0,1,3,9,27</point_scale></project>"  
end
def dontuse
@token="6af079ef1ef5c730ea888cfcba60ae7a"
          
@project_name="#{project}"
@base_url = "http://www.pivotaltracker.com:80/services/v3/projects"

resource_uri = URI.parse("#{@base_url}")
project_xml = build_project_xml(@project_name)
response = net_http(resource_uri).start do |http|
      http.post(resource_uri.path, project_xml, {'X-TrackerToken' => @token, 'Content-Type' => 'application/xml'})
    end

    #pp response.body
response=Hpricot.XML(response.body)
#retrieve_project_id=(response/"").innerHTML
#pp response
#pp retrieve_project_id
data = XmlSimple.xml_in(response.body)
pp data
end

