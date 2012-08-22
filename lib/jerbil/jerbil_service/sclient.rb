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
require 'jerbil/servers'
require 'jerbil/chuser'
require 'jeckyl/errors'

module JerbilService

  # Supervisor - a wrapper class for managing a Jerbil Service
  #
  # Can be used to easily create a daemon script for a service. First gather options
  # from the command line using optparse and then call Supervisor.new. Within the block
  # call the methods below in response to the options on the command line. When the
  # block closes the service will be started and will wait for calls.
  #
  # All of this is already done via /usr/sbin/jserviced. See {file:README_SERVICES.md Jerbil Services} for more details
  #
  class Supervisor

    # create and run a service daemon for the given class, which should be a JerbilService
    # class. This yields a block. Within the block, use the methods below to set parameters and the service
    # will then be launched when the block returns
    #
    # @param [Class] klass a JerbilService class or child of
    #
    def initialize(klass, &block)

      @daemonize = true
      @config_file = nil
      @verbose = false
      @quiet = false
      @no_syslog = false
      @output = $stderr
      @logger = nil
      @set_log_daemon = false # flag to log the daemon itself
      @jerbil_env = nil
      @klass = klass
      @name = klass.to_s.downcase
      @name_symbol = @name.to_sym

      # only called without a block internally to effect the stop
      # see below
      if block_given? then
        block.call(self)
      else
        return self # created for stop
      end
      
      # only gets here for a start
      self.start_service

    end

    # start the service without daemonising
    def no_daemon
      @daemonize = false
    end

    # output extra information about starting up the service. Ignored if quiet has been set
    # Note this controls messages from the Supervisor about the startup process
    # and is unrelated to the service's logger
    def verbose
      @verbose = true unless @quiet
    end

    # output absolutely nothing
    def quiet
      @quiet = true
      @verbose = false
      @output = File.open('/dev/null', 'w')
    end

    # ensure logging does not log to syslog
    # see Jelly::Logger#disable_syslog for details
    def no_syslog
      @no_syslog = true
    end

    # set the config file for the service. Each service expects an options hash, which the supervisor
    # will obtain from either this file, or the default, which is usually: /etc/jermine/<service>.rb
    #
    def config_file=(cfile)
      @config_file = cfile
    end

    # set the supervisor output to a file (object, not path)
    def output=(ofile)
      @output = ofile unless @quiet
    end
    
    # create a log file for the daemon task, the output of
    # which is otherwise lost. This uses jelly and will write the log
    # to a file in the log_dir (see {JerbilService::Config}) named after the service with _sd added.
    # By default this would be /var/log/jermine/<service>_sd.log
    #
    # This logger takes over from the output file set in {JerbilService::Supervisor#output}, but only
    # when the supervisor daemonises.
    #
    def log_daemon
      @set_log_daemon = true
    end
    
    # override the default jerbil config file, used only
    # for testing new versions of jerbil
    # @deprecated - jerbil_env is a standard config parameter now, although still only
    # intended for test purposes.
    def jerbil_env=(env)
      @jerbil_env = env
    end


    # this class method if called to create an instance of the supervisor to
    # stop a Jerbil service. Use the methods above in the block to set
    # parameters
    def self.stop(klass, &block)

      # create an instance of this class without starting the service
      # (no block)
      sclient = self.new(klass)

      block.call(sclient)

      sclient.stop_service

    end
    
    #protected

    # this method is called by the initialize method to start a Jerbil Service
    # messages are logged through @output, which is stderr by default or
    # /dev/null if quiet was enabled, or a Jelly logger.
    #
    def start_service

      @output.puts "Welcome to #{@klass.to_s} (#{@klass.ident})"
      
      # get the config options for this service
      config = @klass.get_config(@config_file)
      
      if Jerbil::Chuser.change_group(config[:group]) then
        @output.puts "Changed group to #{config[:group]}"
        config = @klass.get_config(@config_file)
      end
            
      # create a hash for logger options
      if Jerbil::Chuser.change_user(config[:user]) then
        @output.puts "Changed user to #{config[:user]}"
        config = @klass.get_config(@config_file)
      end
            
      # create a hash for logger options
      log_opts = {}
      
      # to test a new jerbil server, this needs to be set to the
      # jerbil server's environment. Only needed for test purposes
      if @jerbil_env then
        config[:jerbil_env] = @jerbil_env
      end

      # create a Jelly logging object if requested
      # if @set_log_daemon then
      #   Jelly::Logger.disable_syslog if @no_syslog
      #   log_opts = Jelly::Logger.get_options(config)
      #   log_opts[:log_level] = :debug if @verbose
      #   @logger = Jelly::Logger.new("#{@klass.to_s.downcase}_sd", log_opts)
      #   @output.puts "Logging output to #{@logger.logfilename}"
      #   @output.flush
      #   @output = @logger
      # end

      # log the configuration options if requested
      if @verbose then
        @output.puts "Obtained configuration options"
        config.each_pair do |key, value|
          @output.puts "  :#{key} => #{value}"
        end
      end

      @output.puts "Running Service in environment: #{config[:environment]}"
      
      # create a private key for the service
      pkey = Jerbil::Support.create_private_key(@name_symbol, config[:environment], config[:key_dir])

      @output.puts "Created a private key in: #{config[:key_dir]}" if @verbose

      # the service will be daemonized so need to set up daemon parameters
      if @daemonize then
        @output.puts "About to demonize this service"
        # cleanly close everything
        #@output.close
        
        dopts = {:backtrace=>true,
          :app_name=>@klass.to_s.downcase,
          :log_dir=>config[:log_dir],
          :log_output=>true,
          :dir_mode=>:normal,
          :dir=>config[:log_dir]}
        Daemons.daemonize(dopts)
        
        # all those open files are closed?
        # so open the logger again
        if @set_log_daemon then
          log_opts = Jelly::Logger.get_options(config)
          log_opts[:log_level] = :debug if @verbose
          @output = Jelly::Logger.new("#{@klass.to_s.downcase}_sd", log_opts)
        else
          # no logger, so write any messages to /dev/null
          @output = File.open('/dev/null', 'w')
        end
        
      else
        @output.puts "Service is running in the foreground"
      end

      if @no_syslog then
        @output.puts "Disabling messages to syslog"
        Jelly::Logger.disable_syslog
      else
        @output.puts "Sending messages to syslog"
      end

      # now create the pid file
      Jerbil::Support.write_pid_file(@name_symbol, config[:environment], config[:pid_dir])

      @output.puts "Created a pid file for process: #{Process.pid}"

      @service = @klass::Service.new(pkey, config)

      @output.puts "Registered Service with Jerbil"

      @service.wait(pkey)

      @output.puts "Service has stopped"
      
    rescue => err
      puts "Error while starting service: #{err.class.to_s}, #{err.message}"
      puts err.backtrace.join("\n") if @verbose
    end

    # stop a Jerbil Service
    def stop_service

      config = @klass.get_config(@config_file)
      pid = 0
      
      # to test a new jerbil server, this needs to be set to the
      # jerbil server's environment. Only needed for test purposes
      if @jerbil_env then
        config[:jerbil_env] = @jerbil_env
      end

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
        jerbil_server = Jerbil::Servers.get_local_server(config[:jerbil_env])

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
    rescue => err
      @output.puts "Error while stopping service: #{err.message}"
      @output.puts err.backtrace if @verbose
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