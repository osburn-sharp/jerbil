$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.delete('/usr/local/lib')
require 'jerbil'
require 'rspec'

RSpec.configure do |config|
  config.color = true
  config.formatter = :doc
  
end

puts "Running under Ruby #{RUBY_VERSION}"
