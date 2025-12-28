# Features

## Implemented
- AnimeUnity browsing: latest, popular, search, details, episodes
- Archivio page with filters, search, and infinite scroll
- Video playback (Meedu player)
- Picture-in-picture button (Android + iOS)
- Dark / Light themes
- Dynamic theme (supported platforms)
- OTA updates (Android only)
- Backup / Restore ObjectBox database
- Themed Android icon (adaptive icon)

## Partially implemented
- PiP auto-switch on background is disabled in code. Only manual button entry is enabled.

## Not implemented
- Chromecast / AirPlay UI (flutter_video_cast is included but not used in app UI)

## Known warnings
- file_picker platform warnings appear in CI but do not block builds.
- Some third_party plugins use deprecated Android/iOS APIs.
