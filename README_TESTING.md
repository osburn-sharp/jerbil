# Jerbil Testing

Testing is generally through rspec, development/test versions of the Jerbil server, and service mocks.

## Basic tests

The following basic rspec tests should be run (all in spec/)

* jerbil_local_spec - set up a server and register a local service
* jerbil_remote_spec - set up a server and register a remote service (as if another server)
* jerbil_missing_spec - set up a server, register a remote service (or not) and check if it is missing
* server_spec - test the Servers interface using a local server - a local record that assists in connecting 
  to real servers
* service_spec - test the Service interface - local records for services known to the server

The following tests require a jerbil server to be started separately:

    $ export RUBYLIB="lib"
    $ sbin/jerbild -c test/conf.d/jerbil_test.rb
    #do the tests
    $ rspec spec/jerbil_daemonised/jerbil_local_spec.rb
    $ rspec spec/jerbil_daemonised/jerbil_remote_spec.rb
    #stop the server
    $ sbin/jerbil-stop -c test/conf.d/jerbil_test.rb
    
The following tests require the RubyTest service to be started as well:

    $ export RUBYLIB="lib:test/lib"
    $ sbin/jerbild -c test/conf.d/jerbil_test.rb
    $ sbin/jserviced -c test/conf.d/ruby_test.rb -s ruby_test -V
    $ rspec spec/jerbil_client_spec.rb
    $ sbin/jservice-stop -c test/conf.d/ruby_test.rb -s ruby_test -V
    $ sbin/jerbil-stop -c test/conf.d/jerbil_test.rb
    
## Dev and Test servers

Jerbil can be run with dev and test servers in parallel with any production server. To access these servers requires
the :jerbil_env parameter to be set to the required value. This is how the rubytest service operates, so check out
the config file above.

Testing Jerbil across the network is best done using git to clone the jerbil files, and then running the RubyTest tests
described above. To check the status of a server, use the jerbil command:

    $ jerbil services -c test/conf.d/jerbiltest.rb
    
    $ jerbil services -c test/conf.d/jerbiltest.rb -v
  
