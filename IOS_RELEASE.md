# iOS Release & Push Notifications

Bundle ID: **`com.vipgo.app`** (was `com.moovit.busticketing`, renamed before the
first TestFlight upload — after that the bundle ID is permanently bound to the
App Store record and can never be changed).

Everything in section 1 is manual and one-time. Codemagic's `ios-testflight`
workflow handles certificates and profiles, but it **cannot** register an App ID
or enable a capability on one.

---

## 1. One-time Apple + Firebase setup

### 1.1 Register the App ID

Apple Developer → Certificates, Identifiers & Profiles → **Identifiers** → `+`

- Type: App IDs → App
- Bundle ID: **explicit**, `com.vipgo.app`
- Capabilities — tick both:
  - **Push Notifications**
  - **Associated Domains** (the deep links in `ios/Runner/Runner.entitlements`)

If the identifier already exists, edit it and make sure both are ticked. A
provisioning profile only carries `aps-environment` when the App ID had Push
Notifications enabled *at the time the profile was generated* — enabling it
later means the profile must be regenerated.

### 1.2 Create the APNs Auth Key

Firebase does not deliver to iPhones itself; it relays through Apple's APNs.
Without this key, `getToken()` on iOS fails with *"APNS token has not been set
yet"* and nothing is ever deliverable, no matter how correct the Dart code is.

Apple Developer → **Keys** → `+`

- Name: `VIPGo APNs`
- Enable **Apple Push Notifications service (APNs)**
- Download the `.p8`. **Apple allows this download exactly once, ever.** Store
  it somewhere durable and private — it is not in this repo and must not be.
- Note the **Key ID** (on the key page) and the **Team ID** (top-right of the
  portal).

Use a `.p8` key, not the legacy `.p12` certificates: one key covers both the
sandbox and production APNs environments and never expires, whereas certificates
are per-environment and expire annually.

### 1.3 Register the iOS app in Firebase

The Firebase project (`busticketing-8a775`) has an iOS client registered under
the *old* `com.moovit.busticketing` ID. A new one is needed:

Firebase Console → Project Settings → **Your apps** → Add app → iOS

- Bundle ID: `com.vipgo.app`
- Download `GoogleService-Info.plist`

Then regenerate the Dart config, which also drops the plist into `ios/Runner/`
and adds it to the Xcode project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure \
  --project=busticketing-8a775 \
  --ios-bundle-id=com.vipgo.app \
  --android-package-name=com.vipgo.app
```

Commit the regenerated `lib/firebase_options.dart` and the new
`ios/Runner/GoogleService-Info.plist`.

> **Windows gotcha.** Run from Windows, `flutterfire configure` writes the plist
> to `ios/Runner/` but cannot run the Ruby `xcodeproj` step that registers it
> with the Runner target — so the file sits on disk and never reaches the app
> bundle. It has already been wired into `project.pbxproj` by hand (file
> reference, Runner group, and the Resources build phase). **If you re-run
> `flutterfire configure`, check that `grep GoogleService-Info
> ios/Runner.xcodeproj/project.pbxproj` still returns four lines.** The
> `ios-testflight` workflow's final step catches this by inspecting the built
> bundle, but it costs you a full CI run to find out.

### 1.4 Upload the APNs key to Firebase

Firebase Console → Project Settings → **Cloud Messaging** → the `com.vipgo.app`
iOS app → **APNs Authentication Key** → Upload.

Supply the `.p8`, the Key ID, and the Team ID from 1.2. **This is the step that
is skipped most often and it is the single most common cause of "iOS push just
doesn't work."**

### 1.5 App Store Connect

1. Create the app record (App Store Connect → Apps → `+`), selecting the
   `com.vipgo.app` bundle ID.
2. Users and Access → **Integrations** → App Store Connect API → generate a key
   with the **App Manager** role. Download the `.p8` (again, one download only)
   and note the Key ID and Issuer ID.

### 1.6 Codemagic

- Team settings → **Integrations** → Developer Portal → add the App Store
  Connect API key from 1.5. Name it exactly **`VIPGo App Store Connect`** —
  `codemagic.yaml` references it by that name.
- Team settings → **Environment variables** → group `appstore_credentials`:
  - `CERTIFICATE_PRIVATE_KEY` — an RSA private key, marked *secure*. Generate
    once and never rotate casually; Apple caps an account at a small number of
    distribution certificates and a fresh key each build burns through them.

    ```bash
    ssh-keygen -t rsa -b 2048 -m PEM -f cert_key -q -N ""
    # paste the contents of `cert_key` (the private one) as the value
    ```

### 1.7 Clear stale push tokens

Every `users.fcm_token` issued to `com.moovit.busticketing` is undeliverable
under the new bundle ID:

```sql
UPDATE users SET fcm_token = NULL;
```

Clients re-register on next launch via `AuthCubit` → `POST /auth/fcm-token`.

---

## 2. What is already wired in this repo

| Piece | Where |
|---|---|
| Permission request, channel, foreground/background/tap handling | `lib/core/notifications/fcm_service.dart` |
| Cold-start tap → navigation | `lib/main.dart` → `_handleColdStart` |
| Token registration / clearing | `AuthCubit` → `POST/DELETE /auth/fcm-token` |
| `aps-environment` (push capability) | `ios/Runner/Runner.entitlements` |
| `UIBackgroundModes: remote-notification` | `ios/Runner/Info.plist` |
| Entitlements wired to Debug/Release/Profile | `ios/Runner.xcodeproj/project.pbxproj` |
| `GoogleService-Info.plist` in the Resources build phase | `ios/Runner.xcodeproj/project.pbxproj` |

`AppDelegate.swift` needs no changes: firebase_messaging 15.x uses method
swizzling by default, so the APNs device token is forwarded to FCM
automatically.

`aps-environment` is `development` in the checked-in entitlements. That is
correct — `xcode-project use-profiles` rewrites it to `production` during the
TestFlight export.

---

## 3. Backend payload requirements

iOS displays nothing for a data-only FCM message; it is silent by design. It
also means `FcmService._showForegroundNotification` returns early, since it
bails when `message.notification == null`.

The backend must send `notification` **and** `data` together, plus an `apns`
block:

```json
{
  "notification": { "title": "...", "body": "..." },
  "data": { "type": "booking_confirmed", "booking_id": "..." },
  "apns": {
    "headers": { "apns-priority": "10" },
    "payload": { "aps": { "sound": "default", "content-available": 1 } }
  }
}
```

`data` values must all be **strings** — FCM rejects nested objects and numbers.
The `type` values consumed by `FcmService.navigate` are:

- Client: `special_offer`, `booking_confirmed`, `ticket_scanned_client`,
  `trip_status_changed`, `trip_cancelled_client`
- Driver: `new_passenger_booked`, `ticket_scanned_driver`, `trip_assigned`,
  `trip_cancelled_driver`, `complaint_filed`

---

## 4. Testing

Push does not work on the iOS Simulator against real APNs. iOS 16+ simulators
accept a drag-and-dropped `.apns` file, which exercises the tap-handling and
navigation paths but not delivery. **A real device is required for a genuine
end-to-end test.**

A TestFlight build runs against the *production* APNs environment. The `.p8` key
from 1.2 covers both, which is why it is preferred over certificates.

---

## 5. Known gap: background location on iOS

The driver live-tracking foreground service is Android-only. The iOS equivalent
needs `UIBackgroundModes: location` plus `NSLocationAlwaysUsageDescription`, and
App Review scrutinises always-on location closely. Not addressed here — driver
tracking on iOS currently only updates while the app is foregrounded.
