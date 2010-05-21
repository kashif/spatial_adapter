require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'spatial_adapter/sqlite3'
require 'db/spatialite_raw'
require 'models/common'

describe "Spatially-enabled Models" do
  before :each do
    spatialite_connection
    @connection = ActiveRecord::Base.connection
  end
  
  describe "inserting records" do
    it 'should save Point objects' do
      model = PointModel.new(:extra => 'test', :geom => GeometryFactory.point)
      @connection.should_receive(:select_value).with(Regexp.new(GeometryFactory.point.as_hex_ewkb))
      model.save.should == true
    end
  
    it 'should save Point geography objects' do
      model = GeographyPointModel.new(:extra => 'test', :geom => GeometryFactory.point)
      @connection.should_receive(:select_value).with(Regexp.new(GeometryFactory.point.as_hex_ewkb))
      model.save.should == true
    end
  end
end