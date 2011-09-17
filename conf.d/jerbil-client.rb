# provide Jerbil configuration information for a client calling Jerbil

env = :prod
environment env


# Array of Jerbil::Server, one for each server in the system
require 'jerbil/server'

my_servers = Array.new
my_servers << Jerbil::ServerRecord.new("lucius.osburn-sharp.ath.cx","Amz09+C8GqQ+StC9wbPEKE2dm5WbOxLVXM+McvxnJ7QM17qcnYshzF0zFOGK", env)
my_servers << Jerbil::ServerRecord.new("germanicus.osburn-sharp.ath.cx","2lR3hsR8mrpcQ8GfN7Tpukwt15/u1Npctp1owQt89jLEZEbpOZWmK/C1aQW4", env)
my_servers << Jerbil::ServerRecord.new("octavia.osburn-sharp.ath.cx","WJbgpOfYOBjlSjcPGyheouPBIJNwhJrKmIqUFly5oLBaHJ8NtI1nhTDrk5p3", env)
my_servers << Jerbil::ServerRecord.new("antonia.osburn-sharp.ath.cx","gpbYk9BEcmyO4xZfZuwu1/Nkd6Dnxjo+INRtrkBmGEQUq3KYi7NfBVW4pfGV", env)
my_servers << Jerbil::ServerRecord.new("valeria.osburn-sharp.ath.cx","V05+VKO0rxNm0qz0BqfJKaAyxZOO1YsyXnYknE3PmzKJg5tbUFsz39YA12LJ", env)

servers my_servers


