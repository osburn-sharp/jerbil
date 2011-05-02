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
require 'jerbil'
require 'jelly'
require 'socket'

Jelly.disable_syslog
config_dir = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/')
config_file = config_dir + '/jerbil.conf'

describe "Jerbil Support" do
  
  it "should return a server from the config file" do
    germ_fqdn = 'germanicus.osburn-sharp.ath.cx'
    config = Jerbil.get_config(config_file)
    germ = Jerbil.get_server(germ_fqdn, config)
    germ.fqdn.should == germ_fqdn
  end

  it "should return this server from the config file" do
    me = Socket.gethostname
    config = Jerbil.get_config(config_file)
    lucius = Jerbil.get_local_server(config)
    lucius.fqdn.should == me
  end

  it "should not find a server with the wrong env" do
    config = Jerbil.get_config(config_file)
    config[:environment] = :prod
    lambda{Jerbil.get_local_server(config)}.should raise_error(Jerbil::MissingServer)
  end

  it "should not find a server that is not there" do
    config = Jerbil.get_config(config_file)
    lambda{Jerbil.get_server('theimprobableone',config)}.should raise_error(Jerbil::MissingServer)
  end

  it "should not find a local server that is not there" do
    no_local_config = config_dir + '/jerbil_no_local.conf'
    config = Jerbil.get_config(no_local_config)
    lambda{Jerbil.get_server('theimprobableone',config)}.should raise_error(Jerbil::MissingServer)
  end

  it "should not like a missing config file" do
    lambda{Jerbil.get_config('config_file_is_missing')}.should raise_error(Jerbil::JerbilConfigError)
  end

  it "should default to the current system config" do
    me = Socket.gethostname
    lucius = Jerbil.get_local_server()
    lucius.fqdn.should == me

  end
  
end