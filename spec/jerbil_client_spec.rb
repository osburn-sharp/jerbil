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
require File.expand_path(File.dirname(__FILE__) + '/../test/lib/ruby_test')
require File.expand_path(File.dirname(__FILE__) + '/../test/lib/ruby_test/config')
require 'jerbil/jerbil_service/client'
require 'jerbil/errors'
require 'socket'

config_file = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/ruby_test.rb')
jerbil_config = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil.conf')
log_filename = File.expand_path(File.dirname(__FILE__) + '/../log/client.log')
localhost = Socket.gethostname

describe "Test Jerbil Client Interface" do

  before(:all) do
    @client_opts = {:local=>true, :config_file=>config_file, :environment=>:dev, :quiet=>true, :jerbil_env=>:test}
  end

  it "should respond to the old connect method" do
    client_opts = {:local=>true, :config_file=>config_file, :quiet=>true, :jerbil_env=>:test}
    JerbilService::Client.connect(RubyTest, client_opts) do |rubytest|
      expect(rubytest.action).to eq('Hello')
      expect(rubytest.host).to eq(localhost)
    end
  end

  it "should respond to the new find_services method" do
    JerbilService::Client.find_services(:first, RubyTest, @client_opts) do |rubytest|
      expect(rubytest.action).to eq('Hello')
      expect(rubytest.host).to eq(localhost)
    end
  end

  it "should respond to the new find_services method with local service" do
    JerbilService::Client.find_services(:local, RubyTest, @client_opts) do |rubytest|
      expect(rubytest.action).to eq('Hello')
      expect(rubytest.host).to eq(localhost)
    end
  end

  it "should work with multiple client call" do
    JerbilService::Client.find_services(:all, RubyTest, @client_opts) do |rubytest|
      expect(rubytest.action).to eq('Hello')
    end
  end

  it "should work output welcome things with the welcome option" do

    log_file = File.open(log_filename, "w")
    options = @client_opts.dup
    options[:welcome] = true
    options[:output] = log_file
    options[:quiet] = false
    JerbilService::Client.find_services(:local, RubyTest, options) do |rubytest|
      expect(rubytest.action).to eq('Hello')
    end
    log_file.close
    log = File.readlines(log_filename)
    expect(log[0]).to match(/^Welcome/)
  end

  it "should not respond to an unknown method" do
    JerbilService::Client.find_services(:first, RubyTest, @client_opts) do |rubytest|
      expect {rubytest.unlikely_method}.to raise_error(NoMethodError)
    end
  end

  it "should not respond to an unknown search key" do
    expect {JerbilService::Client.find_services(:last, RubyTest, @client_opts)}.to raise_error(ArgumentError)
  end

  it "should not allow the stop_callback to be called" do
    JerbilService::Client.find_services(:first, RubyTest, @client_opts) do |rubytest|
      expect {rubytest.stop_callback}.to raise_error(Jerbil::UnauthorizedMethod)
    end
  end

end

describe "Jerbil Clients that do different things" do
  before(:all) do
    @client_opts = {:local=>true, :config_file=>config_file, :quiet=>true, :jerbil_env=>:test}
  end

  it "should not find an invalid service" do
    expect {JerbilService::Client.connect(Blabla)}.to raise_error(NameError)
  end

  it "should find a local service" do
    JerbilService::Client.connect(RubyTest, @client_opts) do |client|
      expect(client.action).to eq('Hello')
    end
  end

  it "should not find a local service if it thinks it is somewhere else" do
    allow(Socket).to receive_message_chain(:gethostname).and_return('germanicus.osburn-sharp.ath.cx', 'lucius.osburn-sharp.ath.cx')
    expect {JerbilService::Client.connect(RubyTest, @client_opts)}.to raise_error(Jerbil::ServiceNotFound)
  end

end