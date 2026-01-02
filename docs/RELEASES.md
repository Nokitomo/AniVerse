# Release e OTA

## Tagging
Le release sono create dai tag git:
- Formato tag: vX.Y.Z (esempio: v1.1.13)
- Il push del tag avvia i workflow iOS e Android.

## Naming GitHub release
Il CI usa il nome del tag come titolo release:
- Release v1.1.13

## Aggiornamenti Android (OTA)
L'app controlla releases/latest e si aspetta:
- Titolo release che inizi con "Release vX.Y.Z"
- Asset APK nominato: app-release.apk

L'URL di update viene costruito come:
- https://github.com/Nokitomo/AniVerse/releases/download/vX.Y.Z/app-release.apk

Se il titolo release o il nome asset cambiano, l'OTA fallira.

## Aggiornamenti iOS (LiveContainer)
Per iOS non e' possibile aggiornare l'app in modo automatico. Il flusso supportato e':
- L'app scarica il file IPA dalla release.
- L'utente apre l'IPA con LiveContainer e installa la nuova versione.

Asset richiesto:
- AniVerse-unsigned.ipa

URL usato dall'app:
- https://github.com/Nokitomo/AniVerse/releases/download/vX.Y.Z/AniVerse-unsigned.ipa

## Aggiornamenti Windows (MSIX)
L'update automatico richiede installazione tramite file App Installer.

Asset richiesti:
- AniVerse.msix
- AniVerse.appinstaller

URL usato dall'app per l'installer:
- https://github.com/Nokitomo/AniVerse/releases/latest/download/AniVerse.appinstaller

## Aggiornamenti Linux (AppImage)
L'update automatico usa AppImage + zsync.

Asset richiesti:
- AniVerse-x86_64.AppImage
- AniVerse-x86_64.AppImage.zsync

URL usato dall'app per il download:
- https://github.com/Nokitomo/AniVerse/releases/latest/download/AniVerse-x86_64.AppImage
