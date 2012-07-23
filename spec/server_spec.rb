#
# Description
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2010 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
# 
# 

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'jerbil/servers'
require 'jerbil/errors'
require 'socket'

key_file = File.expand_path(File.dirname(__FILE__) + '/../test/private_key_file.asc')
my_key = File.readlines(key_file).join('')
conf_file = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil_local.rb')

describe "Jerbil Server Record" do

  before(:all) do
    @hostname = Socket.gethostname
    @jport = Socket.getservbyname('jerbil') + 2
    @pkey = "ABCDEFG"
    @my_conf = Jerbil::Config.new(conf_file)
    #puts my_conf.inspect
    @my_session = Jerbil::Broker.new(@my_conf, @pkey)
    
    @my_server = Jerbil::Servers.get_local_server(@my_conf[:environment])
    DRb.start_service(@my_server.drb_address, @my_session)
  end
  
  after(:all) do
    #@my_session.stop(@pkey) should be stopped anyway
  end

  it "should create a server object" do
    @my_server.fqdn.should == Socket.gethostname
    @my_server.ident.should == "#{@hostname}[:#{@my_conf[:environment]}]"
  end

  it "should connect to its server (WHEN ACTIVE)" do
    jserver = @my_server.connect
    jserver.verify.should be_true
  end

  it "should fail to stop the server with the wrong key" do
    jserver = @my_server.connect
    lambda{jserver.stop('123456')}.should raise_error(Jerbil::InvalidPrivateKey)
  end

  it "should stop the server with the correct key" do
    jserver = @my_server.connect
    lambda{jserver.stop(@pkey)}.should_not raise_error
    #lambda{jserver.verify}.should raise_error
  end

  
  it "should find all running servers on the system" do
    servers = Jerbil::Servers.find_servers(@my_conf[:environment], @my_conf[:net_address], @my_conf[:net_mask])
    servers.each {|s| puts s.fqdn}
  end

end