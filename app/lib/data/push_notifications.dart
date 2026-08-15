import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

const _apiKey = String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: 'AIzaSyCmXG_bCXAfMFKpdxJQ-FXCqwUTwk9oPyQ',
);
const _projectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: 'onward-app-260815-chanu',
);
const _senderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '897292387660',
);
const _androidAppId = String.fromEnvironment(
  'FIREBASE_ANDROID_APP_ID',
  defaultValue: '1:897292387660:android:28a591d99aaa8c33183be9',
);
const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
const _iosBundleId = String.fromEnvironment(
  'FIREBASE_IOS_BUNDLE_ID',
  defaultValue: 'com.intentional.onward',
);

bool get pushConfigured =>
    _apiKey.isNotEmpty &&
    _projectId.isNotEmpty &&
    _senderId.isNotEmpty &&
    (kIsWeb
        ? _webAppId.isNotEmpty
        : (defaultTargetPlatform == TargetPlatform.iOS
              ? _iosAppId.isNotEmpty
              : _androidAppId.isNotEmpty));

FirebaseOptions get _options => FirebaseOptions(
  apiKey: _apiKey,
  appId: kIsWeb
      ? _webAppId
      : defaultTargetPlatform == TargetPlatform.iOS
      ? _iosAppId
      : _androidAppId,
  messagingSenderId: _senderId,
  projectId: _projectId,
  iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
      ? _iosBundleId
      : null,
);

@pragma('vm:entry-point')
Future<void> onwardFirebaseBackgroundMessage(RemoteMessage _) async {
  if (pushConfigured && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: _options);
  }
}

class PushNotifications {
  bool _ready = false;
  String? _token;

  Future<bool> register(ApiClient api) async {
    if (!pushConfigured) return false;
    if (!_ready) {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _options);
      }
      FirebaseMessaging.onBackgroundMessage(onwardFirebaseBackgroundMessage);
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _sendToken(api, token),
      );
      _ready = true;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return false;
    await _sendToken(api, token);
    return true;
  }

  Future<void> unregister(ApiClient api) async {
    final token = _token;
    if (token == null) return;
    try {
      await api.post('/notifications/devices/unregister', {'token': token});
    } on ApiException {
      return;
    }
    _token = null;
  }

  Future<void> _sendToken(ApiClient api, String token) async {
    await api.post('/notifications/devices', {
      'token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
    _token = token;
  }
}
