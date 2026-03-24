import os
import osmium
import pygeohash as geohash
import sqlite3
import shapely.geometry as geom
import shapely.wkb as swkb
import argparse
import time

# --- Configuration & Filters ---
EXCLUDED_HIGHWAYS = {
    'footway', 'path', 'track', 'steps', 'cycleway',
    'service', 'pedestrian', 'bridleway', 'construction'
}
ROAD_PRECISION = 8
REGION_PRECISION = 5 

BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz'

def geohash_to_int(gh):
    """Convert a geohash string to a 64-bit integer."""
    val = 0
    for char in gh:
        val = (val << 5) | BASE32.index(char)
    return val

class GeohashCoverer:
    @staticmethod
    def get_covering_hashes_for_segment(p1, p2, precision):
        """Find all geohashes that a line segment intersects."""
        line = geom.LineString([p1, p2])
        step = 0.0001 # approx 11m
        length = line.length
        num_steps = max(1, int(length / step))
        hashes = set()
        for i in range(num_steps + 1):
            t = i / num_steps
            p = line.interpolate(t, normalized=True) 
            hashes.add(geohash.encode(p.y, p.x, precision=precision))
        return hashes

    @staticmethod
    def get_covering_hashes_for_polygon(polygon, precision):
        """Find all geohashes within a polygon."""
        minx, miny, maxx, maxy = polygon.bounds
        step = 0.044 
        hashes = set()
        y = miny + step/2
        while y <= maxy:
            x = minx + step/2
            while x <= maxx:
                if polygon.contains(geom.Point(x, y)):
                    hashes.add(geohash.encode(y, x, precision=precision))
                x += step
            y += step
        return hashes

class GeocoderBuilder(osmium.SimpleHandler):
    def __init__(self, cursor, lang_code=None):
        super(GeocoderBuilder, self).__init__()
        self.cursor = cursor
        self.lang_tag = f"name:{lang_code}" if lang_code else "name"
        self.wkb_factory = osmium.geom.WKBFactory()
        self.batch_streets = []
        self.batch_regions = []
        self.name_cache = {}

    def get_name_id(self, tags):
        """Get or create a name ID for the given tags based on language preference."""
        name = tags.get(self.lang_tag) or tags.get('name')
        if not name:
            return None
        if name in self.name_cache:
            return self.name_cache[name]
        
        self.cursor.execute("INSERT OR IGNORE INTO names (name) VALUES (?)", (name,))
        self.cursor.execute("SELECT id FROM names WHERE name = ?", (name,))
        name_id = self.cursor.fetchone()[0]
        self.name_cache[name] = name_id
        return name_id

    def way(self, w):
        highway = w.tags.get('highway')
        if highway and highway not in EXCLUDED_HIGHWAYS:
            name_id = self.get_name_id(w.tags)
            if name_id:
                weight = 0.5 if highway in ['primary', 'trunk', 'motorway'] else 1.0
                nodes = [(n.lon, n.lat) for n in w.nodes if n.location.valid()]
                if len(nodes) < 2: return
                
                hashes = set()
                for i in range(len(nodes) - 1):
                    hashes.update(GeohashCoverer.get_covering_hashes_for_segment(nodes[i], nodes[i+1], ROAD_PRECISION))
                
                gh_ints = {geohash_to_int(gh) for gh in hashes}
                
                for gh_int in gh_ints:
                    # Weight: 1 for main roads, 2 for others
                    w_int = 1 if highway in ['primary', 'trunk', 'motorway'] else 2
                    self.batch_streets.append((gh_int, name_id, w_int))
                    if len(self.batch_streets) >= 10000: self._flush_streets()

    def area(self, a):
        boundary = a.tags.get('boundary')
        if boundary == 'administrative':
            name_id = self.get_name_id(a.tags)
            lvl = a.tags.get('admin_level')
            if name_id and lvl:
                try:
                    level = int(lvl)
                    if 2 <= level <= 10:
                        wkb = self.wkb_factory.create_multipolygon(a)
                        poly = swkb.loads(wkb)
                        hashes = GeohashCoverer.get_covering_hashes_for_polygon(poly, REGION_PRECISION)
                        for gh in hashes:
                            self.batch_regions.append((geohash_to_int(gh), name_id, level))
                            if len(self.batch_regions) >= 1000: self._flush_regions()
                except Exception: pass

    def node(self, n):
        # Handle "place" points as fallback
        place = n.tags.get('place')
        if place:
            name_id = self.get_name_id(n.tags)
            if name_id:
                # Simple level mapping
                lvl_map = {
                    'state': 4, 'region': 4,
                    'city': 6, 'district': 6,
                    'town': 8, 'township': 8, 'suburb': 8,
                    'village': 9, 'neighbourhood': 9, 'quarter': 9, 'ward': 9, 'hamlet': 9
                }
                lvl = lvl_map.get(place, 10)
                
                gh_int = geohash_to_int(geohash.encode(n.location.lat, n.location.lon, precision=REGION_PRECISION))
                self.batch_regions.append((gh_int, name_id, lvl))
                if len(self.batch_regions) >= 1000: self._flush_regions()

    def _flush_streets(self):
        if self.batch_streets:
            self.cursor.executemany("INSERT INTO streets_temp VALUES (?, ?, ?)", self.batch_streets)
            self.batch_streets.clear()

    def _flush_regions(self):
        if self.batch_regions:
            self.cursor.executemany("INSERT OR IGNORE INTO regions VALUES (?, ?, ?)", self.batch_regions)
            self.batch_regions.clear()

def main():
    parser = argparse.ArgumentParser(description="Traccar-style Geocoder DB Generator")
    parser.add_argument("--osm", default="myanmar-latest.osm.pbf", help="Input OSM PBF file")
    parser.add_argument("--out", default="myanmar_ultra_res_my.db", help="Output SQLite DB file")
    parser.add_argument("--lang", default="my", help="Prefered language code (my, en, zh, etc.)")
    args = parser.parse_args()

    if not os.path.exists(args.osm): 
        print(f"Error: {args.osm} not found.")
        return

    print(f"🚀 Starting generation for language: {args.lang}")
    if os.path.exists(args.out): os.remove(args.out)
    
    conn = sqlite3.connect(args.out)
    cur = conn.cursor()
    cur.execute("PRAGMA synchronous = OFF")
    cur.execute("PRAGMA journal_mode = WAL")
    
    cur.execute("CREATE TABLE names (id INTEGER PRIMARY KEY, name TEXT UNIQUE)")
    cur.execute("CREATE TABLE regions (gh INTEGER, name_id INTEGER, lvl INTEGER, PRIMARY KEY(gh, name_id)) WITHOUT ROWID")
    cur.execute("CREATE TABLE streets_temp (gh INTEGER, name_id INTEGER, weight INTEGER)")
    conn.commit()

    builder = GeocoderBuilder(cur, args.lang)
    builder.apply_file(args.osm, locations=True, idx='flex_mem')
    
    builder._flush_streets()
    builder._flush_regions()
    conn.commit()

    print("⚡ Optimizing and building index...")
    # Create the final streets table with WITHOUT ROWID and composite PK for clustering
    cur.execute("""
        CREATE TABLE streets (
            gh INTEGER, 
            name_id INTEGER, 
            weight INTEGER, 
            PRIMARY KEY(gh, name_id)
        ) WITHOUT ROWID
    """)
    cur.execute("INSERT INTO streets SELECT gh, name_id, MIN(weight) as weight FROM streets_temp GROUP BY gh, name_id ORDER BY gh")
    cur.execute("DROP TABLE streets_temp")
    
    # We no longer need separate indexes on gh because WITHOUT ROWID uses the PK as the index itself,
    # and gh is the first column in the PK.
    conn.commit()
    
    cur.execute("VACUUM")
    conn.close()
    
    print(f"🎉 Done! Generated: {args.out} (Size: {os.path.getsize(args.out)/1024/1024:.2f} MB)")

if __name__ == "__main__":
    start_time = time.time()
    main()
    print(f"Total time: {time.time() - start_time:.2f}s")
