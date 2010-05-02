require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'spatial_adapter/sqlite3'
require 'db/spatialite_raw'
require 'models/common'

describe "Modified SQLite3Adapter" do
  before :each do
    spatialite_connection
    @connection = ActiveRecord::Base.connection
  end
end