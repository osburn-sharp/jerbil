# Jerbil

## Jumpin Ermin's Reliable Broker for Integrated Linux services

An Object Broker for ruby that provides reliable access to services across the LAN and comes complete with a service class
that makes writing services easy, hiding all of the broker interactions.

# Installation

## Installing the Gem

Jerbil is available as a gem, so to get the gem:

    # gem install jerbil
    
Jerbil now needs to be installed on the system, which is done with the help of Jenny (v??):

    # jerbil-install
    
This will install various files over and above those installed by the gem, including configuration files, 
runscripts, and sbin wrappers for the jerbil server and for services that use the server.

## Configuration

The configuration file for the server (jerbil.rb) will be placed in a directory /etc/jermine. As well as checking
the defaults, you need to provide a secret. A random secret can be generated using the jerbil command:

    # jerbil server secret
    
although any long string will do. Full details of the configuration parameters for Jerbil are in {Jerbil::Config}.

## Editting /etc/services

Jerbil uses /etc/services to find its services (unsurprisingly) so this file needs to be updated. There must
be an entry for the server itself, as well as the services that use jerbil. Because Jerbil supports three 
operating environments (dev, test and prod), these services must be assigned in triplets. The following is an example

    # starts from 49195
    #
    jerbil		  49200/tcp	# Jerbil Server
    jerbil-test	49201/tcp
    jerbil-dev	49202/tcp
    
    jexten		  49203/tcp	# Jexten Service - controls CM15pro
    jexten-test	49204/tcp
    jexten-dev 	49205/tcp
    
    tittle		  49206/tcp	# Tittle - Thermostatic Temperature Logger
    tittle-test	49207/tcp
    tittle-dev	49208/tcp
    
    tittledm	    49209/tcp	# Tittle's little device manager service
    tittledm-test	49210/tcp
    tittledm-dev	49211/tcp
    
    jemb		  49212/tcp	# Jumpin' Ermin's Music Box
    jemb-test	49213/tcp
    jemb-dev	49214/tcp

Strictly speaking the intermediate assignments do not need to be defined: Jerbil looks for the first one
and offsets it if either test or dev is selected. They are included here as a reminder that the ports may be used.

## Starting and Stopping the Server

It is now possible to start the Jerbil Server. This can be done using the jerbild script:

    # /usr/sbin/jerbild
    
which will start the server, get the default config file (/etc/jermine/jerbil.rb), daemonise, and say very little.
You can then test that the server is running with:

    # jerbil server
    
If this does not report the server as up, go to the troubleshooting section.

If you can support init scripts, then jerbil is ready to go. Edit /etc/conf.d/jerbild to change settings such as 
where the config file is and then run:

    # /etc/init.d/jerbild start
    # rc-update add jerbild default
    
the latter command works on Gentoo at least.

You can also check if the server is working using:

    # /usr/sbin/jerbil-status -V
    or
    # /etc/init.d/jerbild status
    
To stop the server:

    # /usr/sbin/jerbil-stop
    or
    # /etc/init.d/jerbild stop
    
Further details of all these commands can be obtained with the -h or --help option


# General Description

The function of Jerbil is to make it easy to write linux services in ruby that can be deployed anywhere on 
a network, once or multiple times, and enabling clients to access these services regardless of where they are. Its
a wrapper around DRb and a replacement for Rinda.

A Jerbil Server is required to run on each machine where services are needed or from which they are accessed. 
Each server will discover other servers on the network and register with them, provided they all share the same
secret and are running in the same environment. During registration, new servers will receive details from the other 
servers of all the services that are local to them. This provides a robust and relatively self-healing network where
a server can come and go without needed to restart any of the others.

A Service registers with a server to make its services available. A client then searches the server for the service(s)
it is interested in and receives back all of the matching services known. The client can then connect to each service 
and carry out whatever action is required. The search can controlled, e.g. to return only local services or the first
service or services in a given environment.

Writing a Service is eased by various support classes. The main class is {JerbilService::Base}, which is a generic service
that deals with all of the Jerbil server interactions. By inheriting this class, a service can be created that uses 
Jerbil with only a couple of lines of code.

Controlling a service is also made easy by the {JerbilService::Supervisor} class. This hides all of the actions needed
to start a service. However, service control is made even easier by /usr/bin/jserviced, which starts any service
given that services name, provided the files conform to certain protocols. The /usr/sbin/jservice-status and 
/usr/sbin/jservice-stop commands work in a similar manner.

Writing a client is similarly made easy by the {JerbilService::Client} class, which finds one or more services ready
to be connected to and acted upon.

## Further Reading

* {file:README_SERVICES.md Jerbil Services} A short guide.

# Code Walkthrough

Jerbil is divided into two groups: the server and the services that use the server.

## Servers

The server consists of one main class: {Jerbil::Broker} and two data-type classes: {Jerbil::Servers} and {Jerbil::Service}.
The Broker is the main server code, finding and registering with other servers, accepting and recording services and
responding to queries about registered services. When a service registers with the broker, the broker will also
inform all of the other servers of that service. The {Jerbil::Servers} class is used by the broker to record information
about a server and it provides convenience methods to connect to a server and a class method to find the local
server. The {Jerbil::Service} class fulfils a similar role for services.

Jerbil is intended to be as reliable as possible - to survive any of the servers and their services leaving the network
unexpectedly. If a local client attempts to connect to a remote service and fails, then the server will be asked to check
with {Jerbil::Broker#service_missing?}. This will attempt to contact the service's local server and ask it to check. If
the local server is running, it will check that the service is OK and if not, remove the service and update all the other
servers. If this server is not available (e.g. server has gone down) then the original server will take responsibility
for purging the service from its own records and all the remaining servers.

Jerbil uses Jelly for logging and on :debug level produces copious records to help understand what it is doing.

Jerbil and Jerbil Services use the standard library daemons to run in the background but they keep track of their own pids 
instead of relying on daemon. To stop the server, an attempt is made to call the stop method, which cleans up with all
the other servers, but failing that the pid is used to kill the server.

## Services

Services are created by inheriting the {JerbilService::Base} class:

    module RubyTest
    
      extend JerbilService::Support
    
      class Service < JerbilService::Base
    
        def initialize(pkey, options)
          super(:rubytest, pkey, options)
        end
    
        def action
          @logger.debug("Someone called the action method!")
          return "Hello"
        end
    
      end
    
    end
    
The Base class takes care of Jerbil registration and creates a Jelly logger instance variable. It also provides a stop
method and a verify method.

## Security

Security is currently limited:

* Servers share a secret key, recorded in their config file which should be readable by limited people! They use this 
  key to ensure that registering servers are bona fide.
  
* Each server is given a private key that it shares with the others and checks for all of the remote server methods.
  The same key is also required to stop the server.
  
* A similar key is provided to each service and is required to stop the service. It is up to service writers to decide
  whether to require clients to use this key.
  
The purpose of these checks is largely to protect integrity rather than make Jerbil secure. Jerbil is currently 
targetted at a benign network environment.

## Support


## Dependencies

A ruby compiler - works with 1.8.7.

Check the {file:Gemfile} for other dependencies.

### Documentation

Documentation is best viewed using Yard.

## Testing/Modifying

Details of testing can be found in the {file:README_TESTING.md Testing README}.
    
## Bugs

Details of any unresolved bugs and change requests are in {file:Bugs.rdoc Bugs}

## Changelog

See {file:History.txt} for a summary change history

## Copyright and Licence

Copyright (c) 2012 Robert Sharp

This software is licensed under the terms defined in {file:LICENCE.rdoc}

The author may be contacted by via [GitHub](http://github.com/osburn-sharp) 

## Warranty

This software is provided "as is" and without any express or implied
warranties, including, without limitation, the implied warranties of
merchantibility and fitness for a particular purpose.

