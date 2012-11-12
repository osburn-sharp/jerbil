# Jerbil::Config Parameters

The following parameters are defined in {Jerbil::Config} and should be used
in a configuration file. A default config file can be generated using:

    jeckyl config lib/jerbil/config.rb

## Parameters

 * **net_mask**
 
    A valid netmask for the hosts to search using the above net address. This should be
    between 24 (a class C network) and 30, beyound which its not much of a network. If you only have a few
    hosts it will be easier to restrict them to a small subnet.
    
    To find out more about netmasks, go to [UnixWiz](http://www.unixwiz.net/techtips/netmask-ref.html).

    Default: 26

 * **scan_timeout**
 
    Provide a timeout when searching for jerbil servers on the net during startup.
    Depending on the size of the net mask this timeout may make the search long.
    The default should work in most cases

    Default: 0.1

 * **net_address**
 
    A valid IPv4 address for the LAN on which the servers will operate.
    Note that the broker uses this address to search for all servers.
    Therefore a large range will take a long time to search. Set the net_mask to limit this.

    Default: "192.168.0.1"

 * **secret**
 
    A secret key available to all Jerbil Servers and used to authenticate the initial registration.
    If security is an issue, ensure that this config file is readable only be trusted users

    No default set


## See Also

There are also parameters in:

 * {JerbilService::Config}
 * Jelly::Options
