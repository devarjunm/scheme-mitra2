# Android release checklist

This directory contains a Flutter Android app project and release signing *configuration*. It does not contain a signing key, production URL, Play Console entry, verified catalog publication, or a built AAB. Do not treat the project files as evidence that an app has been signed, tested on real devices, or published.

## Before a release build

1. Install Flutter 3.47 or newer and a JDK 17 toolchain. Install Android SDK Platform 36 and the matching build tools. Run `flutter doctor` and resolve every Android toolchain issue.
2. Confirm that `org.schememitra.app` is available to, and controlled by, the actual Play developer account. It is a code default, not proof of ownership; the application ID becomes a durable Play identity after first publication.
3. Deploy the API behind HTTPS and complete database, Redis, monitoring, backup/restore, privacy/support contact, deletion-retention, admin access and scheme-review operations. Use the public API origin only; it is configuration, not a secret.
4. Create the upload key in a secure environment, enroll in Play App Signing, and keep an encrypted, access-controlled offline backup of the key and recovery material. Never send the signing key or passwords to this repository or a chat.

Example upload-key creation (run privately, after the organization has chosen a key owner):

```sh
keytool -genkey -v -keystore android/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
# Edit android/key.properties with the matching passwords and alias.
```

`android/key.properties` and `android/upload-keystore.jks` are ignored by Git. The Gradle release task deliberately fails if the operator-owned keystore is missing. Do not use a debug key for Play uploads. A lost upload key requires the Play Console recovery process; a lost app-signing key can be irreversible if not managed through Play App Signing.

## Build the signed app bundle

From `mobile/`:

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.org
```

Replace the example with the actual production HTTPS origin. Never put a password, API secret, private signing material, or an internal-only host in `--dart-define`. The app refuses to start if the API origin is missing/invalid and rejects HTTP/local origins in release mode.

Expected Flutter output: `mobile/build/app/outputs/bundle/release/app.aab`.

Increment the `+buildNumber` in `pubspec.yaml` for every uploaded build. Test the signed AAB through Play internal testing or `bundletool` on real devices before a staged rollout.

## Current Play requirements to re-check at submission

- Google Play's current help page says new mobile apps and app updates must target Android 16, API 36 or higher from **31 August 2026**. This project currently sets both `compileSdk` and `targetSdk` to 36; re-check the policy and SDK/Play warnings at the time of upload: <https://support.google.com/googleplay/android-developer/answer/11926878?hl=en>.
- The current new-personal-account testing help page says personal developer accounts created after 13 November 2023 need at least **12 testers continuously opted into a closed test for 14 days** before applying for production access. This is account-specific; verify the actual Play Console workflow and eligibility: <https://support.google.com/googleplay/android-developer/answer/14151465?hl=en>.

## Still required outside this repository

Play Console account and app registration, approved final application ID, Play App Signing enrollment, signed AAB, store listing and localized screenshots/feature graphic, data-safety answers, content rating, privacy-policy URL, support contact, app-access instructions, test-track setup, accessibility/security/device testing, incident/backup ownership, and real pilot evidence. No government partnership or pilot outcome is asserted by the app.
