# Power Grid Incremental – Bauplan

Nov 13, 2026 · @Daniel Kaiser

## Lesehilfe und Stand der Prüfung

Dieser Bauplan legt Zahlen, Module und Reihenfolge für das MVP fest. Alle Spielwerte sind Entwurf v0.2, mit deinen Entscheidungen vom 13.11.2026, und werden in Meilenstein 1 per Luau-Simulation bestätigt oder korrigiert. Grundlage ist das [Design- und Marktkonzept](https://claude.ai/artifact/AxaB8TWq7WQHpM5cZa7Dn1).

**Kennzeichnung**

- **\[B\] belegt:** Quelle steht am Ende, abgerufen am 13.11.2026.
- **\[D\] aus Design-Dokument:** unverändert übernommen.
- **\[S\] geschätzt:** aus belegten Zahlen gerechnet oder aus meiner Vorab-Simulation. Das war ein Wegwerfskript in Python mit 27 Läufen je Fall, nicht die spätere Luau-Simulation.
- **\[A\] Annahme:** von mir gesetzter Entwurfswert.

**Was ich nicht prüfen konnte**

- Das DevForum war beim Abruf im Wartungsmodus. Ankündigungen und der ProfileStore-Beitrag liegen mir nur als Suchausschnitt vor.
- Von den Werkzeugen kenne ich die neuesten Versionsnummern, aber nicht deren Veröffentlichungsdatum.
- Wie ProfileStore offiziell installiert wird (Wally-Paket ja oder nein), steht nicht auf der API-Seite. Das Projekt hat keine Versionsnummern.
- Die Schwelle für Kids/Select steht in der Doku bei 250. Die angekündigte Senkung auf 100 ist dort nicht eingetragen.
- Das aktuelle Mindestbudget für Roblox-Werbung habe ich nur aus einem DevForum-Beitrag von 2025.
- Eine Roblox-Regel speziell zu Offline-Ertrag habe ich nicht gefunden. Die Community Standards enthalten dazu nichts.
- Das Feld `PurchaseId` im Kaufbeleg nennt die abgerufene Doku-Seite nicht ausdrücklich. Ich kenne es aus der API, es wird in Meilenstein 3 gegengeprüft.
- Ob dieselbe Luau-Datei unverändert in Lune und in Roblox lädt, beweist erst Meilenstein 0.
- Was 1.000 Robux beim Kauf in Euro kosten, habe ich nicht nachgesehen.

## 1. Kernschleife und Zielwerte

Kurbeln, Anlagen kaufen, Strom zum besten Preis verkaufen, Netz ausbauen. Der erste Netz-Ausbau (Prestige) soll nach 30–45 Minuten kommen, das erste Kaufangebot frühestens in Minute 12.

1. **Erzeugen:** Anlagen liefern Energie pro Sekunde, abhängig von Tageszeit und Wetter. Die Kurbel liefert Energie pro Klick.
2. **Verkaufen:** Energie wird sofort zum aktuellen Preis verkauft, außer der Speicher lädt gerade.
3. **Investieren:** Coins fließen in Anlagen und Upgrade-Knoten.
4. **Optimieren:** Der Speicher lädt mittags billig und verkauft abends teuer, von Hand oder per Regel.
5. **Ausbauen:** Bei genug Einnahmen steigt die Netzstufe. Anlagen und Coins gehen zurück auf null, dafür gibt es ×1,6 auf alles und Funken für Dauer-Upgrades.

### Zielwerte

| Größe | Ziel | Herkunft |
| --- | --- | --- |
| Erster Netz-Ausbau, echter Spieler | 30–45 min | \[A\]. Der Bot braucht im Median 23 min (optimal) und 27 min (gelegentlich) \[S\] |
| Weitere Ausbauten, Stufe 2–6 | je 12–25 min | \[S\] |
| Erstes Kaufangebot | frühestens Minute 12 und erst nach dem Speicher-Kauf. In den ersten 10 Minuten kein Kaufhinweis | \[A\] |
| Sitzungslänge | Median mindestens 12 min, mindestens 45 % der Sitzungen über 10 min | \[A\]. Die 10 Minuten zählen für Creator Rewards \[D\] |
| Längste Pause ohne bezahlbaren Kauf in den ersten 10 min | höchstens 45 s | \[A\], noch nicht simuliert |
| Umfang des MVP | Stufe 6 nach rund 2 h Spielzeit, Stufe 8 nach 4,5–5 h. Danach braucht es neue Inhalte | \[S\] |

### Die ersten 10 Minuten

Zeiten und Werte stammen aus einem Beispiel-Lauf des optimalen Bots \[S\]. Menschen sind langsamer.

| Minute | Was passiert | Einnahmen/s am Ende |
| --- | --- | --- |
| 0–1 | Start auf dem eigenen Grundstück, ein Pfeil zeigt zur Kurbel. Erstes Balkonmodul nach etwa 5 s, nach einer Minute vier Module und das erste Wasserrad | 3 |
| 1–2 | Weitere Wasserräder, sie laufen Tag und Nacht gleich. Hinweis auf die Tag/Nacht-Leiste | 7 |
| 2–3 | Erster Upgrade-Knoten. Das zehnte Balkonmodul verdoppelt alle Balkonmodule, mit Konfetti | 20 |
| 3–5 | Dach-PV für 1.100 Coins. Erster Wetterwechsel, für alle auf dem Server sichtbar | 140 |
| 5–7 | Netzverstärkung I und Direktvermarktung. Speicher (2.000) und Regelzentrale (3.000) | 280 |
| 7–10 | Die Nachführung verdoppelt die Dach-PV, der Park wächst auf rund 15 Dachanlagen. Erste Abendspitze mit vollem Speicher. Der Zielbalken „Netz-Ausbau bei 10 Mio.“ erscheint | 950 |

### Die erste Stunde

| Minute | Was passiert |
| --- | --- |
| 10–15 | Kleinwindrad (12.000), Speicher Stufe 2, Solarpark (130.000), der Börsenzugang zeigt das nächste Wetter. Rund 6.200 Coins/s in Minute 15 |
| ab 12 | Der Shop-Knopf bekommt erstmals einen dezenten Hinweis. Kein Pop-up |
| 15–25 | Speicher Stufe 3 und Wirkungsgrad 95 %. Rund 21.000 Coins/s in Minute 20. Der Bot erreicht 10 Mio. nach 23 min. Das Windrad (1,4 Mio.) kommt je nach Kaufweg kurz vor oder erst nach dem ersten Ausbau |
| 25–45 | Erster Netz-Ausbau eines echten Spielers: Stufe 1 „Straße“, 5 Funken, erster Dauer-Knoten |
| 45–60 | Der zweite Lauf geht schneller (Bot 19 min). Ziel nach einer Stunde: Stufe 2, schnelle Spieler Stufe 3 |

### Der erste Tag

Angenommen sind drei Sitzungen mit 35, 25 und 25 Minuten und Pausen von 4 und 14 Stunden \[A\]. Ergebnisse aus der Vorab-Simulation \[S\].

| Sitzung | Stand am Ende | Rückkehr |
| --- | --- | --- |
| 1 | Stufe 1 | Willkommen-Bildschirm mit Offline-Ertrag (Deckel 2 h, 50 %) |
| 2 | Stufe 3 (gelegentlich) bis 4 (optimal). Offline-Deckel 4 h und Auto-Ausbau-Regel gekauft | Offline-Ertrag reicht oft direkt für den nächsten Ausbau |
| 3 | Stufe 5 bei beiden Bots, 55 Funken, fünf Dauer-Knoten |  |

## 2. Wirtschaftsmodell

Alle Werte in diesem Abschnitt sind Entwurf v0.2 \[A\]. Die Vorab-Simulation zeigt, dass sie die Zielkurven treffen \[S\]. Verbindlich wird erst die Luau-Simulation in Meilenstein 1. Anlagen, Wetter und Netzstufen stehen als Tabellen in Abschnitt 3.

### Tag und Nacht

Ein Tag dauert 480 Sekunden und gilt für den ganzen Server. Das Wetter wechselt alle 120 Sekunden und lässt sich aus einem Server-Startwert berechnen, damit die Simulation dieselben Verläufe erzeugt.

| Phase | Dauer | Solarfaktor | Preisfaktor |
| --- | --- | --- | --- |
| Morgen | 60 s | 0,5 | 1,2 |
| Mittag | 150 s | 1,0 | 0,7 |
| Abend | 90 s | 0,3 | 1,8 |
| Nacht | 180 s | 0,1 | 1,0 |

Daraus gerechnete Erwartungswerte je Einheit Nennleistung: Solar 0,320, Wind 1,152, Grundlast 1,130 Coins pro Sekunde. Mittags liefern Solar 0,725, Wind 1,02 und Grundlast 1,0 der Nennleistung.

### Formeln

```
Erzeugung_i   = Basis_i × Anzahl_i × M_i × Faktor_Typ
Faktor_solar  = Phase.solar × Wetter.solar
Faktor_wind   = Wetter.wind
Faktor_grund  = 1
M_i           = 2^Meilensteine_i × Knoten_i × Global
Meilensteine  bei 10, 25, 50, 100, 150, 200 Stück (mit P7: 2,5 statt 2)
Global        = 1,6^Netzstufe × Netzverstärkung (U09, U10, U11)

Preis         = Phase.preis × Wetter.preis × Markt (U14, U15; abends zusätzlich U16)
Einnahmen/s   = (Erzeugung − Laden + Entladen + Kurbel) × Preis
Kosten_i      = Basiskosten_i × 1,15^Anzahl_i
Kurbel/Klick  = 1 (mit U12: 3) + 2 % der Erzeugung/s (mit U13); höchstens 8 Klicks/s

Speicher_max  = Sekunden_Stufe × Mittagserzeugung        (30 / 60 / 100 / 150 s)
Mittagserz.   = Σ Basis_i × Anzahl_i × M_i × (Solar 0,725 | Wind 1,02 | Grundlast 1,0)
Laden/Entl.   = höchstens Speicher_max / 60 pro Sekunde
Wirkungsgrad  = 85 % beim Laden (mit U22: 95 %)

Netz-Ausbau   = erlaubt, wenn Einnahmen im Lauf ≥ 10 Mio. × 6^Netzstufe
Funken        = 5 + 3 × bisherige Netzstufe

Offline       = Schnittrate × min(Abwesenheit, Deckel) × Wirkungsgrad_offline
Schnittrate   = Σ Basis_i × Anzahl_i × M_i × Erwartungswert_Typ × Markt
```

Drei Entscheidungen hinter den Formeln:

- **Speicher zählt in Sekunden.** Seine Größe wächst mit dem Kraftwerkspark mit. Eine feste Größe in Energie war in der Simulation nach wenigen Minuten wertlos \[S\].
- **Prestige in festen Stufen.** Eine übliche Wurzelformel auf die Einnahmen lief in der Simulation aus dem Ruder: Die Funken verdoppelten sich alle paar Minuten \[S\]. Feste Stufen sind stabil und für Kinder leichter zu verstehen.
- **Nachts liefert Solar 10 %.** Deine Entscheidung vom 13.11.2026. Echt wäre null, die 10 % nehmen Neulingen die zähe erste Nacht. Wasserrad und Speicher bleiben wichtig: Der Speicher bringt weiterhin bis zu 48 % mehr Einnahmen \[S\].

### Offline-Ertrag

- Deckel 2 Stunden, mit P2 4 Stunden, mit P6 8 Stunden. Der Pass „Langzeit-Zähler“ legt 4 Stunden obendrauf.
- Wirkungsgrad 50 %, mit P4 75 %.
- Gezählt wird ab 60 Sekunden Abwesenheit, immer mit Serverzeit.
- Speicher, Regeln und Kurbel zählen offline nicht. Das ist Absicht: Wer online bleibt, verdient mit Speicher knapp 50 % mehr.

### Automationsregeln

- **Günstig laden:** lädt, solange der Preisfaktor höchstens die Schwelle erreicht. Standard 0,7.
- **Teuer verkaufen:** entlädt, sobald der Preisfaktor die Schwelle erreicht. Standard 1,2.
- **Auto-Ausbau:** kauft alle 2 Sekunden die Anlage mit der kürzesten Amortisation, wenn danach die eingestellte Reserve übrig bleibt (0–90 % der Coins).
- Schwellen lassen sich in Schritten von 0,1 zwischen 0,5 und 2,0 einstellen.

### Upgrade-Baum: 22 Lauf-Knoten

Lauf-Knoten kosten Coins und werden beim Netz-Ausbau zurückgesetzt.

| ID | Name | Wirkung | Kosten | Voraussetzung |
| --- | --- | --- | --- | --- |
| U01 | Saubere Module | Balkonmodul ×2 | 150 | 1 Balkonmodul |
| U02 | Kugellager | Wasserrad ×2 | 1.200 | 1 Wasserrad |
| U03 | Nachführung | Dach-PV ×2 | 12.000 | 1 Dach-PV |
| U04 | Leichtbau-Flügel | Kleinwindrad ×2 | 130.000 | 1 Kleinwindrad |
| U05 | Putzroboter | Solarpark ×2 | 1,5 Mio. | 1 Solarpark |
| U06 | Getriebelos | Windrad ×2 | 16 Mio. | 1 Windrad |
| U07 | Doppelglas-Module | alle Solaranlagen ×1,5 | 60.000 | U03 |
| U08 | Höhere Türme | alle Windanlagen ×1,5 | 700.000 | U04 |
| U09 | Netzverstärkung I | alles ×1,25 | 5.000 |  |
| U10 | Netzverstärkung II | alles ×1,25 | 250.000 | U09 |
| U11 | Netzverstärkung III | alles ×1,5 | 8 Mio. | U10 |
| U12 | Kurbel-Übersetzung | Kurbel ×3 | 50 |  |
| U13 | Schwungrad | Kurbel zusätzlich 2 % der Erzeugung | 2.000 | U12 |
| U14 | Direktvermarktung | Verkaufspreis +10 % | 3.000 |  |
| U15 | Börsenzugang | Verkaufspreis +10 %, zeigt nächstes Wetter | 40.000 | U14 |
| U16 | Spitzenlast-Vertrag | Abendpreis ×1,25 | 400.000 | U15 |
| U17 | Heimspeicher | Speicher Stufe 1, 30 s | 2.000 |  |
| U18 | Speicher-Erweiterung | Speicher Stufe 2, 60 s | 30.000 | U17 |
| U19 | Quartierspeicher | Speicher Stufe 3, 100 s | 400.000 | U18 |
| U20 | Großspeicher | Speicher Stufe 4, 150 s | 5 Mio. | U19 |
| U21 | Regelzentrale | zwei Regel-Plätze, Regeln „Günstig laden“ und „Teuer verkaufen“ | 3.000 | U17 |
| U22 | Neue Zellchemie | Speicher-Wirkungsgrad 95 % | 150.000 | U17 |

### Upgrade-Baum: 8 Dauer-Knoten

Dauer-Knoten kosten Funken und bleiben für immer. Zusammen kosten sie 185 Funken, genau so viele bringen die Stufen 1 bis 10.

| ID | Name | Wirkung | Funken |
| --- | --- | --- | --- |
| P1 | Startkapital | jeder Lauf beginnt mit 1.000 Coins | 3 |
| P2 | Größerer Zähler | Offline-Deckel 4 h | 5 |
| P3 | Auto-Ausbau | schaltet die dritte Regel frei | 8 |
| P4 | Nachtschicht | Offline-Wirkungsgrad 75 % | 12 |
| P5 | Fest verbaut | Speicher-Knoten und Regelzentrale bleiben beim Ausbau erhalten | 18 |
| P6 | Riesenzähler | Offline-Deckel 8 h | 25 |
| P7 | Serienfertigung | Meilensteine geben ×2,5 statt ×2 | 44 |
| P8 | Dritter Regel-Platz | alle drei Regeln laufen gleichzeitig | 70 |

### Zielkurven für die Simulation

Gemessen wird mit zwei Bots über 9 Startwerte und 3 Startzeiten (Morgen, Abend, Nacht). Der optimale Bot kauft jede Sekunde das Angebot mit der besten Amortisation. Der gelegentliche Bot kurbelt eine Minute und kauft alle 20 Sekunden. Ein dritter Bot „Kind“, der immer das Billigste kauft, kommt in der Luau-Simulation dazu.

| Nr. | Kennzahl | Ziel mit Toleranz | Vorab-Simulation \[S\] |
| --- | --- | --- | --- |
| Z1 | Erster Ausbau, optimaler Bot | Median 22–27 min, alle Läufe 18–34 min | 22,9 (19,9–27,8) |
| Z2 | Erster Ausbau, gelegentlicher Bot | Median 26–32 min | 27,2 (23,3–31,9) |
| Z3 | Lauf-Median Stufe 2 bis 6 | je 12–25 min | 19 / 16 / 12 / 15 / 18 |
| Z4 | Lauf-Median Stufe 7 und 8 | höchstens 60 und 150 min | 45 / 123 |
| Z5 | Spielzeit bis Stufe 6 | 100–130 min | 101 optimal, 122 gelegentlich |
| Z6 | Mehreinnahmen durch Speicher mit Regeln, gemischter Park | Stufe 1: +8–12 %, Stufe 4: +40–50 %, mit U22 bis +55 % | +10 %, +41 %, +48 % |
| Z7 | Speicher nach Parktyp | nur Solar +60–70 %, nur Wind und Wasser +15–25 % | +61 %, +19 % |
| Z8 | Start in der Nacht | verlängert den ersten Ausbau um höchstens 25 % | in Z1 enthalten |
| Z9 | Längste Kaufpause in den ersten 10 min | höchstens 45 s | nicht gemessen |
| Z10 | Erster Tag (siehe Abschnitt 1) | Stufe 4–5 | 5 bei beiden Bots |
| Z11 | Summe aller gekauften Multiplikatoren | höchstens ×3 | per Bauart erfüllt |

Ein Befund, den Meilenstein 1 klären muss: Im ersten Lauf verkürzt der Speicher die Zeit bis zum Ausbau nicht (22,9 min mit, 21,7 min ohne) \[S\]. Sein Wert zeigt sich erst in längeren Läufen. Ob er sich für Spieler trotzdem von Anfang an lohnend anfühlt, beurteilst du im Spieltest.

## 3. Inhalte des MVP

Sechs Anlagen, ein Speicher, drei Regeln, zehn Netzstufen, fünf Wetterlagen, zwei Bestenlisten und ein Booster für den ganzen Server. Namen stehen deutsch und englisch, Werte sind Entwurf v0.2 \[A\].

### Anlagen

Jede Anlage erscheint, sobald man die vorige einmal besitzt. Der Schnitt-Ertrag ist Nennleistung mal Erwartungswert aus Abschnitt 2.

| Nr. | Name | Typ | Basiskosten | Nennleistung/s | Schnitt-Ertrag Coins/s | Kurzbeschreibung |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Balkonmodul / Balcony Panel | Solar | 15 | 1 | 0,32 | Der Einstieg. Billig, nachts nur ein Zehntel |
| 2 | Wasserrad / Water Wheel | Grundlast | 120 | 1,5 | 1,7 | Läuft immer gleich, trägt durch die erste Nacht |
| 3 | Dach-PV / Rooftop Solar | Solar | 1.100 | 28 | 8,9 | Erster großer Sprung, macht den Speicher interessant |
| 4 | Kleinwindrad / Mini Turbine | Wind | 12.000 | 40 | 46 | Schwankt mit dem Wetter, stark bei Sturm |
| 5 | Solarpark / Solar Farm | Solar | 130.000 | 900 | 288 | Viel Mittagsstrom zum Speichern |
| 6 | Windrad / Wind Turbine | Wind | 1,4 Mio. | 1.300 | 1.498 | Das Großgerät rund um den ersten Ausbau |

### Speicher

**Heimspeicher / Home Battery.** Vier Stufen mit 30, 60, 100 und 150 Sekunden Mittagserzeugung (U17–U20). Wirkungsgrad 85 %, mit U22 95 %. Drei Schalter: Laden, Verkaufen, Automatik. Die Anzeige zählt in „Sekunden Sonne“.

### Regeln

| Regel | Wirkung | Verfügbar ab |
| --- | --- | --- |
| Günstig laden / Charge Cheap | lädt bei niedrigem Preis, Schwelle einstellbar | U21 |
| Teuer verkaufen / Sell High | entlädt bei hohem Preis, Schwelle einstellbar | U21 |
| Auto-Ausbau / Auto Build | kauft selbständig die lohnendste Anlage, Reserve einstellbar | P3 oder Pass „Smart-Zentrale“ |

U21 bringt zwei Regel-Plätze. Den dritten gibt es über P8 oder sofort über den Pass.

### Prestige-Ebene: Netz-Ausbau

Jede Stufe ändert Schild und Randfarbe des Grundstücks, sichtbar für alle. Stufe 10 ist das Ende des MVP.

| Stufe | Name | Nötige Einnahmen im Lauf | Multiplikator danach | Funken |
| --- | --- | --- | --- | --- |
| 1 | Straße / Street | 10 Mio. | ×1,6 | 5 |
| 2 | Dorf / Village | 60 Mio. | ×2,6 | 8 |
| 3 | Kleinstadt / Town | 360 Mio. | ×4,1 | 11 |
| 4 | Stadt / City | 2,2 Mrd. | ×6,6 | 14 |
| 5 | Landkreis / County | 13 Mrd. | ×10,5 | 17 |
| 6 | Region / Region | 78 Mrd. | ×16,8 | 20 |
| 7 | Land / Country | 470 Mrd. | ×26,8 | 23 |
| 8 | Kontinent / Continent | 2,8 Bio. | ×42,9 | 26 |
| 9 | Planet / Planet | 17 Bio. | ×68,7 | 29 |
| 10 | Sonnensystem / Solar System | 100 Bio. | ×110 | 32 |

### Wetter

| Wetter | Anteil | Solar | Wind | Preis | Kurzbeschreibung |
| --- | --- | --- | --- | --- | --- |
| Sonnig / Sunny | 40 % | 1,0 | 0,6 | 1,0 | Normalfall, Solar voll |
| Bewölkt / Cloudy | 25 % | 0,5 | 1,0 | 1,0 | Solar halbiert |
| Windig / Windy | 20 % | 0,8 | 1,6 | 1,0 | Windanlagen laufen hoch |
| Gewitter / Storm | 10 % | 0,2 | 2,0 | 1,2 | Wind doppelt, Strom teurer |
| Flaute / Calm | 5 % | 0,4 | 0,2 | 1,5 | Kaum Erzeugung, Speicher verkauft teuer |

### Bestenliste

- **Server-Liste:** alle Spieler auf dem Server, sortiert nach Netzstufe und dann nach Einnahmen im Lauf. Aktualisiert sich live.
- **Welt-Liste:** die besten 50 aller Server, alle 5 Minuten aktualisiert. Gespeichert wird eine Punktzahl aus Netzstufe × 1.000.000 + 1.000 × Zehnerlogarithmus der Lauf-Einnahmen. So bleibt die Zahl klein und ganzzahlig.

### Serverweiter Booster

**Sonnenstunde für alle / Sunshine Hour.** 10 Minuten lang verdoppelt sich die Erzeugung aller Spieler auf dem Server. Der Himmel wird golden, ein Banner nennt den Käufer. Mehrere Käufe reihen sich aneinander, höchstens 60 Minuten Vorrat. Fällt der Server aus, bekommt der Käufer die Restzeit beim nächsten Besuch gutgeschrieben.

## 4. Monetarisierungs-Katalog

Elf Angebote ohne Zufall. Im mittleren Szenario des Design-Dokuments tragen sie 100 € pro Monat bei rund 2.300 täglichen Spielern und 200 € bei rund 4.600.

**Grundsätze**

- Pässe verkaufen Bequemlichkeit und Zeit. Was die Spielstärke betrifft, können Gratis-Spieler später selbst freischalten, mit Ausnahme von Premium-Tarif und Langzeit-Zähler.
- Gekaufte Multiplikatoren sind gedeckelt: Premium-Tarif ×1,5 mal höchstens ein Booster ×2 ergibt ×3. Booster stapeln sich nicht in der Stärke, nur in der Dauer bis 60 Minuten.
- Kein Kaufhinweis in den ersten 10 Minuten, keine Pop-ups, keine Countdown-Angebote.

### Katalog

Preise liegen in den Spannen der Preistabelle im Design-Dokument \[D\]. Für Kosmetik nennt die Tabelle keine Spanne, diese drei Preise sind Annahmen \[A\].

| Angebot | Typ | Robux | Effekt | Sichtbar für andere | Platz im Spielverlauf |
| --- | --- | --- | --- | --- | --- |
| Gründer-Paket / Founder Pack | Pass | 59 | einmalig 30 Minuten Schnittertrag, goldene Kurbel, Gründer-Schild | Schild und Kurbel am Grundstück | Shop ab Minute 12, Hinweis nach dem Speicher-Kauf |
| Smart-Zentrale / Smart Hub | Pass | 149 | dritter Regel-Platz und Auto-Ausbau sofort statt über P3 und P8 | Antenne auf der Regelzentrale | im Regel-Menü, sobald U21 gekauft ist |
| Langzeit-Zähler / Long Meter | Pass | 99 | Offline-Deckel +4 Stunden | nein | eine Zeile im Willkommen-Bildschirm, wenn der Deckel erreicht war |
| Premium-Tarif / Premium Tariff | Pass | 249 | Verkaufspreis dauerhaft ×1,5 | goldenes Zählerhäuschen | am Markt-Terminal, nach dem ersten Netz-Ausbau hervorgehoben |
| Netzbetreiber-VIP / Grid VIP | Pass | 299 | Namensschild über der Figur, leuchtende Leitungen, VIP-Farben, täglich ein Gratis-Turbo | ja, alles | Shop, Hinweis ab Stufe 2 |
| Neon-Anlagen / Neon Plants | Pass | 99 | alle Anlagen leuchten, Farbe wählbar | ja | Farbmenü am Grundstück |
| Ausbau-Feuerwerk / Upgrade Fireworks | Pass | 79 | Feuerwerk und Server-Meldung bei jedem Netz-Ausbau | ja, alle sehen es | Vorschau beim ersten Ausbau |
| Themen-Grundstück / Plot Themes | Pass | 129 | drei Designs für Boden, Zaun und Schild | ja | Farbmenü am Grundstück |
| Sonnenstunde für alle / Sunshine Hour | Produkt | 79 | 10 Minuten ×2 Erzeugung für den ganzen Server | goldener Himmel, Banner mit Käufername | Knopf an der Wetteranzeige |
| Turbo-Einspeisung / Turbo Feed-in | Produkt | 29 | 15 Minuten ×2 eigene Einnahmen | Funken-Effekt am Netzanschluss | Shop und Markt-Terminal |
| Zeitsprung / Time Skip | Produkt | 49 | sofort 1 Stunde Schnittertrag, höchstens 3 pro Tag | nein | Shop |

Das Gründer-Paket kostet 59 statt 49, weil Roblox beworbene Pässe nur zwischen 50 und 800 Robux zulässt \[B\].

### Rechnung gegen das Ziel

Feste Größen \[D\]: 100 € entsprechen 29.084 verdienten Robux im Monat, also 969 am Tag. Vom Kaufpreis bleiben 70 %. Creator Rewards bringen 5 Robux je qualifiziertem Spieler und Tag.

Beispiel für 2.300 tägliche Spieler. Die Käufe pro Tag sind Annahmen \[A\], zusammen etwa 14 Käufe oder 0,6 % der Spieler:

| Angebot | Robux | Käufe pro Tag | Robux brutto pro Tag |
| --- | --- | --- | --- |
| Premium-Tarif | 249 | 1,2 | 299 |
| Sonnenstunde für alle | 79 | 2,5 | 198 |
| Gründer-Paket | 59 | 3 | 177 |
| Turbo-Einspeisung | 29 | 5 | 145 |
| Kosmetik-Pässe, im Schnitt | 100 | 1 | 100 |
| Smart-Zentrale | 149 | 0,4 | 60 |
| Zeitsprung | 49 | 0,8 | 39 |
| **Summe** |  | **13,9** | **1.017** |

- Verkäufe netto: 1.017 × 70 % = 712 Robux am Tag. Das sind 0,31 je täglichem Spieler, nah am mittleren Szenario von 0,30 \[D\].
- Creator Rewards: 2.300 × 2,5 % × 5 = 288 Robux am Tag. Der Anteil von 2,5 % ist eine Annahme \[D\].
- Zusammen rund 1.000 Robux am Tag, 30.000 im Monat, rund 103 €.

VIP und Langzeit-Zähler sind in der Rechnung nicht enthalten.

| Szenario \[D\] | Robux je täglichem Spieler | Spieler für 100 € | Spieler für 200 € |
| --- | --- | --- | --- |
| Vorsichtig | 0,10 | 9.700 | 19.400 |
| Mittel | 0,425 | 2.300 | 4.600 |
| Gut | 1,25 | 780 | 1.550 |

Randbedingungen \[D\]: Auszahlung erst ab 30.000 verdienten Robux, Creator Rewards kommen 60 Tage später. Der höhere Kurs für US-Erwachsene und Audience Expansion sind nicht eingerechnet.

## 5. Technische Architektur

Das ganze Spiel rechnet in einem reinen Luau-Kern ohne Roblox-Abhängigkeit. Der Server ist dessen einzige Hülle mit Schreibrecht, der Client zeigt nur an. Derselbe Kern läuft in Tests und Simulation außerhalb von Studio.

### Projektstruktur

```
power-grid/
  default.project.json        Rojo: welcher Ordner wohin in Studio gehört
  rokit.toml                  feste Werkzeug-Versionen
  selene.toml, stylua.toml    Prüfregeln und Formatierung
  .github/workflows/ci.yml    Format, Lint, Tests, Simulation bei jeder Änderung
  src/
    shared/                   -> ReplicatedStorage
      Config/                 Plants, Upgrades, Prestige, Weather, Phases, Shop
      Core/                   GameCore, Formulas, Env (Phase und Wetter aus Startwert)
      Locale/                 en.luau, de.luau
      Net.luau                Namen und Prüfregeln der Nachrichten
      Types.luau, Format.luau
    server/                   -> ServerScriptService
      Services/               Data, Session, Env, Action, Purchase, Policy, Boost, Leaderboard, Plot
      Migrations/             ein Schritt je Datenversion
      Vendor/ProfileStore.luau
      Main.server.luau
    client/                   -> StarterPlayerScripts
      Controllers/            State, Hud, Shop, Tree, Rules, Plot, Weather, Tutorial
      UI/                     Bausteine der Oberfläche
      Main.client.luau
  tests/                      Unit-Tests, dazu fixtures/ mit alten Spielständen
  sim/                        Bots, Zielkurven, Bericht
  docs/                       dieser Bauplan, Entscheidungen, Balance-Berichte
```

Änderungen gegenüber der Vorlage im Design-Dokument:

- **Kein Wally.** Die einzige fremde Bibliothek ist ProfileStore, und die besteht aus einer einzigen Datei \[B\]. Sie liegt im Ordner Vendor, mit notiertem Stand.
- **Kein Ordner assets.** Grundstücke und Anlagen baut der Code aus Grundformen. Damit liegt das ganze Spiel in Git, in Studio bleibt eine fast leere Welt.
- **Neu:** Core als Rechenkern, sim getrennt von tests, Locale, Migrations und die automatische Prüfung bei GitHub.

### Werkzeuge

Versionen sind die neuesten Tags der Projekte am 13.11.2026 \[B\].

| Werkzeug | Version | Wofür |
| --- | --- | --- |
| Rojo | 7.7.1 | überträgt die Dateien nach Studio |
| Rokit | 1.2.0 | installiert die anderen Werkzeuge in fester Version |
| Lune | 0.11.1 | führt Luau außerhalb von Studio aus: Tests und Simulation |
| Selene | 0.32.0 | findet typische Fehler im Code |
| StyLua | 2.6.0 | einheitliche Formatierung |
| ProfileStore | ohne Versionsnummer | Speichern mit Sitzungssperre und automatischem Sichern |
| Studio-MCP-Server | in Studio eingebaut | Spiel starten, Konsole lesen, Bildschirmfoto, Eingaben simulieren |

Nicht gewählt: Wally 0.3.2 (unnötig) und jest-lua 3.10.0. Unsere Tests prüfen reine Rechenlogik, dafür reicht ein kleiner eigener Testläufer unter Lune \[A\].

**MCP-Regel.** Verbunden wird über Assistant, Manage MCP Servers, „Enable Studio as MCP server“ und Quick connect für Claude Code \[B\]. Auf deinem Windows-Rechner startet der Server über cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat", Quick connect trägt das selbst ein \[B\]. Erlaubt sind die lesenden und spielenden Werkzeuge: `get_studio_state`, `start_stop_play`, `get_console_output`, `screen_capture`, `character_navigation`, `user_keyboard_input`, `user_mouse_input`, `search_game_tree`, `inspect_instance`, `script_read`, `script_grep` sowie `execute_luau` zum Auslesen im laufenden Test. Verboten sind `multi_edit`, `insert_asset`, alle `generate_*`, `upload_image` und `save_place`.

### Module

| Modul | Aufgabe |
| --- | --- |
| Core/GameCore | `tick(state, env, dt)`, `apply(state, action, env)`, `offline(state, sekunden)`. Kennt weder Spieler noch Netzwerk |
| Core/Env | berechnet Phase und Wetter aus Serverzeit und Startwert |
| Config/\* | alle Zahlen aus Abschnitt 2 und 3 als Tabellen. Kein Code enthält Spielwerte |
| DataService | lädt und sichert Profile über ProfileStore, führt Migrationen aus |
| SessionService | hält den Zustand je Spieler, rechnet einmal pro Sekunde, schickt Änderungen |
| ActionService | nimmt Nachrichten an, prüft und begrenzt sie, ruft `GameCore.apply` |
| EnvService | Tageszeit, Wetter und Beleuchtung für den Server |
| PurchaseService | ProcessReceipt, Pass-Prüfung, Gutschriften |
| PolicyService-Hülle | fragt Altersregeln je Spieler ab und merkt sie für die Sitzung |
| BoostService | Sonnenstunde und Turbo, Warteschlange, Restzeit |
| LeaderboardService | Server-Liste und Welt-Liste |
| PlotService | weist Grundstücke zu und baut die Anlagen sichtbar auf |
| Client-Controller | zeigen Zustand an und schicken Absichten. Keine Spiellogik |

Ein Server fasst 8 Spieler \[A\], die Avatare bleiben Standard R15 \[D\].

### Netzwerk-Nachrichten

Je Nachricht ein RemoteEvent, keine RemoteFunctions. Der Client schickt nie Beträge, Preise oder Zeiten.

| Nachricht | Richtung | Inhalt | Server prüft | Limit |
| --- | --- | --- | --- | --- |
| BuyPlant | Client → Server | Anlage 1–6, Menge 1, 10 oder max | Anlage freigeschaltet, Coins reichen, Preis rechnet der Server | 8/s |
| BuyNode | Client → Server | Knoten-ID | Knoten existiert, Voraussetzung erfüllt, nicht doppelt, Währung reicht | 4/s |
| Crank | Client → Server | leer | nichts, der Server zählt | 8/s, Rest verfällt |
| SetRule | Client → Server | Platz, Regel, Schwelle, an/aus | Platz und Regel freigeschaltet, Schwelle 0,5–2,0 in Zehntelschritten, Reserve 0–90 % | 2/s |
| SetStorageMode | Client → Server | Laden, Verkaufen oder Automatik | Speicher vorhanden | 2/s |
| Prestige | Client → Server | leer | Einnahmen im Lauf reichen, Stufe unter 10 | 1 je 5 s |
| SetCosmetic | Client → Server | Platz, Gegenstand | Pass gehört dem Spieler | 1/s |
| Ready | Client → Server | leer | Profil geladen | 1 je 5 s |
| Snapshot | Server → Besitzer | ganzer Zustand |  | bei Beitritt und nach Ausbau |
| Delta | Server → Besitzer | Coins, Raten, Speicherstand |  | 1/s |
| Env | Server → alle | Phase, Wetter, Booster, Vorschau |  | bei Änderung |
| PlotPublic | Server → alle | Anlagenzahlen, Stufe, Kosmetik eines Grundstücks |  | höchstens alle 5 s je Grundstück |
| Notice | Server → Spieler oder alle | Meilenstein, Kauf bestätigt, Server-Meldung |  | bei Ereignis |

Allgemeine Prüfung für jede eingehende Nachricht: Typ jedes Feldes, IDs nur aus Config, Zahlen ganzzahlig und endlich, unbekannte Felder werden ignoriert. Jede Nachricht hat ein eigenes Kontingent je Spieler. Wer dauerhaft über 30 Nachrichten pro Sekunde schickt, wird protokolliert und beim dritten Mal vom Server entfernt.

### Datenmodell, Version 1

```lua
{
  v = 1,                                   -- Datenversion
  coins = 0, runEarned = 0, lifetimeEarned = 0,
  level = 0, sparks = 0, sparksSpent = 0,
  plants = { 0, 0, 0, 0, 0, 0 },
  nodes = {},                              -- Lauf-Knoten, z. B. { U01 = true }
  pnodes = {},                             -- Dauer-Knoten
  storage = { charge = 0, mode = "auto" },
  rules = {},                              -- je Platz { id, th, on }
  lastSeen = 0,                            -- Serverzeit beim letzten Sichern
  playSeconds = 0, sessions = 0, firstJoin = 0,
  purchases = {},                          -- die letzten 100 Kaufbeleg-IDs
  grants = { founder = false, boostSeconds = 0, skipDay = 0, skipCount = 0 },
  cosmetics = {},                          -- gewählte Kosmetik je Platz
  settings = { lang = "auto", sfx = true, music = true },
  tutorial = 0,
}
```

- **Migrationen:** `Migrations[n]` hebt einen Spielstand von Version n auf n+1. Beim Laden laufen alle fehlenden Schritte nacheinander, danach füllt `Profile:Reconcile()` neue Felder aus der Vorlage \[B\].
- **Schutz vor Brüchen:** Von jeder veröffentlichten Version liegt ein Beispiel-Spielstand in `tests/fixtures`. Ein Test lädt alle bis zur aktuellen Version.
- **Pass-Besitz wird nicht gespeichert.** Roblox ist dafür die Quelle. Gespeichert werden nur einmalige Gutschriften.
- **Zahlen:** Luau rechnet mit 64-Bit-Kommazahlen. Stufe 10 liegt bei 100 Billionen, das ist weit im sicheren Bereich.

### Kauf-Abwicklung

Entwicklerprodukte (Sonnenstunde, Turbo, Zeitsprung) laufen über einen einzigen `ProcessReceipt`-Callback auf dem Server \[B\]:

1. Spieler nicht auf dem Server oder Profil nicht aktiv: `NotProcessedYet`. Roblox versucht es beim nächsten Beitritt erneut \[B\].
2. Beleg-ID steht schon in `purchases`: sofort `PurchaseGranted`, nichts doppelt gutschreiben.
3. Produkt-ID in der Shop-Tabelle nachschlagen und die Gutschrift im Profil eintragen, geschützt mit `pcall`. Bei Fehler `NotProcessedYet`.
4. Beleg-ID eintragen, `Profile:Save()` anstoßen \[B\], dann `PurchaseGranted`.

Das Ereignis `PromptProductPurchaseFinished` wird nie zum Gutschreiben benutzt \[B\]. Kaufdialoge öffnen sich nur nach einem Klick des Spielers \[B\]. Der Kaufdialog von Roblox ist die Bestätigung, eine eigene zweite Abfrage ist nicht vorgeschrieben \[B: in Doku und Community Standards keine solche Pflicht gefunden\].

Pässe: beim Beitritt `UserOwnsGamePassAsync` je Pass in `pcall`, nach einem Kauf zusätzlich `PromptGamePassPurchaseFinished` \[B\]. Roblox führt keine Kaufhistorie je Spieler, einmalige Gutschriften merkt sich das Profil \[B\].

### PolicyService

Der Server ruft beim Beitritt `GetPolicyInfoForPlayerAsync` in `pcall` auf und merkt sich das Ergebnis für die Sitzung \[B\]. Benutzt werden `ArePaidRandomItemsRestricted`, `AreAdsAllowed` und `IsSubjectToChinaPolicies`. Schlägt der Aufruf fehl, gilt der Spieler als eingeschränkt. Im MVP ändert das nichts am Angebot, weil es keine Zufallskäufe und keine Werbung gibt. Die Hülle steht bereit, falls sich das ändert.

### Anti-Exploit-Grundregeln

- Der Server rechnet alles. Der Client bekommt nur Kopien zum Anzeigen.
- Zeit kommt immer vom Server. Offline-Zeit wird auf 0 bis Deckel begrenzt.
- Jede Aktion prüft Besitz, Voraussetzung und Preis neu, egal was der Client anzeigt.
- Coins und Speicherstand dürfen nie negativ oder unendlich werden. Ein Test prüft das mit Zufallseingaben.
- Käufe sind über die Beleg-ID gegen doppeltes Gutschreiben geschützt.
- ProfileStore sperrt ein Profil für genau einen Server. Lädt es nicht, wird der Spieler mit Hinweis entfernt \[B: Empfehlung der ProfileStore-Doku\].
- Bestenlisten schreibt nur der Server.

### Sprachen

Texte liegen als eigene Tabellen `en.luau` und `de.luau` im Projekt. Gewählt wird nach der Sprache des Spielers, umschaltbar in den Einstellungen. Ein Test prüft, dass beide Tabellen dieselben Schlüssel haben. Titel und Beschreibung des Spiels übersetzt du im Creator Hub von Hand.

## 6. Teststrategie

Vier Ebenen: Die ersten beiden laufen ohne Studio bei jeder Änderung, die dritte über MCP an deinem Rechner, die vierte bist du.

| Ebene | Was geprüft wird | Womit | Wann |
| --- | --- | --- | --- |
| 1 Unit-Tests | Formeln, GameCore, Migrationen, Sprachtabellen, Config (IDs eindeutig, Voraussetzungen vorhanden, Kosten steigend), Kaufgutschrift bei doppeltem Beleg, Zufallseingaben gegen negative Coins | Lune, eigener Testläufer, dazu StyLua und Selene | bei jeder Änderung, automatisch bei GitHub |
| 2 Balancing-Simulation | drei Bots über 9 Startwerte und 3 Startzeiten gegen die Zielkurven Z1–Z11 | Lune, derselbe GameCore wie im Spiel | bei jeder Änderung an Config oder Core. Außerhalb der Toleranz schlägt die Prüfung fehl |
| 3 Studio-Playtest | Spiel startet ohne Fehler und Warnungen, Prüfliste des Meilensteins (kurbeln, kaufen, Regel setzen, ausbauen, Shop öffnen), Bildschirmfotos der Oberfläche in Englisch und Deutsch | Studio-MCP: starten, Konsole lesen, Eingaben simulieren, Zustand auslesen, Bildschirmfoto | am Ende jeder Aufgabe mit sichtbarer Wirkung, nur wenn Studio offen ist |
| 4 Handprüfung | Spielspaß, Tempo, Verständlichkeit ohne Erklärung, Lesbarkeit, Handy-Ansicht im Studio-Emulator, deutsche Texte, Testkäufe | du in Studio | am Ende jedes Meilensteins |

- Die Simulation schreibt einen kurzen Bericht nach `docs/balance`. Jede Änderung an Spielwerten zeigt damit vorher und nachher.
- Speichern wird in Studio gegen `ProfileStore.Mock` getestet, damit keine echten Spielstände entstehen \[B\].
- Mehrspieler-Fälle (zwei Grundstücke, Sonnenstunde für alle) testest du mit dem lokalen Server-Test von Studio mit zwei Spielern.
- Offene technische Annahme: Lune und Roblox laden dieselbe Datei mit denselben `require`-Pfaden. Meilenstein 0 beweist das oder wählt einen anderen Weg \[A\].

## 7. Meilensteine

Sechs Meilensteine mit zusammen 13–16 Sitzungen. Eine Sitzung sind zwei bis drei Stunden \[D\]. Nach Meilenstein 1 steht die Entscheidung, ob das Spiel Spaß macht.

| Meilenstein | Sitzungen | Inhalt | Abnahmekriterien | Was du in Studio prüfst |
| --- | --- | --- | --- | --- |
| M0 Fundament | 1 | Repository, Werkzeuge über Rokit, Rojo-Verbindung, automatische Prüfung, Testläufer, MCP verbunden | Prüfung bei GitHub grün. Eine Testdatei läuft unverändert in Lune und in Studio. Claude startet und stoppt einen Playtest und liest die Konsole | Skripte erscheinen aus den Dateien in Studio. Der MCP-Schalter zeigt eine Verbindung |
| M1 Kernschleife, ohne Shop und Speichern | 3–4 | GameCore, alle Config-Tabellen, Kurbel, sechs Anlagen, Lauf-Knoten, Tag/Nacht, Wetter, Speicher, Regeln, Netzstufen, einfache Oberfläche, ein Grundstück aus Grundformen | Unit-Tests grün. Luau-Simulation trifft Z1–Z11 oder die Werte sind begründet angepasst. Playtest-Prüfliste ohne Fehler | 30–45 Minuten spielen bis zum ersten Ausbau. Macht es Spaß? Versteht man es ohne Erklärung? Fühlt sich der Speicher lohnend an? Danach: weiter, anpassen oder Plan B |
| M2 Speichern | 2 | ProfileStore, Datenmodell v1, Migrations-Gerüst, Offline-Ertrag, acht Grundstücke, Willkommen-Bildschirm | Verlassen und Wiederkommen stellt den Stand exakt her. Offline-Ertrag stimmt mit der Formel. Fixture-Test läuft. Zwei Spieler stören sich nicht | Spielen, verlassen, wiederkommen. Betrag im Willkommen-Bildschirm plausibel? Test mit zwei Spielern |
| M3 Käufe | 2 | Pässe, Produkte, ProcessReceipt, PolicyService, Shop, Booster-Warteschlange, Sonnenstunde | Doppelter Beleg schreibt nur einmal gut. Jeder Artikel wirkt sofort und nach erneutem Beitritt. Kein Kaufhinweis vor Minute 12 | Pässe und Produkte im Creator Hub anlegen und die IDs übergeben. Jeden Artikel einmal im Testmodus kaufen |
| M4 Inhalte | 3–4 | Baum-Ansicht, Funken-Shop, Bestenlisten, sichtbare Kosmetik, Englisch und Deutsch, Tutorial, Klänge und Effekte, Handy-Oberfläche, Messpunkte für die Auswertung | Beide Sprachen vollständig. Tutorial führt bis zum Speicher. Kosmetik ist auf fremden Grundstücken zu sehen. Bedienbar im Handy-Format | Ersten Tag nachspielen. Deutsche Texte lesen. Handy-Emulator. Sieht das Grundstück eines Zahlers sichtbar anders aus? |
| M5 Feinschliff und Veröffentlichung | 2–3 | Balancing aus den Spieltests, Last mit acht Spielern, Inhalts-Fragebogen, Icon, Vorschaubilder, Beschreibung, Veröffentlichung ab 16 | Server bleibt mit acht Spielern flüssig. Keine Fehler in der Konsole über 30 Minuten. Alle Punkte aus Abschnitt 9 erledigt | Gesamteindruck. Titel, Bilder und Beschreibung freigeben. Veröffentlichen |

Pässe und Produkte kann nur der Kontoinhaber anlegen, deshalb liegt das in M3 bei dir. Claude liefert dazu eine Liste mit Namen, Preisen und Beschreibungen zum Abtippen.

## 8. Agenten-Aufteilung

Fünf Rollen plus du. Wer baut, prüft nie die eigene Arbeit.

| Rolle | Aufgabe in einem Satz |
| --- | --- |
| Planer | Zerlegt einen Meilenstein in kleine Aufgaben und schreibt zu jeder auf, woran man „fertig“ erkennt |
| Bauer | Schreibt den Code als Dateien, immer nur für eine Aufgabe |
| Prüfer | Liest jede Änderung mit frischem Blick gegen diesen Bauplan, bevor sie übernommen wird |
| Rechner | Lässt Tests und Simulation laufen und meldet jede Abweichung von den Zielkurven |
| Tester | Startet das Spiel über MCP in Studio, liest Fehlermeldungen, klickt die Prüfliste durch und macht Bildschirmfotos |
| Du | Beurteilst Spielspaß und gibst Meilensteine frei |

Was du davon siehst: grüne oder rote Haken bei GitHub für Ebene 1 und 2, einen kurzen Testbericht mit Bildern für Ebene 3 und am Ende jedes Meilensteins eine Prüfliste für dich. Der Tester braucht deinen Rechner mit offenem Studio, die anderen vier Rollen nicht.

## 9. Veröffentlichung

Das Spiel startet bei Nutzern ab 16 und braucht 250 Plays stark engagierter Spieler in 60 Tagen, um auch Jüngere zu erreichen \[B\]. Werbegeld fließt erst, wenn die Messwerte stimmen.

### Titel

| Variante | Englisch | Deutsch | Wofür sie steht |
| --- | --- | --- | --- |
| A | Power Grid Incremental | Stromnetz Incremental | enthält das Genre-Suchwort, wie mehrere Chart-Spiele \[D\] |
| B | Power the City! | Versorge die Stadt! | Verb-Titel im Stil von „Cut a Rock“ und „Sweep The Moon“ \[D\] |

### Vorschaubild und Icon

Vorschaubilder sind 1920 × 1080 Pixel, das Icon ist quadratisch mit mindestens 512 × 512 \[B: Angaben Dritter zum Creator Hub\]. Sind zwei oder mehr Vorschaubilder aktiv, testet Roblox sie selbstständig gegeneinander \[B\]. Beide Varianten gehen deshalb gleichzeitig online. Alle Bilder entstehen aus echten Spielszenen mit Schrift darüber, damit sie zeigen, was das Spiel wirklich bietet.

|  | Variante A | Variante B |
| --- | --- | --- |
| Vorschaubild | „Abendspitze“: Grundstück bei Sonnenuntergang, leuchtende Module, großes Windrad, jubelnde Figur, große Zahl „+1.2M/s“ | „Vorher/Nachher“: links ein einzelnes Balkonmodul, rechts dasselbe Grundstück voll ausgebaut unter goldenem Himmel |
| Icon | gelber Blitz mit lachendem Solarmodul auf Blau | rundliches Windrad mit Münze, Gelb auf Dunkelblau |

Das Icon muss auch bei etwa 150 Pixeln Kantenlänge erkennbar bleiben.

### Beschreibung

**Variante A, sachlich**

- EN: Build your own power grid! Crank, buy solar panels and wind turbines, store cheap midday power and sell it at the evening peak. The weather changes for the whole server. Grow your grid from a single street to the whole solar system. No loot boxes, no random purchases.
- DE: Bau dein eigenes Stromnetz! Kurble, kaufe Solarmodule und Windräder, speichere billigen Mittagsstrom und verkaufe ihn zur Abendspitze. Das Wetter gilt für den ganzen Server. Bau dein Netz von einer Straße bis zum Sonnensystem aus. Keine Lootboxen, keine Zufallskäufe.

**Variante B, verspielt**

- EN: Sun's out, coins in! Start with one tiny balcony panel and end up powering a planet. Set smart rules, ride the storms, climb the leaderboard. Fair play: there is nothing random to buy.
- DE: Sonne an, Kasse klingelt! Starte mit einem Balkonmodul und versorge am Ende einen Planeten. Stell schlaue Regeln ein, nutze jedes Gewitter, klettere in der Bestenliste. Fair: Hier gibt es nichts Zufälliges zu kaufen.

### Was du vor dem Start selbst erledigst

- [ ] Altersnachweis mit Ausweis im Roblox-Konto \[B\]
- [ ] Zwei-Faktor-Anmeldung einschalten \[B\]
- [ ] Inhalts-Fragebogen ausfüllen, Ziel ist die Einstufung Minimal oder Mild \[B\]
- [ ] 1.000 Robux Gebühr hinterlegen \[D\]. Sie wird 90 Tage nach der Freigabe automatisch erstattet, sonst 90 Tage nach der Zahlung \[B\]. Alternative: seit zwei Monaten laufendes Roblox-Plus- oder Premium-Abo \[B\]

### Plan für die ersten 100 Spieler und die Evaluation

1. **Stiller Start ab 16, eine Woche ohne Werbung.** Ziel sind Fehler, nicht Zahlen. Spieler kommen über die Suche und über Bekannte ab 16.
2. **Messschranke.** Weiter geht es erst, wenn Rückkehr am nächsten Tag und Sitzungszeit mindestens den Mittelwert ähnlicher Spiele erreichen. Der Creator Hub zeigt dafür die Spanne vom 50. bis 90. Perzentil \[B\]. Unter 100 neuen Spielern sind die Werte zu wacklig für ein Urteil \[A\].
3. **Kleine Anzeige mit dem Ziel „Engagement“.** Sitzungen aus solchen Anzeigen zählen für die Schwelle der stark engagierten Spieler \[B\]. Ein Werbeguthaben kostet 263 Robux \[B: Suchausschnitt der Doku-Seite\]. Als Mindestbudget nannte Roblox 2025 zehn Guthaben, also rund 2.600 Robux. Ob das noch gilt, ist offen.
4. **Fortschritt verfolgen** im Reiter Audience Reach des Creator Hub \[B\].
5. **Runden drehen.** Eine Runde dauert zwei Wochen oder 300 neue Spieler, je nachdem was früher eintritt \[A\]. Danach auswerten, eine Sache ändern, neu messen.

Ehrliche Einordnung zum Budget: Ein einzelner, nicht prüfbarer Erfahrungsbericht nennt rund 180 $ Werbekosten für 500 stark engagierte Spieler in elf Tagen. Für 250 wäre das grob die Hälfte und damit fast dein ganzes Startbudget. Die Freigabe für unter 16-Jährige allein über Werbung zu kaufen ist also knapp. Roblox hat angekündigt, die Schwelle noch 2026 auf 100 zu senken. In der Doku steht weiter 250.

### Erfolgsmesswerte und Abbruchkriterium

| Messwert \[D\] | Ziel |
| --- | --- |
| Anteil der Sitzungen über 10 Minuten | mindestens 45 % \[A\] |
| Rückkehr am nächsten Tag | mindestens Mittelwert ähnlicher Spiele im Creator Hub |
| Robux je täglichem Spieler | 0,4 \[D\] |

Abbruch \[D\]: Zeigen drei Verbesserungsrunden keinen Fortschritt, folgt der Wechsel auf Idee 4 oder das Ende des Projekts. Als Fortschritt zählt, wenn mindestens ein Messwert um 10 % steigt und keiner um mehr als 10 % fällt \[A\].

## 10. Offene Fragen an dich

Vier Punkte hast du am 13.11.2026 entschieden. Fünf sind noch offen und haben Zeit bis Meilenstein 3.

### Entschieden

- **Premium-Tarif:** kommt, Verkaufspreis dauerhaft ×1,5.
- **Erster Netz-Ausbau:** Ziel bleibt 30–45 Minuten, Kontrolle im Spieltest von Meilenstein 1. Ausweg, falls es sich zu lang anfühlt: Schwelle 3 Mio. statt 10 Mio., das wären rund 20 Minuten \[S\].
- **Solar in der Nacht:** 10 % statt null. Formeln, Tabellen und Simulation sind angepasst.
- **Rechner:** Roblox Studio läuft unter Windows.

### Noch offen

1. **Bekommen Verbrauchskäufe Tagesgrenzen?** Geplant sind höchstens drei Zeitsprünge am Tag und höchstens 60 Minuten Booster-Vorrat. Empfehlung: ja. Das schützt jüngere Spieler, passt zum Ziel Kids/Select und kostet wenig Umsatz.
2. **Ist es in Ordnung, dass die Smart-Zentrale etwas sofort gibt, was Gratis-Spieler erst spät freischalten?** Empfehlung: ja. Der Pass verkauft Zeit, keine exklusive Stärke. Die Alternative wäre ein rein kosmetischer Pass mit weniger Kaufanreiz.
3. **Wo arbeiten die Agenten?** Empfehlung: in einer Claude-Code-Sitzung auf deinem Rechner, mit der automatischen Prüfung bei GitHub als Sicherheitsnetz. Der Tester braucht dein offenes Studio, das kann ein Agent bei GitHub nicht erreichen. Dein Agenten-Template lässt sich später für Bauen, Prüfen und Rechnen andocken, wenn Meilenstein 1 den Spaßtest bestanden hat.
4. **Wie teilen wir das Startbudget auf?** Empfehlung: die 1.000 Robux Gebühr erst in Meilenstein 5 zahlen, Werbung erst nach der Messschranke aus Abschnitt 9, zusammen höchstens dein Rahmen von 100 €. Geld in ein Spiel zu stecken, das Spieler nicht hält, bringt nichts.
5. **Soll das GitHub-Repository privat sein?** Empfehlung: ja. Das Genre wird schnell kopiert \[D\], und offener Code samt Balancing-Tabellen würde das erleichtern.

Titel: Ich würde mit Variante A starten, weil das Suchwort Spieler bringt, die genau dieses Genre suchen. Variante B bleibt als Test für später.

## Quellen

Alle Seiten am 13.11.2026 abgerufen.

**Vollständig gelesen**

- [Design- und Marktkonzept](https://claude.ai/artifact/AxaB8TWq7WQHpM5cZa7Dn1): alle Angaben mit \[D\]
- [Roblox-Doku: Studio MCP server](https://create.roblox.com/docs/studio/mcp): Einrichtung, Werkzeugnamen, Sicherheitshinweis
- [Roblox-Doku: Developer Products](https://create.roblox.com/docs/production/monetization/developer-products): ProcessReceipt, Rückgabewerte, Kaufdialog nur nach Nutzeraktion
- [Roblox-Doku: Passes](https://create.roblox.com/docs/production/monetization/passes): Besitzprüfung, Preisgrenzen beworbener Pässe
- [Roblox-Doku: Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select): Voraussetzungen, Schwelle 250, Erstattung der Gebühr
- [Roblox-Doku: PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService.md): Felder und Fehlerfälle
- [Roblox-Doku: Ads Manager](https://create.roblox.com/docs/production/promotion/sponsoring-experiences): Ziele, Werbeguthaben, Engagement zählt für die Schwelle
- [Roblox Community Standards](https://about.roblox.com/community-standards): Regeln zu Käufen und irreführenden Inhalten
- [ProfileStore API](https://madstudioroblox.github.io/ProfileStore/api): Sitzungen, Reconcile, Save, Mock
- Versions-Tags per Git: [Rojo](https://github.com/rojo-rbx/rojo), [Rokit](https://github.com/rojo-rbx/rokit), [Lune](https://github.com/lune-org/lune), [Selene](https://github.com/Kampfkarren/selene), [StyLua](https://github.com/JohnnyMorganz/StyLua), [Wally](https://github.com/UpliftGames/wally), [jest-lua](https://github.com/jsdotlua/jest-lua)

**Nur als Suchausschnitt gelesen**

- [DevForum: Highly Engaged Player Threshold Drops to 250](https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164)
- [DevForum: Antwort von Roblox zur geplanten Senkung auf 100](https://devforum.roblox.com/t/existing-game-arcadia-locked-to-16-despite-meeting-creator-requirements/4908927)
- [DevForum: Kids and Select Global Launch](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717): Anzeigenziel Engagement
- [DevForum: More Ads Manager Upgrades](https://devforum.roblox.com/t/more-ads-manager-upgrades/3659656): Mindestbudget von zehn Werbeguthaben, Stand 2025
- [Roblox-Doku: Analytics](https://create.roblox.com/docs/production/analytics): Vergleichswerte ähnlicher Spiele
- [Roblox-Doku: Thumbnails](https://create.roblox.com/docs/it-it/production/promotion/thumbnails): automatischer Test mehrerer Vorschaubilder
- [Bildgrößen laut Dritten](https://moda.app/resources/sizes/roblox): 1920 × 1080 und 512 × 512
- [Erfahrungsbericht zu Werbekosten](https://sozai.app/transcript/roblox-500-highly-engaged-players-update/): Einzelfall, nicht prüfbar
