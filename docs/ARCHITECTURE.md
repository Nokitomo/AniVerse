# Architecture

## Overview
AniVerse is a Flutter app that scrapes AnimeUnity and plays episodes using a custom video player (Meedu).
State and navigation are handled with GetX. Local persistence is handled with ObjectBox.

## Key modules
- lib/helper/api.dart: AnimeUnity HTTP requests, parsing, and episode/stream URL resolution.
- lib/helper/classes/anime_obj.dart: model mapping and image URL normalization.
- lib/services/internal_api.dart: app settings, version lookup, database import/export.
- lib/services/internal_db.dart + lib/objectbox.g.dart: ObjectBox initialization and models.
- lib/ui/pages: screens (home, details, settings, player, transition).
- lib/ui/widgets: UI fragments and player widgets.
- third_party/flutter_meedu_videoplayer: embedded video player with PiP support.

## Data flow
1) UI requests data via api.dart (latest, popular, search, details, episodes, stream url).
2) api.dart fetches AnimeUnity HTML/JSON and returns normalized models.
3) UI renders lists and details, and stores progress in ObjectBox.
4) Player page builds Meedu controller and plays network stream URL.
5) Settings page reads/writes local preferences and can perform OTA updates (Android only).

## State management
- GetX controllers and Rx values are used for UI state and dialogs.
- ObjectBox stores watch progress and last seen episode index.

## Video player
- PlayerPage uses MeeduPlayerController (lib/ui/widgets/player.dart).
- PiP is enabled and button is visible. Auto PiP on background is disabled in code.
- Fullscreen is forced on load.

## Third-party overrides
Several packages are overridden in third_party/ to keep compatibility with Flutter/Android tooling.
See pubspec.yaml for the override list.
