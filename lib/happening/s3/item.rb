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
          :server => 's3.amazonaws.com',
          :protocol => 'https',
          :aws_access_key_id => nil,
          :aws_secret_access_key => nil,
          :retry_count => 4,
          :permissions => 'private'
        }.update(options.symbolize_keys)
        options.assert_valid_keys(:timeout, :server, :protocol, :aws_access_key_id, :aws_secret_access_key, :retry_count, :permissions)
        @aws_id = aws_id.to_s
        @bucket = bucket.to_s
      
        validate
      end
    
      def get(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("GET", path) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:get, url, request_options).execute
      end
      
      def put(data, request_options = {}, &blk)
        permissions = options[:permissions] != 'private' ? {'x-amz-acl' => options[:permissions] } : {}
        headers = needs_to_sign? ? aws.sign("PUT", path, permissions.update({'url' => path})) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers, :data => data)
        Happening::S3::Request.new(:put, url, request_options).execute
      end
      
      def delete(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("DELETE", path, {'url' => path}) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:delete, url, request_options).execute
      end
    
      def url
        URI::Generic.new(options[:protocol], nil, server, port, nil, path(!dns_bucket?), nil, nil, nil).to_s
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
