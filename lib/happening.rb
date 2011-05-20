require 'rubygems'
require 'em-http'
require 'openssl'
require 'logger'

require File.dirname(__FILE__) + '/happening/utils'
require File.dirname(__FILE__) + '/happening/log'
require File.dirname(__FILE__) + '/happening/aws'
require File.dirname(__FILE__) + '/happening/s3'
require File.dirname(__FILE__) + '/happening/s3/request'
require File.dirname(__FILE__) + '/happening/s3/item'

module Happening
  class Error < RuntimeError
  end
end
