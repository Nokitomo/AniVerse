# Compilazione

## Prerequisiti
- Flutter (canale stable)
- Dart SDK incluso con Flutter
- Android SDK + JDK 17 per build Android
- Xcode per build iOS

## Android
1) Assicurarsi che la firma sia configurata:
   - android/key.properties (ignorato da git)
   - android/app/upload-keystore.jks

Esempio key.properties:
storeFile=upload-keystore.jks
storePassword=...
keyPassword=...
keyAlias=...

2) Build:
- Debug: flutter build apk --debug
- Release: flutter build apk --release

Output:
- build/app/outputs/flutter-apk/app-release.apk

Note:
- La build debug usa applicationId con suffisso ".debug" e nome app "AniVerse Debug".

## iOS (non firmato)
1) Installare i pod:
- cd ios && pod install --repo-update

2) Build (no codesign):
- flutter build ios --release --no-codesign

3) Pacchettizzare IPA (manuale):
- mkdir -p build/ios/ipa/Payload
- cp -R build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
- cd build/ios/ipa && zip -r AniVerse-unsigned.ipa Payload

## Desktop (Windows / macOS / Linux)
Prerequisiti: abilitare il target desktop in Flutter.
- flutter config --enable-windows-desktop
- flutter config --enable-macos-desktop
- flutter config --enable-linux-desktop

Build:
- Windows: flutter build windows --release
- macOS: flutter build macos --release
- Linux: flutter build linux --release

## Windows MSIX (Auto Update)
Prerequisiti:
- Windows SDK (MakeAppx + SignTool)
- Certificato di firma (PFX)

Build MSIX (workflow consigliato in CI):
1) flutter build windows --release
2) Genera MSIX e firma con certificato PFX
3) Genera file AniVerse.appinstaller e pubblicalo su GitHub Release

Nota: l'update automatico funziona solo se l'app e' installata tramite
il file .appinstaller.
Ricorda di aggiornare `msix_version` in `pubspec.yaml` quando cambi versione.

## Linux AppImage (Auto Update)
Prerequisiti:
- appimage-builder installato

Build AppImage:
1) flutter build linux --release
2) appimage-builder --recipe AppImageBuilder.yml
3) Pubblica AniVerse-x86_64.AppImage e AniVerse-x86_64.AppImage.zsync su GitHub Release
Ricorda di aggiornare `AppImageBuilder.yml` con la versione corretta.

## Note
- Le build iOS non sono firmate. Usare tool di sideload dopo la build.
- Il minSdk Android e legato alla configurazione Flutter e ai vincoli NDK.
