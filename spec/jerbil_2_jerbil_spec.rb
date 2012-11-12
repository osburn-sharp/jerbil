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
require 'jerbil/service'
require 'jerbil'
require 'jellog'
require 'socket'
require 'syslog'
require 'drb'

config = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil.conf')
log_dir = File.expand_path(File.dirname(__FILE__) + '/../log')
key_file = File.expand_path(File.dirname(__FILE__) + '/../test/private_key_file.asc')

describe "Jerbil to Jerbil tests" do

  before(:all) do
    hostname = Socket.gethostname
    @options = Jerbil::Config.new(config)
    @options[:servers].each do |server|
      if server.fqdn == hostname then
        @remote_jerbil_server = server
      else
        @jerbil_server ||= server
      end
    end
    DRb.start_service
    Jellog::Logger.disable_syslog
    #@remote_jerbil_server = Jerbil::ServerRecord.new(hostname, 'ABCDE')
    #@jerbil_server = Jerbil::ServerRecord.new(hostname, @my_key)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    @b_service = Jerbil::ServiceRecord.new(:rubytest, :prod)
    @remote_jerbil = @remote_jerbil_server.connect
    @remote_jerbil.register(@a_service)
    @remote_jerbil.register(@b_service)
    @jerbil_key = "djrtuefgf"
    @ant_fqdn = 'antonia.osburn-sharp.ath.cx'
  end

  after(:all) do
    @remote_jerbil.remove(@a_service)
    @remote_jerbil.remove(@b_service)
  end

  it "should be easy to configure a live server" do
    @remote_jerbil.services.should == 2
  end

  it "should be possible to start another server" do
    servers = [@jerbil_server, @remote_jerbil_server]
    my_options = {:log_dir=>log_dir, :log_level=>:debug, :key_file=>key_file}
    jerbil = Jerbil::Broker.new(@jerbil_server, servers, my_options, @jerbil_key)
    jerbil.verify.should be_true
    jerbil.find({}).length.should == 2
    aservice = jerbil.get({:name=>:rubytest, :env=>:test}, true)
    aservice.should == @a_service
  end

  it "should be possible to add a service to the local server and see it remotely" do
    servers = [@jerbil_server, @remote_jerbil_server]
    my_options = {:log_dir=>log_dir, :log_level=>:debug, :key_file=>key_file}
    Socket.stub(:gethostname).and_return(@ant_fqdn)
    jerbil = Jerbil::Broker.new(@jerbil_server, servers, my_options, @jerbil_key)
    jerbil.verify.should be_true
    another_service = Jerbil::ServiceRecord.new(:numbat, :dev)
    jerbil.register(another_service)
    Socket.unstub(:gethostname)
    aservice = @remote_jerbil.get({:name=>:numbat}, true)
    aservice.should == another_service
    jerbil.remove(another_service)
    @remote_jerbil.find({}).length.should == 2
  end

end
