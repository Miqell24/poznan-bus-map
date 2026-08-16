#!/usr/bin/env bash
# Downloads input data: ZTM Poznań GTFS feed, OSM network (Overpass), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# Poznań quirk: ONE feed carries both modes (route_type 0 trams, 3 buses), unlike
# Kraków's split A/T feeds — build.mjs separates them by route_type.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs data/osm web/vendor

# A downloaded extract is only accepted if it PARSES and carries a plausible
# number of elements. `grep -q '"elements"'` — the guard this family used
# everywhere — passes on a truncated response too: Brașov's roads arrived as a
# 65 kB fragment that still contained the string, was taken for complete, and
# silently skipped the city (16.08.2026).
# The minimum differs by extract: a road network runs to tens of thousands of
# ways, a tram network to a few hundred, so the caller passes its own floor
# rather than sharing one.
# A rejected file is deleted rather than left behind — the `[ ! -f … ]` gates
# below only ask whether the file exists, so a fragment on disk would be taken
# for a finished download on the next run.
ok_json () { # $1=file  $2=minimum element count
  python3 - "$1" "$2" <<'PYEOF' 2>/dev/null
import json, sys
try:
    sys.exit(0 if len(json.load(open(sys.argv[1])).get("elements", [])) >= int(sys.argv[2]) else 1)
except Exception:
    sys.exit(1)
PYEOF
}

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
       && ok_json "data/osm/poznan.json" 2000; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/poznan.json; echo "Overpass: all mirrors failed" >&2; exit 1; }
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
       && ok_json "data/osm/poznan-tram.json" 40; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/poznan-tram.json; echo "Overpass (tram): all mirrors failed" >&2; exit 1; }
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/ztm_poznan_gtfs.zip data/osm/poznan.json data/osm/poznan-tram.json web/vendor/maplibre-gl.js 2>/dev/null || true
