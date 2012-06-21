module Happening
  module S3
    class Request
      include Utils
      
      VALID_HTTP_METHODS = [:head, :get, :put, :delete]

      DELEGATED_METHODS = [ :stream, :headers, :response, :response_header, :on_body_data ]
      
      attr_accessor :http_method, :url, :options, :request, :item

      def initialize(http_method, url, options = {})
        @item = options.delete(:item)
        @options = {
          :timeout => 10,
          :retry_count => 4,
          :headers => {},
          :on_error => nil,
          :on_success => nil,
          :on_retry => nil,
          :data => nil,
          :file => nil,
          :ssl => {
            :cert_chain_file => nil,
            :verify_peer => false
          }
        }.update(options)
        assert_valid_keys(options, :timeout, :on_success, :on_error, :on_retry, :retry_count, :headers, :data, :file, :ssl)
        @http_method = http_method
        @url = url
        
        validate
      end
      
      def execute
        Happening::Log.debug "Request: #{http_method.to_s.upcase} #{url}"

        request_options = {
          :timeout => options[:timeout],
          :ssl => options[:ssl]
        }
        request_options.update(:head => options[:headers]) unless options[:headers].empty?
        request_options.update(:body => options[:data]) unless options[:data].nil?
        request_options.update(:file => options[:file]) unless options[:file].nil?
        @request = http_class.new(url).send(http_method, request_options)

        @request.errback { error_callback }
        @request.callback { success_callback }
        self
      end
      
      def http_class
        EventMachine::HttpRequest
      end

      def on_success &blk
        options[:on_success] = blk
      end

      def on_error &blk
        options[:on_error] = blk
      end

      def on_retry &blk
        options[:on_retry] = blk
      end
      
      ##
      # Handle delegation to em-http-request
      ##
      def methods
        super + DELEGATED_METHODS
      end

      def respond_to? id
        super or DELEGATED_METHODS.include?(id)
      end
      
      def method_missing id, *args, &block
        if DELEGATED_METHODS.include?(id)
          if @request.nil?
            nil
          else
            @request.send(id, *args, &block)
          end
        else
          super
        end
      end
      
    protected
    
      def validate
        raise ArgumentError, "#{http_method} is not a valid HTTP method that #{self.class.name} understands." unless VALID_HTTP_METHODS.include?(http_method)
      end
      
      def error_callback
        Happening::Log.error "Response error: #{http_method.to_s.upcase} #{url}: #{response_header.status rescue ''}"
        if should_retry?
          Happening::Log.info "#{http_method.to_s.upcase} #{url}: retrying after error: status #{response_header.status rescue ''}"
          handle_retry
        elsif options[:on_error].respond_to?(:call)
          call_user_error_handler
        else
          raise Happening::Error.new("#{http_method.to_s.upcase} #{url}: Failed reponse! Status code was #{response_header.status rescue ''}")
        end
      end
      
      def success_callback
        Happening::Log.debug "Response success: #{http_method.to_s.upcase} #{url}: #{response_header.status rescue ''}"
        case response_header.status
        when 0, 400, 401, 404, 403, 409, 411, 412, 416, 500, 503
          if should_retry?
            Happening::Log.info "#{http_method.to_s.upcase} #{url}: retrying after: status #{response_header.status rescue ''}"
            handle_retry
          else
            Happening::Log.error "#{http_method.to_s.upcase} #{url}: Re-tried too often - giving up"
            error_callback
          end
        when 300, 301, 303, 304, 307
          Happening::Log.info "#{http_method.to_s.upcase} #{url}: being redirected_to: #{response_header['LOCATION'] rescue ''}"
          handle_redirect
        else
          call_user_success_handler
        end
      end
      
      def call_user_success_handler
        options[:on_success].call(self) if options[:on_success].respond_to?(:call)
      end
      
      def call_user_error_handler
        options[:on_error].call(self) if options[:on_error].respond_to?(:call)
      end
      
      def call_user_retry_handler
        options[:on_retry].call(self) if options[:on_retry].respond_to?(:call)
      end
      
      def should_retry?
        options[:retry_count] > 0
      end
      
      def handle_retry
        if should_retry?
          call_user_retry_handler
          new_request = self.class.new(http_method, url, options.update(:retry_count => options[:retry_count] - 1 ))
          new_request.execute
        else
          Happening::Log.error "#{http_method.to_s.upcase} #{url}: Re-tried too often - giving up"
        end
      end
      
      def handle_redirect
        new_location = response_header['LOCATION'] rescue ''
        raise "Could not find the location to redirect to, empty location header?" if blank?(new_location)

        new_request = self.class.new(http_method, new_location, options)
        new_request.execute
      end
    
    end
  end
end
