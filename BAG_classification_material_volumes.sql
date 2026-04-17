CREATE SCHEMA IF NOT EXISTS building_material_volumes;

-- Create temporary table with current_buildings_filtered
DROP TABLE IF EXISTS building_material_volumes.current_buildings_filtered;
CREATE TABLE building_material_volumes.current_buildings_filtered AS

WITH 
-- Selects buildings (pand) currently in use in a specific bounding box:
current_buildings AS (
    SELECT p.identificatie AS id_pand, 
        p.geovlak AS geom
    FROM bron_bag.pand p
    WHERE p.eindregistratie IS NULL
    AND p.geovlak && ST_MakeEnvelope(
        12543, -- xmin
        270897, -- ymin
        321634, -- xmax
        642251, -- ymax
        28992   -- crs
    )    
    AND (p.pandstatus = 'Pand in gebruik'
    OR p.pandstatus = 'Pand in gebruik (niet ingemeten)'
    OR p.pandstatus = 'Verbouwing pand'
    OR p.pandstatus = 'Pand buiten gebruik'
    OR p.pandstatus = 'Sloopvergunning verleend'
    )
),

/*
| id_pand          | geom      |
| ---------------- | --------- |
| 0363100012345678 | POLYGON() |
| 0363100012345679 | POLYGON() |
*/

-- Links verblijfsobjecten (residential/office units) to their buildings:

current_addresses AS (
    SELECT vp.identificatie AS id_verblijfsobject,
        vp.gerelateerdpand AS id_pand
    FROM bron_bag.verblijfsobjectpand vp
    LEFT JOIN current_buildings cb
    ON vp.gerelateerdpand = cb.id_pand
    WHERE vp.einddatumtijdvakgeldigheid IS NULL
    AND (vp.verblijfsobjectstatus = 'Verblijfsobject in gebruik'
    OR vp.verblijfsobjectstatus = 'Verblijfsobject in gebruik (niet ingemeten)'
    OR vp.verblijfsobjectstatus = 'Verbouwing verblijfsobject'
    )
),

/*
| id_verblijfsobject | id_pand          |
| ------------------ | ---------------- |
| 0363010000123456   | 0363100012345678 |
| 0363010000123457   | 0363100012345679 |
*/

-- Counts the number of verblijfsobjecten per building:

address_count AS (
    SELECT 
        ca.id_pand,
        COUNT(*) AS n_addresses
    FROM current_addresses ca
    GROUP BY ca.id_pand
)

/*
| id_pand          | n_addresses |
| ---------------- | ----------- |
| 0363100012345678 | 1           |
| 0363100012345679 | 2           |
*/

-- Filters out buildings with zero addresses:

-- current_buildings_filtered table
SELECT cb.*, ac.n_addresses
FROM current_buildings cb
LEFT JOIN address_count ac
ON cb.id_pand = ac.id_pand
WHERE ac.n_addresses IS NOT NULL;


/*
| id_pand          | geom      | n_addresses |
| ---------------- | --------- | ----------- |
| 0363100012345678 | POLYGON() | 1           |
| 0363100012345679 | POLYGON() | 2           |
*/

-- Create index on new table
CREATE INDEX idx_cbf_geom 
ON building_material_volumes.current_buildings_filtered 
USING GIST (geom);

CREATE INDEX idx_cbf_id 
ON building_material_volumes.current_buildings_filtered (id_pand);


DROP TABLE IF EXISTS building_material_volumes.verblijfsobject_pand;
CREATE TABLE building_material_volumes.verblijfsobject_pand AS

-- Selects active verblijfsobjecten with floor area, point geometry, and gebruiksdoel (use type):
WITH
current_verblijfsobject AS (
SELECT v.oppervlakteverblijfsobject AS floor_area,
    v.identificatie AS id_verblijfsobject,
    v.geopunt AS geom,
    g.gebruiksdoelverblijfsobject AS gebruiksdoel
    FROM bron_bag.verblijfsobject v
    LEFT JOIN bron_bag.verblijfsobjectgebruiksdoel g
    ON v.identificatie = g.identificatie
    WHERE v.eindregistratie IS NULL
	AND g.einddatumtijdvakgeldigheid IS NULL
    AND v.geopunt && ST_MakeEnvelope(
        12543, -- xmin
        270897, -- ymin
        321634, -- xmax
        642251, -- ymax
        28992   -- crs
    )
    AND (v.verblijfsobjectstatus = 'Verblijfsobject in gebruik'
    OR v.verblijfsobjectstatus = 'Verblijfsobject in gebruik (niet ingemeten)'
    OR v.verblijfsobjectstatus = 'Verbouwing verblijfsobject'
	OR v.verblijfsobjectstatus = 'Verblijfsobject buiten gebruik'
    )
)

/*
| id_verblijfsobject | floor_area | gebruiksdoel       | geom      |
| ------------------ | ---------- | ------------------ | --------- |
| 0363010000123456   | 85         | woonfunctie        | POINT()   |
| 0363010000123457   | 72         | woonfunctie        | POINT()   |
*/

-- Joins verblijfsobjecten with their buildings, filtering active relations:

-- Create table verblijfsobject_pand
SELECT cv.*,
    vp.gerelateerdpand AS id_pand
FROM current_verblijfsobject cv
LEFT JOIN bron_bag.verblijfsobjectpand vp
ON cv.id_verblijfsobject = vp.identificatie
WHERE vp.einddatumtijdvakgeldigheid IS NULL;

/*
| id_verblijfsobject | id_pand          | floor_area | gebruiksdoel     |
| ------------------ | ---------------- | ---------- | ---------------- |
| 0363010000123456   | 0363100012345678 | 85         | woonfunctie      |
| 0363010000123459   | 0363100012345680 | 300        | industriefunctie |
*/

CREATE INDEX idx_vp_geom 
ON building_material_volumes.verblijfsobject_pand 
USING GIST (geom);

CREATE INDEX idx_vp_pand 
ON building_material_volumes.verblijfsobject_pand (id_pand);

CREATE INDEX idx_vp_vo 
ON building_material_volumes.verblijfsobject_pand (id_verblijfsobject);

DROP TABLE IF EXISTS building_material_volumes.verblijfsobject_pand_no_dup;
CREATE TABLE building_material_volumes.verblijfsobject_pand_no_dup AS

-- create table verblijfsobject_pand_no_dup
SELECT DISTINCT ON (id_verblijfsobject, id_pand)
*
FROM building_material_volumes.verblijfsobject_pand;

/*
| id_verblijfsobject | id_pand          | floor_area | gebruiksdoel  | geom      |
| ------------------ | ---------------- | ---------- | ------------- | --------- |
| 0363010000123456   | 0363100012345678 | 85         | woonfunctie   | POINT()   |
| 0363010000123457   | 0363100012345679 | 72         | woonfunctie   | POINT()   |
*/

CREATE INDEX idx_vpnd_geom 
ON building_material_volumes.verblijfsobject_pand_no_dup 
USING GIST (geom);

CREATE INDEX idx_vpnd_pand 
ON building_material_volumes.verblijfsobject_pand_no_dup (id_pand);

CREATE INDEX idx_vpnd_vo 
ON building_material_volumes.verblijfsobject_pand_no_dup (id_verblijfsobject);

-- Create table of buildings with buffer to account for small drawing errors (inspired by ESRI)
-- Buffer was suggested in earier work by ESRI: https://www.esri.nl/content/dam/distributor-restricted/esri-nl/collateral/productinformatie-woningtypering-dataset.pdf
DROP TABLE IF EXISTS building_material_volumes.current_buildings_filtered_buffer;
CREATE TABLE building_material_volumes.current_buildings_filtered_buffer AS

SELECT id_pand, 
       ST_Buffer(geom, 0.03, 'endcap=round join=round') AS geom
FROM building_material_volumes.current_buildings_filtered;

-- Create index on new table
CREATE INDEX idx_cbf_buff_geom
ON building_material_volumes.current_buildings_filtered_buffer
USING GIST (geom);

CREATE INDEX idx_cbf_buff_id 
ON building_material_volumes.current_buildings_filtered_buffer (id_pand);

-- Create temporary table with classified buildings
DROP TABLE IF EXISTS building_material_volumes.classified_buildings;
CREATE TABLE building_material_volumes.classified_buildings AS

WITH
-- Aggregates gebruikstypen per building:
gebruiksdoel_building AS (
    SELECT 
        cbf.id_pand,
        ARRAY_AGG(DISTINCT vp.gebruiksdoel) AS gebruiksdoel
    FROM building_material_volumes.current_buildings_filtered cbf
    LEFT JOIN building_material_volumes.verblijfsobject_pand vp
        ON cbf.id_pand = vp.id_pand
    GROUP BY cbf.id_pand
),

/*
| id_pand          | gebruiksdoel                        |
| ---------------- | ----------------------------------- |
| 0363100012345678 | {woonfunctie}                       |
| 0363100012345679 | {woonfunctie,kantoorfunctie}        |
*/

count_per_pand AS (
SELECT id_verblijfsobject,
	COUNT(*) AS n_pand
    FROM building_material_volumes.verblijfsobject_pand_no_dup
    GROUP BY id_verblijfsobject
),

/*
| id_verblijfsobject | n_pand |
| ------------------ | ------ |
| 0363010000123456   | 1      |
| 0363010000456789   | 2      |
*/

floor_area_building AS (
    SELECT
       vp.id_pand,
        SUM(vp.floor_area / cpp.n_pand) AS tot_floor_area
    FROM building_material_volumes.verblijfsobject_pand_no_dup vp
	LEFT JOIN count_per_pand cpp
	ON vp.id_verblijfsobject = cpp.id_verblijfsobject
    GROUP BY vp.id_pand
),


/*
| id_pand          | tot_floor_area |
| ---------------- | -------------- |
| 0363100012345678 | 85             |
| 0363100012345679 | 192            |
*/

-- Counts spatially touching buildings:

touch_count AS (
    SELECT
        a.id_pand,
        COUNT(b.id_pand) AS touch_count
    FROM building_material_volumes.current_buildings_filtered_buffer a
    JOIN building_material_volumes.current_buildings_filtered_buffer b
      ON a.geom && b.geom
     AND a.id_pand <> b.id_pand
     AND ST_Intersects(a.geom, b.geom)
    GROUP BY a.id_pand
),

/*
| id               | touch_count |
| ---------------- | ----------- |
| 0363100012345678 | 0           |
| 0363100012345679 | 1           |
*/

-- Adds 3D BAG information (number of floors, heights):
bag3d AS (
    SELECT 
        REPLACE(p3d.identificatie, 'NL.IMBAG.Pand.', '') AS id_pand,
        p3d.b3_bouwlagen AS n_floors,
        p3d.b3_h_maaiveld,
        p3d.b3_h_nok
    FROM bron_3dbag.pand p3d
    WHERE p3d.geom && ST_MakeEnvelope(
        12543, -- xmin
        270897, -- ymin
        321634, -- xmax
        642251, -- ymax
        28992   -- crs
        )
),
/*
| id_pand          | n_floors | b3_h_maaiveld | b3_h_nok |
| ---------------- | -------- | ------------- | -------- |
| 0363100012345678 | 2        | 0.0           | 7.2      |
| 0363100012345681 | [null]   | 0.0           | 12.0     |
*/

-- Joins everything per building:

merged_buildings AS (
    SELECT
        cbf.*,
        g.gebruiksdoel,
		f.tot_floor_area,
        COALESCE(t.touch_count, 0) AS touch_count,
        b.n_floors,
        b.b3_h_maaiveld,
        b.b3_h_nok
    FROM building_material_volumes.current_buildings_filtered cbf
    LEFT JOIN gebruiksdoel_building g ON cbf.id_pand = g.id_pand
	LEFT JOIN floor_area_building f ON cbf.id_pand = f.id_pand
    LEFT JOIN touch_count t ON cbf.id_pand = t.id_pand
    LEFT JOIN bag3d b ON cbf.id_pand = b.id_pand
)

/*
| id_pand          | geom      | n_addresses | gebruiksdoel       | tot_floor_area | touch_count | n_floors | b3_h_maaiveld | b3_h_nok |
| ---------------- | --------- | ----------- | ------------------ | -------------- | ----------- | -------- | ------------- | -------- |
| 0363100012345678 | POLYGON() | 1           | {woonfunctie}      | 85             | 0           | 2        | 0             | 7.2      |
| 0363100012345681 | POLYGON() | 8           | {woonfunctie}      | 950            | 2           | [null]   | 0             | 12       |
*/

-- Computes boolean flags for building typology:
-- Create table classified_buildings 
SELECT *,
    ('winkelfunctie' = ANY(gebruiksdoel)) AS commercial,
    ('kantoorfunctie' = ANY(gebruiksdoel)) AS office,
    (n_addresses = 1 AND touch_count = 0 
                     AND ('woonfunctie' = ANY(gebruiksdoel)
                     OR 'overige gebruiksfunctie' = ANY(gebruiksdoel))) AS single_house,
    (n_addresses <= 2 AND touch_count >= 1 
                      AND ('woonfunctie' = ANY(gebruiksdoel)
                      OR 'overige gebruiksfunctie' = ANY(gebruiksdoel))) AS row_house,
    (n_addresses >= 3 AND ('woonfunctie' = ANY(gebruiksdoel)
                      OR 'overige gebruiksfunctie' = ANY(gebruiksdoel))) AS apartment,
    (n_addresses >= 6 AND n_floors IS NULL 
                        AND ('woonfunctie' = ANY(gebruiksdoel)
                        OR 'overige gebruiksfunctie' = ANY(gebruiksdoel))) 
                        AND COALESCE((b3_h_nok - b3_h_maaiveld) >= 15, TRUE) AS potential_highrise
FROM merged_buildings;


/*
| id_pand          | n_addresses | touch_count | single_house | row_house | apartment | potential_highrise |
| ---------------- | ----------- | ----------- | ------------ | --------- | --------- | ------------------ |
| 0363100012345678 | 1           | 0           | TRUE         | FALSE     | FALSE     | FALSE              |
| 0363100012345679 | 2           | 1           | FALSE        | TRUE      | FALSE     | FALSE              |
*/

CREATE INDEX idx_cb_geom 
ON building_material_volumes.classified_buildings 
USING GIST (geom);

CREATE INDEX idx_cb_id 
ON building_material_volumes.classified_buildings (id_pand);

-- Create temporary table with classified buildings
DROP TABLE IF EXISTS building_material_volumes.classified_buildings_materials;
CREATE TABLE building_material_volumes.classified_buildings_materials AS

WITH
-- Filters buildings flagged as potential highrise:
potential_highrise_buildings AS (
    SELECT *
    FROM building_material_volumes.classified_buildings
    WHERE potential_highrise
),

/*
| id_pand          | n_addresses | touch_count | ... | potential_highrise |
| ---------------- | ----------- | ----------- | --- | ----------------- |
| 0363100012345681 | 10          | 5           | ... | TRUE              |
*/

-- Computes building–parcel overlap and overlap_ratio:

highrise_parcels AS (
	SELECT DISTINCT CONCAT(p.akrgemeente,'-',p.sectie,'-',p.perceelnummer) AS id_parcel,
		p.begrenzing AS geom_parcel
	FROM potential_highrise_buildings phb
    LEFT JOIN bron_dkk.perceel p
      ON phb.geom && p.begrenzing
	  AND ST_Intersects(
            phb.geom,
            p.begrenzing
         )
),

/*
| id_parcel | geom_parcel |
| --------- | ----------- |
| 0345-A-120| POLYGON()   |
| 0345-A-121| POLYGON()   |
*/

buildings_on_parcel AS (
    SELECT
        hp.id_parcel,
        hp.geom_parcel,
        cb.id_pand,
        cb.tot_floor_area,
        cb.geom as geom_building,
        ST_AREA(ST_Intersection(cb.geom, hp.geom_parcel))/ST_AREA(cb.geom) AS overlap_ratio
    FROM highrise_parcels hp
    LEFT JOIN building_material_volumes.classified_buildings cb
      ON cb.geom && hp.geom_parcel
	  AND ST_Intersects(
            cb.geom,
            hp.geom_parcel
         )
),

/*
| id_parcel | id_pand          | tot_floor_area | geom_building | overlap_ratio |
| --------- | ---------------- | -------------- | ------------- | ------------- |
| 1000-A-1  | 0363100012345681 | 1000           | POLYGON()     | 0.95          |
| 1000-A-1  | 0363100012345682 | 400            | POLYGON()     | 0.91          |
*/

-- Aggregates highrise indicators per parcel:

combined_buildings AS (
    SELECT
	id_parcel,
	SUM(tot_floor_area) AS floor_area_parcel,
	SUM(ST_AREA(geom_building)) AS building_area,
	SUM(tot_floor_area)/SUM(ST_AREA(geom_building)) AS ratio,
	(SUM(tot_floor_area)/SUM(ST_AREA(geom_building)) > 5) AS highrise
    FROM buildings_on_parcel bop
	WHERE overlap_ratio > 0.9
    GROUP BY id_parcel
),

/*
| id_parcel | floor_area_parcel | building_area | ratio | highrise |
| ----------| ---------------- | ------------- | ----- | -------- |
| 1000-A-1  | 1000             | 180           | 5.56  | TRUE     |
*/

-- Assigns a final building category, merging building typology with parcel-level highrise data:

buildings_highrise AS (
	SELECT bop.id_pand, cb.highrise
	FROM buildings_on_parcel bop
	LEFT JOIN combined_buildings cb
	ON bop.id_parcel = cb.id_parcel
	WHERE cb.highrise AND bop.overlap_ratio > 0.9
),

/*
| id_pand          | highrise |
| ---------------- | -------- |
| 0363100012345681 | TRUE     |
| 0363100012345682 | TRUE     |
*/

classified_buildings_final AS (
    SELECT
    cb.id_pand,
    CASE WHEN bh.highrise THEN 'highrise'
        WHEN cb.apartment THEN 'apartment'
        WHEN cb.row_house THEN 'row'
        WHEN cb.single_house THEN 'single'
        WHEN cb.office THEN 'office'
        WHEN cb.commercial THEN 'commercial'
        ELSE 'other'
        END AS category,
	CAST(cb.tot_floor_area AS int),
	cb.geom
    FROM building_material_volumes.classified_buildings cb
    LEFT JOIN buildings_highrise bh
    ON cb.id_pand = bh.id_pand
)

/*
| id_pand          | category  | tot_floor_area | geom      |
| ---------------- | --------- | -------------- | --------- |
| 0363100012345678 | single    | 85             | POLYGON() |
| 0363100012345679 | row       | 144            | POLYGON() |
*/

-- Computes material volumes per building based on typology-specific material intensities:
-- create table classified_buildings_materials
SELECT cbf.id_pand,
    cbf.category,
    cbf.tot_floor_area,
    cbf.tot_floor_area * mi.concrete AS concrete,
    cbf.tot_floor_area * mi.clay_brick AS clay_brick,
    cbf.tot_floor_area * mi.wood AS wood,
    cbf.tot_floor_area * mi.aluminium AS aluminium,
    cbf.tot_floor_area * mi.steel AS steel,
    cbf.tot_floor_area * mi.glass AS glass,
    cbf.tot_floor_area * mi.ceramic AS ceramic,
    cbf.tot_floor_area * mi.gypsum AS gypsum,
    cbf.tot_floor_area * mi.bitumen AS bitumen,
    cbf.tot_floor_area * mi.plastic AS plastic,
    cbf.tot_floor_area * mi.cast_iron AS cast_iron,
    cbf.tot_floor_area * mi.glass_wool AS glass_wool,
    cbf.tot_floor_area * mi.copper AS copper,
    cbf.tot_floor_area * mi.total AS total,
    cbf.geom
FROM classified_buildings_final cbf
LEFT JOIN building_material_volumes.material_intensities mi
ON cbf.category = mi.type;

/*
| id_pand          | category  | tot_floor_area | concrete | clay_brick | wood | steel | glass | ... | total  | geom      |
| ---------------- | --------- | -------------- | -------- | ---------- | ---- | ----- | ----- | --- | ------ | --------- |
| 0363100012345678 | single    | 85             | 34000    | 12000      | 2500 | 800   | 600   | ... | 52000  | POLYGON() |
| 0363100012345679 | row       | 144            | 58000    | 21000      | 4300 | 1200  | 900   | ... | 87000  | POLYGON() |
*/

CREATE INDEX idx_cbm_geom 
ON building_material_volumes.classified_buildings_materials
USING GIST (geom);

CREATE INDEX idx_cbm_id 
ON building_material_volumes.classified_buildings_materials (id_pand);

-- Create temporary table with classified addresses
DROP TABLE IF EXISTS building_material_volumes.classified_addresses;
CREATE TABLE building_material_volumes.classified_addresses AS

SELECT 
    vp.identificatie AS id_verblijfsobject,
    cbm.id_pand,
    cbm.category,
    cbm.geom
    FROM bron_bag.verblijfsobjectpand vp
    LEFT JOIN building_material_volumes.classified_buildings_materials cbm
    ON vp.gerelateerdpand = cbm.id_pand
    WHERE vp.einddatumtijdvakgeldigheid IS NULL
    AND (vp.verblijfsobjectstatus = 'Verblijfsobject in gebruik'
    OR vp.verblijfsobjectstatus = 'Verblijfsobject in gebruik (niet ingemeten)'
    OR vp.verblijfsobjectstatus = 'Verbouwing verblijfsobject'
    );

CREATE INDEX idx_ca_geom 
ON building_material_volumes.classified_addresses
USING GIST (geom);

CREATE INDEX idx_ca_id
ON building_material_volumes.classified_addresses (id_verblijfsobject);

DROP TABLE building_material_volumes.current_buildings_filtered, 
           building_material_volumes.current_buildings_filtered_buffer, 
           building_material_volumes.classified_buildings, 
           building_material_volumes.verblijfsobject_pand, 
           building_material_volumes.verblijfsobject_pand_no_dup;