#
#
# = install command
#
# == Thor class to install jerbil from its gem
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
# A thor generator that is registered with the Jerbs user command
#
require 'fileutils'

class Installer < Thor::Group
  
  include Thor::Actions
  
  # class_option :verbose, :type=>:boolean, :default=>false, :aliases=>'-V',
  #   :desc=>'output more information about the install'
  # class_option :pretend, :type=>:boolean, :default=>false, :aliases=>'-p',
  #   :desc=>'do not actually install, but show what would happen'
  
  class_option :system, :type=>:boolean, :default=>:false, :desc=>'Do system actions (add users etc)'
  
  add_runtime_options!
    
  Install_dirs = %w{/var/log/jermine /var/run/jermine}
  Install_etc_files = {'init.d/jerbild'=>'init.d/jerbild',
    'conf.d/jerbild'=>'conf.d/jerbild',
    'conf.d/jerbil.rb'=>'jermine/jerbil.rb',
    'conf.d/jerbil-client.rb'=>'jermine/jerbil-client.rb'
  }
  Install_sbin_files = %w{sbin/jerbild sbin/jerbil-stop}
  
  def self.source_root
    File.expand_path('../../..', File.dirname(__FILE__))
  end
    
  def welcome
    say "Welcome to Jerbil"
    say "About to install Jerbil, checking"
    say "Only pretending though!", :yellow if options[:pretend]
  end
    
  def check_install
    quit = false
    unless Process.uid == 1
      say_status "error", "you must be logged in as root", :red
      quit = true
    end
    unless %x(grep '^jermine' /etc/passwd) && $? == 0
      say_status "error", "user jermine does not exist", :red
      quit = true
    end
    unless %x(grep '^jermine' /etc/group) && $? == 0
      say_status "error", "group jermine does not exist", :red
      quit = true
    end
    exit 1 if quit && !options[:pretend]
    say "Installation OK to proceed..."
  end
  
  def create_dirs
    say_status "invoke", "Creating Directories", :white
    Install_dirs.each do |idir|
      
      if FileTest.directory?(idir) then
        say_status "exists", "#{idir}", :blue
      else
        say_status "create", "#{idir}", :green
        empty_directory(idir)
        FileUtils.chown('jermine', 'jermine', idir)
      end
      
    end
  end
  
  def install_etc_files
    say_status "invoke", "Installing files in /etc", :white
    self.destination_root = '/etc'
    Install_etc_files.each_pair do |source, destination|
      copy_file(source, destination)
    end
  end
  
  def install_sbin_files
    say_status "invoke", "Installing files in /usr/sbin", :white
    self.destination_root = '/usr'
    Install_sbin_files.each do |sbin|
      copy_file(sbin)      
    end
  end
  
end