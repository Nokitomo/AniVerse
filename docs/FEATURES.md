# Funzionalita

## Implementate
- Navigazione AnimeUnity: ultimi, popolari, ricerca, dettagli, episodi
- Pagina Archivio con filtri, ricerca, scroll infinito, filtri scorrevoli e header auto-hide
- Riproduzione video (player Meedu)
- Pulsante picture-in-picture (Android + iOS)
- Tema chiaro / scuro
- Tema dinamico (piattaforme supportate)
- Aggiornamenti OTA (solo Android)
- Backup / Ripristino database ObjectBox
- Icona Android tematizzata (adaptive icon)

## Parzialmente implementate
- Auto PiP in background disabilitato nel codice. Solo attivazione manuale.

## Non implementate
- UI Chromecast / AirPlay (flutter_video_cast e incluso ma non usato nella UI)

## Warning noti
- file_picker genera warning in CI ma non blocca le build.
- Alcuni plugin in third_party usano API Android/iOS deprecate.
