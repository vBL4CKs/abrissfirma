# Audioquellen – Abrissfirma

Die acht Audiodateien unter `assets/audio/` stammen unverändert aus **Impact Sounds 1.0** von **Kenney** (veröffentlicht 19.12.2019). Es handelt sich um kurze Aufprall- und Foley-Geräusche. Sie ersetzen die rein synthetischen Einzeltreffer; eine Baustellenaufnahme oder eine physikalisch akkurate Einsturzaufnahme wird damit nicht behauptet.

- Offizielle Paketquelle: https://kenney.nl/assets/impact-sounds
- Öffentliches Originalarchiv: https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip
- Lizenz: **Creative Commons Zero, CC0 1.0 Universal** — https://creativecommons.org/publicdomain/zero/1.0/
- Lizenztext: https://creativecommons.org/publicdomain/zero/1.0/legalcode
- Original-Lizenz aus dem Archiv: `assets/audio/KENNEY-LICENSE.txt`
- Herstellerhinweise: https://kenney.nl/support
- Abgerufen am: 16.10.2026

| Originaldatei | Verwendung |
| --- | --- |
| `impactMining_000.ogg` | Mauerwerk |
| `impactMining_001.ogg` | Beton; Bestandteil des Trümmeraufpralls |
| `impactMining_002.ogg` | Allgemeiner schwerer Treffer |
| `impactWood_heavy_000.ogg` | Holztreffer, Variante 1 |
| `impactPlank_medium_000.ogg` | Holztreffer, Variante 2; Bestandteil des Trümmeraufpralls |
| `impactGlass_heavy_001.ogg` | Glas, Variante 1 |
| `impactGlass_medium_000.ogg` | Glas, Variante 2; leiser Bestandteil des Trümmeraufpralls |
| `impactGeneric_light_000.ogg` | Gerät platzieren |

`scripts/impact_audio.gd` lädt diese OGG-Dateien direkt. Holz und Glas verwenden wechselnde Varianten mit geringer Tonhöhenvariation. Der Einsturzklang kombiniert Beton, Holz und ein leises Glasgeräusch gleichzeitig, mit abgestuften Pegeln. Die vorhandene synthetische Variante bleibt für den fiktiven Sprengeffekt erhalten, da das Paket keinen passenden Sprengklang enthält.

Der CC0-Hinweis erlaubt laut Original-Lizenz auch die kommerzielle Verwendung und Bearbeitung ohne verpflichtende Namensnennung. Die Quelle wird trotzdem dokumentiert. Es wurden weder kostenpflichtige Inhalte noch Kenney-Markenlogos übernommen.
