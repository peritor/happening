require 'rubygems'
require 'em-http'
require 'openssl'
require 'logger'

require 'active_support'
unless {}.respond_to?(:assert_valid_keys)
  require 'active_support/core_ext/hash/keys.rb'
end
unless {}.respond_to?(:blank?)
  require 'active_support/core_ext/object/blank.rb'
end

require File.dirname(__FILE__) + '/happening/log'
require File.dirname(__FILE__) + '/happening/aws'
require File.dirname(__FILE__) + '/happening/s3'
require File.dirname(__FILE__) + '/happening/s3/request'
require File.dirname(__FILE__) + '/happening/s3/item'

module Happening
  class Error < RuntimeError
  end
end
