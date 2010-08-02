require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'spatial_adapter/sqlite3'
require 'db/spatialite_raw'
require 'models/common'

describe "Modified SQLite3Adapter" do
  before :each do
    spatialite_connection
    @connection = ActiveRecord::Base.connection
  end
  
  describe "#columns" do
    describe "type" do
      it "should be a regular SpatialSQLite3Column if column is a geometry data type" do
        column = PointModel.columns.select{|c| c.name == 'geom'}.first
        column.should be_a(ActiveRecord::ConnectionAdapters::SpatialSQLite3Column)
        column.geometry_type.should == :point
        column.should_not be_geographic
      end
      
      it "should be SQLiteColumn if column is not a spatial data type" do
        PointModel.columns.select{|c| c.name == 'extra'}.first.should be_a(ActiveRecord::ConnectionAdapters::SQLiteColumn)
      end
    end
    
    describe "@geometry_type" do
      it "should be :point for geometry columns restricted to POINT types" do
        PointModel.columns.select{|c| c.name == 'geom'}.first.geometry_type.should == :point
      end
      
      it "should be :line_string for geometry columns restricted to LINESTRING types" do
        LineStringModel.columns.select{|c| c.name == 'geom'}.first.geometry_type.should == :line_string
      end

      it "should be :polygon for geometry columns restricted to POLYGON types" do
        PolygonModel.columns.select{|c| c.name == 'geom'}.first.geometry_type.should == :polygon
      end

      it "should be :multi_point for geometry columns restricted to MULTIPOINT types" do
        MultiPointModel.columns.select{|c| c.name == 'geom'}.first.geometry_type.should == :multi_point
      end

      it "should be :multi_line_string for geometry columns restricted to MULTILINESTRING types" do
        MultiLineStringModel.columns.select{|c| c.name == 'geom'}.first.geometry_type.should == :multi_line_string
      end
      
      it "should be :multi_polygon for geometry columns restricted to MULTIPOLYGON types" do
        MultiPolygonModel.columns.select{|c| c.name == 'geom'}.first.geometry_type.should == :multi_polygon
      end
      
      it "should be :geometry_collection for geometry columns restricted to GEOMETRYCOLLECTION types" do
        GeometryCollectionModel.columns.select{|c| c.name == 'geom'}.first.geometry_type.should == :geometry_collection
      end
      
      it "should be :geometry for geometry columns not restricted to a type" do
        GeometryModel.columns.select{|c| c.name == 'geom'}.first.geometry_type.should == :geometry
      end
    end
  end
  
  describe "#indexes" do
    before :each do
      @indexes = @connection.indexes('point_models')
    end
    
    it "should return an IndexDefinition for each index on the table" do
      #TODO: @indexes.should have(2).items
      @indexes.should have(1).items
      @indexes.each do |i|
        i.should be_a(ActiveRecord::ConnectionAdapters::IndexDefinition)
      end
    end
    
    it "should indicate the correct columns in the index" do
      #TODO: @indexes.select{|i| i.name == 'idx_point_models_on_geom'}.first.columns.should == ['geom']
      @indexes.select{|i| i.name == 'index_point_models_on_extra'}.first.columns.should == ['extra', 'more_extra']
    end
    
    #it "should be marked as spatial if a GiST index on a geometry column" do
    #  @indexes.select{|i| i.name == 'index_point_models_on_geom'}.first.spatial.should == true
    #end
    
    #it "should not be marked as spatial if not a GiST index" do
    #  @indexes.select{|i| i.name == 'index_point_models_on_extra'}.first.spatial.should == false
    #end
    
    #it "should not be marked as spatial if a GiST index on a non-geometry column" do
    #  @connection.execute(<<-SQL)
    #    create table non_spatial_models
    #    (
    #      id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    #      location point,
    #      extra varchar(255)
    #    );
    #    create index index_non_spatial_models_on_location on non_spatial_models using gist (box(location, location));
    #  SQL
    #  @indexes = @connection.indexes('non_spatial_models')
    #  @indexes.select{|i| i.name == 'index_non_spatial_models_on_location'}.first.spatial.should == false
    #  @connection.execute 'drop table non_spatial_models'
    #end
  end  
  
  describe "#add_index" do
    after :each do
      @connection.should_receive(:execute).with(any_args())
      @connection.remove_index('geometry_models', 'geom')
    end
    
    it "should create a spatial index given :spatial => true" do
      @connection.should_receive(:execute).with(/CreateSpatialIndex/i)
      @connection.add_index('geometry_models', 'geom', :spatial => true)
    end
    
    it "should not create a spatial index unless specified" do
      @connection.should_not_receive(:execute).with(/using gist/i)
      @connection.add_index('geometry_models', 'extra')
    end
  end
end
