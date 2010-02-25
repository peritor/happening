require File.dirname(__FILE__) + "/test_helper"

class ItemTest < Test::Unit::TestCase
  context "An Happening::AWS instance" do
    
    setup do
      @aws = Happening::AWS.new('the-aws-access-key', 'the-aws-secret-key')
    end
    
    context "when constructing" do
      should "require Access Key and Secret Key" do
        assert_raise(ArgumentError) do
          Happening::AWS.new(nil, nil)
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
