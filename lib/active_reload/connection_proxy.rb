module ActiveReload
  class MasterDatabase < ActiveRecord::Base
    self.abstract_class = true
    establish_connection configurations[Rails.env]['master_database'] || configurations['master_database'] || Rails.env
  end

  class SlaveDatabase < ActiveRecord::Base
    self.abstract_class = true
    def self.name
      ActiveRecord::Base.name
    end
    establish_connection configurations[Rails.env]['slave_database'] || Rails.env
  end

  class ConnectionProxy
    
    def initialize(master_class, slave_class)
      @master  = master_class
      @slave   = slave_class
      @current = :slave
    end
    
    def master
      @slave.connection_handler.retrieve_connection(@master)
    end
    
    def slave
      @slave.retrieve_connection
    end
    
    def current
      send @current
    end
    
    def self.setup!
      if slave_defined?
        setup_for ActiveReload::MasterDatabase, ActiveReload::SlaveDatabase
      else
        setup_for ActiveReload::MasterDatabase
      end
    end

    def self.slave_defined?
      ActiveRecord::Base.configurations[Rails.env]['slave_database']
    end

    def self.setup_for(master, slave = nil)
      slave ||= ActiveRecord::Base
      slave.send :include, ActiveRecordConnectionMethods
      ActiveRecord::Observer.send :include, ActiveReload::ObserverExtensions
      slave.connection_proxy = new(master, slave)
    end

    def with_master(to_slave = true)
      set_to_master!
      yield
    ensure
      set_to_slave! if to_slave
    end

    def set_to_master!
      unless @current == :master
        @slave.logger.info "Switching to Master"
        @current = :master
      end
    end

    def set_to_slave!
      unless @current == :slave
        @master.logger.info "Switching to Slave"
        @current = :slave
      end
    end

    delegate :insert, :update, :delete, :create_table, :rename_table, :drop_table, :add_column, :remove_column,
      :change_column, :change_column_default, :rename_column, :add_index, :remove_index, :initialize_schema_information,
      :dump_schema_information, :execute, :columns, :to => :master

    def transaction(start_db_transaction = true, &block)
      with_master(start_db_transaction) do
        master.transaction(start_db_transaction, &block)
      end
    end

    def method_missing(method, *args, &block)
      current.send(method, *args, &block)
    end
  end

  module ActiveRecordConnectionMethods
    def self.included(base)
      base.alias_method_chain :reload, :master
      
      class << base
        def connection_proxy=(proxy)
          @@connection_proxy = proxy
        end
        
        # hijack the original method
        def connection
          @@connection_proxy
        end
      end
    end

    def reload_with_master(*args, &block)
      if connection.class.name == "ActiveReload::ConnectionProxy"
        connection.with_master { reload_without_master }
      else
        reload_without_master
      end
    end
  end

  # extend observer to always use the master database
  # observers only get triggered on writes, so shouldn't be a performance hit
  # removes a race condition if you are using conditionals in the observer
  module ObserverExtensions
    def self.included(base)
      base.alias_method_chain :update, :masterdb
    end

    # Send observed_method(object) if the method exists.
    def update_with_masterdb(observed_method, object) #:nodoc:
      if object.class.connection.respond_to?(:with_master)
        object.class.connection.with_master do
          update_without_masterdb(observed_method, object)
        end
      else
        update_without_masterdb(observed_method, object)
      end
    end
  end
end
