require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
#require 'rspec/mocks/standalone'
require 'jerbil/server'
require 'jerbil/errors'
require 'socket'

key_file = File.expand_path(File.dirname(__FILE__) + '/../test/private_key_file.asc')
my_key = File.readlines(key_file).join('')

describe "Jerbil Server Record" do
  
  before(:all) do
  end
  
  it "should find all running servers on the system" do
    myserv = double("Jerbil::ServerRecord")
    Jerbil::ServerRecord.stub(:new).and_return(myserv)
    myserv.should_receive(:get_key).exactly(5).times.and_return(true)
    myserv.should_receive(:fqdn).and_return("germanicus.osburn-sharp.ath.cx", 
     "lucius.osburn-sharp.ath.cx", 
    "antonia.osburn-sharp.ath.cx", 
    "valeria.osburn-sharp.ath.cx", 
    "aurelius.osburn-sharp.ath.cx")
    servers = Jerbil::ServerRecord.find_servers(:prod, 0.1)
    servers.each {|s| puts s.fqdn}
  end

end