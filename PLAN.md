# PLAN — Interactive Poznań transport map

Target: an interactive (zoom/pan) web map of Poznań public transport in the visual
logic of a printed network map: lines drawn **exactly along roadways and tram
tracks**, line numbers written along every street they use, stops labeled, correct
roundabout arcs and intersection turns. Fourth city of the krakow-bus-map pipeline.

## Architecture

- **Plain JavaScript**: pipeline in Node ≥ 18 (no npm dependencies), frontend in the browser.
- **Input data**: ZTM Poznań GTFS (`ztm.poznan.pl/pl/dla-deweloperow/getGTFSFile`,
  buses + trams of 13 operators in one file) plus the OSM road and tram network via
  the Overpass API (bbox of the whole ZTM service area).
- **Map matching**: own HMM/Viterbi implementation (Newson–Krumm 2009) on a directed
  graph — the heart of the project.
- **Frontend**: MapLibre GL JS (vendored) + OSM vector tiles from OpenFreeMap
  (`positron` style, recolored to a paper-map palette). Static server on port **8127**.

## Poznań-specific data quirks (vs the sibling cities)

1. **One feed, both modes.** Kraków ships separate A/T files and Athens two separate
   agencies' feeds; ZTM Poznań ships one file with `route_type` 0 (19 tram lines,
   1–18 + night 201) and 3 (173 bus lines, incl. `T1`/`T7` tram-replacement and
   `PKS`). New `cfg.routeTypes` filter in build.mjs splits them — without it `--all`
   on the bus mode would swallow the trams — and `--tram all` takes every tram line
   from the feed instead of a hand-written list.
2. **Sparse, simplified shapes**: median point spacing 42 m, p90 164 m, holes up to
   2.8 km. `GAP_MIN` 250 m (measured: 120/250/400 give the same ~3 m error, so the
   error comes from shape simplification, not from the threshold).
3. **Short feed validity**: files are valid for a day or two, so `data/gtfs` must be
   wiped to pull a fresh one (see README).
4. **13 operators**: MPK Poznań plus the suburban companies (KOMBUS, TRANSKOM,
   TPBUS, ROKBUS, …) — all in one `agency.txt`, no special handling needed.
5. **No trolleybuses, no metro** — the trolleybus green and the metro ribbon of the
   sibling maps never trigger here.

## Pipeline stages

1. `pipeline/download.sh` — GTFS zip, Overpass roads (bbox 52.14–52.60, 16.51–17.30),
   Overpass tram tracks (52.33–52.49, 16.78–17.05), MapLibre vendored.
2. `build.mjs` — routes (filtered by route_type) → representative shape per
   line+direction (most trips); stop sequences from streamed `stop_times.txt`.
3. Directed graph from OSM (`lib/graph.mjs`): oneway/roundabout rules, bus-gate
   access, penalty-weighted contraflow; rail mode for trams.
4. HMM/Viterbi (`lib/hmm.mjs`): emission σ, transition |route − straight|/β via
   capped Dijkstra; controlled breaks bridged by routing; raw-trace fallback when
   OSM lacks the road.
5. Data products (`data/out/`): `streets.geojson` (merged strokes per roadway),
   `labels.geojson` (one rotated number label per street × line set),
   `stops.geojson` (snapped, termini flagged), `badges.geojson` (terminus line boxes
   per zoom band), `route.geojson`, `meta.json`.
6. Frontend (`web/`): KMK-style strokes (bus navy, tram red), rotated number labels
   beside streets, two-color shared-corridor rows, half-disc stops, boxed terminus
   badges, mode filters + clickable line list, poster PNG export.

## Current state

- 173 bus + 19 tram lines, 368 directions, 5 365 km drawn. Build ~47 s.
- Weighted mean error **3.75 m**; 16 Viterbi breaks (319 m of raw trace), clustered
  at four spots: 10 of them at one place near Puszczykowo (lines 602/603/651/690/PKS),
  two near Pobiedziska (400/412), two near Kórnik (582) and two on tram 14 at Rondo
  Kaponiera. No observation left without candidates.
- 3 060 stop poles, 1 561 name labels, 1 644 number labels, 2 317 badge boxes across
  4 zoom bands (37 colliding grids fused), 57 shared bus+tram corridor segments.
- Verified in browser: rendering, filters, line selection (tram 14 → its own runs
  only), badge fusion per zoom band, PNG export (5826×6561, 28 MB), no console errors.

## Roadmap

1. Look into the Puszczykowo break cluster (one missing OSM link costs 10 breaks).
2. KMK-style corridors: merging twin carriageways into one stroke — deferred
   ("corridor axes" preprocessing).
3. Route variants + one-way arrows; line/stop search; GTFS-RT (ZTM publishes it).
4. Hosting on GitHub Pages from `main:/docs`, like the three sibling maps.
