require "webrick"
require "webrick/httpproxy"



module WEBrick
	
	# Subclass of HTTPProxyServer that allows access to
	# the HTTPRequest prior to it actually being sent.
	# This is accomplished by providing an additional 
	# configuration symbol +:RequestRewriteProc+ which
	# take a block that is passed the request before it is sent.
	class RewritingProxy < HTTPProxyServer

		# :RequestRewriteProc
		def initialize (config)
			super
		end

		def service(req, res)
			#p req
			if handler = @config[:RequestRewriteProc]
				handler.call(req)
      			end
			
			super
	
		end
	end # RewritingProxy

	# Modifcation of HTTPRequest that allows the request_uri
	# of the request to be replace, typically though, it is better
	# to just modify the existing uri.
	class HTTPRequest
		def request_uri= uri
			@request_uri=uri
			# from httprequest
			@path = HTTPUtils::unescape(@request_uri.path)
			@path = HTTPUtils::normalize_path(@path)
			@host = @request_uri.host
			@port = @request_uri.port
			@query_string = @request_uri.query
			@script_name = ""
			@path_info = @path.dup
			# end
			#
			@header['host']=[@host]
			puts "!!!!!!!! #{@request_uri}"
		end

	end
end # WEBrick

