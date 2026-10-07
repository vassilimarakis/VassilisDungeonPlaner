# Vassilis DungeonPlaner

**Deutsch / English · WoW: Forever · Version 0.5.0 (Beta)**

Plane Raids, Dungeons und andere Termine, verwalte Zusagen und bestätige Teilnehmer – mit oder ohne Gilde. Spieler ohne Addon können per Whisper antworten.

Unter **Beute** werden blaue und epische Beute-Meldungen aus Dungeons und Raids als lokale Historie gespeichert. Abgeschlossene eigene Aufzeichnungen lassen sich mit anderen Addon-Nutzern teilen, auch wenn diese beim Lauf nicht dabei waren. Beide müssen zur Übertragung online sein; der Empfänger übernimmt den Verlauf unter **Beute → Eingänge**.

## Download und Installation / Download and installation


Den Quellcode als ZIP herunterladen und daraus nur den Ordner `VassilisDungeonPlaner` in den entsprechenden Addon Ordner schieben.

**Sprache:** Standardmäßig Clientsprache; über das kleine Zahnrad links neben „Vassilis DungeonPlaner“ zwischen Automatisch, Deutsch und English wechseln.

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
