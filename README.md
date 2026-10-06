# Vassilis DungeonPlaner

**Deutsch / English · WoW: Forever · Version 0.4.0**

Plane Raids, Dungeons und andere Termine, verwalte Zusagen und bestätige Teilnehmer – mit oder ohne Gilde. Spieler ohne Addon können per Whisper antworten.

Plan raids, dungeons and other events, manage signups and confirm participants, with or without a guild. Players without the addon can reply by whisper.

## Download und Installation / Download and installation

Die GitLab-Pipeline erstellt im Job **package-addon** eine installierbare ZIP-Datei. Sobald die Pipeline erfolgreich durchgelaufen ist, den Job öffnen und unter den Artefakten `dist/VassilisDungeonPlaner-0.4.0.zip` herunterladen. Bei „Alle Artefakte herunterladen“ zuerst das äußere Archiv entpacken; die Addon-ZIP liegt darin im Ordner `dist`.

The GitLab pipeline creates an installable ZIP in the **package-addon** job. After a successful pipeline, open the job and download `dist/VassilisDungeonPlaner-0.4.0.zip` from its artifacts. If you download all artifacts, unpack the outer archive first; the addon ZIP is inside `dist`.

1. WoW schließen / Close WoW.
2. Addon-ZIP entpacken / Extract the addon ZIP.
3. Den Ordner `VassilisDungeonPlaner` nach `Interface/AddOns` kopieren / Copy the `VassilisDungeonPlaner` folder to `Interface/AddOns`.
4. Addon aktivieren und `/vdp` eingeben / Enable the addon and enter `/vdp`.

Alternativ den Quellcode als ZIP herunterladen und daraus nur den Ordner `VassilisDungeonPlaner` installieren. / Alternatively, download the source ZIP and install only its `VassilisDungeonPlaner` folder.

**Sprache / Language:** Standardmäßig Clientsprache; im Hauptfenster oben rechts zwischen Automatisch, Deutsch und English wechseln. / Follows your client language by default; choose Automatic, Deutsch or English in the top-right corner of the main window.

**Vorhandene GuildBoard-Installation? / Existing GuildBoard installation?** Vor dem Wechsel die Anleitung zur Übernahme gespeicherter Termine lesen. / Read the saved-data migration instructions before switching folders.

- [Deutsche Anleitung](VassilisDungeonPlaner/README.md)
- [English guide](VassilisDungeonPlaner/README.en.md)

## Entwicklungsstand / Status

Für Interface **16001** vorbereitet. Automatisierte Tests mit simulierten WoW-APIs bestehen; die endgültige Prüfung im Forever-Client steht noch aus. / Targets Interface **16001**. Automated tests with simulated WoW APIs pass; final verification in the Forever client is still pending.

## Entwicklung / Development

Die Lua-Dateien in `VassilisDungeonPlaner` bilden das Addon. Lokale Tests sind unter [tests](tests/README.md) dokumentiert. / The Lua files in `VassilisDungeonPlaner` form the addon. See [tests](tests/README.md) for local tests.

Mit Python 3.9 oder neuer eine installierbare ZIP erstellen / Build an installable ZIP with Python 3.9 or newer:

```sh
python tools/package.py
```

Das Ergebnis liegt in `dist`. Testbibliotheken, Git-Dateien und Entwicklungswerkzeuge werden nicht mitgeliefert. / The output is written to `dist`. Test libraries, Git files and development tools are excluded.

## Lizenz / License

[MIT](LICENSE) · Copyright © 2026 Vassilios Marakis
