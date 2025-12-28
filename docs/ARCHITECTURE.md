# Architettura

## Panoramica
AniVerse e una app Flutter che fa scraping di AnimeUnity e riproduce episodi con un player personalizzato (Meedu).
Stato e navigazione sono gestiti con GetX. La persistenza locale usa ObjectBox.

## Moduli principali
- lib/helper/api.dart: richieste HTTP ad AnimeUnity, parsing e risoluzione URL episodi/stream.
- lib/helper/classes/anime_obj.dart: mapping modelli e normalizzazione URL immagini.
- lib/services/internal_api.dart: impostazioni app, lettura versione, import/export database.
- lib/services/internal_db.dart + lib/objectbox.g.dart: inizializzazione ObjectBox e modelli.
- lib/ui/pages: schermate (home, esplora, calendario, archivio, dettagli, impostazioni, player, transizioni).
- lib/ui/widgets: componenti UI e widget del player.
- third_party/flutter_meedu_videoplayer: player integrato con supporto PiP.

## Flusso dati
1) La UI richiede dati tramite api.dart (ultimi, popolari, ricerca, dettagli, episodi, stream url).
2) api.dart recupera HTML/JSON da AnimeUnity e restituisce modelli normalizzati.
3) La UI renderizza liste e dettagli, e salva i progressi in ObjectBox.
4) La pagina player crea il controller Meedu e riproduce lo stream.
5) La pagina impostazioni legge/scrive preferenze locali e puo eseguire OTA (solo Android).

## Gestione stato
- GetX controllers e valori Rx sono usati per stato UI e dialog.
- ObjectBox salva progresso visione e ultimo episodio visto.

## Video player
- PlayerPage usa MeeduPlayerController (lib/ui/widgets/player.dart).
- PiP e abilitato e il pulsante e visibile. Auto PiP in background e disabilitato nel codice.
- Fullscreen forzato al caricamento.

## Override third-party
Diversi pacchetti sono sovrascritti in third_party/ per mantenere compatibilita con Flutter/Android.
Vedi pubspec.yaml per la lista degli override.
