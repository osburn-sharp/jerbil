project_root = '/home/robert/dev/projects/jerbil'
env = :test
environment env

# directory used to store the daemons pid to assist in stopping reluctant servers
pid_dir "#{project_root}/test/pids"

# Number of log files to retain at any moment
#log_rotation 2

# Location for Jellog (logging utility) to save log files
log_dir "#{project_root}/log"

# Size of a log file (in MB) before switching to the next log
#log_length 1

# Controls the amount of logging done by Jellog
# 
#  * :system - standard message, plus log to syslog
#  * :verbose - more generous logging to help resolve problems
#  * :debug - usually used only for resolving problems during development
# 
log_level :debug

# private key file used to authenticate privileged users
key_dir "#{project_root}/test/pids"

#user 'robert'


# netmask
net_address '192.168.0.1'
net_mask 26
scan_timeout 0.1
secret '123456789=[]'