# Comprehensive Guide: Auth System, Role-Based Routing, and Deep Linking in a Single Flutter App

This guide provides a complete, end-to-end blueprint for building a secure authentication system in a single Flutter app supporting multiple roles (**Clients** and **Drivers**). It covers deep-link handling across all application states (terminated/cold start, background, and foreground), backend configuration, and testing strategies on local servers (`localhost`).

---

## Table of Contents
1. [Architecture Strategy: Single App vs. Dual Apps](#1-architecture-strategy-single-app-vs-dual-apps)
2. [Deep Linking Configuration (Backend & OS Integration)](#2-deep-linking-configuration-backend--os-integration)
3. [Android Manifest Setup (Single Instance & Localhost Dev)](#3-android-manifest-setup-single-instance--localhost-dev)
4. [Lifecycle Routing Implementation in Flutter](#4-lifecycle-routing-implementation-in-flutter)
5. [Auth-Aware Redirection & Router Integration](#5-auth-aware-redirection--router-integration)
6. [Onboarding & Registration Sequence Flow](#6-onboarding--registration-sequence-flow)

---

## 1. Architecture Strategy: Single App vs. Dual Apps

When building a system for both clients and drivers, you have two primary options:

| Strategy | Pros | Cons | Recommendation |
| :--- | :--- | :--- | :--- |
| **Single App (Role-Based)** | Shared codebase (authentication, maps, API layers); unified branding; single store listing. | Increased app bundle size; complex routing logic to keep client/driver views segregated. | **Highly Recommended** for most startups and mid-size products where driver functionality relies on similar libraries. |
| **Dual Apps (Separate Apps)** | Zero code mixing; clean separation of driver location tracking / background permissions. | Double the store maintenance, CI/CD setup, dependency upgrades, and code duplication. | Use only if driver workflows require heavy background operations (e.g., continuous background tracking). |

---

## 2. Deep Linking Configuration (Backend & OS Integration)

To securely route users from an invitation email directly into the app, you must configure validation files on your web server so the OS trusts the incoming links.

### A. iOS: `apple-app-site-association`
Place this file (without any file extension) at `https://yourdomain.com/.well-known/apple-app-site-association`. It must be served with `Content-Type: application/json`.

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "YOUR_APPLE_TEAM_ID.YOUR_IOS_BUNDLE_ID",
        "paths": [ "/accept-invite*" ]
      }
    ]
  }
}
```

### B. Android: `assetlinks.json`
Place this file at `https://yourdomain.com/.well-known/assetlinks.json`.

```json
[
  {
    "relation": [
      "delegate_permission/common.handle_all_urls"
    ],
    "target": {
      "namespace": "android_app",
      "package_name": "YOUR_ANDROID_PACKAGE_NAME",
      "sha256_cert_fingerprints": [
        "YOUR_SHA256_FINGERPRINT"
      ]
    }
  }
]
```

### C. FastAPI Backend Route Example
Add routes in your FastAPI backend to serve these verification configurations correctly:

```python
import json
from pathlib import Path
from fastapi import FastAPI, Response

app = FastAPI()

@app.get("/.well-known/assetlinks.json", tags=["deep-linking"])
def get_assetlinks():
    file_path = Path(__file__).parent / ".well-known" / "assetlinks.json"
    if file_path.exists():
        with open(file_path, "r") as f:
            return json.load(f)
    return Response(content="Not Found", status_code=404)

@app.get("/.well-known/apple-app-site-association", tags=["deep-linking"])
def get_apple_app_site_association():
    file_path = Path(__file__).parent / ".well-known" / "apple-app-site-association"
    if file_path.exists():
        with open(file_path, "r") as f:
            data = json.load(f)
        return Response(
            content=json.dumps(data),
            media_type="application/json"
        )
    return Response(content="Not Found", status_code=404)
```

---

## 3. Android Manifest Setup (Single Instance & Localhost Dev)

Add the intent configurations to your `android/app/src/main/AndroidManifest.xml` under the main `<activity>` block. 

### Key Manifest Settings
1.  **`android:launchMode="singleTask"`**: Crucial to prevent Android from launching a new instance (duplicate tasks) of the app when a deep link is clicked while the app is in the background. Instead, it routes the intent to the active instance.
2.  **Custom Schemes (for localhost dev)**: Enables instant opening on local systems without domain ownership checks.

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTask"
    android:exported="true"
    ... >
    
    <!-- 1. Development Scheme (Localhost): Handles busauth://localhost/accept-invite -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="busauth" android:host="localhost" />
    </intent-filter>

    <!-- 2. Local HTTP Scheme: Handles http://localhost and http://10.0.2.2 (Android Emulator loopback) -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="http" android:host="localhost" />
        <data android:scheme="http" android:host="10.0.2.2" />
    </intent-filter>

    <!-- 3. Production App Links (Requires autoVerify for automatic OS associations) -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="yourproductiondomain.com" />
    </intent-filter>
</activity>
```

---

## 4. Lifecycle Routing Implementation in Flutter

To process deep links at app startup (cold start) or while suspended (background state), create a dedicated lifecycle-aware deep link manager in Flutter using `app_links` (or `uni_links`):

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class DeepLinkManager {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Callback to dispatch URLs to the navigator/state manager
  Function(Uri uri)? onLinkReceived;

  /// Starts listening to deep links in cold, warm, and hot states
  void initDeepLinks() async {
    // 1. Cold Start State (App was terminated/closed)
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error loading initial deep link: $e');
    }

    // 2. Background/Foreground State (App was running or minimized)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Error in deep link stream: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Successfully captured deep link: $uri');
    if (onLinkReceived != null) {
      onLinkReceived!(uri);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
```

---

## 5. Auth-Aware Redirection & Router Integration

Integrating the router with your user credentials ensures authenticated users reach their dashboards, and invited drivers bypass the login checks to complete password setups.

### A. Auth State Definition
```dart
enum UserRole { client, driver, guest }

class AuthState extends ChangeNotifier {
  UserRole _role = UserRole.guest;
  String? _token;
  bool _initialized = false;

  UserRole get role => _role;
  String? get token => _token;
  bool get isInitialized => _initialized;

  Future<void> checkCredentials() async {
    // Mock local storage lookup (e.g., flutter_secure_storage)
    await Future.delayed(const Duration(milliseconds: 500));
    _role = UserRole.guest; 
    _initialized = true;
    notifyListeners();
  }

  void setAuthenticated(String token, String role) {
    _token = token;
    _role = role == 'driver' ? UserRole.driver : UserRole.client;
    notifyListeners();
  }

  void logout() {
    _token = null;
    _role = UserRole.guest;
    notifyListeners();
  }
}
```

### B. Routing Rules using GoRouter
```dart
final authState = AuthState();

final GoRouter router = GoRouter(
  refreshListenable: authState,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/accept-invite',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        final email = state.uri.queryParameters['email'];
        return SetPasswordScreen(token: token, email: email);
      },
    ),
    GoRoute(
      path: '/driver-dashboard',
      builder: (context, state) => const DriverDashboard(),
    ),
    GoRoute(
      path: '/client-dashboard',
      builder: (context, state) => const ClientDashboard(),
    ),
  ],
  redirect: (context, state) {
    if (!authState.isInitialized) return null;

    final isLoggedIn = authState.role != UserRole.guest;
    final isGoingToInvite = state.uri.path == '/accept-invite';
    final isGoingToLogin = state.uri.path == '/';

    // Allow password setup access directly
    if (isGoingToInvite) return null;

    // Direct guests to login
    if (!isLoggedIn && !isGoingToLogin) return '/';

    // Direct logged-in users to their role-specific dashboard
    if (isLoggedIn && isGoingToLogin) {
      return authState.role == UserRole.driver 
          ? '/driver-dashboard' 
          : '/client-dashboard';
    }

    return null;
  },
);
```

### C. Integrating Listener in `main.dart`
```dart
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _deepLinkManager = DeepLinkManager();

  @override
  void initState() {
    super.initState();
    
    // Load local auth credentials
    authState.checkCredentials();

    // Attach router-based navigation callback to deep links
    _deepLinkManager.onLinkReceived = (Uri uri) {
      final path = uri.path;
      if (path == '/accept-invite') {
        final token = uri.queryParameters['token'];
        final email = uri.queryParameters['email'];
        // Re-route dynamically on the existing context
        router.go('/accept-invite?token=$token&email=$email');
      }
    };

    // Begin listening across all states (cold/warm/hot starts)
    _deepLinkManager.initDeepLinks();
  }

  @override
  void dispose() {
    _deepLinkManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      title: 'Bus Ticketing',
    );
  }
}
```
