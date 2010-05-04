require 'spatial_adapter'
require 'active_record/connection_adapters/sqlite3_adapter'

ActiveRecord::ConnectionAdapters::SQLite3Adapter.class_eval do
  include SpatialAdapter
  
  def supports_geographic?
    true
  end
  
  alias :original_native_database_types :native_database_types
  def native_database_types
    original_native_database_types.merge!(geometry_data_types)
  end
  
  alias :original_quote :quote
  #Redefines the quote method to add behaviour for when a Geometry is encountered
  def quote(value, column = nil)
    if value.kind_of?(GeoRuby::SimpleFeatures::Geometry)
      "GeomFromWKB(X'#{value.as_hex_ewkb(false, false)}')"
    else
      original_quote(value,column)
    end
  end
  
  #Redefinition of columns to add the information that a column is geometric
  def columns(table_name, name = nil)#:nodoc:
    table_structure(table_name).map do |field|
      if field['type'] =~ /geometry|point|linestring|polygon|multipoint|multilinestring|multipolygon|geometrycollection/i
        ActiveRecord::ConnectionAdapters::SpatialSQLite3Column.new(field['name'], field['dflt_value'], field['type'], field['notnull'] == "0")
      else
        ActiveRecord::ConnectionAdapters::SQLiteColumn.new(field['name'], field['dflt_value'], field['type'], field['notnull'] == "0")
      end
    end
  end
  
  # Adds an index to a column.
  def add_index(table_name, column_name, options = {})
    index_name = options[:name] || index_name(table_name,:column => Array(column_name))
    if options[:spatial]
      execute "CREATE SPATIAL INDEX #{index_name} ON #{table_name} (#{Array(column_name).join(", ")})"
    else
      super
    end
  end
  
  def indexes(table_name, name = nil)#:nodoc:
    indexes = []
    current_index = nil
    execute("SHOW KEYS FROM #{table_name}", name).each do |row|
      if current_index != row[2]
        next if row[2] == "PRIMARY" # skip the primary key
        current_index = row[2]
        indexes << ActiveRecord::ConnectionAdapters::IndexDefinition.new(row[0], row[2], row[1] == "0", row[10] == "SPATIAL",[])
      end
      indexes.last.columns << row[4]
    end
    indexes
  end

end

module ActiveRecord
  module ConnectionAdapters
    class SQLite3TableDefinition < TableDefinition
      attr_reader :geom_columns
      
      def column(name, type, options = {})
        
      end
    end
    
    class SQLite3ColumnDefinition < ColumnDefinition
      attr_accessor :table_name
      attr_accessor :srid, :with_z, :with_m, :geographic
      attr_reader :spatial
      
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class SpatialSQLite3Column < SQLiteColumn
      include SpatialAdapter::SpatialColumn
      
      def self.string_to_geometry(string)
        return string unless string.is_a?(String)
        begin
          GeoRuby::SimpleFeatures::Geometry.from_ewkb(string)
        rescue Exception => exception
          nil
        end
      end
      
    end
  end
end