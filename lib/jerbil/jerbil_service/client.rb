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
require 'jerbil/servers'
require 'jerbil/service'
require 'socket'

module JerbilService


  #
  # JerbilService::Client provides a wrapper around a {JerbilService::Base} type service that hides
  # all interaction with Jerbil itself, enabling client interfaces with a service to be constructed
  # quickly and painlessly
  #
  # To use, call the {JerbilService::Client.find_services} method, which yields a block for
  # each matching service registered with the Jerbil Server. The service's methods can then 
  # be called on the yielded object, which are then transparently passed back to the
  # service itself. 
  #
  # It should always be remembered that these method calls will be mediated through Ruby's
  # DRb mechanisms and therefore access to objects across this interface may not be
  # the same as accessing them directly. See {file:README_SERVICES.md Services Readme} for
  # more details
  #
  class Client

    private_class_method :new

    # return the server's config options for the given file, or the default if none given
    # 
    # @param [Object] modl must be the constant name of the service's module.
    # @param [String] config_file is an optional path to a Jeckyl config file
    #
    # This method uses [Jeckyl]() to obtain the config parameters. The module name
    # is expected to follow the guidelines for a JerbilService: create a module
    # with the service's name (echoed in the gem name etc) and then a class
    # called Service. The parameter passed in is the module name as a constant
    #
    #    config = JerbilService::Client.get_config(MyService)
    #
    def self.get_config(modl, config_file=nil)
      modl.get_config(config_file)
    end

    # Connect to a one or more instances of a service using Jerbil
    #
    #
    # The method will search the Jerbil Server for services of the given module, as
    # defined by the what parameter:
    # * :first, yields the block once with the first service regardless of how many services there are
    #  and with no guarantee about which services this might be
    # * :local, yields the service running on the same processor as the client
    # * :all, yields the block for each service.
    # Within the block, the user can call any of the service's methods, together with the
    # instance methods of the client itself.
    #
    # For example, to find a service running on a particular host:
    #
    #    JerbilService::Client.find_services(:all, MyService, opts) do |service|
    #      if service.host == 'a_server.network.com' then
    #        # found the services I am looking for, now do something
    #        ...
    #      end
    #    end
    #
    # To find a service running in a particular environment, you need to set the
    # above option:
    #    opts = {:environment => :dev}
    #    JerbilService::Client.find_services(:all, MyService, opts) do ...
    #
    # If you want to use a config file to access this information, you can use
    # {JerbilService::Client.get_config} and extract the env information:
    #
    #    config = JerbilService::Client.get_config(MyService)
    #    opts[:environment] = config[:environment]
    #    ...
    #
    # The connection to the service is closed when the block exits.
    #
    # @param [Symbol] what being one of :first, :all or :local
    # @param [Object] modl - constant for the service module
    # @param [Hash] options - hash of the following
    # @option options [Boolean]  :quiet suppress messages on stdout (default: false)
    # @option options [Boolean]   :local find only the local service (default: false)
    # @option options [IO]    :output a file object or similar (not filename) to be used 
    #   for output - defaults to $stderr. Is overridden with /dev/null if quiet.
    # @option options [Boolean]   :welcome output additional messages to stdout suitable for standalone operation
    # @option options [Symbol]    :environment being that which the service is operating in (:dev, :test, :prod)
    # @yield [service] a client instance for each matching service registered with Jerbil
    def self.find_services(what, modl, options={}, &block)

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
    # @deprecated Use {JerbilService::Client.find_services} instead
    #
    # @param (see find_services)
    # @option (see find_services)
    #
    def self.connect(modl, options={}, &block) # :yields: client

      config_file = options[:config_file]
      config = modl.get_config(config_file)

      options[:environment] ||= config[:environment]
      options[:jerbil_env] ||= config[:jerbil_env]

      self.find_services(:first, modl, options, &block)

    end


    # @private create a client instance and call the block. Should be used internally only
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

      unless quiet
        @output.puts "Options:"
        options.each {|key, val| @output.puts("  #{key}:#{val}") }
      end

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

    # @private connect to the client
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

    # verify that the service is working
    #
    # This is really a no-op in that if the client has entered the block successfully, then
    # the service that is passed to the block will be working and therefore this call
    # will always return true. Consider it a placebo statement for a client interface
    # that only wants to check the service is running!
    #
    # @return [Boolean] indicating if the services if running
    #
    def verify
      @session != nil
    end


    # return the name of the host on which the service is running
    #
    # @return [String] FQDN of the host on which the service is running
    def host
      return @service.host
    end

    # return the service key for the given service, which can be used
    # by the caller where a method requires. See {file:README_SERVICES.md Services Readme}
    # for details about keys.
    #
    # @return [String] key to use to connect to service methods requiring it
    def service_key
      return @service.key
    end

    # @private allow client to pass on methods to the remote service
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