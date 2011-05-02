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
require 'jerbil/server'
require 'jerbil/errors'
require 'socket'

key_file = File.expand_path(File.dirname(__FILE__) + '/../test/private_key_file.asc')
my_key = File.readlines(key_file).join('')

describe "Jerbil Server Record" do

  before(:all) do
    @hostname = Socket.gethostname
    @jport = Socket.getservbyname('jerbil') + 2
    @server = Jerbil::ServerRecord.new(@hostname, 'AB123CEDF', :dev)
  end

  it "should create a server object" do
    @server.fqdn.should == @hostname
    @server.drb_address.should == "druby://#{@hostname}:#{@jport.to_s}"
  end

  it "should connect to its server (WHEN ACTIVE)" do
    jserver = @server.connect
    jserver.verify.should be_true
  end

  it "should fail to stop the server with the wrong key" do
    jserver = @server.connect
    lambda{jserver.stop('123456')}.should raise_error(Jerbil::InvalidPrivateKey)
  end

  it "should stop the server with the correct key" do
    jserver = @server.connect
    lambda{jserver.stop(my_key)}.should raise_error
    #lambda{jserver.verify}.should raise_error
  end

  it "should find the local server from a whole bunch" do
    @a_server = Jerbil::ServerRecord.new('antonia', 'AB123CEDF', :dev)
    @b_server = Jerbil::ServerRecord.new('valeria', 'AB123CEDF', :dev)
    servers = [@a_server, @server, @b_server]
    Jerbil::ServerRecord.get_local_server(servers, :dev).should == @server
  end

end