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
require 'socket'

# Jerbil Service Class
#
# a parent class that provides a basic service framework
#
class JerbilService

  # need to set the following and then call super to execute this code
  #
  # * @service_name - the name you want to use to find this service, as a symbol
  # * @env - one of :dev, :test, :prod
  # 
  def initialize(name, env, options)
    @my_service = Jerbil::Service.new(name, env, :verify_callback, :stop_callback)
    jerbil_server = Jerbil::Service.new(:jerbil)
    # register the service

    # and start it
    DRb.start_service("druby://#{@my_service.address}", self)
    puts "Started service on #{@my_service.address}"
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
    # remove the service
    exit!
  end

end
