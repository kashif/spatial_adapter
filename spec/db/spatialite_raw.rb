spatialite_connection

ActiveRecord::Schema.define() do
  raw_connection.execute_batch <<-SQL
    DELETE FROM geometry_columns;

    drop table if exists idx_point_models_geom;
    drop table if exists point_models;
    create table point_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255),
    	more_extra varchar(255)
    );
    select AddGeometryColumn('point_models', 'geom', 4326, 'POINT', 2);
    SELECT CreateSpatialIndex('point_models', 'geom');
    create index index_point_models_on_extra on point_models (extra, more_extra);

    drop table if exists line_string_models;
    create table line_string_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('line_string_models', 'geom', 4326, 'LINESTRING', 2);

    drop table if exists polygon_models;
    create table polygon_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('polygon_models', 'geom', 4326, 'POLYGON', 2);

    drop table if exists multi_point_models;
    create table multi_point_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('multi_point_models', 'geom', 4326, 'MULTIPOINT', 2);

    drop table if exists multi_line_string_models;
    create table multi_line_string_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('multi_line_string_models', 'geom', 4326, 'MULTILINESTRING', 2);

    drop table if exists multi_polygon_models;
    create table multi_polygon_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('multi_polygon_models', 'geom', 4326, 'MULTIPOLYGON', 2);

    drop table if exists geometry_collection_models;
    create table geometry_collection_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('geometry_collection_models', 'geom', 4326, 'GEOMETRYCOLLECTION', 2);

    drop table if exists geometry_models;
    create table geometry_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('geometry_models', 'geom', 4326, 'GEOMETRY', 2);

    drop table if exists pointz_models;
    create table pointz_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('pointz_models', 'geom', 4326, 'POINT', 3);

    drop table if exists pointm_models;
    create table pointm_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('pointm_models', 'geom', 4326, 'POINT', 'XYM');

    drop table if exists point4_models;
    create table point4_models
    (
    	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    	extra varchar(255)
    );
    select AddGeometryColumn('point4_models', 'geom', 4326, 'POINT', 'XYZM');

    drop table if exists non_spatial_models;
  SQL

end
