spatialite_connection

ActiveRecord::Schema.define() do
#  execute <<_SQL
#    drop table if exists point_models;
#    create table point_models(id serial primary key,extra varchar(255),more_extra varchar(255));
#    select AddGeometryColumn('point_models', 'geom', 4326, 'POINT', 2);
#    select CreateSpatialIndex('point_models', 'geom');
#    create index index_point_models_on_extra on point_models (extra, more_extra);
#_SQL
  
  if ActiveRecord::Base.connection.supports_geographic?
    execute <<_SQL
      drop table if exists geography_point_models;
      create table geography_point_models(id serial primary key,extra varchar(255),geom geography(POINT));
      select CreateSpatialIndex('geography_point_models', 'geom');
      create index index_geography_point_models_on_extra on geography_point_models (extra);
_SQL
  end
end
