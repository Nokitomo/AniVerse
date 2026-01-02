# Funzionalita

## Implementate
- Navigazione AnimeUnity: ultimi, popolari, ricerca, dettagli, episodi
- Lista episodi con selezione range (blocchi da 120)
- Header dettagli con controlli episodio fissi e compatti durante lo scroll
- Descrizione con link "Leggi tutto" nella scheda dettaglio
- Refresh automatico dello stream al primo errore del player
- Messaggio in player quando lo stream e' temporaneamente non disponibile
- Pagina Archivio con filtri, ricerca, scroll infinito, filtri scorrevoli e header auto-hide
- Pagina Esplora con sezioni tematiche (top-anime e categorie archivio)
- Pagina Calendario con programmazione per giorno
- Riproduzione video (player Meedu)
- Sezione "Riprendi a guardare" mostra episodio e progresso
- Pulsante picture-in-picture (Android + iOS)
- Tema chiaro / scuro
- Tema dinamico (piattaforme supportate)
- Aggiornamenti OTA (solo Android)
- Backup / Ripristino database ObjectBox
- Icona Android tematizzata (adaptive icon)
- Supporto desktop base (Windows / macOS / Linux)

## Parzialmente implementate
- Auto PiP in background disabilitato nel codice. Solo attivazione manuale.

## Non implementate
- UI Chromecast / AirPlay (flutter_video_cast e incluso ma non usato nella UI)

## Warning noti
- file_picker genera warning in CI ma non blocca le build.
- Alcuni plugin in third_party usano API Android/iOS deprecate.
- Aggiornamenti OTA disponibili solo su Android (iOS via download IPA).
- Export database su desktop salva in Download (fallback Documenti se Download non disponibile).
