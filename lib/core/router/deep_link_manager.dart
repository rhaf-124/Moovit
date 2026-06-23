import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class DeepLinkManager {
  DeepLinkManager._privateConstructor();
  static final DeepLinkManager instance = DeepLinkManager._privateConstructor();

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
