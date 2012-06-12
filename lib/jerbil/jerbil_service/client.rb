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

    # return the server's config options for the given file, or the default if none given
    def self.get_config(modl, config_file=nil)
      modl.get_config(config_file)
    end

    # Connect to a single service using Jerbil
    #
    # * modl - constant for the service module
    # * client_options - hash of:
    #   :quiet - boolean, suppress messages on stdout (default: false)
    #   :local - boolean, find only the local service (default: false)
    #   :output - a file object or similar (not filename) to be used for output - defaults to
    #   $stderr. Is overridden with /dev/null if quiet.
    #   :welcome - boolean, output additional messages suitable for standalone operation
    #   :environment - symbol for environment from config-file (probably), defaults to :prod
    #
    # The block is called with the client so that within the block the user
    # can call methods on the remote object
    #
    # The connection to the service is closed at the end of the block
    #
    def self.find_services(what, modl, options={}, &block) # :yields: client

      case what
      when :first
        select = :first
      when :all
        select = :all
      when :local
        select = :first
        options[:local] = true
      else
        raise ArgumentError, "Find Services invalid search key: #{what}"
      end

      unless options[:environment]
        # set the default environment if not already set
        options[:environment] = :prod
      end

      new(modl, options) do |client|
        client.connect(select, &block)
      end
    end

    # backwards compatible method to connect to first service using environment
    # defined in config_file which is read in from options[:config_file] or the default
    # location (see get_config)
    #
    def self.connect(modl, options={}, &block) # :yields: client

      config_file = options[:config_file]
      config = modl.get_config(config_file)

      options[:environment] = config[:environment]

      self.find_services(:first, modl, options, &block)

    end


    #create a client instance and call the block. Should be used internally only
    def initialize(modl, options, &block)

      @klass = modl::Service
      name = modl.to_s
      name_symbol = name.downcase.to_sym

      quiet = options[:quiet]
      unless quiet
        @output = options[:output] || $stderr
      else
        @output = File.open('/dev/null', 'w')
      end

      @welcome = options[:welcome]

      @output.puts "Welcome to #{name} (#{modl.ident})" if @welcome

      env = options[:environment]

      service_opts = {:name=>name_symbol, :env=>env}
      service_opts[:host] = Socket.gethostname if options[:local]

      begin
        # find jerbil
        @jerbil_server = Jerbil::Servers.get_local_server(options[:jerbil_env])

        # now connect to it
        jerbil = @jerbil_server.connect

        # and find all of the services
        @services = []
        @services = jerbil.find(service_opts)

        if @services.length == 0 then
          @output.puts "No services for #{name}[:#{env}] were found"
          raise Jerbil::ServiceNotFound, "No services for #{name}[:#{env}] were found"
        end

        block.call(self)

        @output.puts "Stopping the service" if @welcome
        #output.close unless @output == $stderr

        return nil # give the caller nothing back

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

    #private

    # connect to the client
    def connect(index=:all, &block)

      if index == :first then
        @session = @services[0].connect
        @service = @services[0]
        block.call(self)

        @session = nil
      else
        @services.each do |service|
          @service = service
          @session = service.connect
          block.call(self)
        end
      end

    end

    # verify that the service is working - having a @session is enough cos
    # calling @service.connect will already try verify_callback. This is a bit of a
    # no-op cos to call it OK you must already have connected and if it could ever
    # return false you wouldn't have got this far! Still, it gives mean to what
    # would otherwise be a meaningless empty block.
    #
    def verify
      @session != nil
    end


    # return the name of the host on which the service is running
    def host
      return @service.host
    end

    def service_key
      return @service.key
    end

    #:nodoc: allow client to pass on methods to the remote service
    #
    def method_missing(symb, *parameters)

      # stop anyone from calling the stop method
      raise Jerbil::UnauthorizedMethod if symb == :stop_callback

      # make sure this is a valid method of the receiving instance
      # This is needed cos sending an unknown method over DRb with $SAFE = 1
      # raises a Security Error. Could catch this, but it might happen for
      # different reasons so best not to.
      
      # need to fix symbols problem
      if String.instance_methods.first.instance_of?(String) then
        # < 1.9 Ruby
        method_id = symb.to_s
        @output.puts "Setting method id to a string: #{method_id}"
      else
        method_id = symb
        @output.puts "Ensuring method id is a symbol: #{method_id}"
      end
      
      unless @klass.instance_methods.include?(method_id)
        @output.puts "Failed to find method id:"
        @output.puts "#{@klass.instance_methods.inspect}"
        raise NoMethodError, "Failed to find method: #{method_id}"
      end

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