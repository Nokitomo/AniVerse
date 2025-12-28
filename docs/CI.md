# CI

Workflows live in .github/workflows.

## android-release.yml
- Trigger: push tags matching v*
- Builds signed release APK
- Uploads artifact
- Publishes GitHub release (tag runs only)

Required secrets:
- ANDROID_KEYSTORE_BASE64
- ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_ALIAS
- ANDROID_KEY_PASSWORD

The keystore is decoded to:
- android/app/upload-keystore.jks

## ios-unsigned.yml
- Trigger: push tags matching v*
- Builds unsigned iOS app
- Packages IPA
- Uploads artifact
- Publishes GitHub release (tag runs only)

## Manual runs
If you run a workflow manually (workflow_dispatch), it only uploads artifacts.
Release publishing only happens on tag runs.
