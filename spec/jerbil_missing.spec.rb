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
require 'jerbil/config'
require 'jerbil'
require 'socket'
require 'syslog'
require 'drb'
require 'jelly'


config = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/missing_services')

describe "Missing Services" do
  before(:each) do
    @options = Jerbil::Config.new(config)
    @servers = @options.delete(:servers)
    @env = @options[:environment]
    @local = Jerbil::ServerRecord.get_local_server(@servers, @env)

    @mock_server = double('broker')
    @servers.each do |server|
      server.stub(:connect).and_return(@mock_server)
    end

    @jerbs = Jerbil::Broker.new(@local, @servers, @options, @env)
    @germs_fqdn = 'germanicus.osburn-sharp.ath.cx'
    @germs = Jerbil::ServerRecord.get_server(@servers, @germs_fqdn, @env)
    @ant_fqdn = 'antonia.osburn-sharp.ath.cx'
    @ant = Jerbil::ServerRecord.get_server(@servers, @ant_fqdn, @env)
    @calling_key = @local.key

    Syslog.stub(:info).and_return(true)
    
    @my_service = Jerbil::ServiceRecord.new(:rubytest, :dev)
    Socket.stub(:gethostname).and_return(@germs_fqdn)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    Socket.stub(:gethostname).and_return(@ant_fqdn)
    @b_service = Jerbil::ServiceRecord.new(:rubytest, :prod)
    Socket.unstub(:gethostname)

    @jerbs.register(@my_service)
    @jerbs.register_remote(@calling_key, @a_service)
    @jerbs.register_remote(@calling_key, @b_service)
  end

  it "should be possible to mock and stub server objects" do
    @germs.stub(:fqdn).and_return('germs')
    @germs.fqdn.should == 'germs'
    @germs.unstub(:fqdn)
    #@ant.should_receive(:connect).and_return(false)
    @mock_server.should_receive(:stop).and_return(true)
    my_mock = @ant.connect
    my_mock.stop.should be_true
  end

  it "should be possible to remove a local missing service" do

    @my_service.should_receive(:connect).once.and_raise(ArgumentError)
    @jerbs.service_missing?(@my_service).should be_true
  end

  it "should be possible to remove a valid remote missing service" do
    DRbObject.stub(:new).and_return(@mock_server)
    @mock_server.should_receive(:service_missing?).once.and_return(true)
    @jerbs.service_missing?(@a_service).should be_true
  end

  # not sure what this is about? You can remove a missing service without
  # the server.
  it "should not possible to remove a missing service without the server" do
    #@germs.should_receive(:connect).and_return(@mock_server)
    #@ant.unstub(:connect)
    #@ant.should_receive(:connect).and_return(false)
    #@mock_server.should_receive(:remove_remote).once.and_return(true)
    @jerbs.service_missing?(@b_service).should be_true
  end

end
