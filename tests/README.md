# Offline addon tests

From the repository root, using Python 3:

```sh
python -m pip install --target .test-deps lupa
python -m unittest discover -s tests -p "test_*.py" -v
```

The tests execute the addon in Lua 5.1 with a small WoW API mock. They cover client-language defaults, manual overrides, persistence, live UI changes, search-placeholder behavior, dialogs and calendar labels, whisper limits and replies, and sync between a German organizer and an English guest. The test dependencies are not part of the addon and are not needed in WoW.

An actual Forever client is still needed to verify rendering, font widths and Blizzard API behavior in game.

`test_loot.py` additionally covers German/English loot receipts independently of addon language, rarity and quantity, accented names, duplicate chat events, delayed item data, run boundaries, persisted history and pending metadata, UI filters/tooltips, and sharing a raid with an absent player through the real encoded packet queue. Transfer cases include reordered/duplicate packets, repeated imports, explicit acceptance, sender validation, declined offers, truncated/corrupt data and expiry. No real game or network messages are sent by the tests.
