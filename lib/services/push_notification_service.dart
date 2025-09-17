import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'navigation_service.dart';
import '../models/user.dart';
import 'user_service.dart';
import 'auth_service.dart';
import '../constants/app_constants.dart';

// Background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No heavy work here. Just ensure plugins are initialized if needed.
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

  Future<void> initialize() async {
    if (kIsWeb) {
      await _requestWebPermissionAndToken();
      return;
    }
    await _requestPermissions();
    await _initLocalNotifications();

    // Background messages (fires when app is in background or terminated)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // When app is opened from background by tapping a notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // When app is launched from terminated via a notification tap
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  Future<void> _requestWebPermissionAndToken() async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _messaging.getToken(
          vapidKey:
              AppConstants.webVapidKey.isEmpty
                  ? null
                  : AppConstants.webVapidKey,
        );
        if (token != null) {
          await _updateServerWithTokenIfLoggedIn(token);
        }
      }
    } catch (_) {}
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    }
    // On Android 13+, request notifications permission via local notifications plugin
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return; // Skip on web
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle tap on local notification
        final payload = details.payload;
        _navigateFromPayload(payload);
      },
    );

    // Create channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_defaultChannel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final android = notification?.android;

    // Show our own notification when in foreground
    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultChannel.id,
            _defaultChannel.name,
            channelDescription: _defaultChannel.description,
            icon: '@mipmap/launcher_icon',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: _extractPayloadFromMessage(message),
      );
    }
  }

  // Public: subscribe/unsubscribe based on role
  Future<void> updateTopicSubscriptionsForRole(UserRole role) async {
    if (kIsWeb) return; // Not supported on web client
    const topic = 'orders';
    if (role == UserRole.admin || role == UserRole.employee) {
      await _messaging.subscribeToTopic(topic);
    } else {
      await _messaging.unsubscribeFromTopic(topic);
    }
  }

  // Public: ensure server has latest token if user logged in
  Future<void> ensureServerHasCurrentToken() async {
    final token = await _messaging.getToken(
      vapidKey:
          kIsWeb && AppConstants.webVapidKey.isNotEmpty
              ? AppConstants.webVapidKey
              : null,
    );
    if (token != null) {
      await _updateServerWithTokenIfLoggedIn(token);
    }
  }

  Future<void> _updateServerWithTokenIfLoggedIn(String token) async {
    final user = AuthService.currentUser;
    final authToken = AuthService.currentToken;
    if (user == null) return;
    try {
      await UserService.updateFcmToken(
        userId: user.id,
        fcmtoken: token,
        token: authToken,
      );
    } catch (_) {}
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final payload = _extractPayloadFromMessage(message);
    _navigateFromPayload(payload);
  }

  String? _extractPayloadFromMessage(RemoteMessage message) {
    if (message.data.isEmpty) return null;
    // Minimal: pass a route or id if provided
    // Example expects 'route' key in data
    return message.data['route'];
  }

  void _navigateFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;
    // Expecting a named route string in payload
    navigator.pushNamed(payload);
  }
}
