# Vassilis DungeonPlaner

**Deutsch / English · WoW: Forever · Version 0.4.0**

Plane Raids, Dungeons und andere Termine, verwalte Zusagen und bestätige Teilnehmer – mit oder ohne Gilde. Spieler ohne Addon können per Whisper antworten.

## Download und Installation / Download and installation


Den Quellcode als ZIP herunterladen und daraus nur den Ordner `VassilisDungeonPlaner` in den entsprechenden Addon Ordner schieben.

**Sprache :** Standardmäßig Clientsprache; im Hauptfenster oben rechts zwischen Automatisch, Deutsch und English wechseln.

- [Deutsche Anleitung](VassilisDungeonPlaner/README.md)
- [English guide](VassilisDungeonPlaner/README.en.md)

## Entwicklung / Development

Die Lua-Dateien in `VassilisDungeonPlaner` bilden das Addon. Lokale Tests sind unter [tests](tests/README.md) dokumentiert. 

Mit Python 3.9 oder neuer kann alternativ eine installierbare ZIP erstellt werden.

```sh
python tools/package.py
```

Das Ergebnis liegt in `dist`. Testbibliotheken, Git-Dateien und Entwicklungswerkzeuge werden nicht mitgeliefert. 

## Lizenz / License

[MIT](LICENSE) · Copyright © 2026 Vassilios Marakis
