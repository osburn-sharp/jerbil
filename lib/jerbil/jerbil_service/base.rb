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
require 'jerbil/service'
require 'jerbil/servers'
require 'jerbil/errors'
require 'jerbil/config'
require 'jerbil/support'
require 'jellog'
require 'jellog/config'
require 'socket'
require 'drb'

# == Jerbil Service
#
# Designed to help create ruby services easily, hiding all of the interactions with
# Jerbil itself.
#
# To create a service, create a service module (e.g. RubyTest) and within that a
# service class (e.g. RubyTest::Service) that whose parent is JerbilService::Base
# You can add a config file by copying the jerbil_service/config template and changing
# the module to your module (e.g. RubyTest::Config). Finally, use the jerbil_service/support
# module to extend your base module to include the get_config method.
#
#   module RubyTest
#
#     extend JerbilService::Support
#
#     class Service < JerbilService::Base
#
#       def initialize(pkey, options)
#
#         super(:rubytest, pkey, options)
#
#       end
#     end
#   end
#
# See also the Client, MultiClient and SuperClient classes to assist with a complete solution.
#
#
module JerbilService

  # == JerbilService::Base
  #
  # Parent class to be used for all services. Manages all interactions with Jerbil
  # and sets up a Jellog logger.
  #
  # In general, services using this class are intended to be started and stopped
  # using {JerbilService::Supervisor} and clients are expected to interact with the
  # service through {JerbilService::Client}.
  #
  # Further details can be found in {file:README_SERVICES.md Jerbil Service Readme}
  #
  class Base
    
    # create a Jerbil Service
    #
    # @param [String] name - symbol for the service needs to correspond with /etc/services
    # @param [String] pkey - private key used for privileged methods
    # @param [Hash] options for the service. The easiest way to generate this hash is to use
    #   Jeckyl and inherit the {JerbilService::Config} class. See class description for details of
    #   the options required by a service
    def initialize(name, pkey, options)
      @name = name.to_s.capitalize
      @env = options[:environment]
      @private_key = pkey
      
      # change the process name 
      $0 = "#{@name.downcase}-#{@env}"
      
      # start up a logger
      log_opts = Jellog::Config.intersection(options)
      @logger = Jellog::Logger.new(@name, log_opts)
      # @logger.log_level = options[:log_level]
      
      @exit = options[:exit_on_stop]

      begin
        @service = Jerbil::ServiceRecord.new(name, @env, :verify_callback, :stop_callback)

        # register the service
        # Note that if the options hash includes a :jerbil_env, then this
        # will be passed to select a Jerbil system running at other than :prod, the default
        # This is not documented above because it is for testing Jerbil only
        @jerbil_server = Jerbil::Servers.get_local_server(options[:jerbil_env])

        # now connect to it
        jerbil = @jerbil_server.connect

        # and register self
        jerbil.register(@service)

        # and start it - preventing anything nasty from coming over DRb
        $SAFE = 1 unless options[:unsafe]
        DRb.start_service(@service.drb_address, self)

      rescue Jerbil::MissingServer
        @logger.fatal("Cannot find a local Jerbil server")
        raise
      rescue Jerbil::JerbilConfigError => err
        @logger.fatal("Error in Jerbil Config File: #{err.message}")
        raise
      rescue Jerbil::JerbilServiceError =>jerr
        @logger.fatal("Error with Jerbil Service: #{jerr.message}")
        raise
      rescue Jerbil::ServerConnectError
        @logger.fatal("Error connecting to Jerbil Server")
        raise
      rescue DRb::DRbConnError =>derr
        @logger.fatal("Error setting up DRb Server: #{derr.message}")
        raise Jerbil::ServerConnectError
      end

      @logger.system "Started service: #{@service.ident}"
    end

    # give access to {Jerbil::ServiceRecord} Record for this service
    # @deprecated - unless I can find why I allowed it!
    attr_reader :service

    # return the DRb address for the service
    # @deprecated - as above
    def drb_address
      @service.drb_address
    end

    # this is used by callers just to check that the service is running
    # if caller is unaware of the key, this will fail
    #
    # @param [String] skey - private key given to the service when created
    #
    # This method is not intended to be called directly. It is usually
    # called when connecting to the service (see {Jerbil::ServiceRecord#connect}).
    #
    def verify_callback(skey="")
      check_key(skey, @service.key)
      @logger.info "Verify called"
      return true
    end

    # used to stop the service. Requires the private key
    #
    # @param [String] pkey - private key given when service is created
    #
    # This method is not intended to be called directly. To stop a service, the
    # user should use the {JerbilService::Supervisor} class.
    #
    def stop_callback(pkey="")
      check_key(pkey)
      # deregister
      jerbil = @jerbil_server.connect
      jerbil.remove(@service)
      @logger.system "Stopped service: #{@service.ident}"
      @logger.close
      # and stop the DRb service, to exit gracefully
      DRb.stop_service
    end

    # wait for calls. This hides the DRb call to be made once the
    # service is up and running. It is not intended to be called by
    # anyone outside of {JerbilService::Supervisor}
    #
    def wait(pkey='')
      check_key(pkey)
      DRb.thread.join
    end

  protected

    # convenience method to check that the given key is the object's private key
    # and raise {Jerbil::InvalidServiceKey} if not
    def check_key(key, my_key = @private_key)
      if key != my_key then
        @logger.debug "Key mismatch: given #{key} but need #{my_key}"
        raise Jerbil::InvalidServiceKey, @logger.error("Call made with Invalid Service Key: #{key}")
      end
    end

  end
end