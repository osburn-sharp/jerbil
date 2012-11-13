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
require 'jerbil/service'
require 'jerbil/config'
require 'jerbil'

require 'socket'
require 'syslog'
require 'drb'
require 'jellog'
#require 'rspec/mocks/standalone'


config = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil_local.rb')

describe "Missing Services" do
  before(:all) do
    @config = Jerbil::Config.new(config)
    @env = @config[:environment]
    #@local = Jerbil::ServerRecord.get_local_server(@servers, @env)
    @pkey = '123456'
    @secret = @config[:secret]
    @env = @config[:environment]
    @calling_key = 'JKLMNOP'
    @calling_server = Jerbil::Servers.new('germanicus.osburn-sharp.ath.cx', @calling_key, :dev, 49902)

    #@mock_server = double('broker')

    @jerbs = Jerbil::Broker.new(@config, @pkey)
    @germs_fqdn = 'germanicus.osburn-sharp.ath.cx'
    #@germs = Jerbil::Servers.get_server(@servers, @germs_fqdn, @env)
    @ant_fqdn = 'antonia.osburn-sharp.ath.cx'
    #@ant = Jerbil::Servers.get_server(@servers, @ant_fqdn, @env)
    #@calling_key = @local.key

    #Syslog.stub(:info).and_return(true)
    Jellog::Logger.disable_syslog
    
  end
  
  before(:each) do
    
    @my_service = Jerbil::ServiceRecord.new(:rubytest, :dev)
    Socket.stub(:gethostname).and_return(@germs_fqdn)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    Socket.stub(:gethostname).and_return(@ant_fqdn)
    @b_service = Jerbil::ServiceRecord.new(:rubytest, :prod)
    Socket.unstub(:gethostname)

    @jerbs.register(@my_service)
    rkey = @jerbs.register_server(@calling_server, @secret, @env)
    @jerbs.register_remote(rkey, @a_service)
    @jerbs.register_remote(rkey, @b_service)
  end
  
  after(:all) do
    @jerbs.stop(@pkey)
  end


  it "should be possible to remove a local missing service" do
    
    @my_service.should_receive(:connect).once.and_raise(ArgumentError)
    @jerbs.service_missing?(@my_service).should be_true
  end

  it "should be possible to remove a valid remote missing service" do
    mock_server = double('broker')
    DRbObject.stub(:new).and_return(mock_server)
    mock_server.should_receive(:service_missing?).once.and_return(true)
    @jerbs.service_missing?(@a_service).should be_true
  end

  # not sure what this is about? You can remove a missing service without
  # the server.
  it "should not possible to remove a missing service without the server" do
    #@germs.should_receive(:connect).and_return(@mock_server)
    #@ant.unstub(:connect)
    #@ant.should_receive(:connect).and_return(false)
    #@mock_server.should_receive(:remove_remote).once.and_return(true)
    @jerbs.service_missing?(@b_service).should be_false
  end

end
