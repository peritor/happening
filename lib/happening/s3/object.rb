module Happening
  module S3
    module Object
      REQUIRED_FIELDS = [:server]
      VALID_HEADERS = ['Cache-Control', 'Content-Disposition', 'Content-Encoding', 'Content-Length', 'Content-MD5', 'Content-Type', 'Expect', 'Expires']

      def server
        dns_bucket? ? "#{bucket}.#{options[:server]}" : options[:server]
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
