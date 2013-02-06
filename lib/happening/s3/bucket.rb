require 'uri'
require 'cgi'

module Happening
  module S3
    class Bucket
      include Utils
      include Object

      REQUIRED_FIELDS = [:server]
      VALID_HEADERS   = ['Cache-Control', 'Content-Disposition', 'Content-Encoding', 'Content-Length', 'Content-MD5', 'Content-Type', 'Expect', 'Expires']

      attr_accessor :bucket, :options

      def initialize(bucket, options = { })
        @options = {
          :timeout               => 10,
          :server                => 's3.amazonaws.com',
          :protocol              => 'https',
          :aws_access_key_id     => nil,
          :aws_secret_access_key => nil,
          :retry_count           => 4,
          :permissions           => 'private',
          :ssl                   => Happening::S3.ssl_options,
          :prefix                => nil,
          :delimiter             => nil
        }.update(symbolize_keys(options))
        assert_valid_keys(options, :timeout, :server, :protocol, :aws_access_key_id, :aws_secret_access_key, :retry_count, :permissions, :ssl, :prefix, :delimiter)
        @bucket = bucket.to_s

        validate
      end

      def get(request_options = { }, &blk)
        headers = needs_to_sign? ? aws.sign("GET", path_with_query) : { }
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:get, url, { :ssl => options[:ssl], :parser => proc { |http| parse_body(http) } }.update(request_options)).execute
      end

      def url
        URI::Generic.new(options[:protocol], nil, server, port, nil, path(!dns_bucket?), nil, query_string, nil).to_s
      end

      def path(with_bucket=true)
        with_bucket ? "/#{bucket}/" : "/"
      end

      def path_with_query(with_bucket=true)
        base  = path(with_bucket)
        query = query_string
        query ? "#{base}?#{query}" : base
      end

      protected

      XML = /^application\/xml/

      def parse_body(http)
        content_type = http.response_header['CONTENT_TYPE']
        if content_type =~ XML
          doc = Nokogiri::XML(http.response)
          doc.remove_namespaces!
          http.response = doc.xpath('//Contents').inject([]) do |items, node|
            items << node_to_value(node)
            items
          end
        end
      end

      def parse_string_value(key, val)
        if key == 'LastModified'
          Time.parse(val)
        elsif key == 'Size'
          val.to_i
        else
          val
        end
      end

      def query_string
        if @options[:prefix] || @options[:delimiter]
          str = ""
          str += "prefix=#{CGI::escape(@options[:prefix])}&" if @options[:prefix]
          str += "delimiter=#{CGI::escape(@options[:delimiter])}&" if @options[:delimiter]
          str.gsub(/&\Z/, "")
        else
          nil
        end
      end

      def validate
        raise ArgumentError, "need a bucket name" unless present?(bucket)

        REQUIRED_FIELDS.each do |field|
          raise ArgumentError, "need field #{field}" unless present?(options[field])
        end

        raise ArgumentError, "unknown protocol #{options[:protocol]}" unless ['http', 'https'].include?(options[:protocol])
      end

    end
  end
end
