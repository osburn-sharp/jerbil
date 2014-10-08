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
require 'jerbil/errors'
require 'jerbil/config'
require 'digest/sha1'
require 'fileutils'
require 'socket'

module Jerbil

  #
  # Set of utilities to assist in managing Jerbil services. Used largely by JerbilService
  # modules and classes
  #
  module Support

    # create a pid file for the given service and env in the given pid_dir
    #
    # @param [Symbol] name of the service
    # @param [Symbol] env the services is running in
    # @param [String] pid_dir path to directory where pid file is to be written
    # @return [String] the pid
    # @raise [Jerbil::ServiceConfigError] if the pid file cannot be written to
    def Support.write_pid_file(name, env, pid_dir, pid=Process.pid)
      #pid = Process.pid.to_s
      pid_file = "#{pid_dir}/#{name.to_s}-#{env}.pid"
      FileUtils.rm_f(pid_file) if File.exists?(pid_file) # avoid permissions probs
      File.open(pid_file, "w") do |pfile|
        pfile.puts pid.to_s
      end
      return pid.to_s
    rescue Errno::ENOENT
      # failed to write pid to file
      raise Jerbil::ServiceConfigError, "Cannot write pid file: #{pid_file}"
    end

    # retrieve the pid from a perviously created pid file
    #
    # @param (see Support.write_pid_file)
    # @return [Integer] the pid from the pid file
    def Support.get_pid_from_file(name, env, pid_dir)
      pid_file = "#{pid_dir}/#{name.to_s}-#{env}.pid"
      pid = File.read(pid_file).chomp
      return pid.to_i
    rescue
      # something went wrong so return 0
      return 0
    end

    # (see Support.get_pid_from_file)
    # @note This deletes the pid file as well
    def Support.get_pid_and_delete_file(name, env, pid_dir)
      pid = get_pid_from_file(name, env, pid_dir)
      if pid > 0 then
        # there is a pid, so delete it
        pid_file = "#{pid_dir}/#{name.to_s}-#{env}.pid"
        FileUtils.rm_f(pid_file)
      end
      return pid
    rescue
      # hmm. something went wrong, but do I ignore it
      return 0
    end

    # create a private key, save it to a key file in the given directory and return it
    #
    # Private keys should be created by the daemon start script and used to supervise
    # the service (e.g. stop)
    #
    # @param [Symbol] name of the service
    # @param [Symbol] env the services is running in
    # @param [String] key_dir path to directory where key file is to be written  
    # @return [String] the private key
    # @raise [Jerbil::ServiceConfigError] if the key file cannot be written to
    def Support.create_private_key(name,  env, key_dir)
      key = Digest::SHA1.hexdigest(Time.now.to_s + rand(12341234).to_s)[1..20]
      key_file = "#{key_dir}/#{name.to_s}-#{env}.asc"
      FileUtils.rm_f(key_file) if File.exists?(key_file) # avoid permissions probs
      File.open(key_file, "w") do |kfile|
        kfile.puts key
      end
      return key
    rescue Errno::ENOENT
      # failed to write pid to file
      raise Jerbil::ServiceConfigError, "Cannot write key file: #{key_file}"
    end

    # return a previously saved private key
    #
    # @param (see Support.create_private_key)
    # @return (see Support.create_private_key)
    def Support.get_private_key(name, env, key_dir)
      key_file = "#{key_dir}/#{name.to_s}-#{env}.asc"
      key = File.read(key_file).chomp
      return key
    rescue
      return ''
    end

    # (see Support.get_private_key)
    # @note This deletes the key file
    def Support.get_key_and_delete_file(name, env, key_dir)
      key = get_private_key(name, env, key_dir)
      if key != '' then
        # there is a key file, so delete it
        key_file = "#{key_dir}/#{name.to_s}-#{env}.asc"
        FileUtils.rm_f(key_file)
      end
      return key
    rescue
      # hmm. something went wrong, but do I ignore it
      return ''

    end

  end

  # General support methods for Jerbil itself

  # get the Jerbil config options
  #
  # This will create a hash of the Jerbil Server config options from either
  # the given config file or, if none is provided, the default file. The
  # location of the default file is currently defined by the Jeckyl gem as the
  # default location for all Jeckyl config files.
  #
  # @note This method is used to get the environment for the Jerbil Server
  #  and therefore find the server.
  #
  # @param [String] config_file path to jerbil config file
  # @return [Hash] of config options
  # @raise [Jerbil::JerbilConfigError] if there was any error reading the file
  def Jerbil.get_config(config_file=nil)
     # check that the config_file has been specified
    if config_file.nil? then
      # no, so set the default
      config_file = File.join(Jeckyl.config_dir, "/jerbil.rb")
    end

    # read the config file
    return Jerbil::Config.new(config_file)

  rescue Jeckyl::JeckylError =>err
    # something went wrong with the config file
    raise Jerbil::JerbilConfigError, err.message
  end


end
