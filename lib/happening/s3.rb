module Happening
  module S3

    def self.ssl_options
      @_ssl_options ||= {
        :cert_chain_file => nil,
        :verify_peer => false
      }
    end
  
    def self.ssl_options=(val)
      @_ssl_options = val
    end

  end
end
