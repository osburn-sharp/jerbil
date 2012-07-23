# Jerbil

## Jumpin Ermin's Reliable Broker for Integrated Linux services

An Object Broker for ruby that provides reliable access to services across the LAN and comes complete with a service class
that makes writing services easy, hiding all of the broker interactions.

# Installation

Jerbil is available as a gem, so to get the gem:

    gem install jerbil
    
Jerbil now needs to be installed on the system, which is done with the help of Jenny (v??):

    jerbil-install
    
This will install the following:

* **/etc/jermine/jerbil.rb** - the configuration file for Jerbil (see below)
* **/etc/conf.d/jerbild** - the standard config file for the Jerbil initscript
* **/etc/init.d/jerbild** - the initscript to start the Jerbil Server
* **/etc/conf.d/jserviced** - a template to be copied for specific Jerbil Services
* **/etc/init.d/jserviced** - the initscript for Jerbil Services, to be linked to for a specific service
* **/usr/sbin/jerbild** - ruby script to start the Jerbil Server
* **/usr/sbin/jerbil-stop** - ruby script to stop the Jerbil Server
* **/usr/sbin/jserviced** - ruby script to start a specific service
* **/usr/sbin/jservice-stop** - ruby script to stop a specific service
* **/usr/sbin/jservice-status** - ruby script to check the status of a specific service

This installation will also create the following directories if they do not already exist:

* **/etc/jermine** - the default location for all standard Jerbil Service configuration files
* **/var/run/jermine** - the default location for pid files and service keys
* **/var/log/jermine** - the default location for Jerbil Service logs

The installation requires