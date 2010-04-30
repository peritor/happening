require File.dirname(__FILE__) + "/test_helper"

class S3Test < Test::Unit::TestCase
  context "The Happening::S3 module" do
    
    should "allow to set global SSL options" do
      assert Happening::S3.respond_to?(:ssl_options)
      assert Happening::S3.respond_to?(:ssl_options=)
    end
    
    should "set and get verify_peer" do
      Happening::S3.ssl_options[:verify_peer] = true
      assert Happening::S3.ssl_options[:verify_peer]
      Happening::S3.ssl_options[:verify_peer] = false
      assert !Happening::S3.ssl_options[:verify_peer]
    end
    
    should "set and get cert_chain_file" do
      Happening::S3.ssl_options[:cert_chain_file] = '/etc/cacert'
      assert_equal '/etc/cacert', Happening::S3.ssl_options[:cert_chain_file]
      Happening::S3.ssl_options[:cert_chain_file] = nil
      assert_nil Happening::S3.ssl_options[:cert_chain_file]
    end
    
    should "default to no certificate file and no verification" do
      Happening::S3.instance_variable_set("@_ssl_options", nil)
      assert !Happening::S3.ssl_options[:verify_peer]
      assert_nil Happening::S3.ssl_options[:cert_chain_file]
    end
    
  end
end
