# Android export

Presets live in `../export_presets.cfg`:

* **Android**: debug APK, no Gradle, arm64-v8a + armeabi-v7a + x86_64. Built and signature-verified
  in the cloud container. Not yet run on a device.
* **Android Release AAB**: Gradle build, AAB format, for Play. Needs a full Android SDK and the
  Gradle build template (Project > Install Android Build Template, which creates `android/build/`,
  ignored by Git). Not yet built.
* **Linux smoke test**: desktop export used to check the exported package starts cleanly.

Package id: `com.circuitgarden.puzzle` (placeholder, confirm before the first Play upload;
it can never change after that). Version code 1, version name 0.1.0. Portrait only, immersive
mode, no Android permissions requested.

Release signing reads `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` from the environment. Keep the keystore outside
the repo and back it up; with Play App Signing, this is your upload key.
