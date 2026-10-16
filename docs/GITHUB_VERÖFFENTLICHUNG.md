# GitHub-Veröffentlichung

Vorbereitet ist ein öffentliches Projekt mit dem Namen `abrissfirma`.

- `main`: Quellcode, Spielressourcen, Anleitung und Vergleichsaufnahmen.
- Release `v0.2.0`: `Abrissfirma-Spielbereit.zip` als Windows-Download.
- `gh-pages`: separat exportierte Browserfassung für GitHub Pages, sobald
  Export und Browserprüfung erfolgreich abgeschlossen sind.

Die großen lokalen Godot-Programme und fertigen Exportdateien bleiben außerhalb
des Quellcode-Commits. Texturen und Geräusche mit ihren Lizenzhinweisen sind enthalten.

## Voraussetzung

Die GitHub-Anmeldung muss vom Kontoinhaber auf GitHub abgeschlossen werden.
Erst eine erfolgreich bestätigte Anmeldung erlaubt das Erstellen des Repositories,
das Hochladen und das Aktivieren von GitHub Pages. Eine Bestätigung allein im Chat
ersetzt diese Anmeldung nicht.

## Browserfassung

Der Export verwendet Godot 4.7.2, WebGL 2 und die Variante ohne Threads.
Dadurch werden keine speziellen Cross-Origin-Isolation-Header benötigt.
Das Spiel benötigt einen aktuellen Desktop-Browser und eine Tastatur mit Maus.
Die Browserleistung kann von der Windows-Version abweichen.

Quellen: [Godot Web-Export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html),
[GitHub Pages veröffentlichen](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
