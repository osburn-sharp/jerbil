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
require 'jelly/config'

require 'jeckyl'

module JerbilService
  
  
  # configuration options for a Jerbil Service, which includes the Jelly logger and therefore
  # inherits Jelly's options first.
  #
  # @see file:lib/jerbil/jerbil_service/config.md Jerbil Parameter Descriptions
  #
  class Config < Jelly::Options

    def configure_environment(env)

      default :prod
      comment "Set the default environment for service commands etc.",
        "",
        "Can be one of :prod, :test, :dev"

      env_set = [:prod, :test, :dev]
      a_member_of(env, env_set)
      
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
    
    def configure_user(user)
      comment "the name of the valid system user to which a service should switch when being started"
      
      # needs a little testing?
      a_valid_user(user)
      
    end
    
    def configure_jerbil_env(env)
      comment "Set this only to use a Jerbil Server that is not running in the production environment"
      env_set = [:prod, :test, :dev]
      a_member_of(env, env_set)
      
    end
    
    
    # bespoke validator for users
    def a_valid_user(user)
      Etc.getpwnam(user).name
    rescue ArgumentError
      raise ConfigError, "User is not valid: #{user}"
    end


  end

end
