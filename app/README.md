# GoalSpring mobile client

GoalSpring is a calm, Today-first personal goals app built with Flutter. It turns a meaningful direction into milestones, small actions, a workable weekly rhythm, and honest progress feedback.

## Requirements

- Flutter 3.41+ / Dart 3.11+
- The GoalSpring API running on port 4000

## Run

Install packages:

~~~sh
flutter pub get
~~~

The default API URL is configured for an Android emulator:

~~~text
http://10.0.2.2:4000/api/v1
~~~

Run on Android:

~~~sh
flutter run
~~~

For the iOS simulator or web, point the client at the host explicitly:

~~~sh
flutter run -d ios --dart-define=API_BASE_URL=http://localhost:4000/api/v1
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
~~~

For a physical device, use a reachable LAN address during debug development. Production builds should always use HTTPS:

~~~sh
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
~~~

Android and iOS debug builds allow local development traffic; release builds remain HTTPS-only. Web development also requires the API CORS origin to include the Flutter development origin.

## Product walkthrough

From the welcome screen, choose **Explore with sample progress** to enter a complete local demo without an API account. The demo supports the same UI interactions—one-tap action completion, skipping, goal creation/editing, milestones, actions, progress, reflection, schedule, notifications, and settings—but does not send network requests.

The production journey is:

~~~text
Register → onboarding → set a goal → define rhythm and roadmap
→ Today → complete actions → Insights → weekly reflection
~~~

## Architecture

~~~text
lib/
  data/          HTTP client, secure token storage, local read cache
  domain/        User, goal, milestone, action, and reflection models
  ui/            Auth, onboarding, Today, goals, schedule, insights, profile
  app_state.dart Small app-wide state and API orchestration layer
  app_scope.dart Dependency access through an InheritedNotifier
~~~

The client deliberately uses a small dependency set:

- http for the REST API
- flutter_secure_storage for access and refresh tokens
- shared_preferences for non-sensitive offline read recovery
- firebase_core and firebase_messaging for device push registration

All persistent business data remains authoritative in PostgreSQL through the API. Cached data provides graceful read access during poor connectivity, while authenticated writes are queued with stable IDs and replayed in order on reconnect.

Push delivery uses Firebase options supplied as Dart defines. At minimum provide `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_ANDROID_APP_ID` for Android. iOS additionally uses `FIREBASE_IOS_APP_ID` and `FIREBASE_IOS_BUNDLE_ID`; web uses `FIREBASE_WEB_APP_ID`.

## Verify

~~~sh
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:4000/api/v1
flutter build apk --debug
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
~~~

The release artifact is written to `build/app/outputs/flutter-apk/app-release.apk`. Replace the example API URL, add Firebase defines, and configure a private Android signing key before store distribution.

Tests cover the auth entry flow, Today completion, responsive layouts, progress views, and strict API serialization for goal enums, cadence, days, frequency, and time.

## Branding assets

Launcher icons and native launch artwork use the committed GoalSpring sprout-and-progress mark.

The full-resolution source is `assets/branding/goalspring-app-icon.png`.
