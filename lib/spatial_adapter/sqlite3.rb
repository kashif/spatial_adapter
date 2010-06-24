require 'spatial_adapter'
require 'active_record/connection_adapters/sqlite3_adapter'

class ActiveRecord::ConnectionAdapters::SQLite3Adapter

  def initialize(connection, logger, config)
    super(connection, logger, config)
    @config = config
    @connection.enable_load_extension(1)
    #@connection.load_extension('libspatialite.so.2')
    execute("SELECT load_extension('libspatialite.so.2')")
  end

end

ActiveRecord::ConnectionAdapters::SQLite3Adapter.class_eval do
  include SpatialAdapter
  
  def opengis_version
    begin
      select_value("SELECT spatialite_version()")
    rescue ActiveRecord::StatementInvalid
      nil
    end
  end
  
  def opengis_major_version
    version = opengis_version
    version ? version.scan(/^(\d)\.\d\.\d$/)[0][0].to_i : nil
  end
  
  def opengis_minor_version
    version = opengis_version
    version ? version.scan(/^\d\.(\d)\.\d$/)[0][0].to_i : nil
  end
  
  def spatial?
    !opengis_version.nil?
  end
  
  def supports_geographic?
    opengis_major_version > 1 || (opengis_major_version == 1 && opengis_minor_version >= 5)
  end
  
  alias :original_native_database_types :native_database_types
  def native_database_types
    original_native_database_types.merge!(geometry_data_types)
  end

  alias :original_quote :quote
  #Redefines the quote method to add behaviour for when a Geometry is encountered
  def quote(value, column = nil)
    if value.kind_of?(GeoRuby::SimpleFeatures::Geometry)
      "'#{value.as_hex_ewkb}'"
    else
      original_quote(value,column)
    end
  end

  def columns(table_name, name = nil) #:nodoc:
    raw_geom_infos = column_spatial_info(table_name)
    table_structure(table_name).collect do |field|
      name, default, type, notnull = field['name'], field['dflt_value'], field['type'], field['notnull'].to_i == 0
      case type
      when /geography/i
        ActiveRecord::ConnectionAdapters::SpatialSQLiteColumn.create_from_geography(name, default, type, notnull)
      when /geometry/i
        raw_geom_info = raw_geom_infos[name]
        if raw_geom_info.nil?
          # This column isn't in the geometry_columns table, so we don't know anything else about it
          ActiveRecord::ConnectionAdapters::SpatialSQLiteColumn.create_simplified(name, default, notnull)
        else
          ActiveRecord::ConnectionAdapters::SpatialSQLiteColumn.new(name, default, raw_geom_info.type, notnull, raw_geom_info.srid, raw_geom_info.with_z, raw_geom_info.with_m)
        end
      else
        ActiveRecord::ConnectionAdapters::SQLiteColumn.new(name, default, type, notnull)
      end
    end
  end

  def create_table(table_name, options = {})
    # Using the subclassed table definition
    table_definition = ActiveRecord::ConnectionAdapters::SQLite3TableDefinition.new(self)
    table_definition.primary_key(options[:primary_key] || ActiveRecord::Base.get_primary_key(table_name.to_s.singularize)) unless options[:id] == false

    yield table_definition if block_given?

    if options[:force] && table_exists?(table_name)
      drop_table(table_name, options)
    end

    create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
    create_sql << "#{quote_table_name(table_name)} ("
    create_sql << table_definition.to_sql
    create_sql << ") #{options[:options]}"

    # This is the additional portion for opengis
    unless table_definition.geom_columns.nil?
      table_definition.geom_columns.each do |geom_column|
        geom_column.table_name = table_name
        create_sql << "; " + geom_column.to_sql
      end
    end

    execute create_sql
  end

  alias :original_remove_column :remove_column
  def remove_column(table_name, *column_names)
    column_names = column_names.flatten
    columns(table_name).each do |col|
      if column_names.include?(col.name.to_sym)
        # Geometry columns have to be removed using DropGeometryColumn
        if col.is_a?(SpatialColumn) && col.spatial? && !col.geographic?
          execute "SELECT DropGeometryColumn('#{table_name}','#{col.name}')"
        else
          original_remove_column(table_name, col.name)
        end
      end
    end
  end
  
  alias :original_add_column :add_column
  def add_column(table_name, column_name, type, options = {})
    unless geometry_data_types[type].nil?
      geom_column = ActiveRecord::ConnectionAdapters::SQLiteColumnDefinition.new(self, column_name, type, nil, nil, options[:null], options[:srid] || -1 , options[:with_z] || false , options[:with_m] || false, options[:geographic] || false)
      if geom_column.geographic
        default = options[:default]
        notnull = options[:null] == false
        
        execute("ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{geom_column.to_sql}")

        change_column_default(table_name, column_name, default) if options_include_default?(options)
        change_column_null(table_name, column_name, false, default) if notnull
      else
        geom_column.table_name = table_name
        execute geom_column.to_sql
      end
    else
      original_add_column(table_name, column_name, type, options)
    end
  end

  # Adds an index to a column.
  def add_index(table_name, column_name, options = {})
    column_names = Array(column_name)
    index_name   = index_name(table_name, :column => column_names)

    if Hash === options # legacy support, since this param was a string
      index_type = options[:unique] ? "UNIQUE" : ""
      index_name = options[:name] || index_name
      index_method = options[:spatial] ? 'USING GIST' : ""
    else
      index_type = options
    end
    quoted_column_names = column_names.map { |e| quote_column_name(e) }.join(", ")
    execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} #{index_method} (#{quoted_column_names})"
  end

  # Returns the list of all indexes for a table.
  #
  # This is a full replacement for the ActiveRecord method and as a result
  # has a higher probability of breaking in future releases.
  def indexes(table_name, name = nil)
    execute("PRAGMA index_list(#{quote_table_name(table_name)})", name).map do |row|
      index_name = row['name']
      unique = row['unique'].to_i != 0
      column_names = execute("PRAGMA index_info('#{index_name}')").map { |col| col['name'] }
      # Only GiST indexes on spatial columns denote a spatial index
      spatial = false #TODO indtype == 'gist' && columns.size == 1 && (columns.values.first[1] == 'geometry' || columns.values.first[1] == 'geography')
      ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, index_name, unique, column_names, spatial)
    end
  end

  def disable_referential_integrity(&block) #:nodoc:
    if supports_disable_referential_integrity?() then
      execute(tables_without_opengis.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
    end
    yield
  ensure
    if supports_disable_referential_integrity?() then
      execute(tables_without_opengis.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
    end
  end

  private
  
  def tables_without_opengis
    tables - %w{ geometry_columns spatial_ref_sys geometry_columns_auth geom_cols_ref_sys }
  end
  
  def column_spatial_info(table_name)
    constr = select_all("SELECT * FROM geometry_columns WHERE f_table_name = '#{table_name}'")

    raw_geom_infos = {}
    constr.each do |constr_def_a|
      geometry_column = constr_def_a['f_geometry_column']
      raw_geom_infos[geometry_column] ||= SpatialAdapter::RawGeomInfo.new
      raw_geom_infos[geometry_column].type = constr_def_a['type']
      raw_geom_infos[geometry_column].dimension = constr_def_a['coord_dimension'].to_i
      raw_geom_infos[geometry_column].srid = constr_def_a['srid'].to_i

      if raw_geom_infos[geometry_column].type[-1] == ?M
        raw_geom_infos[geometry_column].with_m = true
        raw_geom_infos[geometry_column].type.chop!
      else
        raw_geom_infos[geometry_column].with_m = false
      end
    end

    raw_geom_infos.each_value do |raw_geom_info|
      #check the presence of z and m
      raw_geom_info.convert!
    end
    raw_geom_infos

  end
end

module ActiveRecord
  module ConnectionAdapters
    class SQLite3TableDefinition < TableDefinition
      attr_reader :geom_columns
      
      def column(name, type, options = {})
        unless (@base.geometry_data_types[type.to_sym].nil? or
                (options[:create_using_addgeometrycolumn] == false))

          column = self[name] || SQLiteColumnDefinition.new(@base, name, type)
          column.null = options[:null]
          column.srid = options[:srid] || -1
          column.with_z = options[:with_z] || false 
          column.with_m = options[:with_m] || false
          column.geographic = options[:geographic] || false

          if column.geographic
            @columns << column unless @columns.include? column
          else
            # Hold this column for later
            @geom_columns ||= []
            @geom_columns << column
          end
          self
        else
          super(name, type, options)
        end
      end    
    end

    class SQLiteColumnDefinition < ColumnDefinition
      attr_accessor :table_name
      attr_accessor :srid, :with_z, :with_m, :geographic
      attr_reader :spatial

      def initialize(base = nil, name = nil, type=nil, limit=nil, default=nil, null=nil, srid=-1, with_z=false, with_m=false, geographic=false)
        super(base, name, type, limit, default, null)
        @table_name = nil
        @spatial = true
        @srid = srid
        @with_z = with_z
        @with_m = with_m
        @geographic = geographic
      end
      
      def sql_type
        if geographic
          type_sql = base.geometry_data_types[type.to_sym][:name]
          type_sql += "Z" if with_z
          type_sql += "M" if with_m
          # SRID is not yet supported (defaults to 4326)
          #type_sql += ", #{srid}" if (srid && srid != -1)
          type_sql = "geography(#{type_sql})"
          type_sql
        else
          super
        end
      end
      
      def to_sql
        if spatial && !geographic
          type_sql = base.geometry_data_types[type.to_sym][:name]
          type_sql += "M" if with_m and !with_z
          if with_m and with_z
            dimension = 4 
          elsif with_m or with_z
            dimension = 3
          else
            dimension = 2
          end
        
          column_sql = "SELECT AddGeometryColumn('#{table_name}','#{name}',#{srid},'#{type_sql}',#{dimension})"
          column_sql += ";ALTER TABLE #{table_name} ALTER #{name} SET NOT NULL" if null == false
          column_sql
        else
          super
        end
      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class SpatialSQLiteColumn < SQLiteColumn
      include SpatialAdapter::SpatialColumn

      def initialize(name, default, sql_type = nil, null = true, srid=-1, with_z=false, with_m=false, geographic = false)
        super(name, default, sql_type, null, srid, with_z, with_m)
        @geographic = geographic
      end

      #Transforms a string to a geometry. opengis returns a HewEWKB string.
      def self.string_to_geometry(string)
        return string unless string.is_a?(String)
        GeoRuby::SimpleFeatures::Geometry.from_hex_ewkb(string) rescue nil
      end

      def self.create_simplified(name, default, null = true)
        new(name, default, "geometry", null)
      end
      
      def self.create_from_geography(name, default, sql_type, null = true)
        params = extract_geography_params(sql_type)
        new(name, default, sql_type, null, params[:srid], params[:with_z], params[:with_m], true)
      end
      
    end
  end
end
