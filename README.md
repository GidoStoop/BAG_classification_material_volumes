![alt text](https://github.com/GidoStoop/BAG_classification_material_volumes/blob/main/infographic/20260416_Infographic.png "Infographic")

## 🌇 Classifying the Dutch Building Stock and Estimating Material Volumes

This repository contains an SQL-script that uses data from Sprecher et al., (2022), BAG (Kadaster, 2025a), Kadaster (2025b), and 3D-BAG (TU Delft, 2025) to classify buildings in the Dutch building stock and then uses this classification to estimate the material volumes in buildings. Some classifications of the Dutch building stock already exist, but they are either too limited in their classfication or are not public. 

Therefore this project aims to make the classification **publicly available** and make estimates on the **materials in the current building stock.**

In this README, the SQL-script is dissected and explained, as the documentation functions within SQL-scripts are rather limited.

- Next steps: Map Future build- and demolition projects to predict material flow
- Use prediction to improve logistics and enable circularity
- Further classify buildings in subclasses and improve the 'other' category

---

## Setup

To run the classification script, it is necessary to have:
- A PostgreSQL database with PostGIS
- Database schemas for the Dutch BAG, 3D-BAG, and Cadastral Parcels
- Write permission to the database

If you don't have this setup, but want to give it a go, you can send me a message. I still have some legacy Python code which I used for the first tests and should work for smaller areas.

---

## Glossary

**Address**: a single dwelling.
**Building**: a singular structure that can contain one or more addressses.
**Single house**: A building containing exactly one dwelling unit, not physically attached to other buildings.
**Row house**: A building type where each dwelling unit is side-by-side and shares walls with adjacent units. 
Note: In this analysis, duplex (semi-detached) houses are included as a subset of row houses due to their structural similarity.
**Appartment**: A building with multiple dwelling units stacked vertically (and sometimes horizontally), up to 4 floors and sometimes also horizontally.These can be appartment complexes, duplex houses or maisonettes.
**Highrise**: Same as above, but exceeding 4 floors.

## Workflow

![alt text](https://github.com/GidoStoop/BAG_classification_material_volumes/blob/main/images/classification_workflow.png "Classification workflow")

## SQL Script Walkthrough

The SQL script organizes the pipeline for classifying buildings and estimating their material volumes through the following steps:

### Step 1: Setup and Filters

- **Current Buildings Selection**: Filters buildings (`pand`) currently in use within a defined geographical bounding box.
- **Current Addresses Linkage**: Links each `verblijfsobject` (residential/office unit) to their corresponding building.
- **Address Counting**: Counts the number of address entries per building and filters those without addresses.

```sql
CREATE TABLE building_material_volumes.current_buildings_filtered AS
WITH
current_buildings AS (
    -- Filter buildings based on the bounding box and status
),
current_addresses AS (
    -- Link addresses to buildings
),
address_count AS (
    -- Count addresses per building
)
SELECT ...
```

### Step 2: Handle Geometries and Use Functions

- **Floor Area Calculation**: Computes total floor area for each building by summing up areas of all related `verblijfsobjects`.
- **Geometric Processing**: Handles spatial intersections to calculate touching buildings, potentially determining adjacency and row houses.

```sql
current_verblijfsobject AS (
    -- Select active verblijfsobjecten with specific attributes
),
floor_area_building AS (
    -- Calculate floor area per building
)
...
SELECT id_pand, SUM(vp.floor_area / cpp.n_pand) AS tot_floor_area FROM ...
```

### Step 3: Retrieve Cadastral Parcel Data
- **Cadastral Parcel Overlap**: Obtains cadastral parcel data for BAG polygons that are potentially high-rise buildings. Since parcels can include non-built-up areas like gardens, they are clipped to the extent of the BAG polygons to obtain precise built-up areas.

**Why?** To accurately assess whether a building is a high-rise, it's crucial to understand its actual floor area. Sometimes addresses are based on the front-door's location, not the dwelling's physical location, skewing floor area ratios and consequently material volume calculations. Thus, it's vital to associate BAG polygons with the same building and adjust floor area distribution.

**BAG buildings**
![image](https://github.com/GidoStoop/BAG_classification_material_volumes/blob/main/images/Melissakade-Utrecht_BAG.png)
**Cadastral parcel**
![image](https://github.com/GidoStoop/BAG_classification_material_volumes/blob/main/images/Melissakade-Utrecht_Kadaster.png)</br>

```sql
-- Computes building–parcel overlap and overlap_ratio:
highrise_parcels AS (
    -- Query parcels with potential highrise buildings
),
buildings_on_parcel AS (
    -- Query all buildings on those parcels
),
combined_buildings AS (
    -- Group buildings on same parcel
),
buildings_highrise AS (
    -- Combine the grouped buildings
),
```

### Step 3: Classification

- **Building Typology**: Determines building type (single_house, row_house, apartment, highrise, office, commercial) using SQL logic including `touch_count` and address count rules.
- **3D BAG Integration**: Enhances classification with 3D building data from BAG3D for more precise calculation of potential high-rise buildings.

```sql
SELECT *,
    ('winkelfunctie' = ANY(gebruiksdoel)) AS commercial,
    -- Various conditions to classify the buildings
```

**Note!** Some buildings are very hard to classify, for instance when the BAG-pand and the cadastral parcels are both awkwardly defined:

**BAG**
![image](https://github.com/GidoStoop/BAG_classification_material_volumes/blob/main/images/Scharleistraat-Utrecht_BAG.png)
**Kadaster**
![image](https://github.com/GidoStoop/BAG_classification_material_volumes/blob/main/images/Scharleistraat-Utrecht_Kadaster.png)

### Step 4: Material Volume Estimation

- **Material Intensity**: Calculates material volumes based on typologies using intensity values from Sprecher et al. (2022).
- **Output Results**: Generates a classified dataset with calculated material volumes for each building.

```sql
WITH ...
SELECT cbf.id_pand,
    cbf.category,
    cbf.tot_floor_area * mi.concrete AS concrete,
    -- Calculation for various materials
FROM classified_buildings_final cbf
LEFT JOIN building_material_volumes.material_intensities mi
ON cbf.category = mi.type;
```
---

## Results

The SQL script saves the results to a new schema in the database. Analyzing this data can aid future urban planning, demolition and construction strategy in the context of circularity and sustainability.

Take a look at some results:

![alt text](https://github.com/GidoStoop/BAG_classification_material_volumes/blob/main/images/20260417_Utrecht_building_classification.png "Classification")

![alt text](https://github.com/GidoStoop/BAG_classification_material_volumes/blob/main/images/3D_Bag_treemaps.png "Treemaps")

---

## 📖 Sources

- Kadaster. (2025a). Basisregistratie Adressen en Gebouwen (BAG). BAG-Viewer. [BAG-Viewer](https://bagviewer.kadaster.nl/lvbag/bag-viewer)
- Kadaster. (2025b). Kadastrale percelen. Kadastrale Kaart. [Kadastrale Kaart](https://kadastralekaart.com)
- Sprecher, B., Verhagen, T. J., Sauer, M. L., Baars, M., Heintz, J., & Fishman, T. (2022). Material intensity database for the Dutch building stock: Towards Big Data in material stock analysis. Journal of Industrial Ecology, 26(1), 272-280.
- TU Delft (2025). 3D BAG. 3D BAG-Viewer. [3D BAG-Viewer](https://3dbag.nl/en/viewer)