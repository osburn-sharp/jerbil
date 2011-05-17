#
# = JERBIL
#
# == Jumpin' Ermin's Ruby Broker for Integrated Linux services!
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
# A reliable (hopefully) object request broker for ruby services.
#
# A server runs on every machine. Servers register with Jerbil and offer a polling method so that
# Jerbil can keep checking they are alive. Servers that want to take network wide clients are
# relayed to all the other Jerbil servers.
#
# Clients ask for a service and receive the name and port to connect through using DRb.
#
# Jerbil is meant to be used behind a higher level wrapper that hides DRb as well
#
#
require 'drb'
require 'socket'
require 'jelly'
require 'jerbil/errors'
require 'jerbil/service'
require 'jerbil/version'
require 'jerbil/support'

# == JERBIL - Jumpin' Ermin's Ruby Broker for Integrated Linux services!
#
# A network server for registering services and a suite of classes and methods to
# manage these services and to connect with them.
#
module Jerbil

  class Broker

    # create a new Jerbil server
    #
    # * servers - an array of Jerbil::Server objects, one for each Jerbil Server in the
    #    system
    # * options - a hash of the following:
    #
    #   :log_dir - string path for the directory in which Jelly will log messages
    #   :log_level - a symbol, one of :system, :verbose, :debug (see Jelly)
    #   :key_file - string path for a file containing this servers private key
    #
    # Note that Jerbil leaves default options for the caller to resolve.
    #
    def initialize(this_server, servers, options, pkey) #log_dir, log_level=:system)

      # store details of this server and remote servers
      @local = nil
      @remote_servers = Array.new

      @private_key = pkey

      # who am i
      @host = Socket.gethostname

      #store local and remote services
      @store = Array.new
      @remote_store = Array.new

      # create a jelly logger that continues any previous log and keeps the last 5 log files

      app_name = "Jerbil-#{options[:environment].to_s}"
      @logger = Jelly.new(app_name, options[:log_dir], false, options[:log_rotation], options[:log_length])
      @logger.log_level = options[:log_level]

      # some statistical data
      @started = Time.now
      @registrations = 0

      @key_file = options[:key_file]

      # loop through all of the servers to create local records
      servers.each do |server|
        if server == this_server then
          # this is the local server
          @local = server.copy
          @logger.debug("Registered myself as: #{@local.inspect}")
        else
          @remote_servers << server.copy
        end
      end

      if @local.nil? then
        @logger.fatal("Missing local server")
        @logger.debug("  Servers: " + servers.inspect)
        @logger.debug("  This Server: " + this_server.inspect)
        raise MissingServer
      end

      remote_services = Array.new
      # now loop round the remote servers to see if any are there
      @remote_servers.each do |remote_server|
        rjerbil = remote_server.connect
        unless rjerbil.nil?
          @logger.debug "Getting Remote Services. Connecting to : #{remote_server.inspect}"
          # there is a remote server, so tell it about me
          begin
            remote_services += rjerbil.get_local_services(@local.key)
          rescue DRb::DRbConnError
            # assume it is not working
            @logger.verbose("Failed to get remote services from server: #{remote_server.fqdn}")
          end
        end
      end

      @logger.debug("Got remote services: #{remote_services.inspect}")

      remote_services.each do |rservice|
        add_service_to_store(@remote_store, rservice)
      end

      @logger.system("Started up the Jerbil Server")
    end

    # date/time at which the server was started
    attr_reader :started

    # the number of registrations since the server started
    attr_reader :registrations

    # return the current version of Jerbil
    def version
      Version
    end

    # the total number of services currently registered with the server
    def services
      @store.length + @remote_store.length
    end

    # the number of local services registered
    def local_services
      @store.length
    end

    # the number of remote services registered
    def remote_services
      @remote_store.length
    end

    # add a service to the local server
    #
    # if there is already a matching service registered then raise the
    # ServiceAlreadyRegistered exception
    #
    def register(service)
      if service.local? then
        service.register
        add_service_to_store(@store, service)
        @registrations += 1
        @logger.system("Registered Local Service: #{service.ident}")

        @remote_servers.each do |rserver|
          rjerbil = rserver.connect
          unless rjerbil.nil?
            @logger.debug("Registering remote. Connected to #{rserver.fqdn}")
            begin
              rjerbil.register_remote(@local.key, service)
              @logger.verbose("Registered Service on remote server: #{service.name}")
            rescue DRb::DRbConnError
              # assume it is not working
            end
          end
        end
      else
        # someone is attempting to register a service that is not local
        @logger.warn("Attempt to register non-local service: #{service.ident}")
        raise ServiceNotLocal
      end
    end

    # remove a service from the register
    # does nothing if the service is not registered
    def remove(service)
      if @store.include?(service) then
        # its a local one
        @store.delete(service)
        @logger.system("Deleted Service: #{service.ident}")
        @remote_servers.each do |rserver|
          rjerbil = rserver.connect
          unless rjerbil.nil?
            @logger.debug("Connected to #{rserver.fqdn}")
            begin
              rjerbil.remove_remote(@local.key, service)
              @logger.verbose("Removed Service from remote server: #{service.ident}")
            rescue DRb::DRbConnError
              # assume it is not working
              @logger.debug("Skipping over remove_remote for #{rserver.fqdn} while removing #{service.ident}")
            end
          end
        end
      else
        @logger.warn("Attempt was made to remove a service that is not registered: #{service.ident}")
      end
    end

    # get the services that match the given criteria
    # args has to be a hash of options. Details are provided by Service.matches?
    def find(args={}, ignore_access=false)
      #options = {:name=>nil, :port=>nil, :env=>nil}.merge(args)
      results = Array.new
      services = @store + @remote_store
      services.each do |service|
        if service.matches?(args) then
          service.log_access unless ignore_access
          results << service
        end
      end

      @logger.verbose("Searching for services. Found #{results.length} matching.")
      @logger.verbose("  Arguments: #{args.inspect}")

      return results
    end

    # get the first service that matches. Return nil if no service matches
    # use ignore_access to avoid counting a get as an access to a service
    # mainly for the benefit of the jerbil command
    #
    # NOTE, unless ignore_acess is true, this call will check if the service
    # is connected.
    #
    def get(args={}, ignore_access=false)
      results = Array.new
      results = self.find(args, ignore_access)
      if results.length >= 1 then
        service = results[0]
        @logger.verbose("Get returned #{service.ident}")
        unless ignore_access
          # check if it is working
          begin
            service.connect
          rescue ServiceCallbackMissing
            @logger.warning("Verifying #{service.ident} failed due to missing callback")
            # missing callback but still return it...
          rescue ServiceConnectError
            @logger.verbose("Verification failed for #{service.ident}")
            return nil
          end
        end
        return service
      else
        return nil
      end
    end

    # convenience method to save getting lots of hostnames
    def get_local(args={}, ignore_access=false)
      new_args = args.merge({:host=>@host})
      return get(new_args, ignore_access)
    end

    # return all services
    def get_all(ignore_access=false)
      self.find({}, ignore_access)
    end

    # what to do if you cannot connect to a service that Jerbil thinks is there?
    #
    # check if its local, try to connect and if OK then return false to allow retries
    # otherwise remove the service and return true
    #
    # if not local, find server and ask it the same question.
    # if the server is not there, then fake being that server and remove_remote from
    # everyone.
    #
    def service_missing?(service)
      # is it one of mine?
      if service.local? then
        #yes
        @logger.verbose("Local service missing for #{service.ident}?")
        begin
          service.connect
          # seems to be fine
          @logger.info("Missing service was found to be OK: #{service.ident}")
          return false
        rescue
          # failed to connect for some reason.
          # trying to stop the service
          @logger.debug("Local service appears to be missing: #{service.ident}")
          # and now remove it from the record
          self.remove(service)
          @logger.system("Removed missing local service: #{service.ident}")
          return true
        end
      else
        # not one of mine, so who owns it
        @logger.verbose("Missing service is not local: #{service.ident}")
        failed_remote_server = nil
        @remote_servers.each do |rserver|
          if rserver.fqdn == service.host then
            # found it, so try to warn it
            @logger.debug("Service: #{service.ident} belongs to #{rserver.fqdn}")
            begin
              rjerbil = rserver.connect
              return rjerbil.service_missing?(service)
            rescue
              # whoops, failed to connect to remote server
              # so assume it has gone and allow method to continue
              # so that it removes the service as if it was the remote server
              failed_remote_server = rserver
            end
          end
        end
        # only got here because could not connect to the server
        unless failed_remote_server.nil?
          @logger.warn("Failed to connect to server: #{failed_remote_server.fqdn}, removing service for it")
          rkey = failed_remote_server.key
          @remote_servers.each do |rserver|
            begin
              rjerbil = rserver.connect
              rjerbil.remove_remote(rkey, service)
              @logger.debug("Removed service: #{service.ident} from server #{rserver.fqdn}")
            rescue
              # server not up, so ignore
              @logger.debug("Failed to connect to server to remove service: #{rserver.fqdn}, but who cares!")
            end
          end
          return true
        else
          # strange? Should not have a service for which there is no server...
          @logger.warn("Could not find a server for #{service.ident}. How could this happen?")
          return false
        end
      end
    end

    # probably only useful for testing?
    def close
      @logger.close
    end

    # simple method to check that the server is running from a remote client
    def verify
      return true
    end


    # stop the server. Need to make sure the caller knows what they are doing.
    def stop(private_key)
      if @private_key == private_key then
        @logger.system("Stopping the Jerbil Server now")
        @logger.close
        DRb.stop_service
        #exit!
      else
        @logger.system("Stop called with incorrect private key")
        @logger.debug(" Private Key provided:")
        @logger.debug("#{private_key}")
        @logger.debug(" Private Key required")
        @logger.debug("#{@private_key}")
        raise InvalidPrivateKey
      end
    end


    #
    # Methods used by remote servers and NOT services

    # register a remote server
    # * server_name is the fqdn of the calling server
    # * server_key is known to all valid servers
    #
    # return a unique queue that identifies the caller for
    # future interactions
    #
    # When a remote server connects, need to set the local
    # server record to active, so that new local services are
    # propagated to the remote server
    #
    def open_remote_server(server_name, server_key)
      return my_server_key
    end

    # and get all of the local services registered with this server
    #
    # Must provide a valid key
    #
    def get_local_services(key)
      return [] if @local.key == key
      services = Array.new
      @remote_servers.each do |remote|
        if remote.key == key then
          @store.each do |service|
            services << service
          end
          return services
        end
      end
      @logger.warn("Get local services failed due to unknown server key: #{key}")
      raise InvalidServerKey
    end

    # give the caller all its own services registered here
    def get_my_services(my_server_key)

    end

    # register a remote service
    #
    # the caller must provide a valid key known to this server
    # or the exception InvalidServerKey will be raised
    #
    # Also raises ServiceAlreadyRegistered if the service is a duplicate
    #
    def register_remote(key, service)
      return true if @local.key == key # rare issue, probably only test related
      # check that the caller is a valid server
      @remote_servers.each do |remote|
        if remote.key == key then
          add_service_to_store(@remote_store, service)
          @logger.info("Registered Remote Service: #{service.ident}")
          return true
        end
      end
      # no key matched!
      @logger.warn("Remote registration failed due to unknown server key: #{key}")
      raise InvalidServerKey
    end

    # delete a remote service
    # requires a valid server key
    def remove_remote(key, service)
      @remote_servers.each do |remote|
        if remote.key == key then
          @remote_store.delete_if {|s| s === service}
          @logger.info("Deleted Remote Service: #{service.ident}")
          return true
        end
      end
    end

    # and close a remote server
    def close_remote_server

    end

    protected

    private

    #
    def add_service_to_store(store, service)
      store.each do |s|
        if s == service then
          @logger.warn("Service: #{service.address}-#{service.env} already registered")
          raise ServiceAlreadyRegistered
        end
      end
      store << service

    end

  end
end


