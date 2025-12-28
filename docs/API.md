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

## Normalizzazione URL immagini
Alcune cover usano locandine animeworld.so.
anime_obj.dart le mappa al CDN AnimeUnity:
- https://img.animeunity.so/anime/<filename>

## Comportamento errori
api.dart lancia eccezioni su risposta vuota o non-2xx.
I chiamanti mostrano una pagina di errore e consentono il ritorno indietro.
