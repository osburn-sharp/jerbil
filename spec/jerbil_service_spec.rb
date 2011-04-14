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
require 'jerbil/jerbil_service_class'
require File.expand_path(File.dirname(__FILE__) + '/../test/test_service')
require 'socket'

describe "Test Class" do

  before(:all) do
    #DRb.stub(:start_service).and_return {true}
    @service = TestService.new
    @my_service = @service.my_service
    puts @my_service.key
    #DRbObject.stub(:new).and_return {@service}
  end


  it "should start OK" do
    my_address = Socket::gethostname + ':' + Socket::getservbyname('rubytest').to_s
    @my_service.address.should == my_address
    service = @my_service.connect
    service.action.should == "Hello"
  end

  it "should stop OK" do
    @service.stub(:stop_callback).and_return {@service = nil}
    @my_service.stop(false)
    @service.should be_nil
  end

end