# Build

## Prerequisites
- Flutter (stable channel)
- Dart SDK from Flutter
- Android SDK + JDK 17 for Android builds
- Xcode for iOS builds

## Android
1) Ensure signing is configured:
   - android/key.properties (ignored by git)
   - android/app/upload-keystore.jks

Example key.properties:
storeFile=upload-keystore.jks
storePassword=...
keyPassword=...
keyAlias=...

2) Build:
- Debug: flutter build apk --debug
- Release: flutter build apk --release

Output:
- build/app/outputs/flutter-apk/app-release.apk

## iOS (unsigned)
1) Install pods:
- cd ios && pod install --repo-update

2) Build (no codesign):
- flutter build ios --release --no-codesign

3) Package IPA (manual):
- mkdir -p build/ios/ipa/Payload
- cp -R build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
- cd build/ios/ipa && zip -r AniVerse-unsigned.ipa Payload

## Notes
- iOS builds are unsigned. Use sideload tools after build.
- Android minSdk is tied to Flutter config and NDK constraints.
