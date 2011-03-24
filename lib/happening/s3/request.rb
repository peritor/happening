module Happening
  module S3
    class Request
      
      VALID_HTTP_METHODS = [:head, :get, :put, :delete]
      
      attr_accessor :http_method, :url, :options, :response
      
      def initialize(http_method, url, options = {})
        @options = {
          :timeout => 10,
          :retry_count => 4,
          :headers => {},
          :on_error => nil,
          :on_success => nil,
          :data => nil,
          :ssl => {
            :cert_chain_file => nil,
            :verify_peer => false
          }
        }.update(options)
        options.assert_valid_keys(:timeout, :on_success, :on_error, :retry_count, :headers, :data, :ssl)
        @http_method = http_method
        @url = url
        
        validate
      end
      
      def execute
        Happening::Log.debug "Request: #{http_method.to_s.upcase} #{url}"
        @response = http_class.new(url).send(http_method, :timeout => options[:timeout], :head => options[:headers], :body => options[:data], :ssl => options[:ssl])

        @response.errback { error_callback }
        @response.callback { success_callback }
        nil
      end
      
      def http_class
        EventMachine::HttpRequest
      end
      
    protected
    
      def validate
        raise ArgumentError, "#{http_method} is not a valid HTTP method that #{self.class.name} understands." unless VALID_HTTP_METHODS.include?(http_method)
      end
      
      def error_callback
        Happening::Log.error "Response error: #{http_method.to_s.upcase} #{url}: #{response.response_header.status rescue ''}"
        if should_retry?
          Happening::Log.info "#{http_method.to_s.upcase} #{url}: retrying after error: status #{response.response_header.status rescue ''}"
          handle_retry
        elsif options[:on_error].respond_to?(:call)
          call_user_error_handler
        else
          raise Happening::Error.new("#{http_method.to_s.upcase} #{url}: Failed reponse! Status code was #{response.response_header.status rescue ''}")
        end
      end
      
      def success_callback
        Happening::Log.debug "Response success: #{http_method.to_s.upcase} #{url}: #{response.response_header.status rescue ''}"
        case response.response_header.status
        when 0, 400, 401, 404, 403, 409, 411, 412, 416, 500, 503
          if should_retry?
            Happening::Log.info "#{http_method.to_s.upcase} #{url}: retrying after: status #{response.response_header.status rescue ''}"
            handle_retry
          else
            Happening::Log.error "#{http_method.to_s.upcase} #{url}: Re-tried too often - giving up"
            error_callback
          end
        when 300, 301, 303, 304, 307
          Happening::Log.info "#{http_method.to_s.upcase} #{url}: being redirected_to: #{response.response_header['LOCATION'] rescue ''}"
          handle_redirect
        else
          call_user_success_handler
        end
      end
      
      def call_user_success_handler
        options[:on_success].call(response) if options[:on_success].respond_to?(:call)
      end
      
      def call_user_error_handler
        options[:on_error].call(response) if options[:on_error].respond_to?(:call)
      end
      
      def should_retry?
        options[:retry_count] > 0
      end
      
      def handle_retry
        if should_retry?
          new_request = self.class.new(http_method, url, options.update(:retry_count => options[:retry_count] - 1 ))
          new_request.execute
        else
          Happening::Log.error "#{http_method.to_s.upcase} #{url}: Re-tried too often - giving up"
        end
      end
      
      def handle_redirect
        new_location = response.response_header['LOCATION'] rescue ''
        raise "Could not find the location to redirect to, empty location header?" if new_location.blank?

        new_request = self.class.new(http_method, new_location, options)
        new_request.execute
      end
    
    end
  end
end
