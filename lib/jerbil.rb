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

class Jerbil

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
  def initialize(this_server, servers, options) #log_dir, log_level=:system)

    # store details of this server and remote servers
    @local = nil
    @remote_servers = Array.new

    #store local and remote services
    @store = Array.new
    @remote_store = Array.new

    # create a jelly logger that continues any previous log and keeps the last 5 log files
    @logger = Jelly.new('Jerbil', options[:log_dir], false, 5)
    @logger.log_level = options[:log_level]

    # some statistical data
    @started = Time.now
    @registrations = 0

    @key_file = options[:key_file]

    my_fqdn = Socket.gethostname

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

    raise MissingLocalServer if @local.nil?

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
    service.register
    add_service_to_store(@store, service)
    @registrations += 1
    @logger.system("Registered Local Service: #{service.address} for env: #{service.env}")

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
  end

  # remove a service from the register
  # does nothing if the service is not registered
  def remove(service)
    @store.delete_if {|s| s === service}
    @logger.system("Deleted Service: #{service.address} for env: #{service.env}")
    @remote_servers.each do |rserver|
      rjerbil = rserver.connect
      unless rjerbil.nil?
        @logger.debug("Connected to #{rserver.fqdn}")
        begin
          rjerbil.remove_remote(@local.key, service)
          @logger.verbose("Removed Service from remote server: #{service.name}")
        rescue DRb::DRbConnError
          # assume it is not working
        end
      end
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
  def get(args={}, ignore_access=false)
    results = Array.new
    results = self.find(args, ignore_access)
    if results.length >= 1 then
      service = results[0]
      @logger.verbose("Get returned #{service.name}@#{service.address}[#{service.env}]")
      unless ignore_access
        # check if it is working
        begin
          service.connect
        rescue ServiceCallbackMissing
          @logger.warning("Verifying #{service.ident} failed due to missing callback")
        rescue ServiceConnectError
          @logger.verbose("Verification failed for #{service.ident}")
          self.remove(service)
          return nil
        end
      end
      return service
    else
      return nil
    end
  end

  def get_all(ignore_access=false)
    self.find({}, ignore_access)
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
  def stop(master_key)
    unless FileTest.exists?(@key_file) then
      # what? no master key file. Must be fatal
      @logger.fatal("No Master key file, so giving up anyway: #{@key_file}")
      @logger.close
      DRb.stop_service
      exit!
    end
    my_master_key = File.readlines(@key_file).join('')
    if master_key == my_master_key then
      @logger.system("Stopping the Jerbil Server now")
      @logger.close
      DRb.stop_service
      exit!
    else
      @logger.system("Stop called with incorrect master key")
      @logger.debug(" Master Key provided:")
      @logger.debug("#{master_key}")
      raise InvalidMasterKey
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
        @logger.system("Registered Remote Service: #{service.address} for env: #{service.env}")
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
        @logger.system("Deleted Remote Service: #{service.address} for env: #{service.env}")
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


