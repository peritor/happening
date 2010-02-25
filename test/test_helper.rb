require 'rubygems'

require 'test/unit'
require 'shoulda'
require 'mocha'

$:.unshift(File.dirname(__FILE__) + "/../")

require 'happening'

require 'em-http/mock'

EventMachine.instance_eval do
  # Switching out EM's defer since it makes tests just a tad more unreliable
  alias :defer_original :defer
  def defer
    yield
  end
end unless EM.respond_to?(:defer_original)

class Test::Unit::TestCase
  def setup
    EventMachine::MockHttpRequest.reset_counts!
    EventMachine::MockHttpRequest.reset_registry!
  end
  
  def run_in_em_loop
    EM.run {
      yield
    }
  end
end

module Happening
  module S3
    class Item
      def http_class
        EventMachine::MockHttpRequest
      end
    end
  end
end

def fake_response(data)
  <<-HEREDOC
HTTP/1.0 200 OK
Date: Mon, 16 Nov 2009 20:39:15 GMT
Expires: -1
Cache-Control: private, max-age=0
Content-Type: text/html; charset=ISO-8859-1
Set-Cookie: PREF=ID=9454187d21c4a6a6:TM=1258403955:LM=1258403955:S=2-mf1n5oV5yAeT9-; expires=Wed, 16-Nov-2011 20:39:15 GMT; path=/; domain=.google.ca
Set-Cookie: NID=28=lvxxVdiBQkCetu_WFaUxLyB7qPlHXS5OdAGYTqge_laVlCKVN8VYYeVBh4bNZiK_Oan2gm8oP9GA-FrZfMPC3ZMHeNq37MG2JH8AIW9LYucU8brOeuggMEbLNNXuiWg4; expires=Tue, 18-May-2010 20:39:15 GMT; path=/; domain=.google.ca; HttpOnly
Server: gws
X-XSS-Protection: 0
X-Cache: MISS from .
Via: 1.0 .:80 (squid)
Connection: close

#{data}
HEREDOC
end

# amazon tells us to upload to another location, e.g. happening-benchmark.s3-external-3.amazonaws.com instead of happening-benchmark.s3.amazonaws.com
def redirect_response(location)
    <<-HEREDOC
HTTP/1.0 301 Moved Permanently
Date: Mon, 16 Nov 2009 20:39:15 GMT
Expires: -1
Cache-Control: private, max-age=0
Content-Type: text/html; charset=ISO-8859-1
Via: 1.0 .:80 (squid)
Connection: close
Location: #{location}

<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Error><Code>TemporaryRedirect</Code><Message>Please re-send this request to the specified temporary endpoint. Continue to use the original request endpoint for future requests.</Message><RequestId>137D5486D66095AE</RequestId><Bucket>happening-benchmark</Bucket><HostId>Nyk+Zq9GbtxcspdbKDWyGhsZhyUZquZP55tteYef4QVodsn73HUUad0xrIeD09lF</HostId><Endpoint>#{location}</Endpoint></Error>
  HEREDOC
end

def error_response(error_code)
  <<-HEREDOC
HTTP/1.0 #{error_code} OK
Date: Mon, 16 Nov 2009 20:39:15 GMT
Content-Type: text/html; charset=ISO-8859-1
Connection: close

<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Error><Code>TemporaryRedirect</Code><Message>Please re-send this request to the specified temporary endpoint. Continue to use the original request endpoint for future requests.</Message><RequestId>137D5486D66095AE</RequestId><Bucket>happening-benchmark</Bucket><HostId>Nyk+Zq9GbtxcspdbKDWyGhsZhyUZquZP55tteYef4QVodsn73HUUad0xrIeD09lF</HostId><Endpoint>https://s3.amazonaws.com</Endpoint></Error>
HEREDOC
end

module EventMachine
  class MockHttpRequest
    @@pass_through_requests = false
  end
end
#     def send_request(&blk)
#       # raise @options.inspect
#       query = "#{@uri.scheme}://#{@uri.host}:#{@uri.port}#{encode_query(@uri.path, @options[:query], @uri.query)}"
#       cache_key = query + @options.to_s
#       if s = @@registry[cache_key] and fake = s[@method]
#         @@registry_count[cache_key][@method] += 1
#         client = FakeHttpClient.new(nil)
#         client.setup(fake, @uri)
#         client
#       elsif @@pass_through_requests
#         real_send_request
#       else
#         raise "this request #{query} for method #{@method} isn't registered, and pass_through_requests is current set to false"
#       end
#     end
#   end
# end
