require 'rubygems'
require 'em-http'
require 'openssl'
require 'logger'

unless defined?(Happening)
  $:<<(File.expand_path(File.dirname(__FILE__) + "/lib"))
  require File.expand_path(File.dirname(__FILE__) + '/happening/utils')
  require File.expand_path(File.dirname(__FILE__) + '/happening/log')
  require File.expand_path(File.dirname(__FILE__) + '/happening/aws')
  require File.expand_path(File.dirname(__FILE__) + '/happening/s3')
  require File.expand_path(File.dirname(__FILE__) + '/happening/s3/request')
  require File.expand_path(File.dirname(__FILE__) + '/happening/s3/item')
  require File.expand_path(File.dirname(__FILE__) + '/happening/s3/bucket')

  module Happening
    MAJOR = 0
    MINOR = 2
    PATCH = 5

    VERSION = [MAJOR, MINOR, PATCH].compact.join('.')
    class Error < RuntimeError; end
  end
end
