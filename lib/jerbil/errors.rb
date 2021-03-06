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

module Jerbil

  # general error type
  class JerbilError < RuntimeError; end

  # create a class for all service related errors
  class JerbilServiceError < JerbilError; end

  # error while trying to connect to a Jerbil-registered service
  class ServiceConnectError < JerbilServiceError; end

  # the service being registered is not in /etc/services
  class InvalidService < JerbilServiceError; end

  # the config file used by the service raised an error
  class ServiceConfigError < JerbilServiceError; end

  # the key used was not the key created for this service
  class InvalidServiceKey < JerbilServiceError; end

  # there is no callback defined where one should be
  class ServiceCallbackMissing < JerbilServiceError; end

  # there is already a service with these details registered with the Jerbil Server
  class ServiceAlreadyRegistered < JerbilServiceError; end

  # the service being registered is not local
  class ServiceNotLocal < JerbilServiceError; end

  # tried to do something to a service without access
  class UnauthorizedMethod < JerbilServiceError; end

  # there is no service
  class ServiceNotFound < JerbilServiceError; end

  # create a class for all server related errors
  class JerbilServerError < JerbilError; end
  
  # authentication of a server etc failed
  class JerbilAuthenticationError < JerbilError; end

  # error in the jerbil config file
  class JerbilConfigError < JerbilServerError; end
  
  # no jerbil service
  class MissingJerbilService < JerbilServerError; end

  # failed to find the server in the list of servers provided in config
  class MissingServer < JerbilServerError; end

  # error while trying to connect to a Jerbil Server
  class ServerConnectError < JerbilServerError; end

  # the server key provided for a remote operation does not match any known server
  class InvalidServerKey < JerbilServerError; end

  # the master key provided for a system operation does not match this master key
  class InvalidPrivateKey < JerbilServerError; end

end
