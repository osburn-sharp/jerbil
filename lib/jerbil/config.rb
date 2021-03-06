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

require 'jerbil/jerbil_service/config'


module Jerbil
  
  # Jeckyl config parameters for the Jerbil Server
  #
  # The config file will include all of the parameters defined in {JerbilService::Config}
  # and its parents, such as key directories, logging parameters etc.
  #
  # @see file:lib/jerbil/config.md Jerbil Parameter Descriptions
  # @see file:lib/jerbil/jerbil_service/config.md Jerbil Service Parameter Descriptions
  class Config < JerbilService::Config
    
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
        "between 24 (a class C network) and 30, beyound which its not much of a network. If you only have a few",
        "hosts it will be easier to restrict them to a small subnet.",
        "",
        "To find out more about netmasks, go to [UnixWiz](http://www.unixwiz.net/techtips/netmask-ref.html)."
      in_range(nmask, 24, 30)
    end
    
    def configure_scan_timeout(tim)
      default 0.1
      comment "Provide a timeout in seconds when searching for jerbil servers on the net during startup.",
        "Depending on the size of the net mask this timeout may make the search long.",
        "The default should work in most cases"
        
      a_type_of(tim, Numeric)
    end
    
    def configure_check_count(count)
      default 3
      comment "Define how many times the monitor process will check for other servers",
        "at start up. Limited to at least once and at most 10 times. Probably is not need",
        "to check more than 3 times unless you set a very short scan timeout."
      in_range(count, 1, 10)
    end
    
    def configure_loop_time(delay)
      default 30
      comment "Define the delay between successive checks carried out by the monitor at start up.",
        "Setting it to 0 will cause the checks to be completed without delay. The upper limit is",
        "an hour for no particular reason. Default should work for most cases. Could be quicker on smaller",
        "nets with fewer machines to check each time."
      in_range(delay, 0, 360)
    end
    
    def configure_secret(scrt)
      comment "A secret key available to all Jerbil Servers and used to authenticate the initial registration.",
       "If security is an issue, ensure that this config file is readable only be trusted users"
      a_type_of(scrt, String)
    end
    
  end
end