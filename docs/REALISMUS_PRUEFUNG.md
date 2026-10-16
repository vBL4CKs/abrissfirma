# Realismusprüfung und echte Spielaufnahmen

Diese Überarbeitung wird durch ergänzende Prüfungen abgesichert. Die bestehende
Spielrunde wird außerdem mit `tests/smoke_test.gd` geprüft.

## Ausgangszustand

- Wandstücke waren 1,18 m breit bei 1,20 m Abstand. Dadurch waren offene,
  regelmäßige Fugen bereits am unbeschädigten Haus sichtbar.
- Schaden färbte das gesamte Wandstück dunkel. Beim Bruch wurde dieses Stück
  vollständig durch einen kleineren Quader ersetzt.
- Auch Beton, Holz und Glas erzeugten denselben Quader mit Box-Kollision.
- Große Fragmente erhielten eine Geschwindigkeit von bis zu etwa 9 m/s und
  zufällige Drehimpulse. Ihr Gewicht war auf 12 kg begrenzt.
- Die Stützprüfung entfernte alle nicht verbundenen Teile im selben Aufruf.
- Nach sieben Sekunden wurden Körper unabhängig von ihrer Lage eingefroren;
  oberhalb der Trümmergrenze wurden ältere Körper sofort gelöscht.

## Ergänzende Funktionsprüfungen

`tests/realism_test.gd` prüft Fugen, Materialkarten, örtliche Schäden, geschlossene
Bruchgeometrie, konvexe Kollisionen, begrenzte Abrissimpulse, zeitlichen Einsturz,
Schutt und Auftragsneustart. Geometrieprüfungen können eine Sichtkontrolle nicht
ersetzen.

Der Test verwendet ein separates Konto im Arbeitsspeicher. Er löst weder Käufe
noch Auszahlungen aus. Der Originalspielstand wird vorher als Bytes gelesen und
nachher unverändert verglichen. Sollte ein unerwarteter Schreibvorgang auftreten,
wird der Originalinhalt wiederhergestellt. Ergebnis: `realism-test-results.json`.

## Renderprüfung und Leistung

`tests/visual_benchmark.gd` lädt die echte Hauptszene mit der normalen
Grafikausgabe. Er verweigert einen Lauf ohne Rendering, damit Headless-Werte
nicht als Grafikleistung ausgegeben werden.

Der Benchmark verwendet 1280 × 800 Pixel, deaktiviertes VSync und eine
unbegrenzte Bildrate. Die vorhandene mittlere Qualitätsstufe wird verwendet.
Er erfasst GPU und Renderer sowie durchschnittliche FPS, 1-%-Low, mittlere,
99.-Perzentil- und maximale Framezeit. Framezeiten stammen aus monotonen
Zeitmessungen zwischen gerenderten Frames. Die Messintervalle betragen jeweils
vier Sekunden nach einer Aufwärmphase. Eine Bildschirmaufnahme im Einsturz
wird aus der Messung ausgeschlossen.

Die Aufnahmeansichten liegen unter `docs/realismus/`:

1. `01_fassade_unbeschaedigt.png` – gesamtes Gebäude vor dem Abriss.
2. `01b_fassadendetail_unbeschaedigt.png` – Ausschnitt vor den Treffern.
3. `02_fassade_lokaler_schaden.png` – derselbe Ausschnitt mit örtlichen Hammerschäden.
4. `03_innenraum.png` – begehbarer Raum.
5. `04_einsturz.png` – Gebäude während des nachfolgenden Stützverlusts.
6. `05_schutthaufen.png` – zurückbleibende Teile.

Die Ausgangsaufnahmen der ersten Version bleiben in
`docs/vergleich/vorher/spielansicht.png` und `docs/vergleich/vorher/abriss.png`
erhalten. Benchmarkwerte beschreiben genau diese Testszene
und sind keine zugesicherte Bildrate für jedes spätere Gebäude.

## Tatsächlich geprüfte Ergebnisse

Godot 4.7.2, 16. Oktober 2026:

- **52 von 52 Spielprüfungen bestanden.** Der vollständige Bericht liegt in
  `docs/test-results.json`; der abschließende Lauf dauerte 26,6 Sekunden. Er enthält Bewegung,
  begehbare Treppe, Werkzeuge, Neustart, Auszahlung, Shop und Speichern. Der
  Originalspielstand wurde wiederhergestellt.
- **25 von 25 Realismusprüfungen bestanden.** Der Bericht liegt in
  `docs/realism-test-results.json`; der abschließende Lauf dauerte 27,4 Sekunden.
- 78 geprüfte Fassadenanschlüsse ohne offene Rasterfugen.
- Albedo-, Rauheits- und Normaltexturen für drei Hauptmaterialien vorhanden.
- Zwei örtliche Treffer erzeugten zwei sichtbare Schadenselemente; die Wand
  blieb vor dem endgültigen Ausbruch bestehen.
- 13 geprüfte Bruchstücke aus Ziegel, Beton, Holz und Glas waren geschlossene,
  unregelmäßige Meshes mit konvexen Kollisionsformen.
- Die seitliche Geschwindigkeit der 50 Trümmer nach einem realen
  Impulsgerät-Einsatz lag im ersten Physikschritt höchstens bei 1,6 m/s.
- Nach vollständigem Stützverlust fielen 350 noch wartende Bauteile bereits
  während des vollen Physikpools ab. Der Einsturz wurde innerhalb des
  25-Sekunden-Prüffensters vollständig abgearbeitet.
- Danach waren 1169 Schuttelemente erhalten und noch sechs von höchstens 72
  detaillierten Physikkörpern aktiv. Es wurden keine frei schwebenden Körper
  per Zeitschalter eingefroren.
- Auftragsneustart räumte sowohl Schaden als auch Einsturzwarteschlange auf.
  Firmenkonto und Originalspielstand blieben bei dieser Zusatzprüfung
  bytegenau unverändert.

Diese Funktionsprüfungen liefen ohne Grafikausgabe. Ihre Geschwindigkeit ist
keine Aussage über die Bildrate auf der Grafikkarte.

## Tatsächlicher Grafikbenchmark

Gemessen am 16. Oktober 2026 mit **NVIDIA GeForce GTX 1050 Ti**, Godot 4.7.2,
Windows, GL-Compatibility-Renderer, **1280 × 800 Pixel**, Qualitätsstufe
**Mittel**, VSync aus und unbegrenzter Bildrate. Bericht:
`docs/visual-benchmark.json`.

| Messung | Intaktes Haus | Vollständiger Einsturz |
|---|---:|---:|
| Durchschnitt | 118,7 FPS | 49,5 FPS |
| 1-%-Low | 56,6 FPS | 9,2 FPS |
| Mittlere Framezeit | 8,43 ms | 20,20 ms |
| 99.-Perzentil der Framezeit | 16,56 ms | 97,26 ms |
| Langsamster Frame | 21,17 ms | 120,79 ms |
| Gemessene Frames | 475 | 182 |
| Tatsächlich erfasste Zeit ohne Aufnahme | 4,00 s | 3,68 s |
| Höchste Zahl detaillierter Physikkörper | 0 | 72 |

Der Einsturz belastet das Spiel deutlich: **Einzelne sichtbare Ruckler bleiben**,
wie die niedrigen 1-%-Low und der langsamste Frame zeigen. Die durchschnittlichen
49,5 FPS bedeuten deshalb keine gleichmäßig flüssige Darstellung. Das gewaltsame
Entfernen sämtlicher Bodenstützen ist ein Belastungstest; normale lokale Treffer
aktivieren weniger Teile. Größere Gebäude sind mit diesen Ergebnissen noch nicht
abgesichert.

Nach dem Einsturz waren alle **408 von 408 Bauteilen** entfernt. Es blieben
**1158 Schuttelemente**, neun detaillierte Physikkörper sowie **keine** offenen
Einsturz- oder Fragmentaufträge. Der Originalspielstand blieb unverändert.

Die Aufnahmen wurden aus der tatsächlich laufenden Hauptszene erzeugt. Fassade,
lokaler Schaden und Schutthaufen wurden visuell geprüft. Die Umgebung enthält
weiterhin vereinfachte Kulissen; die Simulation verwendet vereinfachte
Stützverbindungen und vorbereitete Bruchgeometrie. Eine ingenieurmäßige
Baustatik oder durchgehend fotorealistische Welt wird damit nicht behauptet.
