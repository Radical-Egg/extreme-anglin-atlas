PYTHON ?= python3
WIKITEXT ?= data/fishing_locations_wikitext.json
FISH_DIR ?= data/manual/fish
ZONE_DIR ?= data/manual/zones
GENERATED_CSV ?= data/generated/fishing_locations_wowwiki.csv
MANUAL_CSV ?= data/manual/fishing_entries.csv
JSON ?= addon/Data/FishingData.json
LUA ?= addon/Data/FishingData.lua
DIST ?= dist
ADDON_VERSION ?= $(shell sed -n 's/^## Version:[[:space:]]*//p' addon/ExtremeAnglinAtlas.toc)
PACKAGE_ZIP ?= $(DIST)/ExtremeAnglinAtlas-$(ADDON_VERSION).zip

.PHONY: build rebuild extract-data export-json export-lua package check clean clean-dist

build: extract-data export-json export-lua

rebuild: clean build

extract-data:
	$(PYTHON) scripts/extremeanglinatlas_data.py extract-wowwiki --input $(WIKITEXT) --fish-dir $(FISH_DIR) --zone-dir $(ZONE_DIR) --out $(GENERATED_CSV)

export-json:
	$(PYTHON) scripts/extremeanglinatlas_data.py export-json --csv $(GENERATED_CSV) --csv $(MANUAL_CSV) --out $(JSON)

export-lua:
	$(PYTHON) scripts/extremeanglinatlas_data.py export-lua --csv $(GENERATED_CSV) --csv $(MANUAL_CSV) --out $(LUA)

package: build
	$(PYTHON) scripts/package_addon.py --addon-dir addon --out-dir $(DIST)

check:
	$(PYTHON) -m py_compile scripts/*.py
	$(MAKE) build
	$(MAKE) package
	$(PYTHON) -m zipfile --test $(PACKAGE_ZIP)

clean:
	rm -f $(GENERATED_CSV) $(JSON) $(LUA)

clean-dist:
	rm -rf $(DIST)
