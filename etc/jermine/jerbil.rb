# directory used to store the daemons pid to assist in stopping reluctant servers
pid_dir "/var/run/jermine"

env = :prod
environment env

# Number of log files to retain at any moment
#log_rotation 2

# Location for Jelly (logging utility) to save log files
log_dir "/var/log/jermine"

# Size of a log file (in MB) before switching to the next log
#log_length 1

# Controls the amount of logging done by Jelly
# 
#  * :system - standard message, plus log to syslog
#  * :verbose - more generous logging to help resolve problems
#  * :debug - usually used only for resolving problems during development
# 
log_level :debug

# Array of Jerbil::Server, one for each server in the system
# use openssl to greate a key and take a line from this. e.g.
#  openssl genrsa -des3 -out /tmp/key 2048
require 'jerbil/server'

my_servers = Array.new
my_servers << Jerbil::ServerRecord.new("lucius.osburn-sharp.ath.cx","Amz09+C8GqQ+StC9wbPEKE2dm5WbOxLVXM+McvxnJ7QM17qcnYshzF0zFOGK", env)
my_servers << Jerbil::ServerRecord.new("germanicus.osburn-sharp.ath.cx","2lR3hsR8mrpcQ8GfN7Tpukwt15/u1Npctp1owQt89jLEZEbpOZWmK/C1aQW4", env)
my_servers << Jerbil::ServerRecord.new("octavia.osburn-sharp.ath.cx","WJbgpOfYOBjlSjcPGyheouPBIJNwhJrKmIqUFly5oLBaHJ8NtI1nhTDrk5p3", env)
my_servers << Jerbil::ServerRecord.new("antonia.osburn-sharp.ath.cx","gpbYk9BEcmyO4xZfZuwu1/Nkd6Dnxjo+INRtrkBmGEQUq3KYi7NfBVW4pfGV", env)
my_servers << Jerbil::ServerRecord.new("valeria.osburn-sharp.ath.cx","V05+VKO0rxNm0qz0BqfJKaAyxZOO1YsyXnYknE3PmzKJg5tbUFsz39YA12LJ", env)
my_servers << Jerbil::ServerRecord.new("aurelius.osburn-sharp.ath.cx","F9uOyptcP6XT9FnJCI1RpPKXhqakz95tI2kxmKU6JwMQ2slVtPQkRk4t11TGqtt7", env)

servers my_servers

# private key file used to authenticate privileged users
key_dir "/var/run/jermine" 

