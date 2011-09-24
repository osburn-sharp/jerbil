#
#
# = Jerbil
#
# == Thor helpers
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2011 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
#
#
#
require 'fileutils'

module Jermine
  module Actions
  
    def install_link(target, link, options={})
      pretend = options[:pretend]
      unless FileTest.exists?(target)
        say_status "error", "Missing target file #{target}", :red
        exit 1 unless pretend
      end
      if File.exists?(link) && File.readlink(link) == target then
        say_status "identical", link, :blue
      else
        say_status "linking", "#{link}"
        FileUtils.ln_sf(target, link) unless pretend
      end
    end
    
  end

end