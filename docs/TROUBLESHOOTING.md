# Risoluzione problemi

## Android CI: keystore non trovato
Se vedi:
- Keystore file ... not found
Verifica che ANDROID_KEYSTORE_BASE64 sia impostata e che key.properties usi storeFile=upload-keystore.jks.

## Android CI: Java heap space
Aumenta la heap Gradle in android/gradle.properties:
- org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g

## Warning file_picker
Il pacchetto file_picker mostra warning per le piattaforme desktop.
Sono rumorosi ma non fatali per build Android/iOS.

## Desktop build: errori file_picker default_package
Se la build desktop fallisce con errori su "default_package" in file_picker,
assicurati che il plugin desktop sia registrato con `dartPluginClass`
in `third_party/file_picker/pubspec.yaml`.

## Windows build: ffmpeg-6.dll mancante (fvp)
Se la build Windows fallisce con un errore su `ffmpeg-6.dll` dentro `mdk-sdk`,
assicurati che il download del SDK MDK sia completato o lascia che CMake lo
riscarichi automaticamente dalla URL indicata in `third_party/fvp/windows/CMakeLists.txt`.

## PiP non funziona su iOS
- Richiede iOS 14+.
- PiP si attiva solo tramite pulsante (auto PiP in background e disabilitato nel codice).
- Se PiP fallisce, verifica il supporto AVPictureInPictureController sul dispositivo.

## Streaming fallisce
- Gli endpoint AnimeUnity possono cambiare. Controlla docs/API.md.
- L'URL stream viene parsato dalla pagina embed (window.downloadUrl). Se l'HTML cambia, la riproduzione fallira.
