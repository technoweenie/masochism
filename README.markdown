masochism
=========

The masochism plugin provides an easy solution for Ruby on Rails applications to work in a
replicated database environment. It works by replacing the `connection` object accessed by
ActiveRecord models by ConnectionProxy that chooses between master and slave when
executing queries. Generally all writes go to master.


Quick setup
-----------

First, setup your database.yml:

    # default configuration (slave)
    production: &defaults
      adapter: mysql
      database: app_production
      username: webapp
      password: ********
      host: localhost

    # setup for masochism (master)
    master_database:
      <<: *defaults
      host: master.example.com

To enable masochism, this is required:

    # enable masochism
    ActiveReload::ConnectionProxy.setup!

Example usage:
    
    # in environment.rb
    config.after_initialize do
      if Rails.env.production?
        ActiveReload::ConnectionProxy::setup!
      end
    end


Considerations
--------------

### Litespeed web server

If you are using the Litespeed web server, child processes are initialized on creation,
which means any setup done in an environment file will be effectively ignored. [A brief
discussion of the problem is posted here](http://litespeedtech.com/support/wiki/doku.php?id=litespeed_wiki:rails:memcache).

One solution for Litespeed users is to check the connection at your first request and do
the `setup!` call if your connection hasn't been initialized, like:

    # in ApplicationController
    prepend_before_filter do |controller|
      unless ActiveRecord::Base.connection.is_a? ActiveReload::ConnectionProxy
        ActiveReload::ConnectionProxy.setup!
      end
    end


Advanced
--------

The ActiveReload::MasterDatabase model uses a 'master_database' setting that can either be
defined for all of your environments, or for each environment as a nested declaration.

The ActiveReload::SlaveDatabase model uses a 'slave_database' setting that can only be
defined per environment.

Example:

    login: &login
      adapter: postgresql
      host: localhost
      port: 5432
    
    production:
      database: production_slave_database_name
      <<: *login
    
    master_database:
      database: production_master_database_name
      <<: *login
    
    staging:
      database: staging_database_name
      host: slave-db-pool.local
      <<: *login
      master_database: 
        database: staging_database_name
        host: master-db-server.local
        <<: *login
    
    qa:
      database: qa_master_database_name
      host: qa-master
      <<: *login
      slave_database:
        database: qa_slave_database_name
        host: qa-slave
        <<: *login
    
    development: # Does not use masochism
      database: development_database_name
      <<: *login
 
If you want a model to always use the Master database, you can inherit
`ActiveReload::MasterDatabase`. Any models with their own database connection will not be
affected.

### More control at setup

By default, masochism `setup!` is a shorthand for this:

    ActiveReload::ConnectionProxy.setup_for ActiveReload::MasterDatabase, ActiveRecord::Base

The first argument is the model that has the master database connection established; the
second argument is the model whose `connection` gets hijacked by ConnectionProxy. But we
don't have to touch `ActiveRecord::Base` at all:

    # set up MyMaster's connection as the master database connection for User:
    ActiveReload::ConnectionProxy.setup_for MyMaster, User

### The controller filter

If you have any actions you know require the master database for both reads and writes,
simply do the following:

    # in a controller:
    around_filter ActiveReload::MasterFilter, :only => [:show, :edit, :update]
