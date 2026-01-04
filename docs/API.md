# API (AnimeUnity)

AniVerse usa endpoint pubblici AnimeUnity e parsing HTML.
Host base:
- https://www.animeunity.so (principale)
- https://animeunity.so (usato per i widget home)

Header di default:
- Accept: application/json
- User-Agent: stringa iPhone Safari

## Gestione sessione
Alcuni endpoint richiedono cookie XSRF e sessione.
api.dart ottiene i cookie dalla home e costruisce gli header:
- X-XSRF-TOKEN
- Cookie: XSRF-TOKEN, animeunity_session

## Endpoint usati
- Ultimi episodi in home: GET https://animeunity.so/
  Esegue parsing di <layout-items items-json="...">
  Supporta paginazione con parametro page (es. /?page=2).

- Top anime / Popolari: GET https://www.animeunity.so/top-anime?popular=true
  Esegue parsing di <top-anime animes="...">
  Supporta parametri: status, type, order, popular, page.

- Calendario: GET https://www.animeunity.so/calendario
  Esegue parsing di <calendario-item a="..."> e decode HTML dell'attributo.

- Archivio meta: GET https://www.animeunity.so/archivio?hidebar=true
  Legge gli attributi <archivio> per all_genres, anime_oldest_date, tot_count.

- Archivio lista: POST https://www.animeunity.so/archivio/get-animes
  Body JSON: title, type, year, order, status, genres, offset, dubbed, season.
  Ritorna records[] e tot.

- Ricerca (due step):
  1) POST https://www.animeunity.so/livesearch (x-www-form-urlencoded)
  2) POST https://www.animeunity.so/archivio/get-animes (JSON)

- Lista episodi:
  GET https://www.animeunity.so/info_api/{animeId}/
  GET https://www.animeunity.so/info_api/{animeId}/1?start_range=X&end_range=Y

- Risoluzione URL stream:
  GET https://www.animeunity.so/embed-url/{episodeId}
  Segue Location o body per ottenere l'embed URL
  Parse di window.downloadUrl o URL mp4/m3u8 dall'HTML

- Banner per carosello Home:
  GET https://www.animeunity.so/anime/{animeId}-{slug}
  Parse dell'attributo `anime` dentro il tag `video-player`
  Campo usato: `imageurl_cover` (puo' essere vuoto se il banner non e' disponibile)

## Normalizzazione URL immagini
Alcune cover usano locandine animeworld.so.
anime_obj.dart le mappa al CDN AnimeUnity:
- https://img.animeunity.so/anime/<filename>

## Comportamento errori
api.dart lancia eccezioni su risposta vuota o non-2xx.
I chiamanti mostrano una pagina di errore e consentono il ritorno indietro.

# API (StreamingCommunity) - Integrazione in corso

AniVerse include un helper dedicato per StreamingCommunity in `lib/helper/streamingcommunity_api.dart`.
La sezione Film/Serie TV usa una WebView per navigare il sito (non usa gli endpoint API in UI).

## Dominio dinamico
- Fonte domini: https://raw.githubusercontent.com/Arrowar/SC_Domains/refs/heads/main/domains.json
- Chiave letta: `streamingcommunity.full_url`
- Cache locale: 12 ore (SharedPreferences)
- Fallback: se la home risponde 403 si prova il `old_domain` (stesso host con TLD precedente).

## Endpoint usati
- Home payload (Inertia):
  GET {base}/
  Parse di `data-page` per `version`, `sliders`, `slideBanners`, `genres`, `cdn_url`, `scws_url`.
  Se il server risponde 403, viene usata una WebView nascosta con fetch JS per ottenere l'HTML o il `data-page`.

- Slider Home (API):
  GET {base}/api/browse/{slider_name}
  Slider disponibili (home): `trending`, `latest`, `top10`.
  Fallback WebView con fetch JS in caso di 403.

- Ricerca (API):
  GET {base}/api/search?q=...&page=...
  Risposta paginata con `data`, `current_page`, `last_page`, `per_page`, `total`.
  Fallback WebView con fetch JS in caso di 403.

- Archivio (API):
  GET {base}/api/archive?...
  Risposta con `titles` (nessuna paginazione osservata nei test).
  Fallback WebView con fetch JS in caso di 403.

- Preview titolo (API):
  POST {base}/api/titles/preview/{id}
  Risposta con plot/genres/images e metadata base.
  Fallback WebView con fetch JS in caso di 403.

- Dettaglio titolo (Inertia):
  GET {base}/it/titles/{id}-{slug}
  Parse di `title`, `seasons`, `loadedSeason` (episodi stagione attiva).
  Fallback WebView con fetch JS se risposta 403.

- Episodi stagione (Inertia):
  GET {base}/it/titles/{id}-{slug}/season-{num}
  Header richiesti: `X-Inertia: true`, `X-Inertia-Version`.
  Fallback WebView con fetch JS se risposta 403.

- Iframe stream:
  GET {base}/it/iframe/{title_id}?episode_id=...&next_episode=1
  Parse di `iframe src` verso `vixcloud`.
  Fallback WebView con fetch JS in caso di 403.

- Stream URL (Vixcloud):
  GET iframe URL
  Parse `window.masterPlaylist` o URL `m3u8` diretto.
  Fallback WebView con fetch JS in caso di 403.

- Video info (API):
  GET {base}/api/video/{video_id}
  Metadata su qualita' e track video.
  Fallback WebView con fetch JS in caso di 403.
