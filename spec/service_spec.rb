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
require 'jerbil/service'
require 'socket'

describe "Service" do
  it "should create a new service record" do
    service = Jerbil::Service.new(:rubytest, :dev)
    service.name.should == :rubytest
    my_address = Socket::gethostname + ':' + Socket::getservbyname('rubytest').to_s
    service.address.should == my_address
    service.key.should_not be_nil
  end

  describe "Comparisons" do
    it "should match the service with all parameters" do
      a_service = Jerbil::Service.new(:rubytest, :dev)
      my_key = a_service.key
      a_service.matches?(:name=>:rubytest, :env=>:dev, :key=>my_key).should be_true
    end

    it "should match the serice with the same name" do
      a_service = Jerbil::Service.new(:rubytest, :dev)
      a_service.matches?(:name=>:rubytest).should be_true
    end

    it "should match the service with the same env" do
      a_service = Jerbil::Service.new(:rubytest, :dev)
      a_service.matches?(:env=>:dev).should be_true
    end

    it "should match if no arguments are given" do
      a_service = Jerbil::Service.new(:rubytest, :dev)
      a_service.matches?.should be_true
    end

    it "should not not match arguments that are different" do
      a_service = Jerbil::Service.new(:rubytest, :dev)
      a_service.matches?(:name=>:hoaxer, :env=>:dev).should be_false
    end

  end

  describe "Connections" do

    before do
      #@service = Jerbil::Service.new(:rubytest, :dev, :verify, :stop)
      #DRbObject.stub(:new).and_return {@service}
    end

    it "should fail to connect where there is no server" do
      @service = Jerbil::Service.new(:rubytest, :dev)
      lambda{@service.connect}.should raise_error(Jerbil::ServiceConnectError)
    end

  end

end
