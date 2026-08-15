import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const googleCalendarEventsScope =
    'https://www.googleapis.com/auth/calendar.events';
const _onwardGoogleServerClientId =
    '897292387660-hj7r38seqd1odlusqc2mk1k7mcj1bpq2.apps.googleusercontent.com';

enum SocialProvider { google, apple }

class SocialCredential {
  const SocialCredential({
    required this.provider,
    this.idToken,
    this.authorizationCode,
    this.givenName,
    this.familyName,
  });

  final SocialProvider provider;
  final String? idToken;
  final String? authorizationCode;
  final String? givenName;
  final String? familyName;
}

class SocialAuthException implements Exception {
  const SocialAuthException(this.message);

  final String message;
}

typedef SocialSignIn = Future<SocialCredential?> Function();
typedef SocialSignOut = Future<void> Function();

class SocialAuthClient {
  SocialAuthClient({
    SocialSignIn? google,
    SocialSignIn? apple,
    SocialSignOut? signOut,
  }) : _google = google ?? _PlatformSocialAuth.instance.google,
       _apple = apple ?? _PlatformSocialAuth.instance.apple,
       _signOut = signOut ?? _PlatformSocialAuth.instance.signOut;

  final SocialSignIn _google;
  final SocialSignIn _apple;
  final SocialSignOut _signOut;

  Future<SocialCredential?> signIn(SocialProvider provider) =>
      provider == SocialProvider.google ? _google() : _apple();

  Future<void> signOut() => _signOut();

  Future<Map<String, String>?> googleCalendarHeaders() =>
      _PlatformSocialAuth.instance.googleCalendarHeaders();
}

class _PlatformSocialAuth {
  _PlatformSocialAuth._();

  static final instance = _PlatformSocialAuth._();

  static const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: _onwardGoogleServerClientId,
  );
  static const _appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
  static const _appleRedirectUri = String.fromEnvironment('APPLE_REDIRECT_URI');

  Future<void>? _googleInitialization;
  GoogleSignInAccount? _googleAccount;

  Future<void> _initializeGoogle() {
    _googleInitialization ??= GoogleSignIn.instance.initialize(
      clientId: _googleClientId.isEmpty ? null : _googleClientId,
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
    );
    return _googleInitialization!;
  }

  Future<SocialCredential?> google() async {
    if (_googleServerClientId.isEmpty && !kIsWeb) {
      throw const SocialAuthException(
        'Google sign-in is not configured yet. Add GOOGLE_SERVER_CLIENT_ID to this build.',
      );
    }
    if ((kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) &&
        _googleClientId.isEmpty) {
      throw const SocialAuthException(
        'Google sign-in is not configured yet. Add GOOGLE_CLIENT_ID to this build.',
      );
    }
    final google = GoogleSignIn.instance;
    await _initializeGoogle();
    if (!google.supportsAuthenticate()) {
      throw const SocialAuthException(
        'Google sign-in is not available on this platform build.',
      );
    }
    try {
      final account = await google.authenticate(
        scopeHint: const [googleCalendarEventsScope],
      );
      _googleAccount = account;
      try {
        await account.authorizationClient.authorizationHeaders(const [
          googleCalendarEventsScope,
        ], promptIfNecessary: true);
      } on GoogleSignInException {
        // Calendar access is optional; Google authentication still succeeds.
      }
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthException(
          'Google did not return an identity token. Check the OAuth client configuration.',
        );
      }
      return SocialCredential(
        provider: SocialProvider.google,
        idToken: idToken,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw SocialAuthException(
        error.code == GoogleSignInExceptionCode.clientConfigurationError ||
                error.code ==
                    GoogleSignInExceptionCode.providerConfigurationError
            ? 'Google sign-in is not configured correctly for this app.'
            : 'Google sign-in could not be completed. Please try again.',
      );
    }
  }

  Future<Map<String, String>?> googleCalendarHeaders() async {
    await _initializeGoogle();
    var account = _googleAccount;
    if (account == null) {
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (attempt != null) account = await attempt;
      _googleAccount = account;
    }
    return account?.authorizationClient.authorizationHeaders(const [
      googleCalendarEventsScope,
    ]);
  }

  Future<SocialCredential?> apple() async {
    final useWebFlow =
        kIsWeb || defaultTargetPlatform == TargetPlatform.android;
    if (useWebFlow && (_appleServiceId.isEmpty || _appleRedirectUri.isEmpty)) {
      throw const SocialAuthException(
        'Apple sign-in is not configured yet. Add APPLE_SERVICE_ID and APPLE_REDIRECT_URI to this build.',
      );
    }
    if (!await SignInWithApple.isAvailable()) {
      throw const SocialAuthException(
        'Apple sign-in is not available on this device.',
      );
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: useWebFlow
            ? WebAuthenticationOptions(
                clientId: _appleServiceId,
                redirectUri: Uri.parse(_appleRedirectUri),
              )
            : null,
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const SocialAuthException(
          'Apple did not return an identity token. Check the Sign in with Apple configuration.',
        );
      }
      return SocialCredential(
        provider: SocialProvider.apple,
        authorizationCode: credential.authorizationCode,
        idToken: identityToken,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw const SocialAuthException(
        'Apple sign-in could not be completed. Please try again.',
      );
    } on SignInWithAppleException {
      throw const SocialAuthException(
        'Apple sign-in is not configured correctly for this app.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // The API session is still cleared even if the provider is unavailable.
    } finally {
      _googleAccount = null;
    }
  }
}
