# CI

I workflow si trovano in .github/workflows.

## android-release.yml
- Trigger: push di tag che matchano v*
- Compila APK release firmato
- Carica artifact
- Pubblica GitHub release (solo run su tag)

Secret richieste:
- ANDROID_KEYSTORE_BASE64
- ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_ALIAS
- ANDROID_KEY_PASSWORD

Il keystore viene decodificato in:
- android/app/upload-keystore.jks

## ios-unsigned.yml
- Trigger: push di tag che matchano v*
- Compila app iOS non firmata
- Pacchettizza IPA
- Carica artifact
- Pubblica GitHub release (solo run su tag)

## windows-msix.yml
- Trigger: push di tag che matchano v*
- Compila Windows release
- Crea MSIX e App Installer
- Firma MSIX con PFX
- Carica artifact
- Pubblica GitHub release (solo run su tag)

Secret richieste:
- WINDOWS_PFX_BASE64
- WINDOWS_PFX_PASSWORD


## Esecuzioni manuali
Se esegui un workflow manualmente (workflow_dispatch), carica solo gli artifact.
La pubblicazione release avviene solo con i tag.
