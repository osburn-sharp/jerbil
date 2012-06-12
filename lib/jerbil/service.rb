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

  # Define a service to register with Jerbil
  #
  # * name - a unique symbol by which the service will be identified
  # * port - the service port to be used for the service
  # * env - set to :dev, :test, or :production
  #
  class ServiceRecord

    # create a new service object
    #
    # * name - symbol identifying the service - needs to match /etc/services
    #  or create fails with the exception InvalidService
    #
    #  * env - symbol to identify the service's environment. Allows multiple
    #  services to operate for development etc
    #
    #  *verify_callback - symbol being the name of the method to call to check
    #  that the service is working
    #
    #  *stop_callback - as above but the method stops the service
    # 
    def initialize(name, env, verify_callback=:verify_callback, stop_callback=nil)
      @host = Socket.gethostname
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
    # environment services is running in
    attr_reader :env
    # the key needed to access the service
    attr_reader :key
    # the host on which the service is running
    attr_reader :host
    # the full DRb address used to contact the service
    attr_reader :address
    # the port used by the service
    attr_reader :port
    # the date/time at which the service was registered with Jerbil
    attr_reader :registered_at
    # the number of times the service has been accessed on Jerbil
    attr_reader :access_count
    # the date/time at which the service was last accessed
    attr_reader :accessed_at

    # allows Jerbil to set when the service was registered
    def register
      @registered_at = Time.now
      @accessed_at = @registered_at
    end

    # record an access to this service
    def log_access
      @accessed_at = Time.now
      @access_count += 1
    end

    # return a string containing the name, host etc
    def ident
      "#{@name}[#{@env}]@#{@address}"
    end

    # return a hash containing the find arguments for self
    def args
      {:name=>@name, :env=>@env, :host=>@host, :key=>@key}
    end

    # compare services according to a set of arguments
    #
    # args should a hash containing the following keys :name, :env, :key
    #
    # This will return true if the service matches the given keys. An argument of nil
    # matches all services.
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
    # name, env, and host
    def same_service?(rhs)
      self.matches?(:name=>rhs.name, :env=>rhs.env, :host=>rhs.host)
    end

    # compares services directly and returns true if they have the same
    # name, env, host and key
    def ==(rhs)
      self.matches?(:name=>rhs.name, :env=>rhs.env, :host=>rhs.host, :key=>rhs.key)
    end

    # return a DRb session for the given service
    # set verify to true (default) to call the
    # services keep_alive method
    #
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

    def start_drb_if_needed
      DRb.current_server
      @close = false
    rescue
      DRb.start_service
      @close = true
    end
    
  end



end