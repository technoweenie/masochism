module ActiveReload
  class MasterDatabase < ActiveRecord::Base
    self.abstract_class = true
    establish_connection :master_database
  end

  class ConnectionProxy
    def initialize
      @slave   = ActiveRecord::Base.connection
      @master  = ActiveReload::MasterDatabase.connection
      @current = @slave
    end
    
    attr_accessor :slave, :master

    def with_master
      set_to_master!
      yield
    ensure
      set_to_slave!
    end

    def set_to_master!
      @current = @master
    end
    
    def set_to_slave!
      @current = @slave
    end
    
    delegate :insert, :update, :delete, :create_table, :rename_table, :drop_table, :add_column, :remove_column, 
      :change_column, :change_column_default, :rename_column, :add_index, :remove_index, :initialize_schema_information,
      :dump_schema_information, :to => :master
    
    def transaction(start_db_transaction = true, &block)
      with_master { @current.transaction(start_db_transaction, &block) }
    end

    def method_missing(method, *args, &block)
      @current.send(method, *args, &block)
    end
  end
end

class << ActiveRecord::Base
  def inherited_with_master(base)
    base.class_eval do
      def reload(*args, &block)
        connection.with_master { super }
      end
    end
  end
  
  alias_method_chain :inherited, :master
end