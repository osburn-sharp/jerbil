#
# == Jerbil Client Interface
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

  # == Jerbil Client Interface
  #
  # Client provides a wrapper around a JerbilService::Base type service that hides
  # all interaction with Jerbil itself.
  #
  # To use, create an instance and then call the methods of the service.
  #
  class Client

    private_class_method :new

    # Connect to a single service using Jerbil
    #
    # * modl - constant for the service module
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
    # The connection to the service is closed at the end of the block
    #
    def self.connect(modl, client_options={}, &block)

      # the class itself should be called Service within the given module
      klass = modl.module_eval('Service')

      name = modl.to_s
      name_symbol = name.downcase.to_sym

      quiet = client_options[:quiet]
      unless quiet
        output = client_options[:output] || $stderr
      else
        output = File.open('/dev/null', 'w')
      end

      output.puts "Welcome to #{name} (#{modl.ident}"

      config_file = client_options[:config_file]
      config = modl.get_config(config_file)

      env = config[:environment]

      service_opts = {:name=>name_symbol, :env=>env}
      service_opts[:host] = Socket.gethostname if client_options[:local]

      begin
        # find jerbil
        jerbil_server = Jerbil.get_local_server

        # now connect to it
        jerbil = jerbil_server.connect

        # and get service
        servicerecord = jerbil.get(service_opts)

        if servicerecord.nil? then
          raise Jerbil::ServiceNotFound, "cannot find service through Jerbil"
        end
        
        this_client = new(servicerecord, jerbil, output, klass)

        this_client.connect(&block)

        output.puts "Stopping the service"
        #output.close unless @output == $stderr

        return nil # give the caller nothing back

      rescue Jerbil::MissingServer
        output.puts("Cannot find a local Jerbil server")
        raise
      rescue Jerbil::JerbilConfigError => err
        output.puts("Error in Jerbil Config File: #{err.message}")
        raise
      rescue Jerbil::JerbilServiceError =>jerr
        output.puts("Error with Jerbil Service: #{jerr.message}") 
        raise
      rescue Jerbil::ServerConnectError
        output.puts("Error connecting to Jerbil Server") 
        raise
      rescue DRb::DRbConnError =>derr
        output.puts("Error setting up DRb Server: #{derr.message}") 
        raise Jerbil::ServerConnectError
      end
    end

    # Connect to multiple services
    def Client.each_service(modl, client_options, &block)
      # the class itself should be called Service within the given module
      klass = modl.module_eval('Service')

      name = modl.to_s
      name_symbol = name.downcase.to_sym

      quiet = client_options[:quiet]
      unless quiet
        output = client_options[:output] || $stderr
      else
        output = File.open('/dev/null', 'w')
      end

      output.puts "Welcome to #{name} (#{modl.ident}"

      config_file = client_options[:config_file]
      config = modl.get_config(config_file)

      env = config[:environment]

      service_opts = {:name=>name_symbol, :env=>env}
      service_opts[:host] = Socket.gethostname if client_options[:local]

      begin
        # find jerbil
        jerbil_server = Jerbil.get_local_server

        # now connect to it
        jerbil = jerbil_server.connect

        # and find all of the services
        services = []
        services = jerbil.find(service_opts)

        if services.length == 0 then
          raise Jerbil::ServiceNotFound, "cannot find any services through Jerbil"
        end

        services.each do |service_record|
          this_client = new(service_record, jerbil, output, klass)

          block.call(this_client)
          
        end

        output.puts "Stopping the service"
        #output.close unless @output == $stderr

        return nil # give the caller nothing back

      rescue Jerbil::MissingServer
        output.puts("Cannot find a local Jerbil server")
        raise
      rescue Jerbil::JerbilConfigError => err
        output.puts("Error in Jerbil Config File: #{err.message}")
        raise
      rescue Jerbil::JerbilServiceError =>jerr
        output.puts("Error with Jerbil Service: #{jerr.message}")
        raise
      rescue Jerbil::ServerConnectError
        output.puts("Error connecting to Jerbil Server")
        raise
      rescue DRb::DRbConnError =>derr
        output.puts("Error setting up DRb Server: #{derr.message}")
        raise Jerbil::ServerConnectError
      end

    end

    # create a client instance
    def initialize(service, jerbil, output, klass)

      @service = service
      @jerbil_server = jerbil
      @output = output
      @klass = klass
      @session = nil

    end

    #private

    # connect to the client
    def connect(&block)
      @session = @service.connect

      block.call(self)

      @session = nil
      #@service.close

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
          @output.puts "Jerbil confirms the service is missing"
          raise Jerbil::ServiceConnectError, "Service is missing"
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