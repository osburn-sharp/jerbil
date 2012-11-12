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
require 'jellog/config'
require 'jeckyl'

module JerbilService
  
  
  # configuration options for a Jerbil Service, which includes the Jellog logger and therefore
  # inherits Jellog's options first.
  #
  # @see file:lib/jerbil/jerbil_service/config.md Jerbil Service Parameter Descriptions
  #
  class Config < Jellog::Config

    def configure_environment(env)

      default :prod
      comment "Set the environment for the service to run in.",
        "",
        "Can be one of the following:",
        "  :prod - for productionised services in use across a network ",
        "  :test - for testing a release candidate, e.g. also across the network",
        "  :dev - for developing the next release",
        "",
        "Services can be running in all three environments at the same time. Clients",
        "will need to use the appropriate config file to connect with each environment."

      env_set = [:prod, :test, :dev]
      a_member_of(env, env_set)
      
    end

    def configure_key_dir(path)
      default '/var/run/jerbil'
      comment "a writable directory where Jerbil stores a private key for each service.",
        "This key is used to authenticate systems operations, such as stopping the service.",
        "It is not used for client interactions, which can require a separate service key."

      a_writable_dir(path)
    end

    def configure_pid_dir(path)
      default '/var/run/jerbil'
      comment "A writable directory used to store the pid to assist in stopping reluctant servers"

      a_writable_dir(path)
    end
        
    def configure_jerbil_env(env)
      comment "Set this only to use a Jerbil Server that is not running in the production environment"
      env_set = [:prod, :test, :dev]
      a_member_of(env, env_set)
      
    end

  end

end
