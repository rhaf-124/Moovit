# VIPGo — Android release guide

Application ID: **`com.vipgo.app`** (was `com.moovit.busticketing`)
Firebase project: `busticketing-8a775`
CI: Codemagic (`codemagic.yaml`)

---

## 1. Firebase — done

The rename needed a **new Android app inside the existing project**, not a new
project. Service-account credentials are project-scoped, so the backend's
`FIREBASE_CREDENTIALS_JSON` / `FIREBASE_CREDENTIALS_PATH` did not change.

Registered and wired:

| | |
| --- | --- |
| Project | `busticketing-8a775` (number `96693944842`) |
| App nickname | `VipoGo` |
| Package | `com.vipgo.app` |
| App ID | `1:96693944842:android:8867372d07ebf03d1595f3` |

- `android/app/google-services.json` — fresh download, contains both Android clients
- `lib/firebase_options.dart` — `android.appId` points at the new app
- `firebase.json` — same

`flutterfire configure` times out on this network (`Found 0 Firebase projects`), so
these were set by hand and cross-checked against `google-services.json`. If you run
`flutterfire configure` later from a network that reaches Firebase, it will
regenerate the same values.

Still worth doing:

1. Add the two SHA fingerprints from §2 to the `VipoGo` app in Firebase. Not needed
   for plain FCM, but required if you ever add Google Sign-In, phone auth,
   Dynamic Links or App Check.
2. Delete the old `com.moovit.busticketing` Android app once a `com.vipgo.app`
   build is verified on a device.
3. Clear stale push tokens — every `users.fcm_token` in the DB was issued to the
   old package and can never be delivered to again:
   ```sql
   UPDATE users SET fcm_token = NULL;
   ```

> The iOS app is intentionally still `com.moovit.busticketing`. Changing it means a
> new App Store record and a new Firebase iOS client, so it is a separate decision.

## 2. Signing

Release signing material is read by `android/app/build.gradle.kts` from, in order:

| Source | Used by |
| --- | --- |
| `android/key.properties` | local builds (gitignored) |
| `CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD` | Codemagic |

If neither is present the release build falls back to the **debug** key and prints a
warning — such an APK runs but cannot be uploaded to Play.

**Upload key** — `vipgo-upload.jks`, alias `vipgo-upload`, RSA 2048 / SHA256withRSA,
`CN=VIPGo, O=VIPGo Ltd, C=GH`, valid until **13 Jan 2054** (Play requires validity
past 22 Oct 2033 ✓):

```
SHA-1:   07:68:82:CA:E4:46:9D:E5:22:57:83:E7:F9:D1:19:B0:79:6E:23:5B
SHA-256: 98:CF:AE:07:49:CE:BF:84:1D:2E:6A:A9:3B:62:4E:F0:2C:EF:FC:36:0E:1E:20:14:A9:EB:B1:82:91:2E:F1:02
```

The debug keystore (`~/.android/debug.keystore`, alias `androiddebugkey`,
password `android`) is also trusted by `assetlinks.json` so App Links verify on
debug builds:

```
SHA-256: E2:D0:19:38:B6:7A:EF:4F:00:C7:FC:21:17:EA:08:44:6B:9E:3E:72:4F:3F:C4:9B:49:E1:84:53:F2:68:1A:A0
```

Re-read any fingerprint with:

```bash
keytool -list -v -keystore vipgo-upload.jks -alias vipgo-upload
```

The password is in `android/key.properties`, which is gitignored and exists only on
this machine.

> **Back up `vipgo-upload.jks` and its password somewhere off this machine.**
> Losing both means you can never ship an update under this upload key without a
> Play support key reset.

The previous `moovit-release.jks` was replaced on 28 Aug 2026 (brand rename) and is
kept as `moovit-release.jks.archived`. It never signed a published release, so it is
safe to delete once a `vipgo-upload.jks` build is verified on a device.

### Codemagic setup

Teams → Integrations → **Code signing identities** → *Android keystores* → upload
`vipgo-upload.jks`, enter the keystore password, alias `vipgo-upload` and key
password, and name the reference **`vipgo_keystore`** — that exact string is what
`codemagic.yaml` attaches via `android_signing`.

---

## 3. What is in the release build

| Item | Where |
| --- | --- |
| Launcher icon (legacy 48→192 px) | `android/app/src/main/res/mipmap-*/ic_launcher.png` |
| Adaptive icon (Android 8+) | `mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_foreground.png` + `@color/ic_launcher_background` |
| Play listing icon (512 px, opaque) | `store/play_store_icon_512.png` |
| Material Components themes | `res/values/styles.xml`, `res/values-night/styles.xml` |
| R8 shrink + obfuscate + resource shrink | `buildTypes.release` in `android/app/build.gradle.kts` |
| R8 keep rules | `android/app/proguard-rules.pro` |
| Multidex | `defaultConfig.multiDexEnabled = true` |
| Backup / transfer rules | `res/xml/data_extraction_rules.xml` (nothing is backed up) |

Icons are regenerated — only if `assets/images/VIPGo.png` changes — with:

```bash
flutter pub get && dart run flutter_launcher_icons
```

---

## 4. Building

```bash
# Play upload artifact
flutter build appbundle --release

# Directly installable, for QA
flutter build apk --release --split-per-abi
```

Outputs:

- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-<abi>-release.apk`
- `build/app/outputs/mapping/release/mapping.txt` ← keep this, see §7

### On Codemagic

| Workflow | Trigger | Produces |
| --- | --- | --- |
| `android-apk-testing` | push / PR to `main` | signed split APKs |
| `android-aab-release` | pushing a tag matching `v*` | signed `.aab` + universal APK |

Cut a release with:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

The tag drives `--build-name`; `--build-number` comes from Codemagic's
monotonic `$PROJECT_BUILD_NUMBER`.

---

## 5. Publishing to Google Play

1. Play Console → **Create app** → package `com.vipgo.app` (permanent — cannot be changed).
2. Keep **Play App Signing** enabled (default). Your `vipgo-upload.jks` becomes the
   *upload* key; Google holds the app signing key.
3. Upload the `.aab` to **Internal testing** first.
4. After the first upload, copy the **app signing certificate SHA-256** from
   *Release → Setup → App signing* and add it to:
   - Firebase (§1, step 5) — otherwise FCM/phone auth break for Play-installed builds
   - `https://bus-ticketing-backend-u0e3.onrender.com/.well-known/assetlinks.json` —
     otherwise the verified App Links in the manifest silently fall back to a
     browser chooser. The file must list package `com.vipgo.app` and **both** the
     upload and the Play app-signing SHA-256.
5. Complete the Play declarations before promoting to production:
   - Data safety (you collect location, camera images, and account identifiers)
   - Privacy policy URL (required — you request location)
   - Target audience & content rating
   - Prominent-disclosure for `ACCESS_FINE_LOCATION` if used outside the foreground
6. Store listing assets: `store/play_store_icon_512.png`, a 1024×500 feature graphic,
   and at least 2 phone screenshots.

---

## 6. Version numbers

`pubspec.yaml`:

```yaml
version: 1.0.0+1
#        ^^^^^ versionName (user-visible)
#              ^ versionCode (must strictly increase per Play upload)
```

CI overrides both with `--build-name` / `--build-number`, so for CI releases the
only thing you edit is the **git tag**. For a local upload, bump the `+N` yourself —
Play rejects a bundle whose versionCode is not higher than the last one uploaded.

---

## 7. Release FAQ / troubleshooting

**A feature works in debug but crashes or silently no-ops in release.**
Almost always R8 stripping a reflectively-loaded class. Reproduce with
`flutter build apk --release` and read the trace after deobfuscating:

```bash
$ANDROID_SDK_ROOT/tools/proguard/bin/retrace.sh \
  build/app/outputs/mapping/release/mapping.txt stacktrace.txt
```

Then add a `-keep` line to `android/app/proguard-rules.pro`. The QR scanner
(ML Kit), FCM and local notifications are the likely candidates and already have
rules. To rule R8 out quickly, flip `isMinifyEnabled`/`isShrinkResources` to
`false` in `build.gradle.kts` and rebuild.

**Play Console shows "deobfuscation file missing".**
Upload `build/app/outputs/mapping/release/mapping.txt` under
*Release → App bundle explorer → Downloads*. Codemagic archives it as a build artifact.

**"No matching client found for package name 'com.vipgo.app'".**
`google-services.json` predates the rename — do §1.

**App Links open in the browser instead of the app.**
`assetlinks.json` is missing the Play app-signing SHA-256 (§5.4). Verify with:
```bash
adb shell pm get-app-links com.vipgo.app
```

**Notifications never arrive on Android 13+.**
`POST_NOTIFICATIONS` is declared in the manifest but is a *runtime* permission —
the app must request it. Check the FCM init path in `lib/core/notifications/`.

**The release APK installs but the old one won't upgrade.**
Expected: `com.vipgo.app` is a different application ID from
`com.moovit.busticketing`. Users of the old build must uninstall it. Since the old
ID was never published, this only affects sideloaded test devices.

**Release build is signed with the debug key.**
`android/key.properties` is missing or `storeFile` points at a path that does not
exist. The build logs `WARNING: no release keystore found`.
