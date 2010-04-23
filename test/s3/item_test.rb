require File.dirname(__FILE__) + "/../test_helper"

class ItemTest < Test::Unit::TestCase
  context "An Happening::S3::Item instance" do
    
    setup do
      Happening::Log.level = Logger::ERROR
      @item = Happening::S3::Item.new('the-bucket', 'the-key', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :server => '127.0.0.1')
      
      @time = "Thu, 25 Feb 2010 10:00:00 GMT"
      Time.stubs(:now).returns(stub(:httpdate => @time, :to_i => 99, :usec => 88))
    end
    
    context "validation" do
      should "require a bucket and a key" do
        assert_raise(ArgumentError) do
          item = Happening::S3::Item.new()
        end
        
        assert_raise(ArgumentError) do
          item = Happening::S3::Item.new('the-key')
        end
        
        assert_nothing_raised(ArgumentError) do
          item = Happening::S3::Item.new('the-bucket', 'the-key')
        end
        
      end
      
      should "not allow unknown options" do
        assert_raise(ArgumentError) do
          item = Happening::S3::Item.new('the-bucket', 'the-key', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :lala => 'lulul')
        end
      end
      
      should "check valid protocol" do
        assert_raise(ArgumentError) do
          item = Happening::S3::Item.new('the-bucket', 'the-key', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :protocol => 'lulul')
        end
        
        assert_nothing_raised do
          item = Happening::S3::Item.new('the-bucket', 'the-key', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :protocol => 'http')
        end
        
        assert_nothing_raised do
          item = Happening::S3::Item.new('the-bucket', 'the-key', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :protocol => 'https')
        end
      end
    end
    
    context "when building the item url" do
      should "build the full path out of the server, bucket, and key" do
        @item = Happening::S3::Item.new('the-bucketissoooooooooooooooooooooooooooooooooooooolonggggggggggggggggggggggggggggggggggg', 'the-key', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :server => '127.0.0.1')
        assert_equal "https://127.0.0.1:443/the-bucketissoooooooooooooooooooooooooooooooooooooolonggggggggggggggggggggggggggggggggggg/the-key", @item.url
      end
      
      should "use the DNS bucket name where possible" do
        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => '123', :aws_secret_access_key => 'secret')
        assert_equal "https://bucket.s3.amazonaws.com:443/the-key", @item.url
      end
    end
    
    context "when getting an item" do
      
      should "call the on success callback" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :get, {}, fake_response("data-here"))
        
        called = false
        data = nil
        on_success = Proc.new {|http| called = true, data = http.response}
        @item = Happening::S3::Item.new('bucket', 'the-key')
        run_in_em_loop do
          @item.get(:on_success => on_success)
          
          EM.add_timer(1) {
            assert called
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :get, {})
            assert_equal "data-here\n", data
            EM.stop_event_loop
          }
          
        end
      end
      
      should "support direct blocks" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :get, {}, fake_response("data-here"))
        
        called = false
        data = nil
        @item = Happening::S3::Item.new('bucket', 'the-key')
        run_in_em_loop do
          @item.get do |http| 
            called = true
            data = http.response
          end
          
          EM.add_timer(1) {
            assert called
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :get, {})
            assert_equal "data-here\n", data
            EM.stop_event_loop
          }
          
        end
      end

      should "sign requests if AWS credentials are passend" do
        time = "Thu, 25 Feb 2010 12:06:33 GMT"
        Time.stubs(:now).returns(mock(:httpdate => time))
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :get, {"Authorization"=>"AWS abc:3OEcVbE//maUUmqh3A5ETEcr9TE=", 'date' => time}, fake_response("data-here"))
        
        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.get
          
          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :get, {"Authorization"=>"AWS abc:3OEcVbE//maUUmqh3A5ETEcr9TE=", 'date' => time})
          }
          
        end
      end
      
      should "retry on error" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :get, {}, error_response(400))

        @item = Happening::S3::Item.new('bucket', 'the-key')
        run_in_em_loop do
          @item.get(:on_error => Proc.new{} ) #ignore error

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 5, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :get, {})
          }

        end
      end
      
      should "handle re-direct" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :get, {}, redirect_response('https://bucket.s3-external-3.amazonaws.com/the-key'))
        EventMachine::MockHttpRequest.register('https://bucket.s3-external-3.amazonaws.com:443/the-key', :get, {}, fake_response('hy there'))

        @item = Happening::S3::Item.new('bucket', 'the-key')
        run_in_em_loop do
          @item.get

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :get, {})
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3-external-3.amazonaws.com:443/the-key', :get, {})
          }

        end
      end
    end
    
    context "when deleting an item" do
      should "send a DELETE to the items location" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :delete, {
           "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
           'date' => @time, 
           'url' => "/bucket/the-key"}, fake_response("data-here"))

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.delete

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :delete, {
              "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
          }

        end
      end
      
      should "support direct blocks" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :delete, {
           "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
           'date' => @time, 
           'url' => "/bucket/the-key"}, fake_response("data-here"))
        
        called = false
        data = nil
        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.delete do |http| 
            called = true
            data = http.response
          end
          
          EM.add_timer(1) {
            assert called
            assert_equal "data-here\n", data
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :delete, {
              "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
          }
          
        end
      end
      
      should "handle re-direct" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :delete, {
           "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
           'date' => @time, 
           'url' => "/bucket/the-key"}, redirect_response('https://bucket.s3-external-3.amazonaws.com/the-key'))
        EventMachine::MockHttpRequest.register('https://bucket.s3-external-3.amazonaws.com:443/the-key', :delete, {
           "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
           'date' => @time, 
           'url' => "/bucket/the-key"}, fake_response("success!"))

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.delete

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :delete, {
              "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3-external-3.amazonaws.com:443/the-key', :delete, {
              "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
          }

        end
      end
      
      should "handle retry" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :delete, {
           "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
           'date' => @time, 
           'url' => "/bucket/the-key"}, error_response(400))

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.delete(:on_error => Proc.new{} ) #ignore error

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 5, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :delete, {
              "Authorization"=>"AWS abc:nvkrlq4wor1qbFXZh6rHnAbiRjk=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
          }

        end
      end
    end
    
    context "when saving an item" do
      
      should "post to the desired location" do
       EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :put, {
         "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
         'date' => @time, 
         'url' => "/bucket/the-key"}, fake_response("data-here"))

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.put('content')

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :put, {
              "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
          }

        end
      end
      
      should "support direct blocks" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :put, {
           "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
           'date' => @time, 
           'url' => "/bucket/the-key"}, fake_response("data-here"))
        
        called = false
        data = nil
        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.put('upload me') do |http| 
            called = true
            data = http.response
          end
          
          EM.add_timer(1) {
            assert called
            assert_equal "data-here\n", data
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :put, {
              "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
          }
          
        end
      end
      
      should "set the desired permissions" do
       EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :put, {
         "Authorization"=>"AWS abc:cqkfX+nC7WIkYD+yWaUFuoRuePA=", 
         'date' => @time, 
         'url' => "/bucket/the-key",
         "x-amz-acl" => 'public-read'}, fake_response("data-here"))

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123' , :permissions => 'public-read')
        run_in_em_loop do
          @item.put('content')

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :put, {
              "Authorization"=>"AWS abc:cqkfX+nC7WIkYD+yWaUFuoRuePA=", 
              'date' => @time, 
              'url' => "/bucket/the-key",
              'x-amz-acl' => 'public-read'})
          }

        end
      end
      
      should "allow to set custom headers" do
       EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :put, {
         "Authorization"=>"AWS abc:wrPkGKrlwH2AtNzBVS80vU73TDc=", 
         'date' => @time, 
         'url' => "/bucket/the-key",
         "x-amz-acl" => 'public-read',
         'Cache-Control' => "max-age=252460800",
         'Expires' => 'Fri, 16 Nov 2018 22:09:29 GMT',
         'x-amz-meta-abc' => 'ABC'}, fake_response("data-here"))
         
        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', 
                                                             :aws_secret_access_key => '123' , 
                                                             :permissions => 'public-read')
        run_in_em_loop do
          @item.put('content', :headers => { 
             'Expires' => 'Fri, 16 Nov 2018 22:09:29 GMT',
             'Cache-Control' => "max-age=252460800",
             'x-amz-meta-abc' => 'ABC'})

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :put, {
              "Authorization"=>"AWS abc:wrPkGKrlwH2AtNzBVS80vU73TDc=", 
              'date' => @time, 
              'url' => "/bucket/the-key",
              'x-amz-acl' => 'public-read',
              'Cache-Control' => "max-age=252460800",
              'Expires' => 'Fri, 16 Nov 2018 22:09:29 GMT',
              'x-amz-meta-abc' => 'ABC'})
          }

        end
      end
      
      should "validate the headers" do

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', 
                                                             :aws_secret_access_key => '123' , 
                                                             :permissions => 'public-read')
                                                             
        assert_raise(ArgumentError) do
          @item.put('content', :headers => { 
             'expires' => 'Fri, 16 Nov 2018 22:09:29 GMT',
             'cache_control' => "max-age=252460800"})
        end                                                    
      end
      
      should "re-post to a new location" do
        EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :put, {
          "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
          'date' => @time, 
          'url' => "/bucket/the-key"}, redirect_response('https://bucket.s3-external-3.amazonaws.com/the-key'))
        EventMachine::MockHttpRequest.register('https://bucket.s3-external-3.amazonaws.com:443/the-key', :put, {
          "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
          'date' => @time, 
          'url' => "/bucket/the-key"}, fake_response('Thanks!')) 

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.put('content')

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :put, {
              "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
            
            assert_equal 1, EventMachine::MockHttpRequest.count('https://bucket.s3-external-3.amazonaws.com:443/the-key', :put, {
              "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
              'date' => @time, 
              'url' => "/bucket/the-key"})
          }

        end
      end
      
      should "retry on error" do
       EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :put, {
         "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
         'date' => @time, 
         'url' => "/bucket/the-key"}, error_response(400))

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.put('content', :on_error => Proc.new{} )

          EM.add_timer(1) {
            EM.stop_event_loop
            assert_equal 5, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :put, {
              "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
              'date' => @time,
              'url' => "/bucket/the-key"})
          }

        end
      end
      
      should "call error handler after retry reached" do
       EventMachine::MockHttpRequest.register('https://bucket.s3.amazonaws.com:443/the-key', :put, {
         "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
         'date' => @time, 
         'url' => "/bucket/the-key"}, error_response(400))

       called = false
       on_error = Proc.new {|http| called = true}

        @item = Happening::S3::Item.new('bucket', 'the-key', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        run_in_em_loop do
          @item.put('content', :on_error => on_error, :retry_count => 1)

          EM.add_timer(1) {
            EM.stop_event_loop
            assert called
            assert_equal 2, EventMachine::MockHttpRequest.count('https://bucket.s3.amazonaws.com:443/the-key', :put, {
              "Authorization"=>"AWS abc:lZMKxGDKcQ1PH8yjbpyN7o2sPWg=", 
              'date' => @time,
              'url' => "/bucket/the-key"})
          }

        end
      end
      
    end
    
  end
end
