#
#
# = Jerbil Config
#
# == Update to use Jeckyl::Service
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2012 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
#
# 
#

require 'jeckyl/service'
require 'jeckyl'

module Jerbil
  
  # standard service config parameters are all that are needed
  # see Jeckyl::Service for details
  #
  # Updated to find other jerbil servers rather than hard-wire their details in
  class Config < Jeckyl::Service
    
    def configure_net_address(naddr)
      default '192.168.0.1'
      comment "A valid IPv4 address for the LAN on which the servers will operate.",
        "Note that the broker uses this address to search for all servers.",
        "Therefore a large range will take a long time to search. Set the net_mask to limit this."
      a_matching_string(naddr, /\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/)
    end
    
    def configure_net_mask(nmask)
      default 26
      comment "A valid netmask for the hosts to search using the above net address. This should be",
        "between 24 (a class C network) and 30, beyound which its not much of a network. If you only have a few"
        "hosts it will be easier to restrict them to a small subnet"
      in_range(nmask, 24, 30)
    end
    
    def configure_scan_timeout(tim)
      default 0.1
      comment "Provide a timeout when searching for jerbil servers on the net. Depending on the size of the net mask",
        "this timeout may make the search long. The default should work in most cases"
        
      a_type_of(tim, Numeric)
    end
    
    def configure_secret(scrt)
      comment "A secret key available to all Jerbil Servers and used to authenticate the inital registration.",
       "If security is an issue, ensure that this config file is readable only be trusted users"
      a_type_of(scrt, String)
    end
    
  end
end