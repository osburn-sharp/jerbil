#
#
# = Jerbil SService Utilities
#
# == Methods to assist setting up a Jerbil Service
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2012 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
#
# 
#

module JerbilService
  
  # misc. methods for Jerbil scripts
  module Utils

    # convert a filename etc to a proper class name
    # For example, converts 'my_service' to 'MyService'
    #
    # @param [String] string to convert to a classname
    # @return [String] converted classname
    def Utils.classify(string)
      string = string.sub(/^[a-z\d]*/) { $&.capitalize }
      string.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}" }.gsub('/', '::')
    end

  end
end
