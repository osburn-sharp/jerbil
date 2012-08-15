#
# Template for Jerbil Service Config
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2011 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
#
# Use this template to create a service config file by adapting a copy of the jeckly_generate_config
# utility.
# 

require 'jerbil/jerbil_service/config'

module RubyTest
  
  class Config < JerbilService::Config

    def configure_jerbil_env(env)
      vals = [:prod, :test, :dev]
      a_member_of(env, vals)
    end
    

    def configure_exit_on_stop(bool)
      default true
      comment "Boolean - set to false to prevent service from executing exit! on stop"

      a_boolean(bool)
    end
    
    def configure_key_dir(path)
      comment "private key dir used to authenticate privileged users"

      a_writable_dir(path)
    end

    def configure_pid_dir(path)
      comment "directory used to store the daemons pid to assist in stopping reluctant servers"

      a_writable_dir(path)
    end
    
    def configure_jerbil_config(path)
      comment "jerbil config location"
      a_readable_file(path)
    end


  end

end
