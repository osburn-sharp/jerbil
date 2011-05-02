#
# Description
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
require 'rubygems'
require 'daemons'
require 'drb'
require 'socket'

require 'jelly'
require 'jerbil/support'
require 'jeckyl/errors'

module JerbilService

  # Supervisor - a wrapper class for managing a Jerbil Service
  #
  # Can be used to easily create a daemon script for a service. First gather options
  # from the command line using optparse and then call Supervisor.new. Within the block
  # call the methods below in response to the options on the command line. When the
  # block closes the service will be started and will wait for calls.
  #
  class Supervisor

    # create and run a service daemon for the given class, which should be a JerbilService
    # class
    def initialize(klass, &block)

      @daemonize = false
      @config_file = nil
      @verbose = false
      @quiet = false
      @no_syslog = false
      @output = $stderr
      @klass = klass
      @name = klass.to_s.downcase
      @name_symbol = @name.to_sym

      if block_given? then
        block.call(self)
      else
        return self
      end

      self.start_service

    end

    # start the service without daemonising
    def no_daemon
      @daemonize = false
    end

    # output extra information, unless quiet has been set
    def verbose
      @verbose = true unless @quiet
    end

    # output absolutely nothing
    def quiet
      @quiet = true
      @verbose = false
      @output = File.open('/dev/null', 'w')
    end

    def no_syslog
      @no_syslog = true
    end

    def config_file=(cfile)
      @config_file = cfile
    end

    def output=(ofile)
      @output = ofile unless @quiet
    end


    def self.stop(klass, &block)

      sclient = self.new(klass)

      block.call(sclient)

      sclient.stop_service

    end

    def start_service

      @output.puts "Welcome to #{@klass.to_s} (#{@klass.ident})"

      if @verbose then
        @output.puts "Quiet is: #{@quiet ? 'on' : 'off'}"
        @output.puts "Verbose is: #{@verbose ? 'on' : 'off'}"
      end


      config = @klass.get_config(@config_file)

      @output.puts "Obtained configuration options"

      if @verbose then
        config.each_pair do |key, value|
          @output.puts "  :#{key} => #{value}"
        end
      end

      @output.puts "Running Service in environment: #{config[:environment]}"

      pkey = Jerbil::Support.create_private_key(@name_symbol, config[:environment], config[:key_dir])

      @output.puts "Created a private key in: #{config[:key_dir]}" if @verbose

      if @daemonize then
        @output.puts "About to demonize this service"
        Daemons.daemonize
      else
        @output.puts "Service is running in the foreground"
      end

      if @no_syslog then
        @output.puts "Disabling messages to syslog"
        Jelly.disable_syslog
      else
        @output.puts "Sending messages to syslog"
      end


      @service = @klass::Service.new(pkey, config)

      @output.puts "Registered Service with Jerbil"

      # now create the pid file
      Jerbil::Support.write_pid_file(@name_symbol, config[:environment], config[:pid_dir])

      @output.puts "Created a pid file for process: #{Process.pid}"

      @service.wait(pkey)

      @output.puts "Service has stopped"

    end

    def stop_service

      config = @klass.get_config(@config_file)
      pid = 0

      if @verbose then
        @output.puts "Obtained configuration options"
        config.each_pair do |key, value|
          @output.puts "  :#{key} => #{value}"
        end
      end

      @output.puts "Stopping Service #{@klass.to_s} in environment: #{config[:environment]}"
      pkey = Jerbil::Support.get_key_and_delete_file(@name_symbol, config[:environment], config[:key_dir])
      pid = Jerbil::Support.get_pid_and_delete_file(@name_symbol, config[:environment], config[:pid_dir])

      service_opts = {:name=>@name_symbol, :env=>config[:environment]}
      service_opts[:host] = Socket.gethostname

      begin
        # find jerbil
        jerbil_server = Jerbil.get_local_server

        # now connect to it
        jerbil = jerbil_server.connect

        # and get service
        my_service = jerbil.get(service_opts)

        if my_service.nil? then
          @output.puts "Cannot find service through Jerbil"
        end

        session = my_service.connect

      rescue Jerbil::MissingServer
        @output.puts("Cannot find a local Jerbil server")
      rescue Jerbil::JerbilConfigError => err
        @output.puts("Error in Jerbil Config File: #{err.message}")
      rescue Jerbil::JerbilServiceError =>jerr
        @output.puts("Error with Jerbil Service: #{jerr.message}")
      rescue Jerbil::ServerConnectError
        @output.puts("Error connecting to Jerbil Server")
      end

      # now to do the stopping
      begin
        session.stop_callback(pkey)
        @output.puts "Stopped service successfully"
      rescue DRb::DRbConnError
        @ouput.puts "Service stopped, but not gracefully"
        return nil
      end

    rescue Jeckyl::JeckylError => jerr
      @output.puts "Error in Configuration file: #{jerr.message}"
      # there is no pid, so just exit
    rescue Exception => err
      @output.puts "Error: #{err.message}" if @verbose
      # it went wrong, so fall back on pid killing
      if pid > 0 then
        @output.puts "Killing the process: #{pid}"
        Process.kill("SIGKILL", pid)
      else
        @output.puts "No pid available - nothing to kill"
      end
    end
  end
  
end