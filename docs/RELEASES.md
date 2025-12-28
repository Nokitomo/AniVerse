# Releases and OTA

## Tagging
Releases are created from git tags:
- Tag format: vX.Y.Z (example: v1.1.13)
- Pushing a tag triggers both iOS and Android workflows.

## GitHub release naming
The CI uses the tag name for the release title:
- Release v1.1.13

## OTA updates (Android only)
The app checks releases/latest and expects:
- Release title that starts with "Release vX.Y.Z"
- APK asset named: app-release.apk

The update URL is built as:
- https://github.com/Nokitomo/AniVerse/releases/download/vX.Y.Z/app-release.apk

If the release title or asset name changes, OTA will fail.
