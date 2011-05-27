require 'requirements'
require 'config'
class ImapControl
	@@config=Hash.new
	@@projects_on_pivotal=Hash.new
	
	def initialize(imap_server='imap.gmail.com',username='slidesharebot@gmail.com',password='')
		@@config = {
		  :host     => "#{imap_server}",
		  :username => "#{username}",
		  :password => "#{password}",
		  :port     => 993,
		  :ssl      => true
		}
	end


	def net_http(uri)
		h = Net::HTTP.new(uri.host, uri.port)
		h
	end
	
 	
	def build_project_xml(project)
		project_xml="<project><name>#{project}</name><iteration_length type=\"integer\">2</iteration_length><point_scale>0,1,3,9,27</point_scale></project>"  
	end


	def build_story_xml(project_id,story_type,story_name,requested_by,description,owned_by)
		story_xml="<story><story_type>#{story_type}</story_type><name>#{story_name}</name><requested_by>#{requested_by}</requested_by><description>#{description}</description><owned_by>#{owned_by}</owned_by></story>"
	end

	
    
    def initialize_all_projects (user_email,token)
		base_url = "http://www.pivotaltracker.com:80/services/v3/projects/"
		resource_uri = URI.parse("#{base_url}")
		response = net_http(resource_uri).start do |http|
			http.get(resource_uri.path, {'X-TrackerToken' => "#{token}"})
		end
		data = XmlSimple.xml_in(response.body)
		data['project'].each do |p|
			@@projects_on_pivotal["#{p['name']}"]="#{p['id']}"
		end
	end

	def imapsync
		@imap = Net::IMAP.new( @@config[:host], @@config[:port], @@config[:ssl] )
		if @imap.login( @@config[:username], @@config[:password] )
		puts "Conneted"
		end
		@imap.select('INBOX')
		project=""
		attrs={}
		@imap.search(["NOT","SEEN"]).each do |message_id|
			@mailbox = @imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE'].to[0].mailbox
			@mailbox = @mailbox.gsub(/([_\-\.])+/, ' ').downcase
			@mailbox.gsub!(/\b([a-z])/) { $1.capitalize }
			@msg = @imap.fetch(message_id,'RFC822')[0].attr['RFC822']
			email =  TMail::Mail.parse(@msg)
			raise "Subject Empty" if email.subject.blank? 
			@email_subject=email.subject
			#pp @email_subject
			@split_subject=@email_subject.split(":")
			attrs[:project]=@split_subject[0].gsub(/ /,"")
			if @split_subject[1].empty? 
			attrs[:story_title]="feature" 
			else attrs[:story_type]=@split_subject[1].gsub(/ /,"")
			end
			attrs[:requested_by_email]= email.from
			attrs[:story_title]=@split_subject[2].gsub(/ /,"")
			if !email.cc 
				attrs[:cc]=attrs[:requested_by_email] 
			else
				attrs[:cc]=  email.cc 
			end
			email_body = (email.body.gsub(/[\r]+/," "))
			attrs[:body]=email_body.gsub(/[\n]+/," ")
			attrs[:body]=attrs[:body].unpack('M*').flatten.first
			attrs[:owned_by]=attrs[:cc][0]
			
			
			####START CREATING STORIES IN PROJECTS###
			puts $TOKEN["#{attrs[:requested_by_email]}"]["token"]
		  #  pp 
			initialize_all_projects(attrs[:requested_by_email],$TOKEN["#{attrs[:requested_by_email]}"]["token"]) 				
			 
			 @project_id= @@projects_on_pivotal["#{attrs[:project]}"]
			 @story_type="#{attrs[:story_type]}"
			 @story_name=attrs[:story_title]
			 @token=$TOKEN["#{attrs[:requested_by_email]}"]["token"]
			 @assigned_by=$TOKEN["#{attrs[:requested_by_email]}"]["username"]
			 @description="#{attrs[:body]}"
			 #@
			 #pp attrs
			 #@puts "ASSIGNED BY= #{@assigned_by}"
			 #@assigned_by="saket choudhary"
			 @owned_by=$TOKEN["#{attrs[:owned_by]}"]["username"]
			 #@assigned_by="#{}"
		#@owned_by= "saket choudhary"
		 puts "PROJECT= #{attrs[:project]}"
         puts "STORYTYPE= #{@story_type}"
         puts "PROJECTID= #{@project_id}"
         puts "token=#{@token}"
         puts "ASSIGNED BY #{@assigned_by}"
         puts "OWNED BY #{@owned_by}"    
         puts "DESC : #{@description}"
         @base_url = "http://www.pivotaltracker.com:80/services/v3/projects/#{@project_id}/stories"

		resource_uri = URI.parse("#{@base_url}")
		         story_xml=build_story_xml(@project_id,@story_type,@story_name,@assigned_by,@description,@owned_by)
 #pp story_xml
 #pp @token
 #pp @project_id
		response = net_http(resource_uri).start do |http|
			  http.post(resource_uri.path, story_xml, {'X-TrackerToken' => @token, 'Content-Type' => 'application/xml'})
			end
   pp response
			end
				@imap.logout


		end
end
control=ImapControl.new
control.imapsync
