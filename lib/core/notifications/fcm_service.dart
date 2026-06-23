import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router/app_router.dart';

// Must be a top-level function — FCM requires this for background processing.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized before this is called.
  // Navigation happens when the user taps the system notification (handled via
  // getInitialMessage / onMessageOpenedApp), not here.
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'bus_ticketing_high';
  static const _channelName = 'Bus Ticketing Notifications';
  static const _channelDesc = 'Bookings, trips, and special offers';

  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
  );

  /// Call once after [Firebase.initializeApp] in main().
  Future<void> initialize() async {
    // Request OS-level permission (Android 13+ and iOS require this)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Create the high-importance Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Initialise flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handlePayload(details.payload!);
        }
      },
    );

    // iOS: show alerts while foregrounded
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register the background handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground: show a local notification ourselves (FCM won't show it automatically)
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Background -> user tapped the notification -> navigate
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTap);
  }

  /// Returns the current FCM registration token for this device.
  Future<String?> getToken() => _messaging.getToken();

  /// Emits whenever FCM rotates the token. AuthCubit subscribes to this to
  /// keep the backend updated.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Call after [initialize] to check if the app was opened by tapping a
  /// notification while it was terminated (cold start).
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  // ── Private ─────────────────────────────────────────────────────────────────

  void _showForegroundNotification(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    _localNotifications.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onMessageTap(RemoteMessage message) => navigate(message.data);

  void _handlePayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      navigate(data);
    } catch (_) {}
  }

  /// Navigate the app to the correct screen based on the notification [data].
  /// Safe to call from any context — uses the global [appRouter].
  static void navigate(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'special_offer':
        appRouter.go(AppRoutes.home);

      case 'booking_confirmed':
      case 'ticket_scanned_client':
        final bookingId = data['booking_id'] as String?;
        if (bookingId != null) {
          appRouter.go('/booking-details/$bookingId');
        }

      case 'trip_status_changed':
        final tripId = data['trip_id'] as String?;
        if (tripId != null) {
          appRouter.go('/bus-tracking/$tripId');
        }

      case 'trip_cancelled_client':
        appRouter.go(AppRoutes.tickets);

      // Driver-targeted notifications
      case 'trip_assigned':
      case 'trip_cancelled_driver':
      case 'new_passenger_booked':
      case 'complaint_filed':
      case 'ticket_scanned_driver':
        appRouter.go(AppRoutes.driverDashboard);
    }
  }
}
