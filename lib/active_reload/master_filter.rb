module ActiveReload
  # MasterFilter should be used as an around filter in your controllers that require certain actions to use the Master DB for reads as well as writes
  class MasterFilter
    def self.filter(controller, &block)
      if ActiveRecord::Base.connection.respond_to?(:with_master)
        ActiveRecord::Base.connection.with_master(&block)
      else
        yield block
      end
    end
  end
end