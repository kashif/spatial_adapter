require 'spatial_adapter'
require 'active_record/connection_adapters/sqlite3_adapter'

ActiveRecord::ConnectionAdapters::SQLite3Adapter.class_eval do
  include SpatialAdapter
  
  def supports_geographic?
    true
  end

end

module ActiveRecord
  module ConnectionAdapters
    class SQLite3TableDefinition < SQLiteAdapter
    end
    
  end
end

module ActiveRecord
  module ConnectionAdapters
    class SpatialiteSQLite3Column < SQLiteColumn
    end
  end
end