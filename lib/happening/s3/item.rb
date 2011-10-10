require 'uri'
require 'cgi'

module Happening
  module S3
    class Item
      include Utils
    
      REQUIRED_FIELDS = [:server]
      VALID_HEADERS = ['Cache-Control', 'Content-Disposition', 'Content-Encoding',
        'Content-Length', 'Content-MD5', 'Content-Type', 'Expect', 'Expires']
      
      attr_accessor :bucket, :aws_id, :options

      def initialize(*args)
        options = {}
        bucket = nil
        aws_id = nil
        
        # We handle the arguments array manually to allow calls like:
        # Item.new('bucket', 'object-id') 
        # Item.new('object-id')
        options = args.pop if args.last.is_a?(Hash)
        if args.length > 1
          bucket = args[0]
          aws_id = args[1]
        elsif args.length == 1
          if Happening::AWS.bucket_set?
            bucket = Happening::AWS.defaults[:bucket]
            aws_id = args[0]
          end
        end
        
        @options = {
          :timeout => 10,
          :server => 's3.amazonaws.com',
          :protocol => 'https',
          :aws_access_key_id => Happening::AWS.defaults[:aws_access_key_id],
          :aws_secret_access_key => Happening::AWS.defaults[:aws_secret_access_key],
          :retry_count => 4,
          :permissions => 'private',
          :ssl => Happening::S3.ssl_options
        }.update(symbolize_keys(options))
        
        assert_valid_keys(options, :timeout, :server, :protocol, :aws_access_key_id,
          :aws_secret_access_key, :retry_count, :permissions, :ssl)
        
        @aws_id = aws_id.to_s
        @bucket = bucket.to_s
      
        validate
      end
    
      def head(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("HEAD", path) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:head, url, {:ssl => options[:ssl]}.update(request_options)).execute
      end

      def get(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("GET", path) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:get, url, {:ssl => options[:ssl]}.update(request_options)).execute
      end
      
      def put(desc = nil, request_options = {}, &blk)
        headers = construct_aws_headers('PUT', request_options.delete(:headers) || {})

        # we let the desc be a hash so we can allow execution of put('data', options) 
        # and put(options), the latter will give us the feature of clean putting only
        # with the options ":file"
        if desc.is_a?(Hash)
          request_options = desc
        else
          request_options.update(:data => desc) if request_options[:file].nil?
        end
        if request_options[:file].nil? and request_options[:data].nil?
          raise ArgumentError, "Neither data given, nor file for streaming specified."
        end
        
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:put, url, {:ssl => options[:ssl]}.update(request_options)).execute
      end
      
      def delete(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("DELETE", path, {'url' => path}) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:delete, url, {:ssl => options[:ssl]}.update(request_options)).execute
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
        present?(options[:aws_access_key_id])
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
        raise ArgumentError, "need a bucket name" unless present?(bucket)
        raise ArgumentError, "need a AWS Key" unless present?(aws_id)
      
        REQUIRED_FIELDS.each do |field|
          raise ArgumentError, "need field #{field}" unless present?(options[field])
        end
      
        raise ArgumentError, "unknown protocol #{options[:protocol]}" unless ['http', 'https'].include?(options[:protocol])
      end
      
      def aws
        @aws ||= Happening::AWS.new(options[:aws_access_key_id], options[:aws_secret_access_key])
      end
      
      def construct_aws_headers(http_method, headers = {})
        unless headers.keys.all?{|header| VALID_HEADERS.include?(header) || header.to_s.match(/\Ax-amz-/) }
          raise ArgumentError, "invalid headers. All headers must either one of #{VALID_HEADERS} or start with 'x-amz-'"
        end
        
        permissions = options[:permissions] != 'private' ? {'x-amz-acl' => options[:permissions] } : {}
        headers.update(permissions)
        headers.update({'url' => path})
        
        headers = needs_to_sign? ? aws.sign(http_method, path, headers) : headers
      end
    
    end
  end
end
