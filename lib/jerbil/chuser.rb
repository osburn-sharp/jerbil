#
#
# = Jerbil Support
#
# == Change User ID if possible
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2012 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
#
# Support method to change the current user or raise exceptions
#

module Jerbil
  
  module Chuser
    
    # change the current user and group to the one specified, if possible
    # returns true if it worked, false otherwise
    def self.change(user)
      return false unless user # may not be a user to change to
      return false unless Process.uid == 0 # not root so cannot change anyway
      new_user = Etc.getpwnam(user)
      new_uid = new_user.uid
      new_gid = new_user.gid
      
      # change group first, while still root!
      Process::Sys.setgid(new_gid)
      
      Process::Sys.setuid(new_uid)
      return true
    rescue ArgumentError
      # no such user, so ignore it
      return false
    rescue Errno::EPERM
      # did not have permission to change user
      return false
    end
    
  end
  
end