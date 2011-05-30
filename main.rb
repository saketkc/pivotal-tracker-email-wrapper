require 'requirements' # All the 'require' statements go here
require 'config'           # this is the file where we store the $TOKEN Global Variables
############################################
# CLASS :ImapControl
# NOTES: contains 7 public functions

#List of Functions
#1. intialiize=> Intialize the @params[imapserver],@paramspusername,@params[password]
#2. net_http=> Make HTTP connections #@params[uri]
#3. build_story_xml=> return the XML for adding new story, #@params[project_id],@params[story_type],@params[story_name],@params[requested_by],@params[description],@params[owned_by]
#4. build_project_xml=> Return the XMl for Adding new Project , @params[projectname]**** NOT neing used currentyl
#5. initialize_all_projects=>Fetch project ids for @params[requester_token]
#6. imapsync => Syncing with the imap account 

 	
class ImapControl
	
	#@params[imap server]= Address of the map server where the bot resides
	#@params[username]= The username of the bot
	#@params[password]= Password of the bot
	def initialize(imap_server='imap.gmail.com',username='slidesharebot@gmail.com',password='')
		@config = {
		  :host     => "#{imap_server}",
		  :username => "#{username}",
		  :password => "#{password}",
		  :port     => 993,
		  :ssl      => true
		}
	end

   #@params[uri]= Parsed URL
   #function returns a new HTTP/HTTPS connection to the specified url parameter
	def net_http(uri)
		h = Net::HTTP.new(uri.host, uri.port)
		h
	end
	
 	#@params[projectname]= Project Name to create new Project
 	#funtion returns the xml as per Pivotal Tracker "Add New Project" API documentaion
	def build_project_xml(project_name)
		project_xml="<project><name>#{project_name}</name><iteration_length type=\"integer\">2</iteration_length><point_scale>0,1,3,9,27</point_scale></project>"  
	end

	
	#@params[project_id]=Project Id to add story to
	#@params[story_type]=Story type :feature/bugs/chore
	#@params[story_name]=Story Name/Title
	#@params[requested_by]=Story Requested by (Takes Username as in Pivotal , Email doesnt work)
	#@params[description]=Description of the Story
	#@params[owned_by]=Story owned by
 	#function returns the xml as per Pivotal Tracker "Add New Story" API documentaion
	
	def build_story_xml(project_id,story_type,story_name,requested_by,description,owned_by)
		story_xml="<story><story_type>#{story_type}</story_type><name>#{story_name}</name><requested_by>#{requested_by}</requested_by><description>#{description}</description><owned_by>#{owned_by}</owned_by></story>"
	end
    
	
    #@params[requester_token]=Token of the user who has requested a Story
    #Function fetched all the project Ids.. 
    def initialize_all_projects (requester_token)
		base_url = "http://www.pivotaltracker.com:80/services/v3/projects/" #Base URL for fetching the Project IDs
		resource_uri = URI.parse("#{base_url}") #URI Parse the base url
		response = net_http(resource_uri).start do |http|
			http.get(resource_uri.path, {'X-TrackerToken' => "#{token}"}) #Send a get response to fetch all the Project Ids as an XML response
		end
		data = XmlSimple.xml_in(response.body) #The response needs to be parsed
		data['project'].each do |p| #Search for all "project" nodes in the document
			@projects_on_pivotal["#{p['name']}"]="#{p['id']}" # Intialise the project ids corresponding to the project names
		end
	end

	#Function accesses the sccount over IMAP and Checks for new messages
	#New Messages once read get marked as READ and so won't be read the next time
	def imapsync
		@imap = Net::IMAP.new( @config[:host], @config[:port], @config[:ssl] )
		if @imap.login( @config[:username], @config[:password] )
			puts "Connected"
		else
			raise("Connection Failed")
		end

		
		@imap.select('INBOX') #Select INBOX from the gmail account to look for new messages
		project=""
		attrs={}
		@imap.search(["NOT","SEEN"]).each do |message_id| # Look for UNREAD MESSAGES
			@mailbox = @imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE'].to[0].mailbox #Fetch the unread email
			@mailbox = @mailbox.gsub(/([_\-\.])+/, ' ').downcase
			@mailbox.gsub!(/\b([a-z])/) { $1.capitalize }
			@msg = @imap.fetch(message_id,'RFC822')[0].attr['RFC822']
			email =  TMail::Mail.parse(@msg) #Use TMail Library to parse the email message
			raise "Subject Empty" if email.subject.blank?  #Raise Error in case "Subject" is empty
			@email_subject=email.subject       #Subject of the Email          
            @email_subject=@email.subject.gsub("[","") #The Format of the Sunject should be [ProjectName][Story Type][Story Title]
			@split_subject=@email_subject.split("]") 
			attrs[:project]=@split_subject[0].gsub(/ /,"") #Project Name
			if @split_subject[1].empty? 
			attrs[:story_title]="feature"  # intialise the Story Type as "feature" in case this column is empty
			else attrs[:story_type]=@split_subject[1].gsub(/ /,"") #Else intialize the story Type
			end
			attrs[:requested_by_email]= email.from #Requested By
			attrs[:story_title]=@split_subject[2].gsub(/ /,"") #Story Titile
			if !email.cc 
				attrs[:cc]=attrs[:requested_by_email]  #Incase theres is no person CCed the project should get assigned to the requester of the story himself
			else
				attrs[:cc]=  email.cc 
			end
			email_body = (email.body.gsub(/[\r]+/," "))
			attrs[:body]=email_body.gsub(/[\n]+/," ")
			attrs[:body]=attrs[:body].unpack('M*').flatten.first #To support Multipart Data.
			attrs[:owned_by]=attrs[:cc][0] #Owner of the Story is the person who was CCed
			
			
			####START CREATING STORIES IN PROJECTS###
			initialize_all_projects($TOKEN["#{attrs[:requested_by_email]}"]["token"]) 		#Fetch the Project Ids vs Project Names from Pivotal
			@project_id= @projects_on_pivotal["#{attrs[:project]}"] #Get the Corresponding Project Id as per the name in the Email Subhect
			 @story_type="#{attrs[:story_type]}".downcase #The Story Type(feature/bug/chores)
			 @story_name=attrs[:story_title] #Story Name/Title
			 @token=$TOKEN["#{attrs[:requested_by_email]}"]["token"] /#The token of the Requester
			 @assigned_by=$TOKEN["#{attrs[:requested_by_email]}"]["username"] #Pivotal Username of the Requester
			 @description="#{attrs[:body]}" #Description of the story
			 @owned_by=$TOKEN["#{attrs[:owned_by]}"]["username"] #Pivotal Username of the Owner
			 @base_url = "http://www.pivotaltracker.com:80/services/v3/projects/#{@project_id}/stories"
			 resource_uri = URI.parse("#{@base_url}")
			 story_xml=build_story_xml(@project_id,@story_type,@story_name,@assigned_by,@description,@owned_by)#Get the XML to Add New Story
			 response = net_http(resource_uri).start do |http|
				http.post(resource_uri.path, story_xml, {'X-TrackerToken' => @token, 'Content-Type' => 'application/xml'}) #POST the parameters to Add New STory
			end
   
		end
			@imap.logout #Logout
	end
end
control=ImapControl.new
control.imapsync
