# trabcdefg


A Flutter GPS tracking app that connects to a compatible tracking server API.
Currently supports API version 6.16.0.

[![Watch Demo Short](https://img.youtube.com/vi/W3b8m3Pv3MQ/0.jpg)](https://youtube.com/shorts/W3b8m3Pv3MQ)

## Features

- Track devices live on a map with multiple map styles.
- Search and filter devices, view status and mileage, and follow live locations.
- Review and replay historical routes, view mileage reports, and export GPX tracks.
- Manage devices, geofences, groups, drivers, notifications, and other tracking data.
- Share device access and customize the app's appearance and language.

## Myanmar Offline Geocoder

The Myanmar offline address database is generated from OpenStreetMap (OSM) PBF data with `scripts/geocoder_generator.py`. The generator creates a SQLite database containing named roads and administrative areas, indexed by geohash. This approach can be adapted for other countries by changing the input data, name language, road filters, geohash precision, and OSM administrative/place mappings to match local data.

### Address format and precision

Offline addresses are intended to use **road name + city/region**. Township names are omitted because their current geohash-based matching can select the wrong township. The offline address lookup currently uses administrative records at `lvl <= 6`; place types such as `township` are assigned `lvl = 8` by the generator and therefore are not used for this broader city/region result. `lvl` is an administrative/search priority, not a geohash precision.

The generator uses these geohash precisions:

- **Roads: 8 characters** (`ROAD_PRECISION`). Each named road is sampled along its OSM line geometry and the resulting geohashes are indexed. Eight characters represent a small area (roughly tens of metres, depending on latitude), suitable for matching a nearby road.
- **Administrative areas: 5 characters** (`REGION_PRECISION`). Polygon areas and supported place nodes are stored at this coarser resolution (roughly several kilometres, depending on latitude), for broader city/region matching.

More geohash characters mean smaller cells and more precise matching. Road lines are sampled at approximately `0.0001` degrees and administrative polygons at approximately `0.044` degrees; these are sampling intervals, not geohash precision. Adjust them along with the precision if the target country's geography or data density requires it.

### Generate the database

Install the Python dependencies `osmium`, `pygeohash`, and `shapely`, obtain an OSM PBF extract, and run:

```bash
python scripts/geocoder_generator.py \
  --osm myanmar-latest.osm.pbf \
  --out myanmar_ultra_res_my.db \
  --lang my
```

- `--osm`: input OSM PBF file (defaults to `myanmar-latest.osm.pbf`).
- `--out`: output SQLite database (defaults to `myanmar_ultra_res_my.db`).
- `--lang`: preferred OSM name language code, used as `name:<code>` when available, with `name` as fallback (defaults to `my`).

For another country, use its PBF extract and preferred language, then review `EXCLUDED_HIGHWAYS`, `ROAD_PRECISION`, `REGION_PRECISION`, and the `place`-to-`lvl` mapping in the generator. Check the local OSM `boundary=administrative` and `admin_level` conventions as well. Ensure the generated database is packaged at the path expected by the app, and verify that the offline lookup's administrative-level filter and address formatting return the intended **road + city/region** format for that country.

## Screenshots

![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/1.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/2.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/3.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/4.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/5.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/6.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/7.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/8.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/9.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/10.jpg) <br />
