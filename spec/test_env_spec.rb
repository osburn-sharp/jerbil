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

logdir = File.expand_path(File.dirname(__FILE__) + '/../log')

describe "This Environment" do

  it "should have a load path" do
    #puts $LOAD_PATH
    $LOAD_PATH.index('/usr/local/lib').should be_false
  end
  
  it "should have the most recent Jelly" do
    require 'jelly/version'
    Jelly::Version.should == "1.0.1"
    Jelly::Logger.respond_to?(:get_options).should be_true
  end
  
  it "should produce coloured logs" do
    logger = Jelly::Logger.new("tester", :logdir=>logdir)
    logger.info "This should be here"
  end
  
  it "should select log options from a hash" do
    opts = {:logdir=>'/tmp', :my_opts=>true}
    Jelly::Logger.get_options(opts).should == {:logdir=>'/tmp'}
  end

end
