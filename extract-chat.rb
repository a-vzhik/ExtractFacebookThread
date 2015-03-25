require 'nokogiri'
require 'date'
require 'io/console'

class MessageThreads
	attr_reader :html
	def initialize(path)
		file = File.open(path, "r");
		@html = Nokogiri::HTML(file);
	end
	
	def find_thread_with(username)
		if block_given? then
			html.xpath("//div[@class='thread']").each do |node|
				thread = MessageThread.new(node)
				if thread.header.include? username then
					yield thread
				end
			end
		end
	end
end

class MessageThread
	def initialize(thread)
		@thread = thread
	end
	
	def header
		@thread.children[0].to_s
	end
	
	def messages
		Messages.new(@thread)
	end
end

class Messages 
	def initialize(thread)
		@thread = thread
	end
	
	def each 
		return if !block_given?
		@thread.xpath("div[@class='message']").reverse.each do |message|
			yield Message.new(message)
		end
	end
end

class Message
	attr_reader :metadata, :original_content
	def initialize(message)
		@metadata = message
		@original_content = message.next_sibling
	end
	
	def htmlized_content
		node = Nokogiri::XML::Node.new(@original_content.name, @original_content.document)
		node.inner_html = @original_content.inner_html.gsub(/\n/, '<br/>')
		node
	end
	
	def write_to(io)
		metadata.write_to io
		htmlized_content.write_to io
	end
end

class OutputMessageThreadFile
	def initialize(thread_header)
		@thread_header = thread_header
	end

	def build_html_skeleton
		builder = Nokogiri::HTML::Builder.new do |doc|
			doc.html {
				doc.head { 
					doc.title "Messages between #{@thread_header}"
					doc.link({'href'=>'../html/style.css', 'rel'=>'stylesheet', 'type'=>'text/css'}) {
					}
					doc.meta({'content'=>'text/html; charset=UTF-8', 'http-equiv'=>'Content-Type'}){
					}
				}
				doc.body {
					doc.div('class'=>'thread'){
					}
				}
			}
		end	
		
		builder.doc.encoding = 'UTF-8'
		builder.doc
	end
	
	def write
		output_html_doc = build_html_skeleton
		html = output_html_doc.to_html
		index = html.index "</div>";
		
		File.open(name, 'w') do |output_file|
			output_file.write html.slice(0, index)
			yield output_file
			output_file.write html.slice(index..html.length)
		end		
	end
	
	def name
		"messages-#{@thread_header}.html"
	end
end

class Application
	def self.run
	
		if ARGV[0] != nil then
			chatmate = ARGV[0]
		else 
			puts "Enter a name of a friend: "
			chatmate = gets
			chatmate.chomp!
		end
		
		begin
			threads = MessageThreads.new("messages.htm")
			threads.find_thread_with(chatmate) do |thread|
				puts "\nA thread between #{thread.header} found\n"

				output = OutputMessageThreadFile.new(thread.header)
				output.write do |file| 
					file.write thread.header
					
					processed_count = 0
					thread.messages.each do |msg|
						msg.write_to file
						
						processed_count = processed_count + 1
						puts "#{processed_count} messages exported" if processed_count % 500 == 0 
					end
					puts "#{processed_count} messages exported"
				end
				
				puts "\nThe thread between #{thread.header} exported successfully to the file \"#{output.name}\""
			end 
		rescue Exception => e  
			puts "Error happened: #{e}"
		end
		puts "\nPress any key"
		STDIN.getch
	end
end

Application.run