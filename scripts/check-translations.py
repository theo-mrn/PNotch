#!/usr/bin/env python3
"""Fails when a string of the app has no French translation.

    scripts/check-translations.py [PNotch/Localizable.xcstrings]
"""
import json
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "PNotch/Localizable.xcstrings"
with open(path, encoding="utf-8") as file:
    catalog = json.load(file)

def is_translated(localization):
    """A string unit, or every variant of a plural or device variation, translated."""
    if "stringUnit" in localization:
        unit = localization["stringUnit"]
        return unit.get("state") == "translated" and bool(unit.get("value"))
    variations = localization.get("variations", {})
    variants = [variant for kind in variations.values() for variant in kind.values()]
    return bool(variants) and all(is_translated(variant) for variant in variants)


missing = []
for key, entry in catalog["strings"].items():
    # Nothing to translate: an empty key, or one marked as such in the catalog.
    if not any(character.isalpha() for character in key) or entry.get("shouldTranslate") is False:
        continue
    if not is_translated(entry.get("localizations", {}).get("fr", {})):
        missing.append(key)

if missing:
    print(f"{len(missing)} string(s) without a French translation in {path}:")
    for key in sorted(missing):
        print(f"  - {key}")
    sys.exit(1)

print(f"All {len(catalog['strings'])} strings of {path} are translated into French.")
