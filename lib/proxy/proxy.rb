require 'proxy/rewrite'



$ignore=["image/jpeg", "image/png", "image/gif", "application/x-javascript", "text/css"]

class Logger
	def log req, res

		return if $ignore.include? res["content-type"]
	
		req.each { |key, value|
			puts "qkey : #{key}"
			puts "qvalue: #{value}"
			
		}	

		puts "query_string: #{req.query_string}"
		puts "addr: #{req.addr}"
		puts "peeraddr: #{req.peeraddr}"
		puts "attributes: #{req.attributes}"
		puts "host: #{req.host}"
		puts "path: #{req.path}"
		puts "path_info: #{req.path_info}"
		puts "request_line: #{req.request_line}"
		puts "request_method: #{req.request_method}"
		puts "request_uri: #{req.request_uri}"


		res.each { |key, value|
			puts "skey : #{key}"
			puts "svalue: #{value}"
		}
	end
end

log = Logger.new


# :ProxyContentHandler will be invoked before sending
# response to User-Agenge. You can inspect the pair of
# request and response messages (or can edit the response
# message if necessary).

pch = Proc.new{|req, res|
  #p [ req.request_line, res.status_line ]
  log.log req, res
  
}

rewrite = Proc.new {|req|
	req.request_uri.host="www.google.de"
}


def upstream_proxy
  if prx = ENV["http_proxy"]
    return URI.parse(prx)
  end
  return nil
end

httpd = WEBrick::RewritingProxy.new(
  :Port     => 10080,
  :ProxyContentHandler => pch,
  :ProxyURI => upstream_proxy,
  :RequestRewriteProc => rewrite 
)

Signal.trap(:INT){ httpd.shutdown }


10.times {
	puts
}

httpd.start

