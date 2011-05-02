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
require 'drb'

module Jerbil
  class ServerRecord

    # returns the local server from an array of servers. Aimed at locating the local
    # server to use from the output of the config file
    #
    def self.get_local_server(servers, env=:prod)
      hostname = Socket.gethostname
      servers.each {|server| return server if server.fqdn == hostname && server.env == env}
      # found nothing to match?
      return nil
    end

    # return the server with the given fqdn
    def self.get_server(servers, fqdn, env=:prod)
      servers.each {|server| return server if server.fqdn == fqdn && server.env == env}
      # found nothing to match
      return nil
    end

    #
    # create a new server record with
    #
    # * fqdn - string fully qualified domain name
    # * key - string access key
    # * port - optional integer for port number
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

    attr_reader :fqdn, :key, :port, :env

    def ==(rhs)
      @fqdn == rhs.fqdn && @key == rhs.key && @port == rhs.port
    end

    # methods to assist in DRb communications

    # drb_address makes it easier to start a DRb server, which
    # is done outside this class because it should only be done
    # under specific circumstances, and not by the general users of this class
    #
    def drb_address
      "druby://#{@fqdn}:#{@port}"
    end

    # connect to the specified server. Always assumes that the caller has a DRb service
    # running. Jerbil certainly should!
    def connect
      DRbObject.new(nil, self.drb_address)
    rescue Exception
      raise ServerConnectError
    end

    # mark the server as being active, and therefore send local services
    # to it as they are added
    def activate
      @active = true
    end

    # server has notified that it is closing down
    def deactivate
      @active = false
    end

    # test active status
    def active?
      return active
    end

    # create a deep copy of the server object.
    def copy
      return ServerRecord.new(self.fqdn, self.key, self.env, self.port)
    end

  end
end