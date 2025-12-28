# API (AnimeUnity)

AniVerse uses AnimeUnity public endpoints and HTML parsing.
Base hosts:
- https://www.animeunity.so (primary)
- https://animeunity.so (used for home page widgets)

Default headers:
- Accept: application/json
- User-Agent: iPhone Safari string

## Session handling
Some endpoints require XSRF and session cookies.
api.dart obtains cookies from the home page and builds headers:
- X-XSRF-TOKEN
- Cookie: XSRF-TOKEN, animeunity_session

## Endpoints used
- Home latest: GET https://animeunity.so/
  Parses <layout-items items-json="...">

- Popular: GET https://www.animeunity.so/top-anime?popular=true
  Parses <top-anime animes="...">

- Search (two-step):
  1) POST https://www.animeunity.so/livesearch (x-www-form-urlencoded)
  2) POST https://www.animeunity.so/archivio/get-animes (JSON body)

- Episodes list:
  GET https://www.animeunity.so/info_api/{animeId}/
  GET https://www.animeunity.so/info_api/{animeId}/1?start_range=X&end_range=Y

- Stream URL resolution:
  GET https://www.animeunity.so/embed-url/{episodeId}
  Follow Location or body to get embed page URL
  Parse window.downloadUrl or direct mp4/m3u8 URL from HTML

## Image URL normalization
Some covers return animeworld.so locandine URLs.
anime_obj.dart maps these to AnimeUnity CDN:
- https://img.animeunity.so/anime/<filename>

## Error behavior
api.dart throws exceptions when a request returns empty body or non-2xx.
Callers show an error page and allow navigation back.
