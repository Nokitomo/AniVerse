# Troubleshooting

## Android CI: keystore not found
If you see:
- Keystore file ... not found
Check that ANDROID_KEYSTORE_BASE64 is set and key.properties uses storeFile=upload-keystore.jks.

## Android CI: Java heap space
Increase Gradle heap in android/gradle.properties:
- org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g

## file_picker warnings
The file_picker package logs default implementation warnings for desktop platforms.
These are noisy but not fatal for Android/iOS builds.

## PiP not working on iOS
- iOS 14+ required.
- PiP is invoked only by the PiP button (auto PiP on background is disabled in app code).
- If PiP still fails, verify AVPictureInPictureController support on the device.

## Streaming fails
- AnimeUnity endpoints may change. Check docs/API.md for current endpoints.
- Stream URL is parsed from embed page HTML (window.downloadUrl). If AnimeUnity changes HTML, playback will fail.
