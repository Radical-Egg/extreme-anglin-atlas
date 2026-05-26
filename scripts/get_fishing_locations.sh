#!/usr/bin/env bash
# Get the initial set of fishing information for the data pipeline

curl -L 'https://wowwiki-archive.fandom.com/api.php?action=parse&page=Fishing_locations&prop=wikitext&format=json' \
    -o fishing_locations_wikitext.json
