# JerbilService::Config Parameters

The following parameters are defined in {JerbilService::Config} and should be used
in a configuration file. A default config file can be generated using:

    jeckyl config lib/jerbil/jerbil_service/config.rb

## Parameters

 * **environment**
 
    Set the environment for the service to run in.
    
    Can be one of the following:
      :prod - for productionised services in use across a network 
      :test - for testing a release candidate, e.g. also across the network
      :dev - for developing the next release
    
    Services can be running in all three environments at the same time. Clients
    will need to use the appropriate config file to connect with each environment.

    Default: :prod

 * **key_dir**
 
    a writable directory where Jerbil stores a private key for each service.
    This key is used to authenticate systems operations, such as stopping the service.
    It is not used for client interactions, which can require a separate service key.

    Default: "/var/run/jerbil"

 * **jerbil_env**
 
    Set this only to use a Jerbil Server that is not running in the production environment

    No default set

 * **pid_dir**
 
    A writable directory used to store the pid to assist in stopping reluctant servers

    Default: "/var/run/jerbil"

## Additional Parameters from Jellog::Config

The following additional parameters are defined in Jellog::Config, which
is an ancestor of this config class. See separate documentation for more details.

### Parameters

 * **disable_syslog**
 
    Set to true to prevent system log calls from logging to syslog as well

    Default: false

 * **log_date_time_format**
 
    Format string for time stamps. Needs to be a string that is recognised by String#strftime
    Any characters not recognised by strftime will be printed verbatim, which may not be what you want

    Default: "%Y-%m-%d %H:%M:%S"

 * **log_rotation**
 
    Number of log files to retain at any time, between 0 and 20

    Default: 2

 * **log_length**
 
    Size of a log file (in MB) before switching to the next log, upto 20 MB

    Default: 1

 * **log_dir**
 
    Path to a writeable directory where Jellog will save log files.

    Default: "/var/log/jellog"

 * **log_coloured**
 
    Set to false to suppress colourful logging. Default colours can be changed by calling
    #colours= method

    Default: true

 * **log_sync**
 
    Setting to true (the default) will flush log messages immediately, which is useful if you
    need to monitor logs dynamically

    Default: true

 * **log_level**
 
    Controls the amount of logging done by Jellog
    
     * :system - standard message, plus log to syslog
     * :verbose - more generous logging to help resolve problems
     * :debug - usually used only for resolving problems during development
    

    Default: :system

 * **log_reset**
 
    Reset the logfile when starting logging by setting to true, otherwise append to
    existing log

    Default: false

 * **log_mark**
 
    Set the string to be used for marking the log with logger.mark

    Default: "   ===== Mark ====="

