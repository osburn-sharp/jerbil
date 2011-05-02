#
# == Jerbil Multi Client Interface
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
#

require 'jerbil/config'
require 'jeckyl/errors'
require 'jerbil/errors'
require 'jerbil/server'
require 'jerbil/service'
require 'socket'

module JerbilService

  # == Jerbil Multi Client Interface
  #
  # MultiClient provides a wrapper around a JerbilService::Base type service that hides
  # all interaction with Jerbil itself.
  #
  # It is similar to the Client Interace, but it allows interaction with all providers
  # of a service across the network.
  #
  #   MultiClient.each_service do |service|
  #     service.connect do |session|
  #       session.call_method
  #     end
  #   end
  #
  class MultiClient

    # create a multiclient object to access a service over Jerbil
    #
    # * modl - constant for the service Module
    # * client_options - hash of:
    #   :quiet - boolean, suppress messages on stdout (default: false)
    #   :local - boolean, find only the local service (default: false)
    #   :output - a file object (not filename) to be used for output - defaults to
    #   $stderr. Is overridden with /dev/null if quiet.
    #   :config_file - filename to config file that overides the default
    #
    # The block is called with the client so that within the block the user
    # can call methods on the remote object
    #
    # Services should be defined within the given Module and should have an inner
    # class called Service that is a descendent of JerbilService::Base
    #
    # module RubyTest
    #   class Service < JerbilService::Base
    #
    #   end
    # end
    #
    def initialize(modl, client_options={}, &block)

      # the class itself should be called Service within the given module
      @klass = modl.module_eval('Service')

      @name = modl.to_s
      @name_symbol = @name.downcase.to_sym

      @quiet = client_options[:quiet]
      unless @quiet
        @output = client_options[:output] || $stderr
      else
        @output = File.open('/dev/null', 'w')
      end

      @output.puts "Welcome to #{@name} (#{modl.ident}"

      @config_file = client_options[:config_file]
      @config = modl.get_config(@config_file)

      @env = @config[:environment]

      service_opts = {:name=>@name_symbol, :env=>@env}
      service_opts[:host] = Socket.gethostname if client_options[:local]

      begin
        # find jerbil
        @jerbil_server = Jerbil.get_local_server

        # now connect to it
        jerbil = @jerbil_server.connect

        # and get service
        @service = jerbil.get(service_opts)

        if @service.nil? then
          raise Jerbil::ServiceNotFound, "cannot find service through Jerbil"
        end
        
        @session = @service.connect

        block.call(self)

        @output.puts "Stopping the service"
        @output.close unless @output == $stderr
        #@service.stop


      rescue Jerbil::MissingServer
        @output.puts("Cannot find a local Jerbil server")
        raise
      rescue Jerbil::JerbilConfigError => err
        @output.puts("Error in Jerbil Config File: #{err.message}")
        raise
      rescue Jerbil::JerbilServiceError =>jerr
        @output.puts("Error with Jerbil Service: #{jerr.message}") 
        raise
      rescue Jerbil::ServerConnectError
        @output.puts("Error connecting to Jerbil Server") 
        raise
      rescue DRb::DRbConnError =>derr
        @output.puts("Error setting up DRb Server: #{derr.message}") 
        raise Jerbil::ServerConnectError
      end
    end

    # allow client to pass on methods to the remote service
    #
    def method_missing(symb, *parameters)

      # stop anyone from calling the stop method
      raise Jerbil::UnauthorizedMethod if symb == :stop_callback

      # make sure this is a valid method of the receiving instance
      # This is needed cos sending an unknown method over DRb with $SAFE = 1
      # raises a Security Error. Could catch this, but it might happen for
      # different reasons so best not to.
      raise NoMethodError unless @klass.instance_methods.include?(symb.to_s)

      retries = 0
      begin

        @session.send(symb, *parameters)

      rescue DRb::DRbConnError
        # service did not respond nicely
        @output.puts "Failed to connected to the service - checking its OK" 
        jerbil = @jerbil_server.connect
        if jerbil.service_missing?(@service) then
          # something nasty has occurred
          @output.puts "Jerbil confirms the service is missing - attempting to stop it"
          @service.stop
          @output.puts "Stopped the missing service"
          raise Jerbil::ServiceConnectError, "Service has been stopped"
        else
          # seems jerbil thinks its ok, so try again
          retries += 1
          @output.puts "Jerbil thinks the service is OK, retrying"
          retry unless retries > 2
          @output.puts "Retried too many times, giving up"
          raise Jerbil::ServiceConnectError, "Service is not responding"
        end
      end
    end

  end
end