#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2014 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
# 
#


module Jerbil
  # Monitors the network for Jerbil servers and reports to the local server
  #
  # Provides a way to decouple the interactions between the jerbil server
  # and other servers on the network to prevent race conditions or
  # holding up start-up while other servers are discovered
  #
  # The Monitor object is intended to be used in a subprocess after creating
  # the main jerbil server. It scans the LAN for other servers and keeps
  # a record of known servers. When a new server is found, it registers it
  # with the local server and also registers each of its services. If a 
  # known server disappears, then it also removes that server (and its services)
  # from the network. If the server left in an orderly manner then it may
  # have already done this, but the server can cope!
  #
  # The subprocess needs to be cleaned up afterwards - does not seem to be possible
  # to either link it with the server's process or tidy up on kill.
  class Monitor
    
    # create the monitor object 
    #
    # @params options [Hash] options hash as for the Jerbil Server
    # @params jkey [String] jerbil servers private key
    def initialize(options, jkey)
      @options = options
      @env = @options[:environment]
      @jerbil_key = jkey
      @local_server = Jerbil::Servers.create_local_server(@env, @jerbil_key)
      @servers = Hash.new
      @servers[@local_server.fqdn] = @local_server
      @log_opts = Jellog::Logger.get_options(options)
      log_opts = @log_opts.dup
      @logger = Jellog::Logger.new('jerbil-monitor', log_opts)
      @logger.system "Started the Jerbil Monitor"
      self.monitor
    end
    
    # start the monitor loop to find and register existing servers
    #
    # Loops round to see what servers are up and adds any that are not
    # already known about. It does this "check_count" times in case it misses
    # a server (the TCP check may not have a long timeout). See
    # 
    # It does one loop every :monitor_loop_time seconds (see {Jerbil::Config})
    #
    def monitor
      # create a monitor thread
      loop_time = @options[:loop_time]
      # loop forever
      ljerbil = @local_server.connect
      
      check_count = @options[:check_count]
      
      check_count.times do |c|
        @logger.info "Starting jerbil server monitor loop: #{c}"
        # set the time until the next loop
        time_to_next_loop = Time.now + loop_time
        # scan the LAN for other monitors
        network_servers = Jerbil::Servers.find_servers(@env, 
          @options[:net_address], 
          @options[:net_mask], 
          @options[:scan_timeout])
        scanned = Array.new
        
        # for each discovered server
        network_servers.each do |nserver|
          
          scanned << nserver.fqdn
          # skip if already known
          next if @servers.has_key? nserver.fqdn
          
          # its new so register with servers
  
          rjerbil = nserver.connect
          unless rjerbil.nil?
            begin
              # register local with remote
              rkey = rjerbil.register_server(@local_server, @options[:secret], @env)
              nserver.set_key(rkey)
              
              # and register remote with local
              ljerbil.register_server(nserver, @options[:secret], @env)
              
              @logger.info "Found server: #{nserver.fqdn}"
              
              # Add to local record - could use jerbil itself?
              @servers[nserver.fqdn] = nserver
              
              
              # now tell my server about these services
              
              rjerbil.get_local_services(rkey).each do |rservice|
                ljerbil.register_remote(@jerbil_key, rservice)
              end
              
            rescue Jerbil::JerbilAuthenticationError
              @logger.fatal "Invalid Secret key registering with #{nserver.fqdn}"
              @servers[nserver.fqdn] = nserver # save it anyway to stop repeated logging
            end
          end
        end
        
        if time_to_next_loop > Time.now then
          @logger.debug "Taking a nap"
          sleep(time_to_next_loop - Time.now)
        end
      
      end # loop

      
    rescue => e
      @logger.exception e
    ensure
      @logger.system "Jerbil Monitor complete and closing down"
      @logger.close
      Process.exit!
    end
    
    
  end
end
