# JerbilService Parameters
The following parameters are defined in JerbilService::Config and should be used
in a configuration file. This file can be generated using:

    jeckyl generate config /home/robert/dev/projects/jerbil/lib/jerbil/jerbil_service/config.rb


**Warning**: there is more than one config class to choose from. The above
command will prompt you to add a classname. To generate a config file for this class
type:

    jeckyl generate config ./lib/jerbil/jerbil_service/config.rb JerbilService::Config

## Parameters

 * **exit\_on\_stop**
 
    Boolean - set to false to prevent service from executing exit! on stop

 * **environment**
 
    Set the default environment for service commands etc.
    
    Can be one of :prod, :test, :dev

 * **jerbil_env**
 
    Set this only to use a Jerbil Server that is not running in the production environment

 * **mark**
 
    Set the string to be used for marking the log with logger.mark

 * **sync**
 
    Setting to true (the default) will flush log messages immediately, which is useful if you
    need to monitor logs dynamically

 * **log_reset**
 
    Reset the logfile when starting logging by setting to true, otherwise append to
    existing log

 * **log_coloured**
 
    Set to false to suppress colourful logging. Default colours can be changed by calling
    colours= method

 * **key_dir**
 
    private key dir used to authenticate privileged users

 * **log_dir**
 
    Location for Jelly (logging utility) to save log files

 * **log_rotation**
 
    Number of log files to retain at any time, between 0 and 20

 * **log_date_time_format**
 
    Format string for time stamps. Needs to be a string that is recognised by String.strftime
    Any characters not recognised by strftime will be printed verbatim, which may not be what you want

 * **pid_dir**
 
    directory used to store the daemons pid to assist in stopping reluctant servers

 * **user**
 
    the name of the valid system user to which a service should switch when being started

 * **log_level**
 
    Controls the amount of logging done by Jelly
    
     * :system - standard message, plus log to syslog
     * :verbose - more generous logging to help resolve problems
     * :debug - usually used only for resolving problems during development
    

 * **log_length**
 
    Size of a log file (in MB) before switching to the next log, upto 20 MB

