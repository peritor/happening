require 'uri'
require 'cgi'

module Happening
  module S3
    class Item
      include Utils
      include ::Happening::S3::Object

      attr_accessor :bucket, :aws_id, :options

      def initialize(bucket, aws_id, options = {})
        @options = {
          :timeout => 10,
          :server => 's3.amazonaws.com',
          :protocol => 'https',
          :aws_access_key_id => nil,
          :aws_secret_access_key => nil,
          :retry_count => 4,
          :permissions => 'private',
          :ssl => Happening::S3.ssl_options
        }.update(symbolize_keys(options))
        assert_valid_keys(options, :timeout, :server, :protocol, :aws_access_key_id, :aws_secret_access_key, :retry_count, :permissions, :ssl)
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

      def put(data, request_options = {}, &blk)
        headers = construct_aws_headers('PUT', request_options.delete(:headers) || {})
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers, :data => data)
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

      def path(with_bucket=true)
        with_bucket ? "/#{bucket}/#{CGI::escape(aws_id)}" : "/#{CGI::escape(aws_id)}"
      end

    protected

      def validate
        raise ArgumentError, "need a bucket name" unless present?(bucket)
        raise ArgumentError, "need a AWS Key" unless present?(aws_id)

        REQUIRED_FIELDS.each do |field|
          raise ArgumentError, "need field #{field}" unless present?(options[field])
        end

        raise ArgumentError, "unknown protocoll #{options[:protocol]}" unless ['http', 'https'].include?(options[:protocol])
      end
    end
  end
end
