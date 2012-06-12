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
require 'jerbil/jerbil_service/utils'


describe "utils" do
  
  it "should classify a string" do
    JerbilService::Utils.classify('robert_sharp').should == "RobertSharp"
    JerbilService::Utils.classify('robert/sharp').should == "Robert::Sharp"
  end
  
end
