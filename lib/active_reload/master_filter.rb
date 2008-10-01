module ActiveReload
  class MasterFilter
    def self.filter(controller, &block)
      proxy = ActiveRecord::Base.active_connections['ActiveRecord::Base']

      if proxy and proxy.respond_to? :with_master
        proxy.with_master(&block)
      else
        yield block
      end
    end
  end
end