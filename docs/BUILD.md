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

## Note
- Le build iOS non sono firmate. Usare tool di sideload dopo la build.
- Il minSdk Android e legato alla configurazione Flutter e ai vincoli NDK.
