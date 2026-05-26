# Fishing Data

Codex did most of the heavy lifting here after I aggregated the source data from the wiki. Here are some notes to remind my future self what is going on here. 


The current seed source is `fishing_locations_wikitext.json`, a saved WowWiki parse response. It is extracted into `generated/fishing_locations_wowwiki.csv` during the build.

Saved fish pages in `manual/fish/*.out` backfill `item_id` values into the generated CSV. Files beginning with `error_` are ignored.

Saved zone pages in `manual/zones/*.out` backfill `zone_external_id` values from `elinks-zone` templates and `zone_category` values from zone category/footer metadata. Redirect-only files do not contain zone IDs and need to be replaced with their target pages.

For repeatable manual entry and corrections, add rows to `manual/fishing_entries.csv` and run:

```sh
make build
```

Keep one row per zone/fish combination. Leave unknown numeric values blank instead of guessing.

The fishing locations source only includes names, so keep the fish and zone page captures around if the CSV needs to be regenerated.

To refresh missing page captures after regenerating the CSV:

```sh
python scripts/grab_a_fish.py
python scripts/grab_a_zone.py
```

Those scripts intentionally sleep between requests. I don't think that the WoW wiki admins care if automation is pulling their pages but I figured a sleep would be respectful. They require `requests` from the repo `requirements.txt`.

The addon consumes `../addon/Data/FishingData.lua`. `../addon/Data/FishingData.json` is kept as a convenient build artifact for inspection and tooling.
