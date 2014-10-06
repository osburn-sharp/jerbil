#
# Jerbil Service Object
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
# Service contains information about a service registered with Jerbil
#
require 'jerbil/errors'
require 'socket'
require 'digest/sha1'

module Jerbil

  # Define a service record for a service to register with Jerbil
  #
  # Used internally by {Jerbil::Broker} and {JerbilService} to record information about
  # running services. Is made available to users through the {JerbilService::Client} 
  # interface where it can be used, for example, to get the service's key.
  #
  class ServiceRecord

    # create a new service record object
    #
    # Note that the callback parameters do not really need to be considered
    # if you are using {JerbilService::Base}
    #
    # Warning - if your hostname is not fully qualified this may not work as expected
    # if you DNS server does not provide expected reverse lookup. Consider using
    # `hostname -f` although *nix dependent.
    #
    # @param [Symbol] name identifying the service - needs to match /etc/services
    #  or create fails with the exception InvalidService
    # @param [Symbol] env identify the service's environment. Allows multiple
    #  services to operate for development etc
    # @param [Symbol] verify_callback being the name of the method to call to check
    #  that the service is working
    # @param [Symbol] stop_callback as above but the method stops the service
    # @return [ServiceRecord] of course
    # @raise [InvalidService] if the service is not registered through /etc/services
    def initialize(name, env, verify_callback=:verify_callback, stop_callback=nil)
      
      # gethostname may npt provide the fqdn
      @host = Socket.gethostname
      if @host.split('.').length == 1 then
        # no domain name
        @host = Socket.gethostbyname(@host).first
      end
      @name = name
      begin
        @port = Socket.getservbyname(@name.to_s)
      rescue
        raise InvalidService, "No service registered as: #{name}"
      end

      # now increment it if not production
      @port += 1 if env == :test
      @port += 2 if env == :dev

      @env = env
      @key = Digest::SHA1.hexdigest(Time.now.to_s + rand(12341234).to_s)[1..10]
      @pid = Process.pid
      @verify_callback = verify_callback
      @stop_callback = stop_callback
      @lock = nil
      @address = @host + ':' + @port.to_s
      @registered_at = nil
      @access_count = 0
      @accessed_at = nil
      @close = true
    end

    # name of the service
    attr_reader :name
    # environment the service is running in
    attr_reader :env
    # the key needed to access the service
    attr_reader :key
    # the host on which the service is running
    attr_reader :host
    # the full DRb address used to contact the service
    # This is only required by Jerbil and should not be needed
    # by the casual user.
    attr_reader :address
    # the port used by the service
    attr_reader :port
    # the date/time at which the service was registered with Jerbil
    attr_reader :registered_at
    # the number of times the service has been accessed on Jerbil
    # since it was registered
    attr_reader :access_count
    # the date/time at which the service was last accessed
    attr_reader :accessed_at

    # method to allow Jerbil to set when the service was registered
    def register
      @registered_at = Time.now
      @accessed_at = @registered_at
    end

    # method to allow Jerbil to record an access to this service
    def log_access
      @accessed_at = Time.now
      @access_count += 1
    end

    # return a string containing the name, env, host etc
    def ident
      "#{@name}[#{@env}]@#{@address}"
    end

    # return a hash containing the find arguments for self
    def args
      {:name=>@name, :env=>@env, :host=>@host, :key=>@key}
    end

    # compare services according to a set of arguments
    #
    # This will return true if the service matches the given keys. An argument of nil
    # matches all services. Uses the same arguments as {Jerbil::Broker#find} except
    # that it will ignore the :ignore_access argument!
    #
    # @param (see Jerbil::Broker#find)
    # @option (see Jerbil::Broker#find)
    #
    def matches?(args={})
      options = {:name => nil, :env => nil, :host=>nil, :key => nil}.merge(args)
      is_equal = true
      is_equal = @name == options[:name] unless options[:name].nil?
      is_equal = is_equal && @env == options[:env] unless options[:env].nil?
      is_equal = is_equal && @host == options[:host] unless options[:host].nil?
      is_equal = is_equal && @key == options[:key] unless options[:key].nil?
      return is_equal
    end

    # compares services directly and returns true if they have the same
    # name, env, and host.
    #
    # Note that this ignores the service records key, allowing you to find
    # instances of the same service e.g. that have previously been registered.
    #
    # @param [ServiceRecord] rhs service to compare to this one
    def same_service?(rhs)
      self.matches?(:name=>rhs.name, :env=>rhs.env, :host=>rhs.host)
    end

    # compares services directly and returns true if they have the same
    # name, env, host and key
    #
    # @param (see Jerbil::ServiceRecord#same_service?)
    def ==(rhs)
      self.matches?(:name=>rhs.name, :env=>rhs.env, :host=>rhs.host, :key=>rhs.key)
    end

    # connect to the service represented by this record
    #
    # You do not need to use this method if you use {JerbilService::Client} to
    # manage the client-server interface direct.
    #
    # This return a DRb session for the given service
    # set verify to true (default) to call the
    # services keep_alive method
    #
    # @param [Boolean] verify if the service is running immedaitely after connecting
    # @raise [ServiceCallbackMissing] if the verify method in this record does not
    #  match the methods of the service being connected to (you have mucked it up!)
    # @raise [ServiceConnectError] if any other exception is raised during the connect 
    #  process.
    def connect(verify=true)
      self.start_drb_if_needed
      service = DRbObject.new(nil, "druby://#{@address}")
      key = service.send(@verify_callback, @key) if verify
      return service
    rescue NoMethodError
      raise ServiceCallbackMissing
    rescue
      raise ServiceConnectError

    end

    # convenience method to assist JerbilService actions
    # 
    # drb_address makes it easier to start a DRb server, which
    # is done outside this class because it should only be done
    # under specific circumstances, and not by the general users of this class
    #
    def drb_address
      "druby://#{@host}:#{@port}"
    end

    # is the service local to the caller?
    def local?
      return @host == Socket.gethostname
    end


    # close the connection to the service
    def close
      DRb.stop_service if @close
    end

    
  protected

    # ensures that there is a DRb session running before trying to use
    # DRb services
    def start_drb_if_needed
      DRb.current_server
      @close = false
    rescue
      DRb.start_service
      @close = true
    end
    
  end



end