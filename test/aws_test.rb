require File.expand_path('../test_helper', __FILE__)

class ItemTest < Test::Unit::TestCase
  context "An Happening::AWS instance" do
    
    setup do
      @aws = Happening::AWS.new('the-aws-access-key', 'the-aws-secret-key')
    end
    
    context "when constructing" do
      context "with defaults set" do
        should "pass without the need for Access Key and Secret Key" do
          Happening::AWS.set_defaults({
              :aws_access_key_id => 'key',
              :aws_secret_access_key => 'secret',
              :bucket => 'bucket' })
          assert_nothing_raised do
            Happening::AWS.new
          end
          Happening::AWS.set_defaults({})
        end

        should "overwrite Access Key and Secret Key" do
          Happening::AWS.set_defaults({
              :aws_access_key_id => 'key',
              :aws_secret_access_key => 'secret',
              :bucket => 'bucket' })
          
          aws = Happening::AWS.new('key2', 'secret2')
          assert_equal 'key2', aws.aws_access_key_id
          assert_equal 'secret2', aws.aws_secret_access_key
          Happening::AWS.set_defaults({})  
        end

        should "inform about the defaults which are set" do
          Happening::AWS.set_defaults({
              :aws_access_key_id => 'key',
              :aws_secret_access_key => 'secret',
              :bucket => 'bucket' })
          assert Happening::AWS.bucket_set?
          assert Happening::AWS.credentials_set?

          Happening::AWS.set_defaults({
              :aws_access_key_id => 'key',
              :aws_secret_access_key => 'secret'
            })
          assert !Happening::AWS.bucket_set?
          assert Happening::AWS.credentials_set?
          
          Happening::AWS.set_defaults({})
          assert !Happening::AWS.bucket_set?
          assert !Happening::AWS.credentials_set?
        end
      end

      should "require Access Key and Secret Key" do
        assert_raise(ArgumentError) do
          Happening::AWS.new()
        end
        
        assert_raise(ArgumentError) do
          Happening::AWS.new('', '')
        end
        
        assert_nothing_raised do
          Happening::AWS.new('abc', 'abc')
        end
      end
    end
    
    context "when signing parameters" do
      should "return a header hash" do
        assert_not_nil @aws.sign("GET", '/')['Authorization']
      end
      
      should "include the current date" do
        assert_not_nil @aws.sign("GET", '/')['date']
      end
      
      should "keep given headers" do
        assert_equal 'bar', @aws.sign("GET", '/', {'foo' => 'bar'})['foo']
      end
    end
    
  end
end
