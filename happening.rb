require 'rubygems'
require 'em-http'
require 'openssl'
require 'active_support'

require File.dirname(__FILE__) + '/lib/log'
require File.dirname(__FILE__) + '/lib/aws'
require File.dirname(__FILE__) + '/lib/s3/request'
require File.dirname(__FILE__) + '/lib/s3/item'

module Happening
  class Error < RuntimeError
  end
end
