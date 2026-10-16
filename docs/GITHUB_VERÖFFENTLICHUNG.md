# GitHub-Veröffentlichung

Öffentliches Projekt: [vBL4CKs/abrissfirma](https://github.com/vBL4CKs/abrissfirma).

Windows-Download: [Release v0.2.0](https://github.com/vBL4CKs/abrissfirma/releases/tag/v0.2.0).
Browserfassung: [Abrissfirma spielen](https://vbl4cks.github.io/abrissfirma/).

- `main`: Quellcode, Spielressourcen, Anleitung und Vergleichsaufnahmen.
- Release `v0.2.0`: `Abrissfirma-Spielbereit.zip` als Windows-Download.
- `gh-pages`: separat exportierte Browserfassung für GitHub Pages.

Die großen lokalen Godot-Programme und fertigen Exportdateien bleiben außerhalb
des Quellcode-Commits. Texturen und Geräusche mit ihren Lizenzhinweisen sind enthalten.

## Erneut veröffentlichen

Nach Änderungen die passende Ausgabe mit Godot exportieren. Lokal befinden sich
die Exportvorlagen unter `tools/export-templates/`; sie werden nicht hochgeladen.
Für eine neue Arbeitskopie die passenden Godot-Exportvorlagen installieren und
die benutzerdefinierten Vorlagenpfade in den Export-Einstellungen anpassen.
Der separate lokale Ordner `tools/pages-publish/` enthält den Veröffentlichungszweig.
Eine neue Windows-Ausgabe als neue Release-Version hochladen.

## Browserfassung

Der Export verwendet Godot 4.7.2, WebGL 2 und die Variante ohne Threads.
Dadurch werden keine speziellen Cross-Origin-Isolation-Header benötigt.
Das Spiel benötigt einen aktuellen Desktop-Browser und eine Tastatur mit Maus.
Die Browserleistung kann von der Windows-Version abweichen.

Quellen: [Godot Web-Export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html),
[GitHub Pages veröffentlichen](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
