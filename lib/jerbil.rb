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
require 'rubygems'
require 'drb'
require 'socket'
require 'jelly'
require 'jerbil/errors'
require 'jerbil/service'
require 'jerbil/servers'
require 'jerbil/version'
require 'jerbil/support'

# == JERBIL - Jumpin' Ermin's Ruby Broker for Integrated Linux services!
#
# A network server for registering services and a suite of classes and methods to
# manage these services and to connect with them.
#
module Jerbil

  # == Jerbil Broker
  #
  # The server class that runs on each machine on which Jerbil services will run or will be
  # required. The Broker registers services and interacts with other servers to share information
  # about services across the network.
  #
  class Broker

    # create a new Jerbil server
    #
    # * options - a hash as provided by Jeckyl using the jerbil/config - see there for details
    #
    # * pkey - a private key generated by the script calling the broker and used
    #   to authenticate certain calls
    #
    # Note that Jerbil leaves default options for the caller to resolve.
    #
    def initialize(options, pkey) #log_dir, log_level=:system)

      # store details of this server and remote servers
      @env = options[:environment] || :prod
      @private_key = pkey
      @secret = options[:secret]
      
      @local = Jerbil::Servers.create_local_server(@env, @private_key)
      @remote_servers = Array.new


      # who am i
      #@host = Socket.gethostname

      #store local and remote services
      @store = Array.new
      @remote_store = Array.new

      # create a jelly logger that continues any previous log and keeps the last 5 log files
      app_name = "Jerbil-#{options[:environment].to_s}"
      log_opts = Jelly::Logger.get_options(options)
      @logger = Jelly::Logger.new(app_name, log_opts)
      @logger.mark
      @logger.debug "Started the Logger for Jerbil"


      # some statistical data
      @started = Time.now
      @registrations = 0
      @logger.verbose("Searching for remote servers")
      network_servers = Jerbil::Servers.find_servers(@env, options[:net_address], options[:net_mask], options[:scan_timeout])
      @logger.verbose("Found #{@remote_servers.length} remote servers")

      # now loop round the remote servers to see if any are there
      network_servers.each do |remote_server|
        rjerbil = remote_server.connect
        unless rjerbil.nil?
          @logger.debug "Getting Remote Services. Connecting to : #{remote_server.inspect}"
          # there is a remote server, so tell it about me
          begin
            rkey = rjerbil.register_server(@local, @secret, @env)
            remote_server.set_key(rkey)
            @logger.debug "Key for #{remote_server.fqdn}: #{rkey}"
            rjerbil.get_local_services(rkey).each {|ls| add_service_to_store(@remote_store, ls)}
            # add it to the list of verified servers
            @remote_servers << remote_server
          rescue DRb::DRbConnError
            # assume it is not working
            @logger.verbose("Failed to get remote services from server: #{remote_server.fqdn}")
          rescue JerbilAuthenticationError => jerr
            @logger.warn("Remote server authentication failed, skipping")
            @logger.warn("  #{jerr.message}")
          rescue ArgumentError, NoMethodError
            @logger.warn("Remote server incompatibility, skipping")
          rescue => jerr
            @logger.exception(jerr)
          end

        end
      end

      @logger.system("Started up the Jerbil Server")
      
      @logger.debug "My key: #{@private_key}"
      @logger.debug "Stored remote keys:"
      @remote_servers.each do |rs|
        @logger.debug "   #{rs.fqdn}: #{rs.key}"
      end
      
    rescue => jerr
      @logger.exception(jerr)
      raise
    end

    # date/time at which the server was started
    attr_reader :started

    # the number of registrations since the server started
    attr_reader :registrations
    
    # the remote servers at any one time
    attr_reader :remote_servers

    # return the current version of Jerbil
    def version
      Jerbil::Version
    end

    # the total number of services currently registered with the server
    def service_count
      @store.length + @remote_store.length
    end

    # the number of local services registered
    def local_service_count
      @store.length
    end

    # the number of remote services registered
    def remote_service_count
      @remote_store.length
    end

    # add a service to the local server
    #
    # if there is already a matching service registered then raise the
    # ServiceAlreadyRegistered exception
    #
    def register(service)
      @logger.verbose("About to register a local service: #{service.ident}")
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
              rjerbil.register_remote(rserver.key, service)
              @logger.verbose("Registered Service: #{service.name} on server: #{rserver.fqdn}")
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
      else
        @logger.warn("Attempt was made to remove a service that is not registered: #{service.ident}")
        @logger.warn("Trying to remove it remotely anyway")
      end
      @remote_servers.each do |rserver|
        rjerbil = rserver.connect
        unless rjerbil.nil?
          @logger.debug("Connected to #{rserver.fqdn}")
          begin
            rjerbil.remove_remote(rserver.key, service)
            @logger.verbose("Removed Service from remote server: #{service.ident}")
          rescue DRb::DRbConnError
            # assume it is not working
            @logger.debug("Skipping over remove_remote for #{rserver.fqdn} while removing #{service.ident}")
          end
        end
      end
    end

    # get the services that match the given criteria
    # args has to be a hash of options. Details are provided by Service.matches?
    def find(args={})
      #options = {:name=>nil, :port=>nil, :env=>nil}.merge(args)
      results = Array.new
      services = @store + @remote_store
      services.each do |service|
        if service.matches?(args) then
          service.log_access unless args[:ignore_access]
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
    def get(args={})
      results = Array.new
      results = self.find(args)
      if results.length >= 1 then
        service = results[0]
        @logger.verbose("Get returned #{service.ident}")
        unless args[:ignore_access]
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
    def get_local(args={})
      new_args = args.merge({:host=>@host})
      return get(new_args)
    end

    # return all services
    def get_all(ignore_access=false)
      self.find(:ignore_access => ignore_access)
    end

    # what to do if you cannot connect to a service that Jerbil thinks is there?
    #
    # check if its local, try to connect and if OK then return false to allow retries
    # otherwise remove the service and return true
    #
    # if not local, find server and ask it the same question.
    # if the server is not there, then fake being that server and remove_remote from
    # everyone. Don't forget to remove it from here too!
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
          self.remove_remote(rkey, service)
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
        @logger.info("About to stop the Jerbil Server")
        @remote_servers.each do |rserver|
          begin
            rjerbil = rserver.connect
            @logger.verbose("Closing connection to; #{rserver.ident}")
            rjerbil.detach_server(rserver.key, @local) 
          rescue ServerConnectError, DRb::DRbConnError
            @logger.error("Failed to connect to #{rserver.ident}")
          end
        end
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
    rescue ServerConnectError
      @logger.error("Connection to remote server failed")
    rescue InvalidPrivateKey
      raise
    rescue => err
      @logger.exception(err)
    end
    
    #================================================
    #
    # SERVER related methods
    #
    #================================================

    
    # Register a remote server, providing limited authentication. Registering a server
    # will purge any old server record and any old services for that server
    #
    # @param [Servers] :server - the remote server's Servers record
    # @param [String] :secret shared between all servers on the net
    # @param [Symbol] :env of the calling server, just to ensure it is the same
    #
    def register_server(server, secret, env)
      @logger.debug("Attempting to register server: #{server.ident}")
      unless secret == @secret
        @logger.debug "mismatching secret: #{secret}"
        raise JerbilAuthenticationError, @logger.error("Secret key from #{server.fqdn} does not match")
      end
      unless env = @env
        raise JerbilAuthenticationError, @logger.error("Registering server with #{env}, against #{@env}")
      end
      # need to delete any stale existing record
      @remote_servers.delete_if {|rserver| rserver.fqdn == server.fqdn}
      
      # registering this new server, but there may be stale services as well
      @remote_store.delete_if {|rservice| rservice.host == server.fqdn}
      
      @remote_servers << server 
      @logger.debug "Registered a new server"
      @logger.debug "   #{server.ident}: #{server.key}"
        
      return @private_key
    end

    # and get all of the local services registered with this server
    #
    # Must provide a valid key
    #
    def get_local_services(my_key)
      raise InvalidServerKey, @logger.error("get_local_services: incorrect key: #{my_key}") unless @private_key == my_key
      return @store.dup
    end


    # register a remote service
    #
    # @param [String] :my_key - the caller must provide this servers private key
    # @param [Service] :service - the service to be registered
    #
    # Silently ignores incorrect keys
    # Also raises ServiceAlreadyRegistered if the service is a duplicate
    #
    def register_remote(my_key, service)
      @logger.debug "About to register a remote service:"
      @logger.debug "   #{service.inspect}"
 
      unless @private_key == my_key
        @logger.warn("register remote: incorrect key: #{my_key}, ignoring")
        return true
      end
      
      # perhaps there is a stale record for this service? Stops add below from assuming it is missing etc
      @remote_store.delete_if {|rservice| rservice.same_service?(service)}
      
      add_service_to_store(@remote_store, service)
      @logger.info("Registered Remote Service: #{service.ident}")
      return true

    end

    # delete a remote service
    # requires a valid server key or operation is ignored
    def remove_remote(my_key, service)
      @logger.debug "About to remove a remote service:"
      @logger.debug "   #{service.inspect}"
 
      unless @private_key == my_key
        @logger.warn("remove_remote: incorrect key: #{my_key}")
        return true
      end
      @remote_store.delete_if {|s| s == service}
      @logger.info("Deleted Remote Service: #{service.ident}")
      return true
    end

    # and close a remote server
    def detach_server(my_key, server)
      @logger.verbose("About to detach a remote server: #{server.ident}")
     
      unless @private_key == my_key
        @logger.warn("close_remote_server: incorrect key: #{my_key}")
        return true
      end
      @remote_store.delete_if {|s| s.host == server.fqdn}
      @remote_servers.delete(server)
      @logger.info("Detached server: #{server.ident}")
    end

    protected

    private

    # add the given service to the given store, but only if it is not already there.
    # If there is a service already registered, check if it is responding. If not, then
    # carry on.
    def add_service_to_store(store, service)
      store.each do |s|
        if s.same_service?(service) then
          # there is already a service registered, but is it active?
          @logger.verbose("There is already a service registered: #{service.ident}")
          if self.service_missing?(s) then
            @logger.verbose "Service: #{s.ident} was registered, but did not respond"
          else
            raise ServiceAlreadyRegistered, @logger.warn("Service: #{service.address}-#{service.env} already registered")
          end
          
        end
      end
      # either service was not registered or was missing, so add it
      store << service
      @logger.verbose "Added #{service.ident}"
    end

  end
end


