module Happening
  class AWS
    
    AMAZON_HEADER_PREFIX   = 'x-amz-'
    AMAZON_METADATA_PREFIX = 'x-amz-meta-'
    DIGEST = OpenSSL::Digest.new('sha1')
    
    attr_accessor :aws_access_key_id, :aws_secret_access_key
    
    def initialize(aws_access_key_id, aws_secret_access_key)
      @aws_access_key_id = aws_access_key_id
      @aws_secret_access_key = aws_secret_access_key
      raise ArgumentError, "need AWS Access Key Id and AWS Secret Key" unless aws_access_key_id.present? && aws_secret_access_key.present?
    end
    
    def sign(method, path, headers={})
      headers = {
        'date' => Time.now.httpdate
      }.update(headers)
      
      request_description = canonical_request_description(method, path, headers)
      headers.update("Authorization" => "AWS #{aws_access_key_id}:#{generate_signature(request_description)}")
    end
    
  protected
        
    def generate_signature(request_description)
      puts "Generating a signature for #{request_description.inspect}"
      res = Base64.encode64(OpenSSL::HMAC.digest(DIGEST, aws_secret_access_key, request_description)).strip
      puts "Generated: #{res}"
      res
    end
    
    def canonical_request_description(method, path, headers = {}, expires = nil)
      s3_attributes = {}
      headers.each do |key, value|
        key = key.downcase
        s3_attributes[key] = value.to_s.strip if key.match(/^#{AMAZON_HEADER_PREFIX}|^content-md5$|^content-type$|^date$/o)
      end
      s3_attributes['content-type'] ||= ''
      s3_attributes['content-md5']  ||= ''
      s3_attributes['date'] = '' if s3_attributes.has_key?('x-amz-date')
      s3_attributes['date'] = expires if expires

        # prepare output string
      description = "#{method}\n"
      s3_attributes.sort { |a, b| a[0] <=> b[0] }.each do |key, value|
        description << (key[/^#{AMAZON_HEADER_PREFIX}/o] ? "#{key}:#{value}\n" : "#{value}\n")
      end
      
      # ignore all parameters by default
      description << path.gsub(/\?.*$/, '')
      
      # handle amazon parameters
      description << '?acl'      if path[/[&?]acl($|&|=)/]
      description << '?torrent'  if path[/[&?]torrent($|&|=)/]
      description << '?location' if path[/[&?]location($|&|=)/]
      description << '?logging'  if path[/[&?]logging($|&|=)/]
      description
    end
    
  end
end