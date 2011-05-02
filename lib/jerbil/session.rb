#
# Description
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2011 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
# 
#
require 'jerbil/service'

# provide a session to access Jerbil data
#
class Session


  # pass in the stored services
  def initialize(store)
    @store = store
  end

  def count
    @store.length
  end

    # add a service to the local server
  def register(service)
    @store << service
  end

  # remove a service from the register
  def remove(service)

  end

  # loop through every service registered with Jerbil
  def each_service(&block)
    @store.each do |service|
      yield(service)
    end
  end

  # get the services that match the given criteria
  # args has to be a hash of options
  def find(args)
    options = {:name=>nil, :port=>nil, :env=>nil, :pid=>nil}.merge(args)
    pattern = Jerbil::ServiceRecord.new(options[:name], options[:port], options[:env], options[:pid])
    results = Array.new
    @store.each do |service|
      results << service if service == pattern
    end
    return results
  end


end
