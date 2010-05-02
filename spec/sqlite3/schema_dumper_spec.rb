require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'spatial_adapter/sqlite3'

describe "Spatially-enabled Schema Dumps" do
  before :all do
    spatialite_connection
    @connection = ActiveRecord::Base.connection
  end
end