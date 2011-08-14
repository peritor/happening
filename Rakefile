require 'rake'
require 'rake/testtask'

task :default => [:test]

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = "test/**/*_test.rb"
  t.verbose = true
end

def source_version
  line = File.read("lib/#{name.gsub(/-/, "/")}.rb")[/^\s*VERSION\s*=\s*.*/]
  line.match(/.*VERSION\s*=\s*['"](.*)['"]/)[1]
end

def name
  'happening'
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "happening"
    s.summary = %Q{An EventMachine based S3 client }
    s.email = "info@peritor.com"
    s.homepage = "http://github.com/peritor/happening"
    s.description = "An EventMachine based S3 client - using em-http-request"
    s.authors = ["Jonathan Weiss"]
    s.files = FileList["[A-Z]*.*", "{lib}/**/*"] - ["Gemfile.lock"]
    s.add_dependency('em-http-request')
    s.add_development_dependency('jeweler')
    s.add_development_dependency('shoulda')
    s.add_development_dependency('mocha')
    s.version = source_version
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: [sudo] gem install jeweler"
end