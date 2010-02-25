require File.dirname(__FILE__) + '/../happening'

require 'benchmark'
require 'right_aws'

AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID'] or raise "please set AWS_ACCESS_KEY_ID='your-key'"
AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY'] or raise "please set AWS_SECRET_ACCESS_KEY='your-scret'"

BUCKET = 'happening-benchmark'
FILE   = 'the_file_name'
PROTOCOL = 'https'

COUNT = 100
CONTENT = File.read('/tmp/VzLinuxUG.pdf')

command = ARGV.first || 'get'

puts "running command: #{command}"

if command == 'get'
  Benchmark.bm(7) do |x|
    x.report("RightAWS - Get an item") do
      count = COUNT
      s3 = RightAws::S3Interface.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, :protocol => PROTOCOL)
      count.times do |i|
        s3.get_object(BUCKET, FILE)
        print '.'; $stdout.flush
      end
    end
  
    puts ""
    x.report("Happening - Get an item") do 
      puts ""
      count = COUNT
      on_success = Proc.new do |http|
        print '.'; $stdout.flush
        count = count - 1
        EM.stop if count <= 0
      end

      on_error = Proc.new do |http|
        puts "Status: #{http.response_header.status}"
        puts "Header: #{http.response_header.inspect}"
        puts "Content:"
        puts http.response.inspect + "\n"
        count = count - 1
        EM.stop if count <= 0
      end
    
      EM.run do
        count.times do |i|
          item = Happening::S3::Item.new(BUCKET, FILE, :protocol => PROTOCOL, :on_success => on_success, :on_error => on_error)
          item.get
        end
      end
    end  
  end

elsif command == 'put'
  Benchmark.bm(7) do |x|
    x.report("RightAWS - Put an item") do
      count = COUNT
      s3 = RightAws::S3Interface.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, :protocol => PROTOCOL)
      count.times do |i|
        s3.put(BUCKET, "upload_test_right_aws_#{i}", CONTENT)
        print '.'; $stdout.flush
      end
    end
  
    puts ""
    x.report("Happening - Put an item") do 
      puts ""
      count = COUNT
      on_success = Proc.new do |http|
        #puts "Success"
        puts "Status: #{http.response_header.status}" unless http.response_header.status == 200
        #puts "Header: #{http.response_header.inspect}"
        #puts "Content:"
        #puts http.response.inspect + "\n"
        print '.'; $stdout.flush
        count = count - 1
        EM.stop if count <= 0
      end

      on_error = Proc.new do |http|
        puts "Error"
        puts "Status: #{http.response_header.status}"
        puts "Header: #{http.response_header.inspect}"
        puts "Content:"
        puts http.response.inspect + "\n"
        count = count - 1
        EM.stop if count <= 0
      end
    
      EM.run do        
        count.times do |i|
          item = Happening::S3::Item.new(BUCKET, "upload_test_happening_#{i}", :protocol => PROTOCOL, :on_success => on_success, :on_error => on_error, :aws_access_key_id => AWS_ACCESS_KEY_ID, :aws_secret_access_key => AWS_SECRET_ACCESS_KEY)
          item.put(CONTENT)
        end
      end
    end  
  end

else
  puts "unknown command: #{command}"  
end
