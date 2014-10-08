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
require 'jellog'
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

  # The Broker, being a server class that runs on each machine on which Jerbil services will run or will be
  # required. The Broker registers services and interacts with other servers to share information
  # about services across the network. 
  # 
  # It is not necessary to use this interface directly. By using the {JerbilService::Base}
  # class all interaction with the server is done under the hood. See {file:README_SERVICES.md Services Readme}
  # for more details.
  #
  # Key methods are:
  #
  # * *{Jerbil::Broker#register}* to add a service to the broker's database
  # * **{Jerbil::Broker#remove}** to remove a service from the broker's database
  # * **{#find} to obtain information about one or more services matching given criteria
  #
  # Methods used between servers are:
  #
  # * {Jerbil::Broker#register_server} to add a remote server to the broker's database
  # * {Jerbil::Broker#detach_server} to remove a remote server from the broker's database
  # * {Jerbil::Broker#get_local_services} called by a remote server to get all of the
  #  local services known to this server
  # * {Jerbil::Broker#register_remote} for a remote server to register a new service
  # * {Jerbil::Broker#remove_remote} for a remote server to remove a service
  # 
  # Methods used to internally:
  #
  # * {Jerbil::Broker#stop} to stop the server gracefully
  # * {Jerbil::Broker#missing_service?} to check if a service is missing and remove it from
  #  the database if it is
  #
  class Broker

    # create a new Jerbil server
    #
    # The options for the server are defined in {Jerbil::Config} and are best created
    # using this class. This is a [Jeckyl](https://github.com/osburn-sharp/jeckyl) config file.
    # Further details are provided in the {file:README.md Readme file}.
    #
    # The private key should be unique to this server and is used to authenticate system actions
    # and to authenticate remote servers. Its not very secure so more a way of avoiding mistakes.
    # The key is best created using {Jerbil::Support.create_private_key}.
    #
    # @param [Hash] options a hash of various options as defined in {Jerbil::Config}.
    # @param [String] pkey a private key generated by the script calling the broker and used
    #   to authenticate system calls
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

      # create a jellog logger that continues any previous log and keeps the last 5 log files
      @app_name = "Jerbil-#{options[:environment].to_s}"
      @log_opts = Jellog::Config.intersection(options)
      #log_opts = @log_opts.dup
      @logger = Jellog::Logger.new(@app_name, @log_opts)
      @logger.mark
      @logger.debug "Started the Logger for Jerbil"
      @logger.debug "Saved logger options: #{@log_opts.inspect}"


      # some statistical data
      @started = Time.now
      @registrations = 0
      @logger.verbose("Searching for remote servers")
      network_servers = [] #Jerbil::Servers.find_servers(@env, options[:net_address], options[:net_mask], options[:scan_timeout])
      #@logger.verbose("Found #{@remote_servers.length} remote servers")

      # now loop round the remote servers to see if any are there
      # DO NOTHING cos its an empty array!
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
      
      #@logger.verbose "Closing logger temporarily"
      #@logger.close
      
    rescue => jerr
      @logger.exception(jerr)
      raise
    end
    
    # restart the logger on the other side of daemonising it
    #
    # NOT NEEDED!
    def restart_logger
      @logger = Jellog::Logger.new(@app_name, @log_opts)     
      @logger.debug "Restarted Logger"
    end

    # date/time at which the server was started
    attr_reader :started

    # the number of registrations since the server started
    attr_reader :registrations
    
    # the remote servers at any one time
    #
    # @return [Array] of {Jerbil::Servers}
    attr_reader :remote_servers
    
    # provide access to the local server record
    def server
      @local
    end
    
    # tell remote users about what version of Ruby we are running
    def ruby_version
      RUBY_VERSION
    end

    # The current version of the Jerbil Server
    # @return [String] version number in the form N.N.N
    def version
      Jerbil::Version
    end

    # the total number of services currently registered with the server
    # @return [Numeric] count of services
    def service_count
      @store.length + @remote_store.length
    end

    # the number of local services registered with the server
    # @return [Numeric] count of services
    def local_service_count
      @store.length
    end

    # the number of remote services registered with the server
    # @return [Numeric] count of services
    def remote_service_count
      @remote_store.length
    end

    # register a service to the local server
    #
    # The caller registers the given service. The server will check that the
    # service is not already registered before adding it. It will then
    # inform all the other servers it is aware of about this service so that
    # anyone on the network can reach it. See {Jerbil::Broker#register_remote} to
    # see what happens when this methods registers a service with a remote server.
    #
    # @param [Jerbil::ServiceRecord] service representing the
    #  service being registered
    # @raise [ServiceAlreadyRegistered] if the service is already registered
    # @raise [ServiceNotLocal] if someone should attempt to register a service
    #  that is not local to this server
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
    #
    # does nothing if the service is not registered, otherwise removes it
    # locally and then calls {Jerbil::Broker#remove_remote} for each
    # registered server.
    #
    # @param [Jerbil::ServiceRecord] service to remove
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

    # return the services that match the given criteria
    #
    # search for services based on name, environment etc:
    #
    #    broker.find(:name=>'MyService', :env=>:test)
    #
    # If an option is not specified it will be ignored. Find uses {Jerbil::ServiceRecord#matches?}
    # to compare services to the given criteria.
    #
    # Normally this method will log the access to each service found (keeps a count)
    # This can be disabled by setting :ignore_access to true. This is used internally
    # to avoid counting Jerbil operations as service accesses. 
    #
    # There are also various short-cut methods that can be used:
    # {Jerbil::Broker#get get}, {Jerbil::Broker#get_local get_local} and {Jerbil::Broker#get_all get_all}
    # 
    # @param [Hash] args search arguments
    # @option args [String] :name to match exactly the name of the service
    # @option args [Symbol] :env to match the services environment (:dev, :test, :prod)
    # @option args [String] :host to match exactly the name of the host on
    #  which the service is running
    # @option args [String] :key to match exactly the service key
    # @option args [Boolean] :ignore_access do not count this call as an access
    # @return [Array] {Jerbil::ServiceRecord Services} that match or nil if none
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

    # get the first service that matches the given criteria. 
    #
    # Uses {Jerbil::Broker#find} to do the real work and returns the first service.
    # There is no guarantee of the order. In addition,
    # unless :ignore_acess is true, this call will check if the service
    # is connected, and will return nil if it is not
    #
    # @param (see #find)
    # @option (see #find)
    # @return (see #find)
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

    # get the first service that matches the given criteria and is running on the same
    # processor
    #
    # @param (see #find)
    # @option (see #find)
    # @return (see #find)
    def get_local(args={})
      new_args = args.merge({:host=>@host})
      return get(new_args)
    end

    # return all services
    # 
    # does not require any matching criteria.
    #
    # @param [Boolean] ignore_access is the same as :ignore_access for #find
    # @return (see #find)
    def get_all(ignore_access=false)
      self.find(:ignore_access => ignore_access)
    end
    
    def get_all_by_server
      services = self.find(ignore_access: true)
      servers = Hash.new
      services.each do |serv|
        unless servers.has_key?(serv.host)
          servers[serv.host] = Array.new
        end
        servers[serv.host] << serv
      end
      return servers
    end

    # Checks for a potentially missing service and removes it if it cannot be found.
    #
    # What to do if you cannot connect to a service that Jerbil thinks is there?
    # check if its local, try to connect and if OK then return false to allow retries
    # otherwise remove the service and return true.
    #
    # If the service is not local, find its server and ask it the same question.
    # if the server is not there, then fake being that server and remove_remote from
    # everyone. Don't forget to remove it from here too!
    #
    # @param [Jerbil::ServiceRecord] service to check for
    # @return [Boolean] true if service was missing
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

    # close the logger that Jerbil is using
    #
    # probably only useful for testing?
    def close
      @logger.close
    end

    # simple method to check that the server is running from a remote client
    def verify
      return true
    end


    # stop the Jerbil server
    #
    # Need to make sure the caller knows what they are doing so requires the
    # server's private key.
    #
    # @param [String] private_key - as given to the server at start-up.
    def stop(private_key)
      if @private_key == private_key then
        @logger.info("About to stop the Jerbil Server")
        @remote_servers.each do |rserver|
          begin
            rjerbil = rserver.connect
            @logger.verbose("Closing connection to: #{rserver.ident}")
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

    
    # Register a remote server, providing limited authentication. 
    #
    # Registering a server
    # will purge any old server record and any old services for that server
    #
    # @param [Servers] server - the remote server's Servers record
    # @param [String] secret shared between all servers on the net
    # @param [Symbol] env of the calling server, just to ensure it is the same
    # @return [String] private key of the called server to be used for further interactions
    # @raise [JerbilAuthenticationError] if the server fails to authenticate
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

    # get all of the local services registered with this server
    #
    # @param [String] my_key must be the called servers private key shared
    #  with a remote server through {Jerbil::Broker#register_server}.
    # @raise [InvalidServerKey] is the given key is incorrect
    # @return [Array] of {ServiceRecord}
    #
    def get_local_services(my_key)
      raise InvalidServerKey, @logger.error("get_local_services: incorrect key: #{my_key}") unless @private_key == my_key
      return @store.dup
    end


    # register a remote service
    #
    # This is called by a jerbil service when it wants to register a service local to
    # it with all the other servers. This will siltenly delete any existing service record.
    #
    # @param [String] my_key - the caller must provide this server's private key
    # @param [Service] service - the service to be registered
    # @raise ServiceAlreadyRegistered if the service is a duplicate
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

    # delete a remote service from this server
    # 
    # @param (see register_remote)
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

    # detach a remote server from this server
    # 
    # called when the remote server is closing down. Incorrect keys are silently
    # ignored. The remote server is removed from the database.
    #
    # @param [String] my_key being the key of the server being called
    # @param [Server] server being the record for the remote server that is detaching
    def detach_server(my_key, server)
     
      unless @private_key == my_key
        @logger.warn("Detaching remote server: incorrect key: #{my_key}")
        return false
      end
      
      unless @remote_servers.include?(server)
        @logger.warn "Detaching remote server: server not known: #{server.ident}"
        return false
      end
      
      @logger.verbose("About to detach a remote server: #{server.ident}")
      @remote_store.delete_if {|s| s.host == server.fqdn}
      @remote_servers.delete(server)
      @logger.info("Detached server: #{server.ident}")
    end

    protected

    private

    # add the given service to the given store, 
    #
    # Used to add either local or remote services and carry out common checks.
    #
    # @param [Array] store which is either local or remote
    # @param [ServiceRecord] service to be added
    # @raise [ServiceAlreadyRegistered] when ... a service is already registered!
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


