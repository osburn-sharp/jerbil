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

# install system files where the Gem cannot reach. 
# expects a directory 'etc' in the root of the project and copies
# files/directories from here into /etc. Also copies files from
# sbin.
class Installer < Thor::Group
  
  include Thor::Actions
  
  # class_option :verbose, :type=>:boolean, :default=>false, :aliases=>'-V',
  #   :desc=>'output more information about the install'
  # class_option :pretend, :type=>:boolean, :default=>false, :aliases=>'-p',
  #   :desc=>'do not actually install, but show what would happen'
  
  class_option :system, :type=>:boolean, :default=>:false, :desc=>'Do system actions (add users etc)'
  
  add_runtime_options!
  
  Project = 'Jerbil'
  ProjectRoot = File.expand_path('../../..', File.dirname(__FILE__))
    
  Install_dirs = %w{/var/log/jermine /var/run/jermine}
  # Install_etc_files = {'init.d/jerbild'=>'init.d/jerbild',
  #   'conf.d/jerbild'=>'conf.d/jerbild',
  #   'conf.d/jerbil.rb'=>'jermine/jerbil.rb',
  #   'conf.d/jerbil-client.rb'=>'jermine/jerbil-client.rb'
  # }
  # Install_sbin_files = %w{sbin/jerbild sbin/jerbil-stop}
  
  # set the source root to project root, assuming that this file is
  # in lib/project/thor
  def self.source_root
    ProjectRoot
  end
    
  def welcome
    say "Welcome to #{Project}"
    say "About to install #{Project}, checking"
    say "Only pretending though!", :yellow if options[:pretend]
  end
    
  def check_install
    quit = false
    unless Process.uid == 0 # this is root...
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
  
  # ensure that the standard jerbil-related directories
  # have been installed already, and install them if not
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
  
  # install files that are in the etc directory
  def install_etc_files
    say_status "invoke", "Installing files in /etc", :white
    self.destination_root = '/etc'
    etc_root = 'etc'#File.join(ProjectRoot, 'etc')
    files = {} #gather up all the files
    Dir["#{etc_root}/**"].each do |dir|
      Dir["#{dir}/*"].each do |file|
        dest_file = file.sub(/^[^\/]*\//,'') # trim root from path
        files[file] = dest_file
      end
    end
    
    files.each_pair do |source, destination|
      #say_status source, destination
      copy_file(source, destination)
    end
  end
  
  def install_sbin_files
    say_status "invoke", "Installing files in /usr/sbin", :white
    self.destination_root = '/usr'
    sbin_root = File.join(ProjectRoot, 'sbin')
    Dir["#{sbin_root}/*"].each do |sbin|
      copy_file(sbin)
      chmod(sbin, 0755)
    end
  end
  
end