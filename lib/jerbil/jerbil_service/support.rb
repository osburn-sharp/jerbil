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


module JerbilService

  # Support methods that should be used to extend a service module
  #
  #   module RubyTest
  #     extend JerbilService::Support
  #
  #     class Service ...
  #
  #
  module Support

    # get the config settings for the given service module.
    #
    # This uses Jeckyl configuration and defaults to the conf file for the service module
    # in the location defined by Jeckyl::ConfigRoot.
    #
    # e.g. for RubyTest, it will default to /etc/jermine/rubytest.conf
    #
    # Provide a different filename to change this.
    #
    def get_config(config_file=nil)
      # check that the config_file has been specified
      if config_file.nil? then
        # no, so set the default
        config_file = Jeckyl::ConfigRoot + "/#{self.to_s.downcase}.rb"
      end

      # read the config file
      return self::Config.new(config_file)

    end

    # get the identity of this module, assuming this has been
    # set up and is maintained by Jevoom
    # Returns 'n/a' otherwise
    def ident
      return self::Ident
    rescue
      return 'n/a'
    end
  end
end
