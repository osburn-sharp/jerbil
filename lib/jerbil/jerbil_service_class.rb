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
require 'jerbil/service'
require 'jerbil/errors'
require 'jerbil/config'
require 'socket'
require 'drb'

# Jerbil Service Class
#
# a parent class that provides a basic service framework
#
class JerbilService

  # general service class to be inherited to create jerbil-compatible services
  # Also sets up a Jelly logger
  #
  # * name - symbol for the service needs to correspond with /etc/services
  # * env - any of :dev, :test, :prod to allow multiple services at once
  # * options - hash that should include:
  #   * log_dir - writeable directory into which jelly places logs
  #   * log_level - :system, :verbose, :debug (see Jelly)
  #   * log_rotation - number of log files to keep
  #   * log_length - size of log files (in bytes)
  #   * jerbil_config - the config file for Jerbil - defaults to /etc/jerbil/config
  #   * exit_on_stop - set to false to prevent the stop method invoking exit! For testing.
  #
  # There is a Jeckyl config class defined as a template that includes these options.
  # 
  def initialize(name, env, options)
    @name = name.to_s.capitalize

    # start up a logger
    @logger = Jelly.new(@name, options[:log_dir], false, options[:log_rotation], options[:log_length])
    @logger.log_level = options[:log_level]

    @exit = options[:exit_on_stop]

    begin
      # get the local jerbil server record
      jerbil_config_file = options[:jerbil_config] || '/etc/jerbil/config'
      jerbil_config = Jerbil::Config.new(jerbil_config_file)

    rescue Jeckyl::JeckylError =>jerr
      @logger.fatal("Error reading config file: #{jerr.message}")
      raise Jerbil::ServiceConfigError
    rescue Exception => err
      @logger.fatal("Unexpected error raised while configuring service: #{err.message}")
    end

    begin
      @my_service = Jerbil::Service.new(name, env, :verify_callback, :stop_callback)
      # and start it
      DRb.start_service(@my_service.drb_address, self)

      # register the service
      @jerbil_server = Jerbil::Server.get_local_server(jerbil_config[:servers])

      # now connect to it
      jerbil = @jerbil_server.connect

      # and register self
      jerbil.register(@my_service)

    rescue Jerbil::JerbilServiceError =>jerr
      @logger.fatal("Error with Jerbil Service: #{jerr.message}")
      raise
    rescue Jerbil::ServerConnectError
      @logger.fatal("Error connecting to Jerbil Server")
      raise
    rescue DRb::DRbConnError =>derr
      @logger.fatal("Error setting up DRb Server: #{derr.message}")
      raise Jerbil::ServerConnectError
    end

    @logger.system "Started service on #{@my_service.address}"
  end

  attr_reader :my_service

  # this is used by callers just to check that the service is running
  # if caller is unaware of the key, this will fail
  def verify_callback(key="")
    raise InvalidServiceKey if key != @my_service.key
    return true
  end

  # used to stop the service
  def stop_callback(key="")
    raise InvalidServiceKey if key != @my_service.key
    # deregister
    jerbil = @jerbil_server.connect
    jerbil.remove(@my_service)
    # remove the service
    exit! if @exit
  end

end
