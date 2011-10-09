require File.expand_path('../../test_helper', __FILE__)

class ItemTest < Test::Unit::TestCase
  context "An Happening::S3::Request instance" do
    
    setup do
      Happening::Log.level = Logger::ERROR
      @response_stub = stub()
      @response_stub.stubs(:errback)
      @response_stub.stubs(:callback)
    end
    
    context "validation" do
      should "check HTTP method" do
        assert_raise(ArgumentError) do
          Happening::S3::Request.new(:foo, 'https://www.example.com')
        end
        
        assert_nothing_raised do
          Happening::S3::Request.new(:get, 'https://www.example.com')
        end
      end
      
      should "check the options" do
        assert_raise(ArgumentError) do
          Happening::S3::Request.new(:get, 'https://www.example.com', {:foo => :bar})
        end
        
        assert_nothing_raised do
          Happening::S3::Request.new(:get, 'https://www.example.com', {:timeout => 4})
        end
      end
    end
    
    context "when executing" do
      should "have no response before executing" do
        assert_nil Happening::S3::Request.new(:get, 'https://www.example.com').response
      end
      
      should "call em-http-request" do
        request = mock(:get => @response_stub)
        EventMachine::HttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:get, 'https://www.example.com').execute
      end
      
      should "return the happening request object" do
        request = mock(:get => @response_stub)
        EventMachine::HttpRequest.expects(:new).with('https://www.example.com').returns(request)
        requ = Happening::S3::Request.new(:get, 'https://www.example.com')
        return_value = requ.execute
        assert_equal requ, return_value
      end
      
      should "pass the given headers and options" do
        request = mock('em-http-request')
        request.expects(:get).with(:timeout => 10, :head => {'a' => 'b'},
          :ssl => {:verify_peer => false, :cert_chain_file => nil}).returns(@response_stub)
        EventMachine::HttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:get, 'https://www.example.com', :headers => {'a' => 'b'}).execute
      end
      
      should "post any given data" do
        request = mock('em-http-request')
        request.expects(:put).with(:timeout => 10, :body => 'the-data',
          :ssl => {:verify_peer => false, :cert_chain_file => nil}).returns(@response_stub)
        EventMachine::HttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:put, 'https://www.example.com', :data => 'the-data').execute
      end
      
      should "pass SSL options to em-http-request" do
        request = mock('em-http-request')
        request.expects(:put).with(:timeout => 10, :body => 'the-data',
          :ssl => {:verfiy_peer => true, :cert_chain_file => '/tmp/server.crt'}).returns(@response_stub)        
        EventMachine::HttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:put, 'https://www.example.com', :data => 'the-data',
          :ssl => {:verfiy_peer => true, :cert_chain_file => '/tmp/server.crt'}).execute
      end

      should "pass file path option to stream big files" do
        request = mock('em-http-request')
        request.expects(:put).with(:timeout => 10, :file => "/test/path/to/file",
          :ssl => {:verify_peer => false, :cert_chain_file => nil}).returns(@response_stub)
        EventMachine::HttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:put, 'https://www.example.com', :file => "/test/path/to/file").execute        
      end
      
      context "when handling errors" do
        should "call the user error handler" do
          stub_request(:get, 'http://www.example.com:80/').to_return(error_response(400)).times(5)

          called = false
          on_error = Proc.new {|http| called = true}

          EM.run do
            Happening::S3::Request.new(:get, 'http://www.example.com/', :on_error => on_error).execute

            EM.assertions do
              assert called
            end
          end
        end
        
        should "use a default error handler if there is no user handler" do
          stub_request(:get, 'http://www.example.com:80/').to_return(error_response(400))
          assert_raise Happening::Error do
            EM.run do
              Happening::S3::Request.new(:get, 'http://www.example.com/').execute
            end
          end
          EM.stop_event_loop if EM.reactor_running?
        end
        
      end
      
    end
        
  end
end
