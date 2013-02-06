require File.expand_path('../../test_helper', __FILE__)

class BucketTest < Test::Unit::TestCase
  context "An Happening::S3::Bucket instance" do

    setup do
      Happening::Log.level = Logger::ERROR
      @bucket              = Happening::S3::Bucket.new('the-bucket', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :server => '127.0.0.1')

      @time = "Thu, 25 Feb 2010 10:00:00 GMT"
      Time.stubs(:now).returns(Time.parse(@time))
      @expected_data = [
        {
          :key           => "my-image.jpg",
          :last_modified => Time.parse("2009-10-12T17:50:30.000Z"),
          :e_tag         => "\"fba9dede5f27731c9771645a39863328\"",
          :size          => 434234,
          :storage_class => "STANDARD",
          :owner         =>
            { :id           => "75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a",
              :display_name => "mtd@amazon.com" }
        },
        {
          :key           => "my-third-image.jpg",
          :last_modified => Time.parse("2009-10-12T17:50:30.000Z"),
          :e_tag         => "\"1b2cf535f27731c974343645a3985328\"",
          :size          => 64994,
          :storage_class => "STANDARD",
          :owner         => {
            :id           => "75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a",
            :display_name => "mtd@amazon.com"
          }
        }
      ]
    end

    context "validation" do
      should "require a bucket and a key" do
        assert_raise(ArgumentError) do
          Happening::S3::Bucket.new()
        end

        assert_nothing_raised(ArgumentError) do
          Happening::S3::Bucket.new('the-bucket')
        end
      end

      should "not allow unknown options" do
        assert_raise(ArgumentError) do
          Happening::S3::Bucket.new('the-bucket', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :lala => 'lulul')
        end
      end

      should "check valid protocol" do
        assert_raise(ArgumentError) do
          Happening::S3::Bucket.new('the-bucket', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :protocol => 'lulul')
        end

        assert_nothing_raised do
          Happening::S3::Bucket.new('the-bucket', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :protocol => 'http')
        end

        assert_nothing_raised do
          Happening::S3::Bucket.new('the-bucket', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :protocol => 'https')
        end
      end
    end

    context "when building the item url" do
      should "build the full path out of the server, bucket, and key" do
        @bucket = Happening::S3::Bucket.new('the-bucketissoooooooooooooooooooooooooooooooooooooolonggggggggggggggggggggggggggggggggggg', :aws_access_key_id => '123', :aws_secret_access_key => 'secret', :server => '127.0.0.1')
        assert_equal "https://127.0.0.1:443/the-bucketissoooooooooooooooooooooooooooooooooooooolonggggggggggggggggggggggggggggggggggg/", @bucket.url
      end

      should "use the DNS bucket name where possible" do
        @bucket = Happening::S3::Bucket.new('bucket', :aws_access_key_id => '123', :aws_secret_access_key => 'secret')
        assert_equal "https://bucket.s3.amazonaws.com:443/", @bucket.url
      end
    end

    context "when getting bucket contents" do

      should "call the on success callback" do
        stub_request(:get, 'https://bucket.s3.amazonaws.com:443').to_return(bucket_list)

        data       = nil
        on_success = Proc.new { |http| data = http.response }
        @bucket    = Happening::S3::Bucket.new('bucket')
        EM.run do
          @bucket.get(:on_success => on_success)

          EM.add_timer(0.1) {
            assert_requested :get, "https://bucket.s3.amazonaws.com:443/", :times => 1
            assert_equal @expected_data, data
            EM.stop
          }
        end
      end

      should "support direct blocks" do
        stub_request(:get, 'https://bucket.s3.amazonaws.com:443/').to_return(bucket_list)

        data    = nil
        @bucket = Happening::S3::Bucket.new('bucket')
        EM.run do
          @bucket.get do |http|
            data = http.response
          end

          EM.add_timer(0.1) {
            assert_requested :get, "https://bucket.s3.amazonaws.com:443/", :times => 1
            assert_equal @expected_data, data
            EM.stop
          }
        end
      end

      should "support stream blocks" do
        stub_request(:get, 'https://bucket.s3.amazonaws.com:443/').to_return(bucket_list)

        data    = ""
        @bucket = Happening::S3::Bucket.new('bucket')
        EM.run do
          response = @bucket.get
          response.stream do |chunk|
            data << chunk
          end

          EM.add_timer(0.1) {
            assert_requested :get, "https://bucket.s3.amazonaws.com:443/", :times => 1
            assert_equal "#{BUCKET_LIST_BODY}\n", data
            EM.stop
          }
        end
      end

      should "use the prefix if one is passed" do
        stub_request(:get, 'https://bucket.s3.amazonaws.com:443/?prefix=foo/bar').to_return(bucket_list)

        @bucket = Happening::S3::Bucket.new('bucket', :prefix => "foo/bar")
        EM.run do
          @bucket.get

          EM.add_timer(0.1) {
            assert_requested :get, "https://bucket.s3.amazonaws.com:443/?prefix=foo/bar", :times => 1
            EM.stop
          }
        end
      end

      should "use the delimiter if one is passed" do
        stub_request(:get, 'https://bucket.s3.amazonaws.com:443/?delimiter=.').to_return(bucket_list)

        @bucket = Happening::S3::Bucket.new('bucket', :delimiter => ".")
        EM.run do
          @bucket.get

          EM.add_timer(0.1) {
            assert_requested :get, "https://bucket.s3.amazonaws.com:443/?delimiter=.", :times => 1
            EM.stop
          }
        end
      end

      should "sign requests if AWS credentials are passed" do
        time    = "Thu, 25 Feb 2010 12:06:33 GMT"
        headers = { "Authorization" => "AWS abc:HwnYs+kcnkjLDqwnJY0tAlG73a4=", 'date' => time }
        Time.stubs(:now).returns(Time.parse(time))
        stub_request(:get, 'https://bucket.s3.amazonaws.com:443/').to_return(bucket_list)

        @bucket = Happening::S3::Bucket.new('bucket', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        EM.run do
          @bucket.get

          EM.add_timer(0.1) {
            assert_requested :get, "https://bucket.s3.amazonaws.com:443/", :times => 1, :headers => headers
            EM.stop
          }
        end
      end

      should "retry on error" do
        stub_request(:get, 'https://bucket.s3.amazonaws.com:443/').to_return(error_response(400))

        @bucket = Happening::S3::Bucket.new('bucket')
        EM.run do
          @bucket.get(:on_error => Proc.new {}) #ignore error

          EM.add_timer(0.1) {
            assert_requested :get, "https://bucket.s3.amazonaws.com:443/", :times => 5
            EM.stop
          }
        end
      end

      should "handle re-direct" do
        stub_request(:get, 'https://bucket.s3.amazonaws.com:443/').to_return(redirect_response('https://bucket.s3-external-3.amazonaws.com/'))
        stub_request(:get, 'https://bucket.s3-external-3.amazonaws.com:443/').to_return(bucket_list)

        @bucket = Happening::S3::Bucket.new('bucket')
        EM.run do
          @bucket.get

          EM.add_timer(0.1) {
            assert_requested :get, "https://bucket.s3.amazonaws.com:443/", :times => 1
            assert_requested :get, "https://bucket.s3-external-3.amazonaws.com:443/", :times => 1
            EM.stop
          }
        end
      end
    end

    context "SSL options" do
      setup do
        Happening::S3.ssl_options[:verify_peer]     = true
        Happening::S3.ssl_options[:cert_chain_file] = '/etc/foo.ca'
      end

      should "re-use the global options" do
        bucket = Happening::S3::Bucket.new('bucket', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        assert bucket.options[:ssl][:verify_peer]
        assert_equal '/etc/foo.ca', bucket.options[:ssl][:cert_chain_file]
      end

      should "allow to override global options" do
        bucket = Happening::S3::Bucket.new('bucket', :aws_access_key_id => 'abc', :aws_secret_access_key => '123', :ssl => { :cert_chain_file => nil, :verify_peer => false })
        assert !bucket.options[:ssl][:verify_peer]
        assert_nil bucket.options[:ssl][:cert_chain_file]
      end

      should "pass the options to the Request" do
        bucket = Happening::S3::Bucket.new('bucket', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        Happening::S3::Request.expects(:new).with(:get, anything, has_entries({ :ssl => { :cert_chain_file => '/etc/foo.ca', :verify_peer => true }, :headers => { 'Authorization' => 'AWS abc:Eb6n+OC9MyUDZ8O5Ky8q11y05pI=', 'date' => 'Thu, 25 Feb 2010 10:00:00 GMT' } })).returns(stub(:execute => nil))
        bucket.get
      end

      should "allow to override the options per request" do
        bucket = Happening::S3::Bucket.new('bucket', :aws_access_key_id => 'abc', :aws_secret_access_key => '123')
        Happening::S3::Request.expects(:new).with(:get, anything, has_entries({ :ssl => { :foo => :bar }, :headers => { 'Authorization' => 'AWS abc:Eb6n+OC9MyUDZ8O5Ky8q11y05pI=', 'date' => 'Thu, 25 Feb 2010 10:00:00 GMT' } })).returns(stub(:execute => nil))
        bucket.get(:ssl => { :foo => :bar })
      end
    end

  end
end
