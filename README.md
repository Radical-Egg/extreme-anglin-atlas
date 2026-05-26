# Extreme Anglin' Atlas

Extreme Anglin' Atlas is a World of Warcraft TBC Classic addon for browsing fishing locations and the fish available in each zone.

Project Structure:

- `addon/` contains the addon.
- `data/fishing_locations_wikitext.json` is the saved WowWiki source page. This is used for the initial data pipeline to start building out the fish and their locations into a csv
- `data/manual/fish/*.out` contains saved fish pages used to backfill item IDs.
- `data/manual/zones/*.out` contains saved zone pages used to backfill zone IDs and regions.
- `data/generated/fishing_locations_wowwiki.csv` is generated from that source.
- `data/manual/fishing_entries.csv` is the repeatable manual-entry and correction path.
- `scripts/extremeanglinatlas_data.py` builds CSV-derived runtime data.
- `scripts/grab_a_fish.py` and `scripts/grab_a_zone.py` refresh saved WowWiki page captures.
- `scripts/package_addon.py` creates the release zip.

## Setup

Setup python virtual environment

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
```

## Data Workflow

The source data is normalized into CSV, then exported directly for the addon. Run:

```sh
make build
```

That:

- extracts `data/fishing_locations_wikitext.json` into `data/generated/fishing_locations_wowwiki.csv`;
- fills `item_id` from saved fish pages in `data/manual/fish`;
- fills `zone_external_id` and `zone_category` from saved zone pages in `data/manual/zones`;
- merges manual rows from `data/manual/fishing_entries.csv`;
- exports `addon/Data/FishingData.json`;
- exports `addon/Data/FishingData.lua` for the addon runtime.

Generated outputs include:

- `data/generated/fishing_locations_wowwiki.csv`
- `addon/Data/FishingData.json`
- `addon/Data/FishingData.lua`

The fishing locations page does not include item IDs, zone IDs, or region categories, so generated rows get those from the saved fish and zone page captures.

The JSON and Lua exports are generated, so do not edit them directly. Edit the source JSON, generated parser, or manual CSV instead, then rebuild.

The saved `.out` files under `data/manual/` are intentionally source data and should be tracked. Local virtualenvs, bytecode caches, and packaged zips are ignored.

## Addon Runtime

The addon loads `addon/Data/FishingData.lua` before `ExtremeAnglinAtlas.lua`. Open it in game with:

```text
/extremeanglinatlas
/eaa
```

## Packaging

Build a CurseForge-ready zip with:

```sh
make package
```

That creates `dist/ExtremeAnglinAtlas-<version>.zip` with a top-level `ExtremeAnglinAtlas/` folder, matching the addon TOC name.

Run the same checks used by CI with:

```sh
make check
```

## Release

Publishing a GitHub release runs `.github/workflows/build_and_release.yml`. The workflow builds the addon zip and uploads `dist/*.zip` to the release page.
