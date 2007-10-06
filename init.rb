require 'active_reload/connection_proxy'
ActiveRecord::Base.active_connections[ActiveRecord::Base.name] = ActiveReload::ConnectionProxy.new