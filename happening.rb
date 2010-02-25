require 'rubygems'
require 'em-http'
require 'right_aws'
require 'active_support'

require File.dirname(__FILE__) + '/lib/aws'
require File.dirname(__FILE__) + '/lib/s3/item'

# 
# EventMachine.run do
#   
#   3.times do |i|
#     puts "scheduling #{i}"
#     on_success = Proc.new do |http|
#       puts "#{i} SUCCESS!"
#       #puts http.response_header.status
#       #puts http.response_header
#       #puts http.response
#     end
#   
#     on_error = Proc.new do |http|
#       puts "#{i} ERROR!"
#     end
#   
#     item = EventS3::Item.new(i, :server => 'heise.de', :bucket => 'newsticker', :on_success => on_success, :on_error => on_error)
#   
#     item.get
#   end
# end

