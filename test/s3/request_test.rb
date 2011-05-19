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
        EventMachine::MockHttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:get, 'https://www.example.com').execute
      end
      
      should "pass the given headers and options" do
        request = mock('em-http-request')
        request.expects(:get).with(:timeout => 10, :head => {'a' => 'b'}, :body => nil,  :ssl => {:verify_peer => false, :cert_chain_file => nil}).returns(@response_stub)
        EventMachine::MockHttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:get, 'https://www.example.com', :headers => {'a' => 'b'}).execute
      end
      
      should "post any given data" do
        request = mock('em-http-request')
        request.expects(:put).with(:timeout => 10, :body => 'the-data', :head => {},  :ssl => {:verify_peer => false, :cert_chain_file => nil}).returns(@response_stub)
        EventMachine::MockHttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:put, 'https://www.example.com', :data => 'the-data').execute
      end
      
      should "pass SSL options to em-http-request" do
        request = mock('em-http-request')
        request.expects(:put).with(:timeout => 10, :body => 'the-data', :head => {}, :ssl => {:verfiy_peer => true, :cert_chain_file => '/tmp/server.crt'}).returns(@response_stub)
        EventMachine::MockHttpRequest.expects(:new).with('https://www.example.com').returns(request)
        Happening::S3::Request.new(:put, 'https://www.example.com', :data => 'the-data', :ssl => {:verfiy_peer => true, :cert_chain_file => '/tmp/server.crt'}).execute
      end
      
      context "when handling errors" do
        should "call the user error handler" do
          EventMachine::MockHttpRequest.register('http://www.example.com:80/', :get, {}, error_response(400))

          called = false
          on_error = Proc.new {|http| called = true}

          run_in_em_loop do
            Happening::S3::Request.new(:get, 'http://www.example.com/', :on_error => on_error).execute

            EM.add_timer(1) {
              EM.stop_event_loop
              assert called
              assert_equal 5, EventMachine::MockHttpRequest.count('http://www.example.com:80/', :get, {})
            }

          end
        end
        
        should "use a default error handler if there is no user handler" do
          EventMachine::MockHttpRequest.register('http://www.example.com:80/', :get, {}, error_response(400))

          assert_raise(Happening::Error) do
            run_in_em_loop do
              Happening::S3::Request.new(:get, 'http://www.example.com/').execute
            end
          end
          EM.stop_event_loop if EM.reactor_running?
        end
        
      end
      
    end
        
  end
end
