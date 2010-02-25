require 'uri'
require 'cgi'

module Happening
  module S3
    class Item
    
      REQUIRED_FIELDS = [:server]
    
      attr_accessor :bucket, :aws_id, :options
    
      def initialize(bucket, aws_id, options = {})
        @options = {
          :timeout => 10,
          :on_error => nil,
          :on_success => nil,
          :server => 's3.amazonaws.com',
          :protocol => 'https',
          :aws_access_key_id => nil,
          :aws_secret_access_key => nil
        }.update(options.symbolize_keys)
        options.assert_valid_keys(:timeout, :on_success, :on_error, :server, :protocol, :aws_access_key_id, :aws_secret_access_key)
        @aws_id = aws_id.to_s
        @bucket = bucket.to_s
      
        validate
      end
    
      def get
        puts "Starting EM-HTTP request to #{url}"
        
        headers = needs_to_sign? ? aws.sign("GET", path) : {}
        
        http = http_class.new(url).get(:timeout => options[:timeout], :head => headers)

        http.errback { 
          options[:on_error].call(http) if options[:on_error].respond_to?(:call)
        }

        http.callback {
          options[:on_success].call(http) if options[:on_success].respond_to?(:call)
        }
      end
    
      def url
        URI::Generic.new(options[:protocol], nil, server, port, nil, path(!dns_bucket?), nil, nil, nil).to_s
      end
    
      def http_class
        EventMachine::HttpRequest
      end
      
      def server
        dns_bucket? ? "#{bucket}.#{options[:server]}" : options[:server]
      end
      
      def path(with_bucket=true)
        with_bucket ? "/#{bucket}/#{CGI::escape(aws_id)}" : "/#{CGI::escape(aws_id)}"
      end
    
    protected
    
      def needs_to_sign?
        options[:aws_access_key_id].present?
      end
    
      def dns_bucket?
        # http://docs.amazonwebservices.com/AmazonS3/2006-03-01/index.html?BucketRestrictions.html
        return false unless (3..63) === bucket.size
        bucket.split('.').each do |component|
          return false unless component[/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/]
        end
        true
      end
    
      def port
        (options[:protocol].to_s == 'https') ? 443 : 80
      end
    
      def validate
        raise ArgumentError, "need a bucket name" unless bucket.present?
        raise ArgumentError, "need a AWS Key" unless aws_id.present?
      
        REQUIRED_FIELDS.each do |field|
          raise ArgumentError, "need field #{field}" unless options[field].present?
        end
      
        raise ArgumentError, "unknown protocoll #{options[:protocol]}" unless ['http', 'https'].include?(options[:protocol])
      end
      
      def aws
        @aws ||= Happening::AWS.new(options[:aws_access_key_id], options[:aws_secret_access_key])
      end
    
    end
  end
end
