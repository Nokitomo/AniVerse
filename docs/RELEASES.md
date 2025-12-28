# Release e OTA

## Tagging
Le release sono create dai tag git:
- Formato tag: vX.Y.Z (esempio: v1.1.13)
- Il push del tag avvia i workflow iOS e Android.

## Naming GitHub release
Il CI usa il nome del tag come titolo release:
- Release v1.1.13

## Aggiornamenti OTA (solo Android)
L'app controlla releases/latest e si aspetta:
- Titolo release che inizi con "Release vX.Y.Z"
- Asset APK nominato: app-release.apk

L'URL di update viene costruito come:
- https://github.com/Nokitomo/AniVerse/releases/download/vX.Y.Z/app-release.apk

Se il titolo release o il nome asset cambiano, l'OTA fallira.
