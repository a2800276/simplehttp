require 'hpricot'

require 'zlib'
require 'uri'
require 'stringio'
require 'digest/sha1'

require 'proxy/rewrite'



def handle_url url
	return nil unless url =~ /^https:\/\//
	uri = URI.parse url
	host = uri.host

	hash = "ssl-proxy."+host
	uri.host=hash
	uri.scheme="http"
	uri.to_s

end

pch = Proc.new { |req, res|


	if res['content-type']=~/^text\/html/
		
		case res['content-encoding']
		when "gzip"
			io = StringIO.new res.body
			zlib = Zlib::GzipReader.new io
			body = zlib.readlines.join
			
		else
			body = res.body
		end
		

		html = Hpricot(body)
		# replace and cache https links
	
		(html/"a").each {|a|
			if hash = handle_url(a.attributes["href"])
				a.attributes["href"]=hash
			end
		}

		(html/"form").each { |form|
			if hash = handle_url(form.attributes["action"])	
				form.attributes["action"]=hash
			end
		}

		res.body=html.to_s
		res['content-length']=res.body.size
		res['content-encoding']=nil
	else
		puts res['content-type']
	end

	if res.status.to_i == 302
		if location = handle_url(res['location'])
			res['location']=[location]
		end

		
	end
	
	puts "------------------------------------------------------------------------"
	puts "-----------------#{req.request_uri}-------------------------------------"
	req.each {|key,value|
		puts "-> #{key} : #{value}"
	}
	res.each {|key,value|
		puts "<- #{key} : #{value}"
	}

	puts "- #{res['set-cookie']} -"
	puts "== #{res.cookies.class} =="
	res.cookies.each { |cookie| 
		cookie.gsub! /; secure/, ''
	}
	puts "------------------------------------------------------------------------"
}

rewrite = Proc.new {|req|
	
	if req.request_uri.host =~ /^ssl-proxy.(.*)/
		orig = $1
		puts "----> rewriting: #{req['host']} -> #{orig} <-"
		
		req.request_uri.host = orig
		req.request_uri.scheme = "https"
	        req.header['host']=[orig]
			
		ref_header = req.header['referer']
		ref_header_str = ref_header[0]
		ref_header_str.gsub!(/ssl-proxy./, '') if ref_header_str 

		#req['host'] = orig.host
		puts req.request_uri.to_s
		#req.each {|key, value|
		#	puts "-> #{key} : #{value}"
		#}


	end
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

