# XyCloudStore native streaming

The Android APK includes Moonlight Android v12.1 as an Android **library**, not as an external installed application. Its GameStream control/pairing, JNI transport, MediaCodec video decoder, audio decoder, mouse/keyboard and virtual controller are used by an internal activity. XyCloudStore's application ID remains `id.xycloud.xycloud_order`.

## Licenses and corresponding source

The user authorized distribution of the integrated Android application under GPLv3. `app/LICENSE` and the in-app license screen contain the original GPL notice. Original upstream source/copyright notices are retained. The separate Worker backend is not linked into the APK.

`native/moonlight.lock.json` pins Moonlight and its submodule revisions. The release publishes `XyCloudStore-2.5.0-source.zip`, including:
- Flutter application, locked package versions, native adapter and build scripts;
- the full pinned Moonlight Java/C/JNI/resource tree and submodules;
- source archives matching the prebuilt OpenSSL 1.1.1q / Opus 1.3 libraries;
- source archives for native-module Maven dependencies and Shield controller extension.

OpenSSL, Opus, Android/Flutter and other dependencies retain their own licenses. This project does not claim to be an official Moonlight release.

## Build

Use Flutter 3.24.5, Java 17, Android SDK 34+, NDK 23.2.8568313:

```sh
cd app
flutter create . --platforms=android --org id.xycloud --project-name xycloud_order
flutter pub get
cd ..
python3 tools/siapkan_streaming.py
python3 tools/patch_manifest.py app/android/app/src/main/AndroidManifest.xml
cd app
flutter build apk --release
```

Use the checked-in GitHub workflow for icons, OneSignal's Kotlin version, signing and ABI splits. The build helper is required because `app/android/` is generated, not checked in. For offline rebuilds from the released source archive, copy `third_party/moonlight` into `.cache/moonlight` and use `python3 tools/siapkan_streaming.py --offline`. Dependencies must already be present in your SDK/package caches. Sign rebuilt APKs with your own key; private release signing keys and backend credentials are deliberately not distributed.

## Integration modifications

The helper adds a function-key input bridge, limits the otherwise-unbounded pairing read timeout to 90 seconds, sets a distinct client pairing name using the generated client ID, and links with 16 KiB page alignment. The native library manifest has **no Moonlight launcher activity**. Streaming is launched through `XyGameActivity` from `SesiScreen` in the same APK.

Initial pairing pins the server certificate. App-to-worker authentication stays in Flutter's authenticated API client; no admin/agent key or Sunshine web-UI password is embedded in the APK. Sunshine administration stays localhost-only on the host PC. GameStream uses its own ports, not the Sunshine web-admin port 47990.

Successful compilation does not prove that a particular VM has a usable display, GPU/encoder or open streaming ports. Those need a real phone-to-host test.
