#
# = Jerbil Server Class
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
# A useful class for managing information about Jerbil Servers
#
#
#
require 'socket'
require 'timeout'
require 'netaddr'
require 'resolv'
require 'drb'

module Jerbil
  
  # An informational class for servers on the network, used by brokers to keep track of each other
  # and by services and clients to find the local broker
  class Servers

    # return a record for the local server
    #
    # @param [Symbol] env being one of :dev, :test, :prod, and defaulting to :prod
    # @param [Boolean] check set true to ensure server is running
    # @raise [Jerbil::MissingServer] if server is not running
    #
    def self.get_local_server(env=nil, check=false)
      env ||= :prod
      hostname = Socket.gethostname
      ip = Resolv.getaddress(hostname)
      port = self.get_port(env)
      return self.new(hostname, '', env, port) if ! check || self.server_up?(ip, port, 0.1)
      raise Jerbil::MissingServer, "Cannot find local server on #{hostname}"
    end
    
    # create the local server record
    # 
    # used by {Jerbil::Broker} during startup to create its own record
    #
    # @param [Symbol] env being one of :dev, :test, :prod
    # @param [String] pkey the private key for this server
    # @return [Jerbil::Servers] a server record
    def self.create_local_server(env, pkey)
      hostname = Socket.gethostname
      port = self.get_port(env)
      return self.new(hostname, pkey, env, port)
    end

    # return the server with the given fqdn
    # @deprecated NOT USED ANYWHERE?
    def self.get_server(servers, fqdn, env=:prod)
      servers.each {|server| return server if server.fqdn == fqdn && server.env == env}
      # found nothing to match
      return nil
    end
    
    # scan the lan for open ports and return an array of servers
    # for each. 
    # 
    # These server records have blank keys. {Jerbil::Broker#register_server} will return
    # the called servers key, which can then be set with {Jerbil::Servers#set_key}.
    #
    # The netaddress and netmask are defined in {Jerbil::Config} where further details
    # about these parameters can be found.
    #
    # @param [Symbol] env being the environment in which the servers should be running
    # @param [String] netaddress for the network to search
    # @param [Numeric] netmask to limit the search
    # @param [Float] seconds to wait before timing out
    # @return [Array] of {jerbil::Servers} that were found
    def self.find_servers(env, netaddress, netmask, seconds=0.1)
      # get the port number for jerbil
      port = self.get_port(env)
      naddr = NetAddr::CIDR.create("#{netaddress}/#{netmask.to_s}")
      servers = []
      
      naddr.enumerate.each do |ip|
        servers << self.new(Resolv.getname(ip), '', env, port) if self.server_up?(ip, port, seconds)
      end
      # servers.each do |server|
      #   server.get_key
      # end
      return servers
    end

    # create a new server record with
    #
    # @param [String] fqdn - string fully qualified domain name
    # @param [String] key - private access key for system methods
    # @param [Symbol] env to set the environment to :dev, :test or :prod
    # @param [Numeric] port - optional integer for port number
    #
    def initialize(fqdn, key, env=:prod, port=nil)
      @fqdn = fqdn
      @key = key
      @env = env
      if port.nil? then
        @port = Socket.getservbyname('jerbil')
        @port += 1 if env == :test
        @port += 2 if env == :dev
      else
        @port = port
      end
      @active = false
    end
    
    # the full-qualified domain name for the server
    attr_reader :fqdn
    
    # the private key for the server
    attr_reader :key
    
    # the port for the server
    attr_reader :port
    
    # the environment that the server is running in
    attr_reader :env
    
    # test for equality
    #
    # ensure equality is across name, key and port.
    # no need to test env because port is unique enough
    #
    # @param [Jerbil::Servers] rhs server to compare
    def ==(rhs)
      @fqdn == rhs.fqdn && @key == rhs.key && @port == rhs.port
    end

    # convenience method to assist Jerbil internals with DRb
    #
    # drb_address makes it easier to start a DRb server, which
    # is done outside this class because it should only be done
    # under specific circumstances, and not by the general users of this class
    #
    # @return [String] the servers DRb address
    def drb_address
      "druby://#{@fqdn}:#{@port}"
    end

    # connect to this server. 
    # 
    # Always assumes that the caller has a DRb service
    # running. Jerbil certainly should!
    # 
    # @raise [ServerConnectError] if anything goes wrong
    def connect
      DRbObject.new(nil, self.drb_address)
    rescue Exception
      raise ServerConnectError
    end
    
    # get the key for this server from the actual server
    # @return [String] private key
    def get_key
      @key = self.connect.get_key
    end
    
    # save the key for this server, ensuring it is local
    #
    # @param [String] pkey - the server's private key'
    def set_key(pkey)
      @key = pkey
    end
    
    # return a string name for the server
    #
    # @return [String] ident string
    def ident
      "#{@fqdn}[:#{@env}]"
    end

    # create a deep copy of the server object.
    #
    # @return [Jerbil::Server] copy of self
    def copy
      return ServerRecord.new(self.fqdn, self.key, self.env, self.port)
    end
    
    # check if the given server is running
    #
    # This is intended for internal use only by {Jerbil::Servers.find_servers}.
    #
    # @param [String] ip address of server to test
    # @param [Integer] port for server
    # @param [Float] timeout_secs to wait for a response
    # @return [Boolean] true if server is up
    def self.server_up?(ip, port, timeout_secs)
      #puts "Checking for #{ip}:#{port}"
      Timeout::timeout(timeout_secs) do
        begin
          TCPSocket.new(ip, port).close
          true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH
          false
        end
      end
    rescue Timeout::Error
      false
    end
    
    # get the port for the Jerbil Server 
    # 
    # Note that jerbil and all its services expect
    # three consecutive ports to be available, one for each environment. 
    # The first port should be :prod, then :test and finally :dev
    #
    # @param [Symbol] env the environment in which the servers are running
    # @raise [Jerbil::MissingJerbilService] if jerbil is not in /etc/services
    #
    def self.get_port(env)
      port = Socket.getservbyname('jerbil')
      port += 1 if env == :test
      port += 2 if env == :dev
      return port
    rescue SocketError
      raise Jerbil::MissingJerbilService, "There is no service 'jerbil' in /etc/services"
    end
      

  end
end