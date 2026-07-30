# poznan-bus-map

Interactive web map of Poznań public transport in the visual logic of a classic
printed network map: **173 bus lines and 19 tram lines (ZTM Poznań)** drawn exactly
along roadways and tram tracks (own HMM/Viterbi map matching on an OSM graph), line
numbers written parallel to every street they use, labeled stops, true roundabout
arcs.

Fourth city of the family, alongside
[krakow-bus-map](https://github.com/Miqell24/krakow-bus-map),
[athens-bus-map](https://github.com/Miqell24/athens-bus-map) and
[thessaloniki-bus-map](https://github.com/Miqell24/thessaloniki-bus-map) — same
pipeline and same visual system, different city and feeds.

## Features

- GTFS from ZTM Poznań matched onto the OSM road and tram network — weighted mean
  error **3.75 m** over 5 365 km of drawn route, 16 Viterbi breaks (319 m of raw
  trace) in the whole network.
- **One feed, two modes**: the ZTM file carries trams (`route_type` 0) and buses
  (3) together, so each mode filters the same feed by `routeTypes` and matches on
  its own graph — trams on `railway=tram`, buses on roadways.
- KMK-style rendering: one stroke per roadway, aggregated line numbers rotated
  parallel to streets, shared bus+tram corridors get a two-color number row,
  half-disc stops turned to their side of the street, termini with boxed line
  badges that fuse into one complex when they would collide at the current zoom.
- "Paper map" recolor of the base map: warm districts, green parks, real-blue
  water, pale-yellow motorways.
- Panel with mode visibility filters and a clickable line list (click a line to
  see its route with all stops).
- Poster-grade PNG export: the current view re-rendered in tiles at ~+3 zoom
  levels of extra detail (street and stop names become legible as you zoom into
  the image).
- GTFS shapes.txt quality report (`npm run report` → `data/gtfs-gaps-report.md`).

## Requirements

Node ≥ 18 (no npm dependencies), `curl`, `unzip`, internet on first run.

## Usage

```bash
npm run download   # ZTM GTFS + OSM (Overpass) + MapLibre (cached in data/ and web/vendor/)
npm run build      # extraction + map matching + GeoJSON files into data/out/
npm run serve      # http://localhost:8127
```

ZTM Poznań feeds are valid for a day or two only. To pull a fresh one:

```bash
rm -rf data/gtfs data/ztm_poznan_gtfs.zip && npm run download && npm run build
```

## Structure

- `pipeline/download.sh` — input data download
- `pipeline/build.mjs` — GTFS → OSM graph → HMM/Viterbi → `data/out/*.geojson`
- `pipeline/lib/` — csv (streaming), geo (local projection), graph (graph + Dijkstra), hmm (Viterbi)
- `pipeline/report-gaps.mjs` — GTFS shapes.txt gap report
- `web/` — MapLibre GL frontend (vendored, OpenFreeMap positron tiles)
- `docs/` — static bundle published via GitHub Pages (web + data/out copies)

Full plan and roadmap: [PLAN.md](PLAN.md).

## Data attribution

Map data © OpenStreetMap contributors · tiles by OpenFreeMap · timetables: GTFS
ZTM Poznań.
