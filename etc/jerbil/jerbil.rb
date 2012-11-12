#
# Configuration Options for: Jelly::Options
#

# Number of log files to retain at any time, between 0 and 20
#log_rotation 2

# Location for Jelly (logging utility) to save log files
#log_dir "/var/log/jerbil"

# Set the string to be used for marking the log with logger.mark
#log_mark "   ===== Mark ====="

# Reset the logfile when starting logging by setting to true, otherwise append to
# existing log
#log_reset false

# Setting to true (the default) will flush log messages immediately, which is useful if you
# need to monitor logs dynamically
#log_sync true

# Size of a log file (in MB) before switching to the next log, upto 20 MB
#log_length 1

# Format string for time stamps. Needs to be a string that is recognised by String.strftime
# Any characters not recognised by strftime will be printed verbatim, which may not be what you want
#log_date_time_format "%Y-%m-%d %H:%M:%S"

# Controls the amount of logging done by Jelly
# 
#  * :system - standard message, plus log to syslog
#  * :verbose - more generous logging to help resolve problems
#  * :debug - usually used only for resolving problems during development
# 
#log_level :system

# Set to false to suppress colourful logging. Default colours can be changed by calling
# colours= method
#log_coloured true

#
# Configuration Options for: JerbilService::Config
#

# private key dir used to authenticate privileged users
#key_dir "/var/run/jerbil"

# Set the default environment for service commands etc.
# 
# Can be one of :prod, :test, :dev
#environment :prod

# Set this only to use a Jerbil Server that is not running in the production environment
#jerbil_env 

# directory used to store the daemons pid to assist in stopping reluctant servers
#pid_dir "/var/run/jerbil"

#
# Configuration Options for: Jerbil::Config
#

# A secret key available to all Jerbil Servers and used to authenticate the initial registration.
# If security is an issue, ensure that this config file is readable only be trusted users
secret "hK78l/z1mIDBOs+/Qx2q7k5beExChmdc3tpw81qTBNLmcQknRrY93oHzIAd3DNo2"

# A valid netmask for the hosts to search using the above net address. This should be
# between 24 (a class C network) and 30, beyound which its not much of a network. If you only have a few
# hosts it will be easier to restrict them to a small subnet.
# 
# To find out more about netmasks, go to [UnixWiz](http://www.unixwiz.net/techtips/netmask-ref.html).
#net_mask 26

# Provide a timeout when searching for jerbil servers on the net during startup.
# Depending on the size of the net mask this timeout may make the search long.
# The default should work in most cases
#scan_timeout 0.1

# A valid IPv4 address for the LAN on which the servers will operate.
# Note that the broker uses this address to search for all servers.
# Therefore a large range will take a long time to search. Set the net_mask to limit this.
#net_address "192.168.0.1"

