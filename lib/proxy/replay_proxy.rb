

require 'proxy/rewrite'


module WEBrick


	class ContentHandler
		IMG_CONTENT 	= ["image/jpeg", "image/png", "image/gif"]
		CSS_CONTENT 	= ["text/css"]
		JS_CONTENT	= ["application/x-javascript"]

		def initialize io, config
			@io=io
			@ignore_content_type= config[:ignore_content_type] || []
			@ignore_content_type += IMG_CONTENT if config[:ignore_img]
			@ignore_content_type += CSS_CONTENT if config[:ignore_css]
			@ignore_content_type += JS_CONTENT if config[:ignore_js]
			
			@ignore_header = config[:ignore_header] || []
			
			@cookies = {}


		end
		
		def write line
			@io.puts line 
		end

		def comment line
			@io.puts "# #{line}"
		end

		def cookie_index val
			@cookie_count ||= 0

			@cookies[val] = @cookie_count
			@cookie_count += 1
			@cookie_count-1

		end
		
		def clear_cookies
			@cookies_req = []
			@cookie_warn = []
		end
		def handle_cookie c_val
			index = @cookies[c_val] 
			unless index
				@cookie_warn << "unknown cookie: '#{c_val}', you may need to clear your browser cookies"
				@cookie_warn << "before recording, page is setting cookies with Javascript, maybe an"
				@cookie_warn << "image or similar content-type you're ignoring is setting the cookie or" 
				@cookie_warn << "you'll need to handle this manually!"
				var_name = "'#{c_val}'"
			else
				@cookie_warn << "__cookies[#{index}] = '#{c_val}'"
				var_name = "__cookies[#{index}]"
			end
			@cookies_req << '#{' + var_name + '}'
		end

		def handle_cookies cookies
			cookies.each {|c|
				c.split(';').each {|cookie|
					handle_cookie cookie.strip
				}
			}

		end

		def finish_cookies
			return unless @cookies_req.size > 0
			@cookie_warn.each {|warning|
				comment warning
			}

			
			write "__http.request_headers['cookie']=\"#{@cookies_req.join(';')}\""
		end

		def get_content_handler
			return lambda {|req, res|
				if @ignore_content_type.include? res['content-type']
					comment "Ignoring #{req.unparsed_uri} because of content-type #{res['content-type']}"

				elsif res.status == 404
					comment "Request to:#{req.unparsed_uri} returned: #{res.status} skipping"

				else
					comment "#{res.status}"
					write "__http = SimpleHttp.new '#{req.request_uri}'"
					clear_cookies
					req.header.each {|key, value|
						next if @ignore_header.include? key
						if key == 'cookie'
							handle_cookies value
						else
							write "__http.request_headers['#{key}']='#{value}'"
						end
					}
					finish_cookies
					method = req.request_method.downcase
					case method
					when 'post':
						write "__res = __http.post '#{req.body}', '#{req['content-type']}'"
					when 'get'
						write "__res = __http.get"
					end
					
					if res.cookies && res.cookies.size > 0
						# determine indes of each cookie in the __cookie array
						res.cookies.each {|cookie|
							c_val = cookie.split(';')[0]
							#write "#{cookie_var c_val} = '#{c_val}'"
							idx = cookie_index c_val
							comment "__cookies[#{idx}] = '#{c_val}'"
						}
						# push each response cookie into the array.
						write "__http.response_headers['set-cookie'].split(',').each {|__cookie| __cookies.push __cookie.split(';')[0]}"
					end

					write "\n\n"

				end
				

			}
		end
	end

	class ReplayProxy < RewritingProxy
		
		# 
		#	:outfile
		#	:ignore_content_types > array of request for content types to ignore
		#	:ignore_css > don't replay requests for css
		#	:ignore_img > don't replay requests for images
		#	:ignore_js > don't replay requests for javascript
		#	:ignore_header > array containing headers not to copy
		#

		def initialize config
			@outfile = config[:outfile] ? config[:outfile] : STDOUT
			init	
			pch = ContentHandler.new(@outfile, config).get_content_handler
			config[:ProxyContentHandler]=pch
			super
			logger.debug "initialized: #{self.class}"
		end

		def init
			@logger.fatal "no outfile!" unless @outfile
			@outfile = File.new(@outfile, "w") unless @outfile.instance_of? IO
			puts @logger
			puts @outfile	
			@outfile.puts "require 'simple_http' \n\n"
			@outfile.puts "__cookies = [] \n\n"
		end

		def finish
			@outfile.close
		end

		def start
			Signal.trap(:INT){
				self.finish
				self.shutdown
			}
			super
		end


	
	end # ReplayProxy
end # WEBrick

if $0 == __FILE__
	config = {
		:outfile => 'tmp.delete', 
		:ignore_img => true,
		:ignore_header => 'user-agent'
	}
	proxy = WEBrick::ReplayProxy.new config 
	proxy.start
end
