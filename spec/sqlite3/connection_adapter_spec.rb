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
      
      it "should be a geographic SpatialSQLite3Column if column is a geography data type" do
        column = GeographyPointModel.columns.select{|c| c.name == 'geom'}.first
        column.should be_a(ActiveRecord::ConnectionAdapters::SpatialSQLite3Column)
        column.geometry_type.should == :point
        column.should be_geographic
      end
      
      it "should be SQLiteColumn if column is not a spatial data type" do
        PointModel.columns.select{|c| c.name == 'extra'}.first.should be_a(ActiveRecord::ConnectionAdapters::SQLiteColumn)
      end
    end
  end

end