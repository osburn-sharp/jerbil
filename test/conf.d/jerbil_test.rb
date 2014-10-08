#
# Configuration Options for: Jellog::Config
#
project_root = '/home/robert/dev/projects/jerbil'

# Path to a writeable directory where Jellog will save log files.
#log_dir "/var/log/jerbil"
log_dir "#{project_root}/log"

# Controls the amount of logging done by Jellog
# 
#  * :system - standard message, plus log to syslog
#  * :verbose - more generous logging to help resolve problems
#  * :debug - usually used only for resolving problems during development
# 
log_level :debug

# Number of log files to retain at any time, between 0 and 20
#log_rotation 2

# Size of a log file (in MB) before switching to the next log, upto 20 MB
#log_length 1

# Reset the logfile when starting logging by setting to true, otherwise append to
# existing log
#log_reset false

# Set to false to suppress colourful logging. Default colours can be changed by calling
# #colours= method
#log_coloured true

# Format string for time stamps. Needs to be a string that is recognised by String#strftime
# Any characters not recognised by strftime will be printed verbatim, which may not be what you want
#log_date_time_format "%Y-%m-%d %H:%M:%S"

# Setting to true (the default) will flush log messages immediately, which is useful if you
# need to monitor logs dynamically
#log_sync true

# Set the string to be used for marking the log with logger.mark
#log_mark "   ===== Mark ====="

# Set to true to prevent system log calls from logging to syslog as well
#disable_syslog false

#
# Configuration Options for: JerbilService::Config
#

# Set the environment for the service to run in.
# 
# Can be one of the following:
#   :prod - for productionised services in use across a network 
#   :test - for testing a release candidate, e.g. also across the network
#   :dev - for developing the next release
# 
# Services can be running in all three environments at the same time. Clients
# will need to use the appropriate config file to connect with each environment.
environment :test

# a writable directory where Jerbil stores a private key for each service.
# This key is used to authenticate systems operations, such as stopping the service.
# It is not used for client interactions, which can require a separate service key.
key_dir "#{project_root}/tmp"

# A writable directory used to store the pid to assist in stopping reluctant servers
pid_dir "#{project_root}/tmp"

# Set this only to use a Jerbil Server that is not running in the production environment
#jerbil_env 

#
# Configuration Options for: Jerbil::Config
#

# A valid IPv4 address for the LAN on which the servers will operate.
# Note that the broker uses this address to search for all servers.
# Therefore a large range will take a long time to search. Set the net_mask to limit this.
#net_address "192.168.0.1"

# A valid netmask for the hosts to search using the above net address. This should be
# between 24 (a class C network) and 30, beyound which its not much of a network. If you only have a few
# hosts it will be easier to restrict them to a small subnet.
# 
# To find out more about netmasks, go to [UnixWiz](http://www.unixwiz.net/techtips/netmask-ref.html).
#net_mask 26

# Provide a timeout in seconds when searching for jerbil servers on the net during startup.
# Depending on the size of the net mask this timeout may make the search long.
# The default should work in most cases
#scan_timeout 0.1

# Define how many times the monitor process will check for other servers
# at start up. Limited to at least once and at most 10 times. Probably is not need
# to check more than 3 times unless you set a very short scan timeout.
#check_count 3

# Define the delay between successive checks carried out by the monitor at start up.
# Setting it to 0 will cause the checks to be completed without delay. The upper limit is
# an hour for no particular reason. Default should work for most cases. Could be quicker on smaller
# nets with fewer machines to check each time.
#loop_time 30

# A secret key available to all Jerbil Servers and used to authenticate the initial registration.
# If security is an issue, ensure that this config file is readable only be trusted users
secret "ddd3863fe7ab8506d13c86b797d5ab45496ce00e"

