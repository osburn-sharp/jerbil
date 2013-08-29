# Jerbil Services

A short guide to writing services that use {file:README.md Jerbil}.

## What is Jerbil and why use it?

Jerbil provides a way of finding services available on a network (or standlone PC for that matter)
and connecting with them to use them.

For example, I want to run a video recorder service for each TV-card I have on the network,
and I want to connect these to a central server for scheduling programmes etc. Each service
registers with Jerbil so that a client can easily find where each service is running,
select the one needed and connect to it to schedule a specific recording.

Jerbil provides the Broker to connect services, but it also provides a framework for
writing the services and hides almost all of the inter-processor comms from the
developer. Anyone who has used DRb on its own will know that there is quite a bit of overhead
involved, made more difficult if you are not sure where the service you want will be running.
You can use a service like Rinda, but its not exactly reliable: if the server goes down you have
to restart everything on the network.

## Some Examples of Jerbil Services

* An X10 controller - can be used by multiple applications to control X10 devices.

* A Thermostatic Temperature Logger - logs temperature data from simple sensors and also
provides a thermostat that can be programmed to trigger events by remote users

* A Central Heating Programmer - capable of controlling multiple devices/zones etc
using the above services

* A Media Player that can be controlled from the web

* A Music Player with multiple interfaces (CLI, LIRC, Web) running on multiple PCs to
share music around the house

* A network Disk manager - to show disc status, space etc for the whole network in one
easy location

* A Gentoo Portage Information Service - see what's installed across the network

## Getting Started

### Step 1 - Register your service

Before you start, you need to allocate a port number for your service that will be recognised across
the network. The standard way of doing this is to add it to /etc/services. There are more details
in the main {file:README.md readme}. Make sure this information is consistent across the network.

### Step 2 - Create a service class

The easiest way to develop a service using Jerbil is to inherit the {JerbilService::Base} class.
That way, all of the registration work is done for you without you even having to worry about it.
All you need to worry about is what methods you want your service to offer its clients:

    #(file: lib/my_service.rb)
    require 'jerbil_service/base'
    require 'jerbil_service/support'

    module MyService
    
      # NOTE: make sure you call this class 'Service' if you
      # want to use jerbil's support to run it etc
      #
      class Service < JerbilService::Base
      
        # add some additional support class methods into the mix
        extend JerbilService::Support
      
        def initialize(pkey, options)
        
          # do anything that needs to be done before the 
          # DRb service is started
          
          # example parameter, see below
          @greeting = options[:welcome]
          
          super(:my_service, pkey, options)
          
          # Ready to go
          @logger.info "MyService ready to go"
          
        end
        
        attr_reader :greeting
        
        # a method that your service provides
        def whoami
          return "This is my service"
        end
        
      end
    end
    
In this very simple example, the service is set up with DRb and registered with the Jerbil
server when the parent {JerbilService::Base#initialize initialize} method is called. It also sets up a logger using
Jellog (see dependencies in {file:Gemfile}). After that, clients will be able to find
the service and call its method.

### Step 3 - Create a config class and file

A Jerbil Service expects to be receive a fair few parameters through the options hash passed
into the initialize method. It would be fairly painful to set this hash manually, but luckily
it is not necessary if you use [Jeckyl](https://github.com/osburn-sharp/jeckyl). What
you need to do is to add your own config class that inherits all of the parameters that
Jerbil is expecting to find:

    #(file:lib/my_service/config.rb)
    require 'jerbil_service/config'
    
    module MyService
    
      class Config < JerbilService::Config
      
        # define your parameter methods here
        
        def configure_welcome(greeting)
          default "Hello and Good Day!"
          comment "Define a welcome greeting for users"
          a_string(greeting)
        end
        
      end
    end
    
To find out more about defining parameters, check the Jeckyl documentation on 
[RubyDoc](http://rdoc.info/github/osburn-sharp/jeckyl/frames).

There is no hard rule that requires this file to be named as it is, but if you use
jerbil support (such as jserviced, see below) then this is what it will look for.
Btw, you can create a template for this file using the jeckyl command:

    $ jeckyl klass MyService JerbilService::Config 
    # echoes template to stdout to ensure you are OK with it
    $ jeckyl klass MyService JerbilService::Config > lib/my_service/config.rb

This defines your service-specific parameters and adds them to those that {JerbilService::Base}
is expecting. You now probably want to create a config file itself:

    $ jeckyl config lib/my_service/config.rb -k
    # everything looks OK?
    $ jeckyl config lib/my_service/config.rb -k > test/conf.d/my_service.rb
    
The -k option ensures that all of the parameters for all parents are included in the
config file you have generated. You can now edit the generated config file to tweak
any of the defaults. For example, you probably want to log you development service
to a local directory instead of the system default and set the environment to :dev.

    # Location for Jellog (logging utility) to save log files
    log_dir "/home/user/dev/my_service/log"
    
    # Set the default environment for service commands etc.
    # 
    # Can be one of :prod, :test, :dev
    environment :dev
    
A small warning - this is Ruby, which does not understand things like "~" in paths.
For testing, you may want to define a project_root at the top of the config file and
derive this from the __FILE__ constant. You can check your config file is not going
to cause you problems again with the jeckyl command:

    $ jeckyl check test/conf.d/my_service.rb
    
You should now be ready to launch your service.

### Step 4 - Launch the service

Jerbil provides a very quick way get your new service up and running: the 'jservice' script:

    $ /usr/sbin/jserviced -s my_service -c test/conf.d/my_service.rb
    
This script provides a few options to control the way the service is launched:

* -n, --no-daemon - do not daemonize the service but run it in the foreground

* -l, --log-daemon - log any output from the daemon to its own log-file

* -S, --no-syslog - suppress log messages to syslog, i.e. during development of your service

* -c, --config - use the given config file instead of the default

* -V, --verbose - output more information while setting up the service

* -q, --quite - output no information while setting up the service

Note that jserviced will expect you to follow ruby gem file-naming conventions so that
it can locate your service both during testing and in the wild. In this case that
would mean having a 'lib' directory with a file called 'my_service.rb' containing
the above code.

If you fancy launching your service long-hand, you can use the {JerbilService:Supervisor}
class to help.

### Step 5 - Check the service is working

Use the 'jerbil' command to check that everything is OK:

    $ jerbil services -v
    There are 13 services registered with Jerbil:
      my_service[:prod]@server.network.org:49203
      my_service[prod]@server.network.org:49203 responded

This shows what services are registered and calls each service's {JerbilService::Base#verify verify} method to make sure
it is running. 

There is also a script that can be used to check that a service is running: 'sbin/jservice-status'. Options
are the same as for 'sbin/jserviced' except most of them are ignored.

### Step 6 - Write a Client and run it

Connecting to a service from a client is made easy by {JerbilService::Client#find_services}. This hides all
of the Jerbil interactions and just serves up interfaces as discovered:

    JerbilService::Client.find_services(:local, MyService, client_opts) do |service|

      puts service.greeting
      puts service.whoami
      
    end
    
This will search Jerbil for the first MyService registered and then call the 'whoami'
method. You can also find multiple services with the ':all' option, in which case the
block is called for each retrieved service, or you just find the :first service, which
is useful when you know there is only one on the network.

### Step 7 - Stopping the service

Finally, you will want to stop the service at some point, and better to do this gracefully.
The most direct way is to use 'sbin/jservice-stop', again with the same options as jserviced.
This script uses {JerbilService::Supervisor#stop_service} to do the real work, and you can
use this interface directly if it suits.

## Understanding Services

To develop a service using {JerbilService::Base} you probably need to know a little bit more about
the following:

* Jerbil Conventions
* the options hash, containing various important parameters
* System methods and how to customise them
* Keys and PIDS

### Jerbil Conventions

The Jerbil support infrastructure makes certain assumptions about how a Jerbil Service project
is named and structured. Given a service name (e.g. jexten for an X10 controller), there
should be a module with the same name containing a class called Service that inherits
{JerbilService::Base}, all within the root gem file (e.g. jexten.rb):

(file: jexten.rb)
    module Jexten
    
      class Service < JerblService::Base
      
      end
      
    end
    
In addition, Jerbil expects (by convention) to find a gem subdirectory named after the
service and containing at least the following files:

* errors.rb - defining within the service module a general exception for the service
  and more detailed exceptions inheriting this general exception class.
* version.rb - defining within the service module three constants: Version containing
  a gem standard version string, Version_Date containing a date string in a format 
  that ruby can easily parse into a Date object, and Ident, being a string that combines
  the service name, version and date.
  
Both these files are not strictly required for Jerbil Services but are expected by some
jerbil support gems (not yet available).

### JerbilService Parameters

The {JerbilService::Base} class expects to receive an options hash containing parameters about
the service itself and about the logger that the service will set up. This options hash is
best created using the [Jeckyl gem](https://github.com/osburn-sharp/jeckyl). To make things easier,
Jerbil provides its own {JerbilService::Config} class that defines the expected parameters and inherits
the logger parameters from the [Jellog gem](https://github.com/osburn-sharp/jellog). A full description
of each parameter is available by going to the {JerbilService::Config config class} and following the
'See Also' link.

The main parameter to consider is :environment, which can be one of :dev, :test and :prod. This allows you to run a
production quality service across the network, test a ready-to-release upgrade also across
the network, and develop the next release all in parallel.

### Customising System Methods

The {JerbilService::Base} class provides a number of "system" methods that you may want to interact with.
In general these should not be called directly, which is why they are suffixed with the rather
cumbersome '_callback'. For example, to verify a service, you should use {JerbilService::Client#verify}
which calls the appropriate 'verify_callback' method.

* verify_callback - this is the method called when, e.g. the 'jerbil' command is asked to verify that
the service is running. There should be no need to modify this, but if you do you need to pass in
the service key (see below) because it will be expecting it.

* stop_callback - called to stop the service and deals with de-registering and stopping DRb. You may need to
add other actions before or after these, but be sure to include 'super' in your modified version

* wait - this should not be altered and is used when the service is started - ensuring all the DRb calls
are dealt with in the same scope.

### Keys and PIDs

If you start a service using {JerbilService::Supervisor} (or through sbin/jserviced which uses this interface)
then this will automatically create a private key and save it to the key directory specified in the
config file (see above). This key is required by all of the above system methods and is deleted when you
close the service using the same interface (or sbin/jservice-stop). 

However, when you register the service with Jerbil you get a service key which you can then use as a minor
security check on clients calling your methods. This is stored as part of the {Jerbil::ServiceRecord} 
object, accessed through the 'key' attribute. Users can access the key when connecting to through
{JerbilService::Client} using the {JerbilService::Client#service_key} method. There is protected
method {JerbilService::Base#check_key} which will compare two keys and raise an exception if they
are not the same (logging the event as well).

{JerbilService::Supervisor} will also store the PID of the service when it starts it up, and uses this
PID if it cannot connect to the service when asking it to stop. Its a blunt instrument but a lot quicker
than having to do it manually.

## The Client-Server Interface

A service can provide a set of methods for clients to use, but how does the client use them? Simple.
By using the {JerbilService::Client.find_services} method a block will be invoked with a single variable.
This variable is a "proxy" for the service itself, as well as providing a few extra methods of its own.
In other words, when you invoke a method on this variable, it checks to see if it is a valid method
for the real service, and if it is it calls that method with the parameters passed to it.
DRb takes care of the rest of it.

What you need to bear in mind, however, is that the interface between the client and the server is
always mediated via DRb. This means that variables passed across this interface cannot always be
treated as if they were local. For example, if you obtain an object from a service and then modify it
the original object that the service still controls will be unchanged. This is true most
of the time because Jerbil does not mixin the DRb::DRbUndumped module. However, more
complex objects may still be passed by reference. For a full discussion of this behaviour
read the [DRb Overview](http://ruby-doc.org/stdlib-1.8.7/libdoc/drb/rdoc/DRb.html) in
the standard library.

## Starting Jerbil Services at boot time

Its convenient to start a service automatically, and Jerbil tries to make this easy.
However, what is on offer will probably only work out of the box for Gentoo.

There is only one runscript needed and if you followed the installation instructions
in {file:README.md the readme file} then this will already be installed as /etc/init.d/jerbil
(not jerbild which is the jerbil server itself). Notice that Jerbil Services can be
managed using a "multiplexed" runscript. The runscript for each service is a link
to a common runscript, there is a config file for each service and another common
file for all services.

To set up a service involves the following:

* create a link to /etc/init.d/jerbil for your service, e.g. /etc/init.d/jerbil.my_service
* create a copy of /etc/conf.d/jerbil.service for your service, e.g. /etc/conf.d/jerbil.my_service
  Ensure these two files (init and conf) have the same name.
* edit the conf.d file as required.
* start the service: /etc/init.d/jerbil.my_service start
* add the service to your default runscripts: rc-update add jerbil.my_service default

The variables defined in the main conf.d file (/etc/conf.d/jerbil) are:

* NO_DAEMON - set to true to run the service in the foreground, usually to debug it.
  Defaults to false.
* NO_SYSLOG - suppress messages that would normally be sent to syslog, again usually
  for debug purposes. Defaults to false.
* CONF_FILE - path to the config file for this service. Defaults to whatever the default 
  location is for Jeckyl (e.g. /etc/jerbil/my_service.rb)
* LOG_DAEMON - log the output from the daemon, which covers the startup process before
  the service starts logging itself. By default this will be logged to a file named
  after the service with the suffix _sd added, e.g. /var/log/jerbil/my_service_sd.log
  Defaults to false
* VERBOSE - output more information during the startup process. This does not affect
  the level of logging for the service itself
* SBIN_PATH - the path to the directory where the service is located. This will be set
  to /usr/local/sbin and can be changed to whatever your default location happens to
  be.
* SERVICE_USER - by default, the service user will be a user created when Jerbil was
  installed (jerbil). Change it here if you want someone else. See below for details.
* Universal runscript dependencies are defined by default using rc_use and rc_need.

For each service it is possible to override the above variables and the following
  
* SERVICE_NAME - by default the service name will be determined from the runscript.
  For example, for my_service the runscript should be called jerbil.my_service.
* DESCRIPTION - a one line description that will be displayed during start/stop operations.

Note if you need to add a dependency (see 'man runscript' for details) then you will
need to preserve existing values as well, either explicitly or by adding the variable
to any new definition:

    rc_use="logger net atd"
    rc_need="postgres ${rc_need}"
    
All services are super-user'd to a given user for safety within the runscript. By default this is jerbil
but you can set it to another user as above. 

When setting use and need dependencies remember that services defined as needed will restart this
service when they are restarted. Services that are just used do not restart this service
but will be started before it.

Finally, the generic runscript does not preserve the environment through the su command and
the path will be very limited (by runscript), which is why SBIN_PATH is required. It
does set one environment variable on start with is LANG and that is to help ruby 1.9 applications
that have complex encoding demands. If you need more variables to be set it is suggested
that you create a bespoke runscript and set them up as part of the su command. Inheriting
the environment and passing in a wider path may present security risks.

## Errors and Exceptions

If you define your parameters using Jeckyl and {JerbilService::Config} and check them
with the 'jeckyl check' command you have taken the first step to reducing errors with
you new service. Jerbil tries to keep on going without upsetting its services, so the
only errors you are likely to suffer are:

* {Jerbil::ServiceAlreadyRegistered} if, for example you
 forget to change the environment variable and already have a service running in the
 same environment
* {Jerbil::MissingServer} if the Jerbil Server is not running. Hopefully
 you will only suffer that one if you have forgotten to start the server!
* {Jerbil::InvalidService} if you forgot to register your service in /etc/services.

All of the other exceptions defined by Jerbil should be rarely encountered. There are
three main classes if you want to trap errors generically: JerbilError for all exceptions;
JerbilServiceError for exceptions relating to registering services etc, and JerbilServerError
for those relating to server opertions.





