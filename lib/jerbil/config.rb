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
# Define a Jeckyl class to collect parameters from config file into an options hash
# 
require 'jeckyl'
require 'jeckyl/errors'
require 'jerbil/server'

class Jerbil

  class Config < Jeckyl

    def configure_servers(ary)
      comment "Array of Jerbil::Server, one for each server in the system"

      an_array_of(ary, Jerbil::Server)
      
    end

    def configure_log_dir(dir)
      default '/tmp'
      comment "Location for Jelly (logging utility) to save log files"

      a_writable_dir(dir)

    end

    def configure_log_level(lvl)
      default :system
      comment "Controls the amount of logging done by Jelly",
        "",
        " * :system - standard message, plus log to syslog",
        " * :verbose - more generous logging to help resolve problems",
        " * :debug - usually used only for resolving problems during development",
        ""

      lvl_set = [:system, :verbose, :debug]
      a_member_of(lvl, lvl_set)

    end

    # log_rotation === 0..20 files
    def configure_log_rotation(int)
      default 2
      comment "Number of log files to retain at any moment"

      a_type_of(int, Integer) && in_range(int, 0, 20)

    end

    # log_length === 1..20 Mb
    def configure_log_length(int)
      default 1 #Mbyte
      comment "Size of a log file (in MB) before switching to the next log"

      a_type_of(int, Integer) && in_range(int, 1, 20)
      @parameter = int * 1024 * 1024
    end

    def configure_key_file(path)
      comment "private key file used to authenticate privileged users"
      
      a_readable_file(path)
    end

    def configure_pid_dir(path)
      comment "directory used to store the daemons pid to assist in stopping reluctant servers"

      a_writable_dir(path)
    end

  end
  
end
