# Vassilis DungeonPlaner 0.5.0

Ein eigenständiges Termin-Addon auf **Deutsch und Englisch** für **WoW: Forever**. Vassilis DungeonPlaner zeigt eine Liste mit Raids, Dungeons und anderen Events. Es funktioniert **auch ohne Gilde**: mit manuellen Teilnehmern, direkten Einladungen und Antworten von Spielern ohne Addon.

[English quick start](README.en.md)

**Status: erste testbare Version.** Die Lua-Logik, Oberfläche und Kommunikation wurden mit simulierten WoW-APIs getestet. Ein echter Forever-Client und mehrere Spielkonten standen für die Entwicklung nicht zur Verfügung. Die Installation ist für den Interface-Stand **16001** vorbereitet. Die endgültige Client-Kompatibilität und Speicherung sind im Spiel zu prüfen.

## Installation

1. WoW vollständig schließen.
2. Falls als ZIP erhalten, `VassilisDungeonPlaner-0.5.0.zip` entpacken.
3. Den Ordner **VassilisDungeonPlaner** in `Interface/AddOns` des tatsächlich verwendeten Forever-Clients kopieren. Der fertige Pfad muss auf `Interface/AddOns/VassilisDungeonPlaner/VassilisDungeonPlaner.toc` enden. Es darf kein zweiter VassilisDungeonPlaner-Ordner dazwischenliegen.
4. WoW starten und **Vassilis DungeonPlaner** in der Addon-Liste aktivieren.
5. Im Spiel **`/vdp`** eingeben oder das **VDP-Symbol an der Minimap** anklicken.

Für den automatischen Addon-Abgleich sollten die beteiligten Spieler dieselbe Addon-Version verwenden. Spieler ohne Addon können per Whisper antworten oder vom Organisator manuell eingetragen werden. Es werden keine zusätzlichen Bibliotheken, Konten oder Webserver benötigt.

**Neu in 0.5.0:** Getrennte Bereiche **Planung** und **Beute**, automatische Beute-Historie und gezieltes Teilen abgeschlossener Dungeon- und Raidaufzeichnungen. Termin-Datenformat und Terminabgleich bleiben kompatibel; für die Beute-Übertragung benötigen beide Spieler mindestens 0.5.0. Bei einem Update innerhalb des Ordners `VassilisDungeonPlaner` genügt es, die Addon-Dateien bei geschlossenem WoW zu ersetzen; die SavedVariables bleiben erhalten.

**Umstieg vom bisherigen Ordner GuildBoard (auch von 0.3.0):** Der Anzeigename lautet jetzt „Vassilis DungeonPlaner“, der Addon-Ordner und die TOC-Datei heißen `VassilisDungeonPlaner`. Damit vorhandene Daten weiter geladen werden:

1. WoW vollständig schließen und den WTF-Ordner sichern.
2. Falls vorhanden, `WTF/Account/<Account>/SavedVariables/GuildBoard.lua` im gleichen Verzeichnis als `VassilisDungeonPlaner.lua` kopieren. Den Dateiinhalt einschließlich `GuildBoardDB` unverändert lassen und die alte Datei als Sicherung behalten. Eine bereits vorhandene `VassilisDungeonPlaner.lua` nicht überschreiben: In diesem Fall die beiden Datenstände zuerst prüfen. Dies für jeden verwendeten Account wiederholen.
3. Den bisherigen Addon-Ordner `GuildBoard` aus `Interface/AddOns` in einen Sicherungsordner außerhalb von `AddOns` verschieben und den neuen Ordner wie oben installieren. Die alte und die neue Ausgabe nicht gleichzeitig laden.
4. Im Spiel Termine und Teilnehmer prüfen und anschließend regulär ausloggen.

Der neue Ordner lädt die alte Speicherdatei nicht automatisch. Nach dem Kopieren bleiben Termine, Anmeldungen, Bestätigungen und Einladungen verfügbar. Der interne Speichername `GuildBoardDB` und der Kommunikationspräfix `GuildBoard3` bleiben zur Kompatibilität erhalten. `/vdp`, `/dungeonplaner`, `/gb` und `/guildboard` funktionieren weiterhin.

**Update von 0.2.x:** Zusätzlich zum Ordnerwechsel oben wird das Datenformat aktualisiert; bisher nicht gespeicherte Level erscheinen als unbekannt.

**Gemeinsam auf 0.3.0 aktualisieren:** Das zusätzliche Level erweitert das Datenformat auf Version 3. Der Abgleich verwendet einen neuen Addonkanal-Präfix; Version 0.2.x kann mit 0.3.0 keine Termine synchronisieren. Ein Downgrade auf 0.2.x wird nach dem Speichern mit Schema 3 abgelehnt. Normale Whisper-Antworten ohne Addon funktionieren weiterhin.

**Korrektur in 0.2.2:** Die Eingabegrenze berücksichtigt jetzt den zusätzlichen Platz im Textpuffer. Uhrzeiten wie `20:00` und Platzzahlen wie `10`, `20` und `40` lassen sich vollständig eingeben; die Prüfung auf gültige Uhrzeiten und 1–40 Plätze bleibt bestehen.

**Update von 0.1:** Ein direktes Update auf 0.5.0 ist möglich. Die aktuelle alte Gildenablage und eigene alte Termine werden in ein Charakterprofil übernommen. Die bisherigen Gildenablagen bleiben unverändert erhalten. Alle Addon-Nutzer sollten gemeinsam aktualisieren.

## Beute-Historie und vergangene Raids teilen

Oben zwischen **Planung** und **Beute** wechseln. Beim Betreten eines Dungeons oder Raids beginnt automatisch ein Lauf. Aufgezeichnet werden die vom Client gemeldeten blauen und epischen Beute-Empfänge: Gegenstand mit Tooltip, Menge, Empfänger und Uhrzeit. Die Filter zeigen Raids/Dungeons, Blau/Episch und die Beute aller Spieler oder nur die eigene. Das Suchfeld durchsucht Instanznamen und Aufzeichner.

Beim Verlassen wird der Lauf abgeschlossen. Eine Rückkehr innerhalb von zehn Minuten setzt denselben Lauf fort. Nach einem Instanzreset **Neuer Lauf** klicken, damit weitere Durchgänge getrennt bleiben. Kurze Reloads innerhalb der Instanz setzen die Aufzeichnung fort. Nach über zwei Stunden ohne Aktualisierung beginnt ein neuer Lauf. Instanzname und Datum stammen vom aufgezeichneten Besuch; es wird keine eindeutige Blizzard-Raid-ID behauptet.

**Vergangenen Raid senden:** Eine eigene abgeschlossene Aufzeichnung auswählen → **Teilen** → Charaktername bzw. Name-Realm eingeben → **Angebot senden**. Der Empfänger muss beim Raid nicht dabei gewesen sein. Bei ihm erscheint unter **Beute → Eingänge** das Angebot mit Aufzeichner, Datum und Anzahl der Einträge. Erst **Übernehmen** fordert die vollständigen Daten an. Nach vollständiger Prüfung wird die Historie gespeichert und dem Absender der Empfang bestätigt. **Verwerfen** lehnt das Angebot ab. Empfangene Aufzeichnungen sind gekennzeichnet; in dieser Version teilt jeweils der ursprüngliche Aufzeichner seinen Verlauf.

Beide Spieler benötigen Version 0.5.0 oder neuer und müssen während der Übertragung online und für Addon-Whisper erreichbar sein. Eine gemeinsame Gilde oder Gruppe ist nicht erforderlich. Der Versand erfolgt gedrosselt und wartet bei WoW-Kommunikationssperren. Große Verläufe können mehrere Minuten benötigen. Es gibt keinen Postfachdienst für offline Spieler. Nach einem Reload oder einer abgebrochenen Übertragung erneut teilen; unvollständige Übertragungen werden nicht als Historie gespeichert. Erneuter Import desselben Aufzeichners aktualisiert denselben Eintrag. Verschiedene Aufzeichner desselben Raids bleiben getrennte Ansichten.

Die Historie liegt pro Charakter im bisherigen `GuildBoardDB`, getrennt von der Terminbereinigung. Sie bleibt bis zum manuellen Löschen erhalten und wird beim normalen Ausloggen bzw. `/reload` auf die Festplatte geschrieben. Grenzen: 250 Läufe pro Charakter, 1.000 Beute-Einträge pro Lauf. Bei Erreichen der Grenze erscheint ein Hinweis; alte Verläufe werden nicht automatisch gelöscht.

**Erfassungsgrenze:** Die Historie enthält beobachtete Beute-Meldungen, keine garantierte vollständige Boss-Dropliste. Nicht gemeldete, ungeplünderte, geschützte oder vor Aktivierung des Addons erhaltene Beute kann fehlen. Herstellung und Würfel-Ankündigungen werden nicht als zusätzliche Drops gezählt. Fehlende Item-Daten werden nachgeladen; ein endgültiger Ladefehler wird angezeigt. Geteilte Daten sind Aufzeichnungen des Absenders, kein von Blizzard beglaubigtes Loot-Protokoll. Die tatsächlichen Forever-Lootmeldungen und das Layout benötigen weiterhin einen Test im Spiel.

## Sprache / Language

Standardmäßig ist **Automatisch** eingestellt: Ein deutscher WoW-Client verwendet Deutsch; englische und andere Clients verwenden Englisch.

Im Hauptfenster auf das kleine **Zahnrad links neben „Vassilis DungeonPlaner“** klicken. Im Dropdown stehen unter **Sprache / Language** die Optionen **Automatisch / Automatic**, **Deutsch** und **English** zur Auswahl; ein Häkchen markiert die aktuelle Einstellung. Nach der Auswahl oder einem Klick daneben schließt das Menü. Die Oberfläche wechselt sofort, ohne `/reload`. Die Auswahl gilt für alle Charaktere dieses WoW-Accounts und wird zusammen mit den übrigen Einstellungen bei `/reload`, normalem Ausloggen oder Beenden gespeichert.

Übersetzt werden Oberfläche, Dialoge, Rollen, Status, Kalender, Tooltips, Fehlermeldungen, Erinnerungen und ausgehende Whisper-Einladungen. Eigene Termintitel, Beschreibungen, Namen und Notizen bleiben unverändert. Deutsche und englische Addon-Nutzer können gemeinsam planen; normale Whisper-Antworten wie `Accept`, `Ja`, `Maybe`, `Vielleicht`, `Decline` und `Nein` werden unabhängig von der eingestellten Sprache erkannt.

Das Suchfeld zeigt **„Suche …“** bzw. **„Search …“**, solange es leer ist, auch wenn es angeklickt wurde. Nach der Eingabe verschwindet der Hinweis; beim Leeren erscheint er wieder.

## Bedienung

- **Termin erstellen:** Titel, Aktivität, Datum, Uhrzeit, 1–40 Plätze und Beschreibung eintragen. Das geht ohne Gilde. Beim Erstellen in einer Gilde kann zwischen „Gilde + Eingeladene“ und „nur Eingeladene“ gewechselt werden. Ohne Gilde ist der Termin zunächst privat. Die Sichtbarkeit wird beim Erstellen festgelegt.
- **Datum auswählen:** Auf das angezeigte Datum klicken, mit den Pfeilen den Monat wechseln und einen Tag anklicken. Alle Wochen haben sieben gleichmäßig ausgerichtete Felder; Randtage des Nachbarmonats sind gedimmt und ebenfalls auswählbar. „Heute“ und „Morgen“ wählen den Tag direkt. Die Uhrzeit bleibt unverändert. X oder ein Klick neben die Monatsauswahl schließt sie ohne Änderung.
- **Beschreibung schreiben:** Die gesamte Textfläche einschließlich Rand ist anklickbar. Beim Darüberfahren wird der Rahmen hell, beim Schreiben gold. Escape oder der Wechsel in ein anderes Eingabefeld beendet den Fokus. Lange Texte lassen sich weiterhin mit dem Mausrad scrollen. Ohne Beschreibung bleibt im Termin kein Platzhaltertext stehen; die Teilnehmerliste nutzt den freien Platz.
- **Termine finden:** links nach Alle, Raids, Dungeons oder Meine filtern; die Suche filtert nach Titel. „Meine“ enthält eigene Termine sowie Termine mit eigener Rückmeldung.
- **Anmelden:** Auf die Karte „Deine Anmeldung“ oder die eigene Teilnehmerzeile klicken. Im Dialog Tank, Heiler oder DD und die Antwort wählen, optional eine Notiz ergänzen, dann „Speichern“ klicken. „Abbrechen“ verwirft den Entwurf. Die Liste selbst enthält keine Eingabefelder.
- **Charakter und Level:** Die Liste zeigt den Charakternamen in der bekannten Klassenfarbe, Level, Rolle und Status. Vollständiger Name-Realm und Notiz erscheinen beim Darüberfahren. Klasse und Level der eigenen Anmeldung stammen beim Speichern vom eingeloggten Charakter. Das gespeicherte Level ist ein Stand der letzten Anmeldung, keine laufende Live-Abfrage. Der Raidlead kann bei Gästen das Level eintragen; unbekannte Level erscheinen als „—“ und unbekannte Klassen neutral.
- **Teilnehmer verwalten:** Als Raidlead gilt der Ersteller des Termins, unabhängig vom aktuellen WoW-Gruppenleiter. Er kann jede Teilnehmerzeile anklicken, Angaben ändern und im Dialog Bestätigen, Ersatzbank oder Offen wählen. Diese Aktionen werden mit „Speichern“ übernommen. Andere Spieler dürfen nur ihren eigenen Eintrag bearbeiten; Bestätigungen bleiben dem Raidlead vorbehalten. Die Anzahl bestätigter Plätze ist begrenzt; zusätzliche Zusagen sind möglich.
- **Teilnehmer manuell eintragen:** „+ Teilnehmer / Einladung“ öffnen, Name-Realm, optional Level, Rolle, Antwort und Notiz eingeben und „Speichern“ wählen. Dabei wird keine Nachricht verschickt. Ohne Realm ergänzt das Addon den eigenen. „Eingeladen“ ist ein Planungsstand und keine Zustellbestätigung. Bestehende Einträge lassen sich durch Klick auf die Zeile ändern; der Charaktername eines bestehenden Eintrags bleibt fest.
- **Einladen:** Im gleichen Dialog „Einladung senden“ klicken. Der Eintrag wird gespeichert und eine normale Whisper-Einladung angefragt. Hat der Empfänger Vassilis DungeonPlaner, erscheint außerdem eine Einladung unter „Einladungen“ bzw. `/vdp invites`. „Termin öffnen“ übernimmt den Termin; die eigentliche Zusage erfolgt danach über „Deine Anmeldung“ und „Speichern“. „Verwerfen“ entfernt nur die Einladung beim Empfänger und sendet keine Absage.
- **Eigener Eintrag:** Die Kombination aus Charaktername und Realm bestimmt, welchen Eintrag ein Spieler bearbeiten kann. Groß-/Kleinschreibung wird normalisiert; gleichnamige Charaktere auf anderen Realms bleiben getrennt. Eine eigene Anmeldung ersetzt den effektiven manuellen Eintrag ohne doppelte Teilnehmerzeile. Der Organisator darf später weiterhin manuell korrigieren. Die jeweils neuere Änderung gilt; manuelle Einträge und Whisper-Antworten sind im Tooltip gekennzeichnet.
- **Anmeldung ändern:** Ändert sich eine bestätigte Anmeldung, wird sie wieder offen und muss erneut bestätigt werden. Ein erneuter Klick auf dieselbe unveränderte Zusage erhält die Bestätigung.
- **Termin bearbeiten/absagen:** über die Schaltflächen unten rechts. Eine Terminabsage wird nach Rückfrage verteilt und als Datensatz behalten, damit alte Kopien den Termin nicht wieder aktivieren.
- **Vergangene: an:** zeigt auch vergangene und abgesagte Termine. Beim Laden werden Termine entfernt, die mehr als 30 Tage zurückliegen, einschließlich ihrer Anmeldungen.
- **Erinnerungen:** angemeldete Spieler erhalten im Spiel innerhalb der letzten 15 Minuten vor Beginn eine Chat-Erinnerung. Dafür muss WoW laufen.
- **Scrollen:** Mausrad über Terminliste, Teilnehmerliste oder langer Beschreibung im Eingabeformular. Längere Terminbeschreibungen sind im Detailbereich zusätzlich als Tooltip lesbar.

Das Fenster lässt sich am Hintergrund verschieben und mit Escape schließen. Das Minimap-Symbol lässt sich verschieben. `/dungeonplaner` öffnet ebenfalls das Fenster; `/vdp sync` oder „Abgleichen“ fordert einen Abgleich für Gilde und angenommene Einladungen an. Rechtsklick auf das Minimap-Symbol gleicht ebenfalls ab.

## Antworten ohne Addon

Die Whisper-Einladung enthält eine sechsstellige Kennung, zum Beispiel `A7B2C3`. Der Spieler antwortet an den Organisator:

| Antwort | Ergebnis |
| --- | --- |
| `Accept A7B2C3 Heiler` | Zusage als Heiler |
| `Accept A7B2C3 Tank` | Zusage als Tank |
| `Accept A7B2C3 DD` | Zusage als DD |
| `Maybe A7B2C3` | Vielleicht, bisherige Rolle bleibt |
| `Decline A7B2C3` | Absage |

Ohne Rolle bleibt die bereits eingetragene Rolle erhalten; neue Einträge stehen zunächst auf DD. `Accept`, `Maybe` oder `Decline` ohne Kennung werden nur verarbeitet, wenn genau eine nicht abgesagte, zukünftige Einladung dieses Absenders zugeordnet werden kann. Mehrere Termine erfordern eine Kennung. Alternativ werden `Ja`, `Vielleicht`, `Nein`, `Zusage`, `Absage`, `Healer`, `Heal` und `DPS` erkannt. Zusätzlicher freier Text wird nicht als Befehl interpretiert.

Es wird ausschließlich der **von WoW gemeldete Whisper-Absender** verwendet, niemals ein in der Nachricht behaupteter Name. Ohne vorherige Einladung wird ein allgemeines „Accept“ ignoriert. Nur der Organisator, der eingeladen hat, verarbeitet diese normalen Whisper-Antworten.

**Beide müssen zum Versand und Empfang online und über WoW-Whispers erreichbar sein.** Normale Whispers sind keine Offline-Post; der Server kann sie etwa wegen Offline-Status, Fraktions-/Realmgrenzen, Ignore oder Chatbeschränkungen ablehnen. „Einladung angefragt“ beweist deshalb keine Zustellung. Offline-Spieler lassen sich manuell eintragen; die Nachricht muss später erneut per Klick gesendet werden. Es gibt keinen automatischen normalen Chat-Spam und keine Zustellungsbestätigung ohne Antwort.

Spieler ohne Addon erhalten keine automatischen Folge-Nachrichten über Bestätigungen, geänderte Uhrzeiten oder Terminabsagen. Solche Änderungen muss der Organisator ihnen separat mitteilen. Addon-Nutzer erhalten sie beim nächsten erfolgreichen Abgleich.

## Uhrzeit und Speicherung

Eingabe und Anzeige im Addon erfolgen in der **lokalen Zeit des jeweiligen Spielers**, nicht pauschal in Realmzeit. Intern wird ein gemeinsamer Zeitstempel gespeichert. Eine normale Whisper-Einladung nennt ausdrücklich die Ortszeit des Organisators; ohne Addon erfolgt keine Zeitzonenumrechnung. Nach einem Terminwechsel sollte der Organisator seine Teilnehmer informieren; eine Terminänderung allein setzt bestehende Zusagen nicht zurück.

WoW verwaltet die lokale Speicherung über `GuildBoardDB` als SavedVariables. Änderungen liegen zuerst im Arbeitsspeicher; WoW schreibt sie bei `/reload`, normalem Ausloggen oder Beenden. Ein Absturz vor dem Schreiben kann lokale Änderungen verlieren. Ein erfolgreicher Test der Python/Lua-Simulation beweist nicht, dass eine bestimmte Forever-Betaversion diese Dateien korrekt lädt.

Die Ablage ist nach Region und vollständigem Charaktername getrennt. Termine behalten ihre ursprüngliche Gildenzuordnung oder den Einladungsmodus. Beim Gildenwechsel bleiben eigene und ausdrücklich angenommene Termine verfügbar; fremde Termine der alten Gilde werden ausgeblendet. Sie werden nicht an die neue Gilde weitergegeben. Ein Gildennamewechsel ändert den Gildenkontext. Alts werden nicht automatisch zusammengefasst.

## So funktioniert der Abgleich

Vassilis DungeonPlaner nutzt die WoW-Addonkanäle `GUILD` und `WHISPER`. Strukturierte, lesbare Nachrichten werden bevorzugt über `SendAddonMessageLogged` gesendet. Diese Synchronisierungsdaten erscheinen nicht als normale Chat-Nachrichten. Die ausdrücklich per Schaltfläche versendete Einladung ist dagegen eine normale, sichtbare Flüsternachricht.

Neue Änderungen werden verteilt. Beim Einloggen, manuell und bei Bedarf etwa alle drei Minuten vergleicht das Addon den Bestand mit erreichbaren Gildenmitgliedern. Ein Mitglied kann dabei Kopien weitergeben, obwohl der ursprüngliche Ersteller offline ist. Unterschiedliche Bestände werden anhand von Revisionen zusammengeführt. Der Transport zerlegt größere Datensätze in kleine UTF-8-Nachrichten und begrenzt die Senderate. In Kämpfen bzw. während einer durch WoW gemeldeten Kommunikationssperre wartet die Übertragung.

**Externe Gäste** erhalten ausschließlich den angenommenen Termin einschließlich dessen Teilnehmerliste. Der Organisator dient für externe Teilnehmer als Verteiler; er muss für einen direkten Abgleich gleichzeitig online sein. Ein Gast kann nach dem Öffnen des Termins auch bei offline befindlichem Organisator lokal antworten. Das Addon überträgt seine eigene Anmeldung beim späteren gemeinsamen Abgleich erneut. Ein externer Gast kann nicht den übrigen Gildenkalender abrufen und kann keine fremden Anmeldungen schreiben. Private Termine werden nicht über den Gildenkanal verteilt.

**Es gibt keine zentrale, dauerhaft erreichbare Datenbank.** Wer mit niemandem mit einem aktuellen Bestand online ist, erhält Änderungen erst bei einem späteren Kontakt. „Letzter Addon-Kontakt“ bedeutet, dass ein anderes Addon erreicht wurde; es ist keine Bestätigung, dass jedes Mitglied alles erhalten hat. Ein Klick auf Zusagen ist außerdem keine Platzzusage des Organisators.

Direkte Änderungen werden an den von WoW gemeldeten Absender gebunden. Normale Clients gestatten eigene Anmeldungen sowie manuelle Einträge und Bestätigungen durch den Organisator. **Weitergereichte Gildenkopien beruhen weiterhin auf Vertrauen innerhalb der Gilde:** Es gibt keine kryptografischen Signaturen; ein absichtlich manipulierter Gildenclient könnte die Autorenangaben einer Kopie fälschen. Externe Gäste vertrauen bei erhaltenen Teilnehmerkopien ihrem eingeladenen Organisator. Die Einladungskennung dient zur Zuordnung, nicht als Ersatz für die Absenderprüfung.

Ein Bestand ist auf 6.000 Datensätze begrenzt, die Sendequeue auf 8.000 Pakete. Pro Abgleich werden höchstens fünf unterschiedliche Peer-Bestände angefordert. Größere Bestände und gleichzeitig startende Mitglieder können deshalb merkbare Wartezeiten verursachen. Wiederholte Abgleiche gleichen unterbrochene Übertragungen aus.

## Erster Test im Spiel

1. Allein, ohne Gilde: `/vdp` öffnen, einen Dungeontermin erstellen und einen beliebigen Teilnehmer über „Speichern“ eintragen. Teilnehmerzeile anklicken und Rolle, Level, Zusage, Bestätigung, Ersatzbank sowie Abbrechen testen. Dafür ist kein zweiter Spieler nötig.
2. Mit Spieler B, ebenfalls ohne Gilde möglich: A lädt B über „Einladung senden“ ein. Mit Addon öffnet B `/vdp invites`, dann den Termin. Ohne Addon antwortet B per `Accept KENNUNG Heiler`.
3. B sagt als Heiler zu. A sieht die Anmeldung und bestätigt sie; B sieht „Bestätigt“.
4. B ändert seine Rolle. Beide sehen wieder „Zugesagt · offen“. A kann Ersatzbank und Offen ausprobieren.
5. Beide benutzen `/reload`, schließen WoW regulär und prüfen nach einem Neustart, ob die Daten erhalten sind.
6. Addon-Gast B öffnet den Termin, während A online ist. A geht offline; B ändert seine Anmeldung. Nach dem erneuten gemeinsamen Login/Abgleich erhält A die neue Antwort. Bei Gildenterminen kann weiterhin ein drittes Gildenmitglied die gespeicherten Daten weiterreichen.
7. A sagt den Termin ab. Bei Addon-Nutzern verschwindet er nach dem Abgleich aus der normalen Liste; mit „Vergangene: an“ wird die Absage angezeigt. Teilnehmer ohne Addon separat informieren.
8. Bei unterschiedlichen lokalen Zeitzonen prüfen, dass derselbe Termin den jeweils richtigen lokalen Zeitpunkt zeigt.

Bei einem Fehler sind Buildnummer (`/run print(GetBuildInfo())`), Lua-Fehlermeldung und die ausgeführte Aktion hilfreich. Lua-Fehler lassen sich mit `/console scriptErrors 1` und anschließendem `/reload` sichtbar machen. Ausschalten: `/console scriptErrors 0`.

## Quellen zum Zielclient

- [Forever: Chat-API aus Blizzards UI-Quellcode](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)
- [Forever: Gilden-API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildInfoDocumentation.lua)
- [Forever: EditBox-API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua)

Vassilis DungeonPlaner ist ein unabhängiges Projekt und verwendet keine mitgelieferten Blizzard-Grafiken. Die Oberfläche verwendet im Spiel verfügbare Standardmittel.
