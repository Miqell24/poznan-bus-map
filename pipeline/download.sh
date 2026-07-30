#!/usr/bin/env bash
# Downloads input data: ZTM Poznań GTFS feed, OSM network (Overpass), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# Poznań quirk: ONE feed carries both modes (route_type 0 trams, 3 buses), unlike
# Kraków's split A/T feeds — build.mjs separates them by route_type.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs data/osm web/vendor

# 1) GTFS — ZTM Poznań (buses + trams, 13 operators). The endpoint always serves
#    the newest file; validity is only a day or two, so re-download often.
if [ ! -f data/gtfs/routes.txt ]; then
  echo "== ZTM Poznań GTFS =="
  curl -fL --retry 3 --max-time 600 -H "Accept: application/octet-stream" \
    -o data/ztm_poznan_gtfs.zip "https://www.ztm.poznan.pl/pl/dla-deweloperow/getGTFSFile"
  unzip -o data/ztm_poznan_gtfs.zip -d data/gtfs
fi

# 2) OSM — roadways over the whole ZTM network (GTFS shapes extent + margin: the
#    suburban lines reach Murowana Goślina, Kórnik, Mosina, Stęszew and Tarnowo
#    Podgórne), incl. highway=construction
if [ ! -f data/osm/poznan.json ]; then
  echo "== Overpass (roads) =="
  Q='[out:json][timeout:900];way(52.14,16.51,52.60,17.30)["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 900 -o data/osm/poznan.json --data-urlencode "data=$Q" "$EP" \
       && grep -q '"elements"' data/osm/poznan.json; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { echo "Overpass: all mirrors failed" >&2; exit 1; }
fi

# 2b) OSM — tram tracks (separate network: railway=tram, not roadways). The bbox
#     covers the city network incl. the PST tramway and the Franowo depot area.
if [ ! -f data/osm/poznan-tram.json ]; then
  echo "== Overpass (trams) =="
  QT='[out:json][timeout:300];way(52.33,16.78,52.49,17.05)["railway"~"^(tram|light_rail)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 300 -o data/osm/poznan-tram.json --data-urlencode "data=$QT" "$EP" \
       && grep -q '"elements"' data/osm/poznan-tram.json; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { echo "Overpass (tram): all mirrors failed" >&2; exit 1; }
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/ztm_poznan_gtfs.zip data/osm/poznan.json data/osm/poznan-tram.json web/vendor/maplibre-gl.js 2>/dev/null || true
