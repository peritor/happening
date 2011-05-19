require 'rake'
require 'rake/testtask'

task :default => [:test]

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = "test/**/*_test.rb"
  t.verbose = true
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
    s.files = FileList["[A-Z]*.*", "{lib}/**/*"]
    s.add_dependency('em-http-request')
    s.add_dependency('activesupport')
    s.add_dependency('i18n')
    s.add_development_dependency('jeweler')
    s.add_development_dependency('shoulda')
    s.add_development_dependency('mocha')
  end
rescue LoadError
  puts "Jeweler not available. Install it with: [sudo] gem install jeweler"
end

