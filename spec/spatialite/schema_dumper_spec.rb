require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'spatial_adapter/sqlite3'

describe "Spatially-enabled Schema Dumps" do
  before :all do
    spatialite_connection
    @connection = ActiveRecord::Base.connection

    @connection.raw_connection.execute_batch <<-SQL
      delete from geometry_columns;
      drop table if exists idx_point_models_geom;
      drop table if exists point_models;
      drop table if exists line_string_models;
      drop table if exists polygon_models;
      drop table if exists multi_point_models;
      drop table if exists multi_line_string_models;
      drop table if exists multi_polygon_models;
      drop table if exists geometry_collection_models;
      drop table if exists geometry_models;
      drop table if exists pointz_models;
      drop table if exists pointm_models;
      drop table if exists point4_models;
      drop table if exists non_spatial_models;
      drop table if exists migrated_geometry_models;
    SQL
    # Create a new table
    ActiveRecord::Schema.define do
      create_table :migrated_geometry_models, :force => true do |t|
        t.integer :extra
        t.point   :geom, :with_m => false, :with_z => true, :srid => 4326
      end
      add_index :migrated_geometry_models, :geom, :spatial => true, :name => 'test_spatial_index'
    end

    File.open('schema.rb', "w") do |file|
      ActiveRecord::SchemaDumper.dump(@connection, file)
    end
    
    # Drop the original tables
    @connection.execute "SELECT DiscardGeometryColumn('migrated_geometry_models', 'geom')"
    @connection.drop_table "migrated_geometry_models"
    
    # Load the dumped schema
    load('schema.rb')
  end
  
  after :all do
    # delete the schema file
    File.delete('schema.rb')

    # Drop the new tables
    @connection.execute "SELECT DiscardGeometryColumn('migrated_geometry_models', 'geom')"
    @connection.drop_table "migrated_geometry_models"
  end
  
  it "should preserve spatial attributes of geometry tables" do
    columns = @connection.columns("migrated_geometry_models")
    
    columns.should have(3).items
    geom_column = columns.select{|c| c.name == 'geom'}.first
    geom_column.should be_a(SpatialAdapter::SpatialColumn)
    geom_column.geometry_type.should == :point
    geom_column.type.should == :string
    geom_column.with_z.should == true
    geom_column.with_m.should == false
    geom_column.srid.should == 4326
  end
  
  it "should preserve spatial indexes" do
    indexes = @connection.indexes("migrated_geometry_models")
    
    indexes.should have(1).item
    
    indexes.first.name.should == 'test_spatial_index'
    indexes.first.columns.should == ["geom"]
    indexes.first.spatial.should == true
  end
end