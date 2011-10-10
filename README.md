Amazon S3 Ruby library that leverages [EventMachine](http://rubyeventmachine.com/) and [em-http-request](http://github.com/igrigorik/em-http-request).

By using EventMachine Happening does not block on S3 downloads/uploads thus allowing for a higher concurrency.

Happening was developed by [Peritor](http://www.peritor.com) for usage inside Nanite/EventMachine. 
Alternatives like RightAws block during the HTTP calls thus blocking the Nanite-Agent.

For now it only supports GET, PUT and DELETE operations on S3 items. The PUT operations support S3 ACLs/permissions.
Happening will handle redirects and retries on errors by default.

Installation
============

    gem install happening

Usage
=============

    require 'happening'
    
    EM.run do
      item = Happening::S3::Item.new('bucket', 'item_id')
      item.get # non-authenticated download, works only for public-read content
    
      item = Happening::S3::Item.new('bucket', 'item_id', :aws_access_key_id => 'Your-ID', :aws_secret_access_key => 'secret')
      item.get # authenticated download
      
      item.put("The new content")
      
      item.delete
    end

The above examples are a bit useless, as you never get any content back. 
You need to specify a callback that interacts with the http response.

## Callbacks

* `#on_success` - invoked when request was successful
* `#on_retry` - invoked when retry started
* `#on_error` - invoked when error response received (handles retries)
* `#stream` - delegated to em-http-request for streaming `GET` requests
* `#headers` - delegated to em-http-request when headers received

The way you provide callback handlers is up to you. You can provide
Procs with the options for each method `put`,`get`,`head` or `delete`,
which is very useful if you want to add an objects method as callback.
For example like this:

    EM.run do
      Happening::S3::Item('object-id').put(
        :file => '/my/big/file.mp4',
        :on_success => self.method(:upload_done))
    end

Or you could add them via blocks to the request object directly:

    EM.run do
      upload = Happening::S3::Item('object-id').put(:file => '/my/big/file.mp4')
      upload.on_success do |uploaded|
        puts "Upload successful!"
      end
      upload.on_error do |error|
        puts "Error uploading. Status: #{error.response_header.status}"
      end
    end

    
# AWS Credentials and Bucketname

When creating an item, you have to provide a bucket name.
Optionally you can 

    item = Happening::S3::Item.new('bucket', 'object-id',
      :aws_access_key_id => 'key',
      :aws_Secret_access_key => 'secret')
    
    item.get do |download|
      puts "Download succeeded."
    end

## Default Values

You can specify the credentials and bucket name application wide. That
way you don't have to mention it every time you'd like to touch an item.

    Happening::AWS.set_defaults(:bucket => 'bucket',
      :aws_access_key_id => 'key_id',
      :aws_secret_access_key => 'secret')

Then you can just provide the essential information      

    EM.run do
      Happening::S3::Item.new('object-id').get do |download|
        puts download.response_header.status
      end
    end

Nevertheless you can always override these settings providing them
directly when creating new `Happening::S3::Item` objects.

# Downloading Items

You can download items easily. 

    EM.run do
      item = Happening::S3::Item.new('item_id')
      item.get do |request|
        puts "the response content is: #{request.response}"; EM.stop
      end
    end

## Streaming

The response data can also be streamed:    
  
    EM.run do
      request = Happening::S3::Item.new('object-id').get
      request.stream do |chunk|
        # .. handle the individual chunk          
      end
    end

# Uploading Items

Happening supports the simple S3 PUT upload:    
  
    EM.run do
      upload = Happening::S3::Item.new('item_id').put(File.read('/etc/passwd'))
      upload.on_success do
        puts 'Upload successful!'; EM.stop
      end
      upload.on_error do |error|
        puts "Upload failed with: #{error.response_header.status}"; EM.stop 
      end
    end

## Setting Permissions

For setting the permissions when uploading, you can directly specify the `:permissions`
option, when creating the `item`.

Setting permissions on an already existing item looks like this:

    EM.run do
      request = Happening::S3::Item.new('item_id', :permissions => 'public-write').get
      request.on_success do |http|
        puts "Permissions set!"; EM.stop
      end
      request.on_error do |http|
        puts "Error setting permissions: #{http.response_header.status}"; EM.stop
      end
    end

## Setting Custom headers

    EM.run do
      item = Happening::S3::Item.new('item_id', :permissions => 'public-write')
      request = item.put(:headers => {
                 'Cache-Control' => "max-age=252460800", 
                 'Content-Type' => 'text/html', 
                 'Expires' => 'Fri, 16 Nov 2018 22:09:29 GMT', 
                 'x-amz-meta-abc' => 'ABC'
                })
      request.on_success do
        puts "Setting custom headers successful."; EM.stop
      end
      request.on_error do |error|
        puts "Error setting headers: #{error.response_header.status}"; EM.stop
      end
    end

## Streaming

If you have big files to upload `File.read` may block the reactor. So
it´s useful to upload chunkwise. Just give Happening the file path
instead of the data:

    EM.run do
      request = Happening::S3::Item.new('item_id').put(:file => '/srv/very_big_video.mp4')
      request.on_success do |response|
        puts "Upload finished!"; EM.stop 
      end
      request.on_error do |error|
        puts "Upload failed with: #{error.response_header.status}"; EM.stop
      end
    end 
    
# Deleting

Happening support the simple S3 PUT upload:    
  
    EM.run do
      request = Happening::S3::Item.new('item_id').delete
      request.on_success do |response|
        puts "Deleted!"; EM.stop
      end
      request.on_error do |response| 
        puts "An error occured: #{response.response_header.status}"; EM.stop 
      end
    end

Amazon returns no content on delete, so having a success handler is usually not needed for delete operations.

# Head

You can also just load the headers of an S3 item:
  
    EM.run do
      request = Happening::S3::Item.new('item_id').head
      request.on_success do |response|
        puts "Headers: #{response.inspect}"
        EM.stop
      end
      request.on_error do |response| 
        puts "An error occured: #{response.response_header.status}"; EM.stop
      end
    end
    
# SSL Support

Happening will use SSL/HTTPS by default. What it cannot do by default is verify the SSL certificate. This means 
that traffic is encrypted but nobody can say if the SSL-endpoint is the one you except. In order to verify the 
SSL certificate you need to provide Happening with the path to a certificate CA collection in PEM format:

    Happening::S3.ssl_options[:cert_chain_file] = '/etc/ca-bundle.crt'
    
You can also set this option on each item:

    Happening::S3::Item.new('bucket', 'item_id', 
      :aws_access_key_id => 'A', 
      :aws_secret_access_key => 'B',
      :ssl => {
        :cert_chain_file => '/etc/ca-bundle.crt'
      }
      
Or even on the request:

    item.get(:ssl => {:cert_chain_file => '/etc/ca-bundle.crt'})
    
The SSL options are directly passed to EventMachine, see the [EventMachine documentation](http://eventmachine.rubyforge.org/EventMachine/Connection.html#M000296) for more information on the SSL support.


# Credits

The AWS signing and canonical request description is based on [RightAws](http://github.com/rightscale/right_aws).
    
    
# License

Happening is licensed under the OpenBSD / two-clause BSD license, modeled after the ISC license. See LICENSE.txt

# About

Happening was written by [Jonathan Weiss](http://twitter.com/jweiss) for [Peritor](http://www.peritor.com).
