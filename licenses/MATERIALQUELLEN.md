# Materialquellen — Abrissfirma

Stand: 16. Oktober 2026. Die vier fotografischen PBR-Sets stammen von Poly Haven. Alle hier verwendeten Texturdateien stehen unter [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Poly Haven erlaubt die Nutzung und Weitergabe auch in kommerziellen Spielen; siehe [offizielle Lizenz](https://polyhaven.com/license). Die Namensnennung erfolgt freiwillig. Keine gekauften Assets, keine KI-Konzeptbilder.

Pro Set werden nur Albedo, OpenGL-Normal und Roughness als 1024 × 1024 JPG verwendet. Die MD5-Werte wurden unmittelbar nach dem Download mit der offiziellen Datei-API verglichen. Dateiadressen und Pruefsummen stehen nachfolgend und in den kompakten *_source.json-Dateien.

| Material | Urheber | Originalbreite | Spielkachelung | Verwendung |
|---|---|---|---|---|
| [Painted Plaster Wall](https://polyhaven.com/a/painted_plaster_wall) | Amal Kumar | 2,0 m | 2,6 m | Fassade und Innenputz |
| [Concrete Wall 007](https://polyhaven.com/a/concrete_wall_007) | Charlotte Baglioni, Dario Barresi, Rico Cilliers | 2,2 m | 3,0 m | Beton, Sockel und Bruchkern |
| [Wood Floor](https://polyhaven.com/a/wood_floor) | Dimitrios Savva | 1,7 m | 2,0 m | Boden, Holz und Tueren |
| [Brick Wall 001](https://polyhaven.com/a/brick_wall_001) | Dimitrios Savva, Rob Tuytel | 3,0 m | 3,0 m | Freigelegtes Mauerwerk und Ziegelbruch |

## Painted Plaster Wall

- [painted_plaster_wall_diff_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/painted_plaster_wall/painted_plaster_wall_diff_1k.jpg) — MD5: `15ba8c1f63a5ab412b1eabe31728540a`
- [painted_plaster_wall_nor_gl_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/painted_plaster_wall/painted_plaster_wall_nor_gl_1k.jpg) — MD5: `43fff290583dbdfc9bfa088a2750e840`
- [painted_plaster_wall_rough_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/painted_plaster_wall/painted_plaster_wall_rough_1k.jpg) — MD5: `e076a6360329a2bc18c7397dc50c074a`

## Concrete Wall 007

- [concrete_wall_007_diff_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/concrete_wall_007/concrete_wall_007_diff_1k.jpg) — MD5: `f8a951200ebe1a42ba57ef331d94f8e2`
- [concrete_wall_007_nor_gl_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/concrete_wall_007/concrete_wall_007_nor_gl_1k.jpg) — MD5: `7d62088fb4f40833226cdb2a09476a58`
- [concrete_wall_007_rough_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/concrete_wall_007/concrete_wall_007_rough_1k.jpg) — MD5: `57fc45c0410543a5117bbfab360e040a`

## Wood Floor

- [wood_floor_diff_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/wood_floor/wood_floor_diff_1k.jpg) — MD5: `b7e927d2bf2f8f103820ff3890c8407c`
- [wood_floor_nor_gl_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/wood_floor/wood_floor_nor_gl_1k.jpg) — MD5: `620f174d2c09b579c5d02d37b2106668`
- [wood_floor_rough_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/wood_floor/wood_floor_rough_1k.jpg) — MD5: `36146634f1dbd1bc30cd071857584c10`

## Brick Wall 001

- [brick_wall_001_diffuse_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/brick_wall_001/brick_wall_001_diffuse_1k.jpg) — MD5: `955d2d4500eb549be0f2873305782798`
- [brick_wall_001_nor_gl_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/brick_wall_001/brick_wall_001_nor_gl_1k.jpg) — MD5: `be151875ed0897fc716aeef6daac8bd5`
- [brick_wall_001_rough_1k.jpg](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/brick_wall_001/brick_wall_001_rough_1k.jpg) — MD5: `618ceca60a4321aecc6d61eebe53d551`

## Verarbeitung und Leistungsrahmen

Die Quelldateien bleiben unveraendert. Farbton, Rauheit und Normalstaerke werden in Godots StandardMaterial3D angepasst. UVs werden in Weltkoordinaten triplanar projiziert, damit angrenzende Fassadensegmente keinen sichtbaren Textur-Neustart bekommen. Fuer bewegliche Truemmer kann die Projektion auf lokale Koordinaten umgestellt werden. Holzmaserung und Putzvarianten teilen sich Texturressourcen.

Sekundaermaterialien (Metall, Lack, Dachhaut und Fliesen) verwenden eigene deterministisch erzeugte 128-px-Detailkarten mit Albedo, Normal und Rauheit. Diese stellen keine fotografischen Scan-Materialien dar. Erde und Schotter verwenden die vorhandenen Beton-Scans mit beigem Farbton und stark reduzierter Normalstaerke; die Gruenflaeche verwendet dezent eingefaerbte Putzkoernung. Diese Ersatzoberflaechen koennen spaeter durch spezielle Boden-Assets ersetzt werden. Fensterglas verwendet einfache Transparenz ohne teure Brechung.

Es gibt kein Parallax Mapping, Tessellation oder Displacement. Die 12 Quellbilder belegen rund 7 MB als JPG; die GPU-Belegung haengt vom Godot-Importformat ab (unkomprimiert einschliesslich Mipmaps etwa 48–64 MiB). Triplanare PBR-Materialien brauchen mehr Texturzugriffe als einfache UV-Materialien. Konkrete Bildraten auf der GTX 1050 Ti muessen im laufenden Spiel gemessen werden.

Geprueft: GDScript-Prueflauf und Laufzeit-Erzeugung aller 25 Materialschluessel mit vorhandenen Albedo-, Normal- und Roughness-Maps. Dies ersetzt keine Sichtpruefung im Level.

