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
require 'jerbil/chuser'
require 'jelly'
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
  # and sets up a Jelly logger
  #
  class Base
    
    # create a service object
    #
    # * name - symbol for the service needs to correspond with /etc/services
    # * env - any of :dev, :test, :prod to allow multiple services at once
    # * options - hash that should include:
    #   * log_dir - writeable directory into which jelly places logs
    #   * log_level - :system, :verbose, :debug (see Jelly)
    #   * log_rotation - number of log files to keep
    #   * log_length - size of log files (in bytes)
    #   * exit_on_stop - set to false to prevent the stop method invoking exit! For testing.
    #   * unsafe - set to true to prevent init from setting $SAFE > 0
    #   * user - set to the name of a user to switch to
    #   * environment - set to one of :dev, :test, :prod
    #
    # * pkey - string containing a private key that has to be provided when calling the
    #   stop_callback, and can optionally be required for all calls. Users can get the private
    #   key either from the Jerbil::ServiceRecord provided by Jerbil, or from the key file
    #
    # There is a Jeckyl::Service config class defined as a template that includes these options.
    #
    # Note that generally it is not necessary to call this method directly, but instead use the 
    # jerbil/jerbil_service/sclient interface to set up a service. This is also automated using
    # the jserviced script and init files. For example, to create a service call TestService, package as
    # a gem and publish, You can then create a symbolic link to the jserviced init script called 
    # test_service and a config file by the same name, and it should start the script automatically!
    #
    def initialize(name, pkey, options)
      @name = name.to_s.capitalize
      @env = options[:environment]
      @private_key = pkey
      
      # change the process name 
      $0 = "#{@name.downcase}-#{@env}"
      
      # can't start the logger yet so need to remember what happened
      #set_uid = Jerbil::Chuser.change(options[:user])

      # start up a logger
      log_opts = Jelly::Logger.get_options(options)
      @logger = Jelly::Logger.new(@name, log_opts)
      # @logger.log_level = options[:log_level]
      
      # now remember what happenned
      # if set_uid then
      #   @logger.system "Set UID to #{options[:user]}" if set_uid
      # elsif options[:user] then
      #   @logger.system "Failed to setuid for #{options[:user]}"
      # else
      #   @logger.system "Remaining with existing user"
      # end

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

    # give access to Jerbil Service Record
    # WHY?
    attr_reader :service

    # return the DRb address for the service
    def drb_address
      @service.drb_address
    end

    # this is used by callers just to check that the service is running
    # if caller is unaware of the key, this will fail
    def verify_callback(key="")
      check_key(key)
      return true
    end

    # used to stop the service
    def stop_callback(pkey="")
      raise Jerbil::InvalidServiceKey if pkey != @private_key
      # deregister
      jerbil = @jerbil_server.connect
      jerbil.remove(@service)
      @logger.system "Stopped service: #{@service.ident}"
      @logger.close
      # and stop the DRb service, to exit gracefully
      DRb.stop_service
    end

    # wait for calls
    def wait(pkey='')
      raise Jerbil::InvalidServiceKey if pkey != @private_key
      DRb.thread.join
    end

  private

    def check_key(key)
      if key != @service.key then
        @logger.error("Call made with Invalid Service Key: #{key}")
        raise Jerbil::InvalidServiceKey
      end
    end

  end
end