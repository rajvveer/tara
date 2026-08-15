import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onward/app_scope.dart';
import 'package:onward/app_state.dart';
import 'package:onward/data/api.dart';
import 'package:onward/data/realtime.dart';
import 'package:onward/data/social_auth.dart';
import 'package:onward/domain/models.dart';
import 'package:onward/ui/auth_onboarding.dart';
import 'package:onward/ui/coach_screen.dart';
import 'package:onward/ui/goal_screens.dart';
import 'package:onward/ui/home_shell.dart';
import 'package:onward/ui/insights_screen.dart';
import 'package:onward/ui/profile_screens.dart';
import 'package:onward/ui/today_goals_screens.dart';
import 'package:onward/ui/theme.dart';
import 'package:onward/ui/widgets.dart';

Widget _host(AppState state, Widget child, {bool dark = false}) => AppScope(
  state: state,
  child: MaterialApp(
    theme: onwardTheme(dark: dark),
    home: child,
  ),
);

class _FakeRealtimeClient extends RealtimeClient {
  _FakeRealtimeClient() : super(ApiClient(baseUrl: 'http://example.test'));

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  @override
  Future<void> connect() async {}

  @override
  void send(String type, Map<String, dynamic> data) {
    if (type != 'voice.start') return;
    _controller.add({
      'type': 'voice.reply',
      'data': {
        'reply': 'Tell me your goal in any language.',
        'languageCode': 'en-IN',
        'audioBase64': '',
        'audioMimeType': 'audio/wav',
        'complete': false,
      },
    });
  }

  @override
  Future<void> dispose() => _controller.close();
}

class _FakeCoachRealtimeClient extends RealtimeClient {
  _FakeCoachRealtimeClient() : super(ApiClient(baseUrl: 'http://example.test'));

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? sentData;

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  @override
  Future<void> connect() async {}

  @override
  void send(String type, Map<String, dynamic> data) {
    if (type != 'chat.message') return;
    sentData = data;
    _controller
      ..add({'type': 'chat.start', 'data': <String, dynamic>{}})
      ..add({
        'type': 'chat.delta',
        'data': {'text': 'Start with **'},
      })
      ..add({
        'type': 'chat.delta',
        'data': {'text': 'ten easy minutes**.'},
      })
      ..add({'type': 'chat.done', 'data': <String, dynamic>{}});
  }

  @override
  Future<void> dispose() => _controller.close();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('refresh reconciles completed onboarding from server truth', () async {
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null),
    );
    final client = MockClient((request) async {
      final path = request.url.path;
      final body = switch (path) {
        '/api/v1/users/me' => {
          'data': {
            'id': 'user-1',
            'name': 'Acceptance User',
            'email': 'acceptance@example.com',
            'onboardingCompleted': true,
            'preferences': <String, dynamic>{},
          },
        },
        '/api/v1/progress/history' => {
          'data': {'history': <dynamic>[]},
        },
        '/api/v1/users/me/preferences' ||
        '/api/v1/notifications/preferences' => {'data': <String, dynamic>{}},
        _ => {
          'data': <dynamic>[],
          'meta': {'pages': 1},
        },
      };
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final state =
        AppState(
            api: ApiClient(
              client: client,
              baseUrl: 'http://example.test/api/v1',
            ),
          )
          ..stage = AppStage.onboarding
          ..offline = true
          ..message = 'We could not reach GoalSpring.'
          ..user = const AppUser(
            id: 'user-1',
            name: 'Acceptance User',
            email: 'acceptance@example.com',
          );

    await state.refresh(silent: true);

    expect(state.stage, AppStage.ready);
    expect(state.user!.onboardingCompleted, isTrue);
    expect(state.offline, isFalse);
    expect(state.message, isNull);
  });

  test('onboarding hydrates generated goal actions immediately', () async {
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null),
    );
    final client = MockClient((request) async {
      final submitted = jsonDecode(request.body) as Map<String, dynamic>;
      final goalId = (submitted['firstGoal'] as Map)['id'];
      return http.Response(
        jsonEncode({
          'data': {
            'user': {
              'id': 'user-1',
              'name': 'Rajveer Demo',
              'email': 'rajveer.demo@example.com',
              'onboardingCompleted': true,
            },
            'preferences': <String, dynamic>{},
            'goal': {
              'id': goalId,
              'title': 'Run my first 5K',
              'category': 'FITNESS',
              'startDate': '2026-08-15T00:00:00.000Z',
              'targetDate': '2026-10-10T00:00:00.000Z',
              'frequency': 'WEEKLY',
              'preferredDays': ['TUESDAY', 'THURSDAY', 'SATURDAY'],
              'preferredTime': '08:00',
              'weeklyTarget': 3,
              'milestones': <dynamic>[],
              'routines': <dynamic>[],
              'progressRecords': <dynamic>[],
              'actions': [
                {
                  'id': 'action-ai',
                  'goalId': goalId,
                  'title': 'Jog 2 km at an easy pace',
                  'scheduledFor': '2026-08-18T08:00:00.000Z',
                  'status': 'UPCOMING',
                  'estimatedMinutes': 30,
                },
              ],
              'progress': 0,
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final state =
        AppState(
            api: ApiClient(
              client: client,
              baseUrl: 'http://example.test/api/v1',
            ),
          )
          ..user = const AppUser(
            id: 'user-1',
            name: 'Rajveer Demo',
            email: 'rajveer.demo@example.com',
          );

    final finished = await state.finishOnboarding(
      name: 'Rajveer Demo',
      objective: 'Run my first 5K',
      targetDate: DateTime(2026, 10, 10),
      avatarKey: 'arjun-rose-plum',
      progressStyle: 'Detailed',
      preferredDays: const ['Tue', 'Thu', 'Sat'],
      preferredTime: 'Morning',
      workingFrequency: 3,
    );

    expect(finished, isTrue);
    expect(state.actions.single.title, 'Jog 2 km at an easy pace');
    expect(state.goals.single.actions.single.id, 'action-ai');
  });

  test('goal creation sends a strict nested plan payload', () async {
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null),
    );
    Map<String, dynamic>? submitted;
    final client = MockClient((request) async {
      submitted = jsonDecode(request.body) as Map<String, dynamic>;
      final responseGoal = Map<String, dynamic>.from(submitted!)
        ..remove('plan')
        ..['milestones'] = <dynamic>[]
        ..['actions'] = <dynamic>[]
        ..['routines'] = <dynamic>[]
        ..['progressRecords'] = <dynamic>[]
        ..['progress'] = 0;
      return http.Response(
        jsonEncode({'data': responseGoal}),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final state = AppState(
      api: ApiClient(client: client, baseUrl: 'http://example.test/api/v1'),
    );
    final draft = Goal(
      id: newClientId(),
      title: 'Acceptance release',
      why: 'Ship confidently',
      description: 'All flows pass',
      category: 'Personal',
      startDate: DateTime(2026, 8, 13),
      targetDate: DateTime(2026, 11, 11),
      frequency: 'Weekly',
      preferredDays: const ['Mon'],
      preferredTime: 'Flexible',
      ongoing: true,
    );

    final created = await state.createGoal(
      draft,
      milestoneTitles: const ['Release ready'],
      actionTitles: const ['Run release smoke test'],
      actionMilestoneIndexes: const [0],
    );

    expect(created, isNotNull);
    final plan = submitted!['plan'] as Map<String, dynamic>;
    final milestone = (plan['milestones'] as List).single as Map;
    final action = (plan['actions'] as List).single as Map;
    expect(milestone.keys.toSet(), {
      'id',
      'title',
      'description',
      'targetDate',
    });
    expect(milestone, isNot(contains('status')));
    expect(milestone, isNot(contains('position')));
    expect(action, isNot(contains('goalId')));
    expect(action, isNot(contains('status')));
    expect(action['milestoneId'], milestone['id']);
  });

  test('system chrome follows light and dark themes', () {
    expect(
      onwardSystemUiOverlayStyle(dark: false).statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      onwardSystemUiOverlayStyle(dark: true).statusBarIconBrightness,
      Brightness.light,
    );
  });

  testWidgets('auth landing opens registration with both providers', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(_host(state, const AuthLanding()));

    expect(find.text('Less planning.\nMore progress.'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsOneWidget);
    expect(find.text('Sign up with Apple'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('goal wizard creates an ongoing milestone action hierarchy', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    state
      ..goals = []
      ..actions = [];
    await tester.pumpWidget(_host(state, const GoalWizardScreen()));

    await tester.enterText(find.byType(TextField).first, 'Acceptance release');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'All flows pass');
    await tester.tap(find.text('Ongoing practice'));
    await tester.enterText(find.byType(TextField).at(1), 'Ship confidently');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Action 1',
      ),
      'Run release smoke test',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Milestone 1',
      ),
      'Release ready',
    );
    final milestoneDropdown = find.byWidgetPredicate(
      (widget) => widget is AppDropdownButtonFormField<int?>,
    );
    await tester.ensureVisible(milestoneDropdown);
    await tester.pumpAndSettle();
    await tester.tap(milestoneDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milestone 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build my plan'));
    await tester.pumpAndSettle();

    final goal = state.goals.singleWhere(
      (item) => item.title == 'Acceptance release',
    );
    expect(goal.ongoing, isTrue);
    expect(goal.milestones.single.title, 'Release ready');
    expect(goal.actions.first.title, 'Run release smoke test');
    expect(goal.actions.first.milestoneId, goal.milestones.first.id);
  });

  testWidgets('360x800 landing balances every meaningful group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(_host(state, const AuthLanding()));
    await tester.pumpAndSettle();

    final artwork = tester.getRect(
      find.byKey(const ValueKey('landing-progress-artwork')),
    );
    final headline = tester.getRect(
      find.text('Less planning.\nMore progress.'),
    );
    final subtitle = tester.getRect(
      find.text('Build a rhythm that fits real life, one small win at a time.'),
    );
    final getStarted = tester.getRect(
      find.widgetWithText(FilledButton, 'Get started'),
    );
    final signIn = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Sign in'),
    );
    final preview = tester.getRect(
      find.widgetWithText(TextButton, 'Preview the app'),
    );

    expect(artwork.top, 0);
    expect(artwork.bottom, 800);
    expect(headline.top, greaterThan(artwork.top));
    expect(subtitle.top, greaterThan(headline.bottom));
    expect(getStarted.top, greaterThan(subtitle.bottom));
    expect(signIn.top, greaterThan(getStarted.bottom));
    expect(preview.top, greaterThan(signIn.bottom));
    expect(preview.bottom, lessThan(artwork.bottom));
    expect(800 - preview.bottom, lessThanOrEqualTo(60));
    expect(find.byKey(const ValueKey('landing-journey-image')), findsOneWidget);
    for (final finder in [
      find.text('GoalSpring'),
      find.text('Less planning.\nMore progress.'),
      find.widgetWithText(FilledButton, 'Get started'),
      find.widgetWithText(OutlinedButton, 'Sign in'),
      find.widgetWithText(TextButton, 'Preview the app'),
    ]) {
      expect(finder.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('login includes Google and Apple below email fields', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(
      _host(state, const AuthScreen(mode: AuthMode.login)),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('or sign in with'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('social cancellation clears provider loading without error', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      socialAuth: SocialAuthClient(google: () async => null),
    );
    await tester.pumpWidget(
      _host(state, const AuthScreen(mode: AuthMode.login)),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(state.busy, isFalse);
    expect(state.activeSocialProvider, isNull);
    expect(state.message, isNull);
  });

  testWidgets('unexpected provider failure becomes a safe visible error', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      socialAuth: SocialAuthClient(
        apple: () async => throw StateError('native failure'),
      ),
    );
    await tester.pumpWidget(
      _host(state, const AuthScreen(mode: AuthMode.register)),
    );

    await tester.ensureVisible(find.text('Sign up with Apple'));
    await tester.tap(find.text('Sign up with Apple'));
    await tester.pumpAndSettle();

    expect(state.busy, isFalse);
    expect(state.activeSocialProvider, isNull);
    expect(
      find.text('Sign-in could not be completed. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('password reset sheet exposes code completion and validation', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(_host(state, const AuthLanding()));

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I have a reset code'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a new password'), findsOneWidget);
    expect(find.text('Reset code'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(2), 'short');
    await tester.enterText(find.byType(TextFormField).at(3), 'password1');
    await tester.enterText(find.byType(TextFormField).at(4), 'password2');
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(find.text('Enter the complete reset code.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('account deletion requires the typed final confirmation', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(_host(state, const SettingsScreen()));

    await tester.scrollUntilVisible(
      find.text('Delete account'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account and data?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm permanent deletion'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Delete forever'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).last, 'DELETE');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Delete forever'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('demo Today action completes in one tap', (tester) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(_host(state, const HomeShell()));

    final before = state.completedThisWeek;
    final actionCard = find.byKey(
      const ValueKey('floating-action-card-action-spanish'),
    );
    await tester.scrollUntilVisible(
      actionCard,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(actionCard).height, 60);
    final surface = tester.widget<AppSurface>(actionCard);
    expect(surface.color, OnwardColors.surface);
    expect(surface.pressed, isFalse);
    expect(surface.radius, 22);
    await tester.tap(find.byTooltip('Mark complete').first);
    await tester.pumpAndSettle();

    expect(state.completedThisWeek, before + 1);
    expect(find.text('Action completed.'), findsOneWidget);
  });

  testWidgets('Coach renders streamed reply deltas as one message', (
    tester,
  ) async {
    final realtime = _FakeCoachRealtimeClient();
    addTearDown(realtime.dispose);
    final state =
        AppState(api: ApiClient(baseUrl: 'http://example.test/api/v1'))
          ..user = const AppUser(
            id: 'user-1',
            name: 'Mira Patel',
            email: 'mira@example.test',
          );
    await tester.pumpWidget(
      _host(state, Scaffold(body: CoachScreen(realtime: realtime))),
    );

    expect(find.textContaining('Mira!'), findsOneWidget);
    expect(
      find.textContaining('move your goals forward every day'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('coach-composer')),
      'What should I do next?',
    );
    await tester.tap(find.byKey(const ValueKey('coach-send')));
    await tester.pumpAndSettle();

    final reply = tester.widget<MarkdownBody>(find.byType(MarkdownBody).last);
    expect(reply.data, 'Start with **ten easy minutes**.');
    expect(
      find.text('Start with ten easy minutes.', findRichText: true),
      findsOneWidget,
    );
    expect(realtime.sentData?['message'], 'What should I do next?');
    expect((realtime.sentData?['history'] as List).single, {
      'role': 'assistant',
      'content':
          'Hi Mira — I’m Tara. What would make today feel a little easier?',
    });
    final preferences = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(preferences.getString('coach_conversations_user-1')!)
            as List<dynamic>;
    final conversation = saved.single as Map<String, dynamic>;
    expect(conversation['title'], 'What should I do next?');
    expect((conversation['messages'] as List<dynamic>).last, {
      'role': 'assistant',
      'content': 'Start with **ten easy minutes**.',
    });
  });

  testWidgets('Today mode thumb slides between habits and tasks', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(_host(state, const HomeShell()));

    final thumb = find.byKey(const ValueKey('today-mode-thumb'));
    await tester.scrollUntilVisible(
      thumb,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final start = tester.getRect(thumb);
    await tester.tap(find.text('HABITS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final middle = tester.getRect(thumb);
    await tester.pumpAndSettle();
    final end = tester.getRect(thumb);

    expect(middle.left, lessThan(start.left));
    expect(middle.left, greaterThan(end.left));
    expect(end.width, start.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today progress ring opens the schedule calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(
      _host(
        state,
        Scaffold(
          body: TodayScreen(
            onCreateGoal: () {},
            onOpenGoals: () {},
            onOpenNotifications: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsOneWidget);
  });

  testWidgets('Today reference dashboard scrolls as one surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(_host(state, const HomeShell()));
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('today-header'));
    final week = find.byKey(const ValueKey('today-week-strip'));
    expect(header, findsOneWidget);
    expect(week, findsOneWidget);
    expect(tester.getRect(header).bottom, lessThan(tester.getRect(week).top));
    expect(find.text('Daily insight'), findsOneWidget);
    expect(find.text('Tara AI'), findsOneWidget);
    expect(find.text("Today's signals"), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today-mode-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home notification button opens inbox and marks all read', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(_host(state, const HomeShell()));
    await tester.pumpAndSettle();

    expect(state.unreadNotifications, 1);
    expect(find.byKey(const ValueKey('notification-badge')), findsOneWidget);
    await tester.tap(find.byTooltip('Open notifications'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notifications-screen')), findsOneWidget);
    expect(find.text('A small step is ready'), findsOneWidget);
    expect(find.byType(GoalWizardScreen), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mark-all-notifications-read')));
    await tester.pumpAndSettle();

    expect(state.unreadNotifications, 0);
    expect(find.text('You are all caught up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daily insight card opens a useful live summary', (tester) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(_host(state, const HomeShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-insight-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-insight-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-insight-chart')), findsOneWidget);
    expect(find.text("Today's actions completed"), findsOneWidget);
    final expectedCompleted = <String>{
      for (final action in state.todayActions)
        if (action.status == ActionStatus.completed) 'action:${action.id}',
    }.length;
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('daily-insight-total')))
          .data,
      '$expectedCompleted',
    );
    expect(
      find.byKey(const ValueKey('daily-insight-completion')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('daily-insight-effort')), findsOneWidget);
    for (var index = 0; index < 3; index++) {
      expect(find.byKey(ValueKey('daily-insight-bar-$index')), findsOneWidget);
    }
    final insightScroll = find.descendant(
      of: find.byKey(const ValueKey('daily-insight-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('daily-insight-goal-breakdown')),
      180,
      scrollable: insightScroll,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-insight-goal-breakdown')),
      findsOneWidget,
    );
    expect(find.text("Today's goals"), findsOneWidget);
    final firstPending = state.todayActions.firstWhere(
      (action) => action.status != ActionStatus.completed,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('daily-insight-primary-action')),
      180,
      scrollable: insightScroll,
    );
    final primaryAction = find.byKey(
      const ValueKey('daily-insight-primary-action'),
    );
    await tester.ensureVisible(primaryAction);
    await tester.pumpAndSettle();
    expect(primaryAction.hitTestable(), findsOneWidget);
    await tester.tap(primaryAction);
    await tester.pumpAndSettle();
    expect(
      state.actions.firstWhere((action) => action.id == firstPending.id).status,
      ActionStatus.inProgress,
    );
    expect(find.text('Mark complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('goal API serialization keeps backend strict values', () {
    final goal = Goal(
      id: 'local',
      title: 'Feel strong',
      why: 'More energy',
      category: 'Health',
      priority: 'medium',
      startDate: DateTime.utc(2026, 8, 1),
      targetDate: DateTime.utc(2026, 11, 1),
      frequency: '4 times a week',
      preferredDays: const ['Mon', 'Wed', 'Fri', 'Sun'],
      preferredTime: 'Evening',
      weeklyTarget: 4,
    );

    expect(goal.toApiJson(), containsPair('category', 'HEALTH'));
    expect(goal.toApiJson(), containsPair('priority', 'MEDIUM'));
    expect(
      goal.copyWith(priority: 'high').toApiJson(),
      containsPair('priority', 'HIGH'),
    );
    expect(goal.toApiJson(), containsPair('frequency', 'WEEKLY'));
    expect(goal.toApiJson(), containsPair('preferredTime', '19:00'));
    expect(goal.toApiJson()['preferredDays'], [
      'MONDAY',
      'WEDNESDAY',
      'FRIDAY',
      'SUNDAY',
    ]);
    expect(goal.toApiJson()['weeklyTarget'], 4);
    expect(goal.toApiJson()['startDate'], '2026-08-01T00:00:00.000Z');
    expect(goal.toApiJson()['targetDate'], '2026-11-01T00:00:00.000Z');
  });

  test('ongoing goals and flexible time preserve backend nulls', () {
    final parsed = Goal.fromJson({
      'id': 'goal',
      'title': 'Keep learning',
      'category': 'LEARNING',
      'startDate': '2026-08-01T00:00:00.000Z',
      'targetDate': null,
      'preferredTime': null,
      'preferredDays': ['MONDAY'],
    });

    expect(parsed.ongoing, isTrue);
    expect(parsed.preferredTime, 'Flexible');
    expect(parsed.toApiJson()['targetDate'], isNull);
    expect(parsed.toApiJson()['preferredTime'], isNull);
  });

  test('goal lifecycle status takes precedence over a stale pace label', () {
    final goal = Goal(
      id: 'goal-status',
      title: 'Lifecycle',
      why: '',
      category: 'Personal',
      startDate: DateTime(2026, 8, 1),
      targetDate: DateTime(2026, 9, 1),
      frequency: 'Weekly',
      preferredDays: const ['Mon'],
      preferredTime: 'Flexible',
      paceStatus: 'On track',
    );

    expect(goal.copyWith(status: GoalStatus.paused).pace, 'Paused');
    expect(goal.copyWith(status: GoalStatus.completed).pace, 'Completed');
  });

  test('progress records remain after an action is reopened', () async {
    final state = AppState(api: ApiClient(baseUrl: 'http://example.test'));
    await state.exploreDemo();
    final action = state.actions.firstWhere(
      (item) => item.status == ActionStatus.completed,
    );
    final completedBefore = state
        .recordsForGoal(action.goalId)
        .where((record) => record.isCompleted && record.actionId == action.id);
    expect(completedBefore, isNotEmpty);

    expect(await state.reopenAction(action.id), isTrue);

    final history = state.recordsForGoal(action.goalId);
    expect(
      history.where(
        (record) => record.isCompleted && record.actionId == action.id,
      ),
      isNotEmpty,
    );
    expect(
      history.firstWhere((record) => record.actionId == action.id).status,
      'UPCOMING',
    );
  });

  test('goal plans retain action to milestone hierarchy', () async {
    final state = AppState(api: ApiClient(baseUrl: 'http://example.test'));
    await state.exploreDemo();
    final goal = Goal(
      id: newClientId(),
      title: 'Ship a project',
      why: 'It matters',
      description: 'A useful release exists',
      category: 'Career',
      startDate: DateTime.now(),
      targetDate: DateTime.now().add(const Duration(days: 60)),
      frequency: '2 times a week',
      preferredDays: const ['Tue', 'Thu'],
      preferredTime: 'Morning',
    );

    final created = await state.createGoal(
      goal,
      milestoneTitles: const ['Prototype'],
      actionTitles: const ['Sketch the first flow'],
      actionMilestoneIndexes: const [0],
    );

    expect(created, isNotNull);
    expect(created!.actions.single.milestoneId, created.milestones.single.id);
  });

  test('offline-safe IDs and action frequency use API-compatible values', () {
    final first = newClientId();
    final second = newClientId();
    expect(first, matches(RegExp(r'^c[a-z0-9]{20,}$')));
    expect(second, isNot(first));

    final action = GoalAction(
      id: first,
      goalId: second,
      title: 'Repeat the useful step',
      dueDate: DateTime.utc(2026, 8, 14, 8),
      frequency: 'Custom',
    );
    expect(action.toApiJson()['frequency'], 'CUSTOM');
    expect(
      GoalAction.fromJson({...action.toJson(), 'frequency': 'DAILY'}).frequency,
      'Daily',
    );
  });

  test('device offsets use the server fixed-offset timezone format', () {
    expect(formatUtcOffset(const Duration(hours: 5, minutes: 30)), 'UTC+05:30');
    expect(formatUtcOffset(const Duration(hours: -7)), 'UTC-07:00');
    expect(formatUtcOffset(Duration.zero), 'UTC+00:00');
  });

  test('calendar dates serialize as UTC midnight, actions retain instants', () {
    final milestone = Milestone(
      id: 'milestone',
      goalId: 'goal',
      title: 'Foundation',
      targetDate: DateTime(2026, 8, 12, 23, 45),
    );
    final reflection = WeeklyReflection(
      id: 'reflection',
      periodStart: DateTime(2026, 8, 10, 18),
      periodEnd: DateTime(2026, 8, 16, 18),
    );
    final instant = DateTime.utc(2026, 8, 12, 14, 30);
    final action = GoalAction(
      id: 'action',
      goalId: 'goal',
      title: 'Do the work',
      dueDate: instant,
      difficulty: 3,
    );

    expect(milestone.toApiJson()['targetDate'], '2026-08-12T00:00:00.000Z');
    expect(reflection.toApiJson()['periodStart'], '2026-08-10T00:00:00.000Z');
    expect(reflection.toApiJson()['periodEnd'], '2026-08-16T00:00:00.000Z');
    expect(action.toApiJson()['scheduledFor'], instant.toIso8601String());
    expect(action.toApiJson()['difficulty'], 3);
  });

  test('API action timestamps are read in local time and written as UTC', () {
    final source = DateTime.utc(2026, 8, 12, 20, 15);
    final parsed = GoalAction.fromJson({
      'id': 'action',
      'goalId': 'goal',
      'title': 'Evening action',
      'scheduledFor': source.toIso8601String(),
    });

    expect(parsed.dueDate, source.toLocal());
    expect(
      parsed.toApiJson()['scheduledFor'],
      parsed.dueDate.toUtc().toIso8601String(),
    );
  });

  test('goal detail reads active routine identity and duration', () {
    final goal = Goal.fromJson({
      'id': 'goal',
      'title': 'Read more',
      'category': 'LEARNING',
      'startDate': '2026-08-01T00:00:00.000Z',
      'targetDate': '2026-10-01T00:00:00.000Z',
      'frequency': 'WEEKLY',
      'weeklyTarget': 3,
      'preferredDays': ['MONDAY'],
      'routines': [
        {'id': 'routine-1', 'durationMinutes': 45},
      ],
    });

    expect(goal.activeRoutineId, 'routine-1');
    expect(goal.routineDurationMinutes, 45);
  });

  test('weekly consistency includes actions completed today', () {
    final now = DateTime.now();
    final state =
        AppState(api: ApiClient(baseUrl: 'http://example.test/api/v1'))
          ..actions = [
            for (var index = 0; index < 2; index++)
              GoalAction(
                id: 'completed-$index',
                goalId: 'goal',
                title: 'Completed $index',
                dueDate: now.subtract(const Duration(days: 8)),
                status: ActionStatus.completed,
                completedAt: now,
              ),
          ];
    state.progressRecords = [
      ProgressRecord(
        id: 'unrelated-record',
        goalId: 'other-goal',
        status: 'MISSED',
        occurredAt: now,
      ),
    ];

    expect(state.weekActions, hasLength(2));
    expect(state.completedThisWeek, 2);
    expect(state.weeklyConsistency, 1);
  });

  testWidgets('week strip reports daily action progress and date', (
    tester,
  ) async {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final actions = [
      GoalAction(
        id: 'done',
        goalId: 'goal',
        title: 'Done',
        dueDate: monday.subtract(const Duration(days: 8)),
        status: ActionStatus.completed,
        completedAt: monday,
      ),
      GoalAction(id: 'open', goalId: 'goal', title: 'Open', dueDate: monday),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: onwardTheme(dark: false),
        home: Scaffold(body: WeekStrip(actions: actions)),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('Mon .*50 percent action completion')),
      findsOne,
    );
    final mondayRing = find.byKey(
      ValueKey('week-action-ring-${monday.year}-${monday.month}-${monday.day}'),
    );
    expect(mondayRing, findsOneWidget);
    expect(
      find.descendant(of: mondayRing, matching: find.text('${monday.day}')),
      findsOneWidget,
    );
    expect(find.text('50%'), findsNothing);
  });

  testWidgets('Home Reflection card opens the weekly check-in', (tester) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(_host(state, const HomeShell()));
    final reflectionCard = find.byKey(const ValueKey('home-signal-reflection'));
    await tester.scrollUntilVisible(
      reflectionCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(reflectionCard);
    await tester.pumpAndSettle();

    expect(find.text('Weekly reflection'), findsOneWidget);
    expect(find.text('A week is information.'), findsOneWidget);
    expect(find.byKey(const ValueKey('weekly-overview')), findsOneWidget);
    expect(find.byKey(const ValueKey('weekly-activity-chart')), findsOneWidget);
  });

  group('compact 200% text accessibility', () {
    Future<void> pumpCompact(
      WidgetTester tester,
      AppState state,
      Widget child,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_host(state, child));
      await tester.pumpAndSettle();
    }

    testWidgets('auth adapts at 320x700', (tester) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await pumpCompact(tester, state, const AuthLanding());
      expect(find.text('Get started'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, 'Preview the app'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, 'Preview the app').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('demo Today adapts at 320x700', (tester) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      await pumpCompact(
        tester,
        state,
        Scaffold(
          body: TodayScreen(
            onCreateGoal: () {},
            onOpenGoals: () {},
            onOpenNotifications: () {},
          ),
        ),
      );
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(TodayScreen)),
        ).scale(10),
        20,
      );
      expect(tester.takeException(), isNull);
      final lastAction = find.byKey(
        const ValueKey('today-action-action-mobility'),
      );
      await tester.scrollUntilVisible(
        lastAction,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(lastAction.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('weekly analytics stay scroll-safe at 320x700', (tester) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      await pumpCompact(tester, state, const WeeklyReflectionScreen());

      expect(tester.takeException(), isNull);
      expect(find.text('Weekly reflection'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('weekly-overview')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('weekly-overview')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('weekly-activity-chart')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('weekly-activity-chart')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('weekly-goal-progress')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('weekly-goal-progress')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Reflect on the pattern'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('goal wizard adapts at 320x700', (tester) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      await pumpCompact(tester, state, const GoalWizardScreen());
      expect(
        find.text('What do you want to make progress on?'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Build a fitness habit'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Build a fitness habit'));
      await tester.pump();
      final goalField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Goal name',
        ),
      );
      expect(goalField.controller?.text, 'Build a fitness habit');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Health'))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('goal-wizard-primary')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'Move consistently and feel stronger and more energetic.',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
        'I want more energy for the people and work I care about.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('signup primary submit remains reachable at 200% text', (
      tester,
    ) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await pumpCompact(
        tester,
        state,
        const AuthScreen(mode: AuthMode.register),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Create account'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsOneWidget);
      expect(find.text('Sign up with Apple'), findsOneWidget);
      final googleSize = tester.getSize(
        find.byKey(const ValueKey('social-register-google')),
      );
      final appleSize = tester.getSize(
        find.byKey(const ValueKey('social-register-apple')),
      );
      expect(googleSize.height, 52);
      expect(appleSize.height, 52);
      expect(googleSize.width, appleSize.width);
      expect(tester.takeException(), isNull);
    });

    testWidgets('legal summaries remain scroll-safe at 200% text', (
      tester,
    ) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await pumpCompact(
        tester,
        state,
        const AuthScreen(mode: AuthMode.register),
      );
      await tester.scrollUntilVisible(
        find.text('Already have an account? Sign in'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final privacyButton = find.ancestor(
        of: find.text('Privacy summary'),
        matching: find.byType(TextButton),
      );
      final accountButton = find.ancestor(
        of: find.text('Already have an account? Sign in'),
        matching: find.byType(TextButton),
      );
      expect(
        tester.getRect(accountButton).top -
            tester.getRect(privacyButton).bottom,
        greaterThanOrEqualTo(16),
      );
      await tester.tap(find.text('Terms of use'));
      await tester.pumpAndSettle();
      expect(find.text('TERMS OF USE — PRE-RELEASE SUMMARY'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Close'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Goals and Insights reflow at 320x700', (tester) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      await pumpCompact(
        tester,
        state,
        Scaffold(
          body: GoalsScreen(onCreateGoal: () {}, onOpenNotifications: () {}),
        ),
      );
      expect(find.text('Activity'), findsOneWidget);
      expect(find.byType(AppProgressRing), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpCompact(tester, state, const InsightsScreen());
      expect(find.text('Progress'), findsOneWidget);
      await tester.tap(find.text('All goals'));
      await tester.pumpAndSettle();
      expect(find.text('Goal completion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Daily insight stays usable at 320x700', (tester) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      await pumpCompact(tester, state, const DailyInsightScreen());

      final screenFinder = find.byKey(const ValueKey('daily-insight-screen'));
      final screen = tester.widget<Scaffold>(screenFinder);
      expect(
        screen.backgroundColor,
        Theme.of(tester.element(screenFinder)).scaffoldBackgroundColor,
      );
      expect(find.byKey(const ValueKey('daily-insight-chart')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('daily-insight-completion')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const ValueKey('daily-insight-scroll')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('daily-insight-goal-breakdown')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const ValueKey('daily-insight-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Progress uses the reference score card and detail grid', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(296, 422);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      await tester.pumpWidget(
        _host(state, const Scaffold(body: InsightsScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Progress'), findsOneWidget);
      expect(find.byKey(const ValueKey('insight-completion')), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Details'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      expect(find.byType(ProgressLine), findsWidgets);
      expect(find.text('Consistency'), findsOneWidget);
      expect(find.text('No data yet'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('Goal details uses the reference activity gauge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(296, 422);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      await tester.pumpWidget(
        _host(state, GoalDetailScreen(goalId: state.goals.first.id)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activity'), findsOneWidget);
      final ring = find.byType(AppProgressRing);
      expect(ring, findsOneWidget);
      expect(tester.getSize(ring), const Size.square(154));
      expect(find.textContaining('actions complete'), findsOneWidget);
      expect(find.textContaining('remaining'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('Home shell and raised navigation reflow at 320x700', (
      tester,
    ) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      await pumpCompact(tester, state, const HomeShell());

      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(TodayScreen)),
        ).scale(10),
        20,
      );
      final surface = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-surface')),
      );
      final puck = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-puck-Home')),
      );
      final tara = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-puck-Tara')),
      );
      expect(puck.top, greaterThan(surface.top));
      expect(tara.top, lessThan(surface.top));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-puck-Activity')));
      await tester.pumpAndSettle();
      expect(find.text('Activity'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('goal detail moves its status below the title at 200%', (
      tester,
    ) async {
      final state = AppState(
        api: ApiClient(baseUrl: 'http://example.test/api/v1'),
      );
      await state.exploreDemo();
      final goal = state.goals.first;
      await pumpCompact(tester, state, GoalDetailScreen(goalId: goal.id));

      expect(
        tester.getRect(find.text(goal.pace)).top,
        greaterThan(tester.getRect(find.text(goal.title)).bottom),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('signup providers are equal 52dp controls below email', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(
      _host(state, const AuthScreen(mode: AuthMode.register)),
    );
    await tester.pumpAndSettle();

    final google = find.byKey(const ValueKey('social-register-google'));
    final apple = find.byKey(const ValueKey('social-register-apple'));
    final email = find.ancestor(
      of: find.text('Email'),
      matching: find.byType(TextFormField),
    );
    final googleRect = tester.getRect(google);
    final appleRect = tester.getRect(apple);
    final emailRect = tester.getRect(email);
    final passwordHintRect = tester.getRect(find.text('At least 8 characters'));
    final createButtonRect = tester.getRect(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    expect(googleRect.height, 52);
    expect(appleRect.height, 52);
    expect(googleRect.width, appleRect.width);
    expect(googleRect.width, emailRect.width);
    expect(googleRect.top, lessThan(appleRect.top));
    expect(emailRect.bottom, lessThan(googleRect.top));
    expect(passwordHintRect.bottom, lessThan(createButtonRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding character chooser customizes head top and bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(_host(state, const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);

    expect(find.text('Choose your character'), findsOneWidget);
    expect(find.text('1 of 5'), findsOneWidget);
    expect(find.text('Profile image URL (optional)'), findsNothing);
    expect(
      find.bySemanticsLabel('Selected GoalSpring character'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('character-garden-stage')),
      findsOneWidget,
    );
    expect(find.text('Woman'), findsNothing);
    expect(find.text('Looks'), findsNothing);

    await tester.tap(find.text('Top'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byTooltip('Next Top option'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Bottom'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byTooltip('Next Bottom option'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Head'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next Head option'));
    await tester.pumpAndSettle();
    expect(
      find.image(
        const AssetImage('assets/avatars/character-layer-amara-base.png'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('character-top-coral')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-bottom-forest')),
      findsOneWidget,
    );
    expect(
      find.image(
        const AssetImage('assets/avatars/character-layer-amara-top.png'),
      ),
      findsOneWidget,
    );
    expect(
      find.image(
        const AssetImage('assets/avatars/character-layer-amara-bottom.png'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal step expands its schedule from the same card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(_host(state, const OnboardingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 5'), findsOneWidget);
    expect(find.text('AI GUIDED  •  AUTO LANGUAGE'), findsNothing);
    expect(find.text('Prefer to type?'), findsOneWidget);
    expect(
      find.image(
        const AssetImage('assets/illustrations/onward-human-guide.png'),
      ),
      findsOneWidget,
    );

    final manualButton = find.text('Prefer to type?');
    await tester.ensureVisible(manualButton);
    await tester.tap(manualButton);
    await tester.pumpAndSettle();
    expect(find.text('3 of 5'), findsOneWidget);
    expect(find.text('Your name'), findsNothing);
    expect(find.text('Set your schedule'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Run my first 5K');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 5'), findsOneWidget);
    expect(find.text('Set your schedule'), findsOneWidget);
    expect(find.text('Preferred days'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    final expansion = tester.widget<AnimatedSize>(
      find.byKey(const ValueKey('schedule-expansion')),
    );
    expect(expansion.duration, const Duration(milliseconds: 220));
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    expect(find.text('Set your schedule'), findsNothing);
    expect(find.text('Set your first goal'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Fine-tune your plan'), findsOneWidget);
    expect(find.text('4 of 5'), findsOneWidget);
    expect(find.text('Your name'), findsNothing);
    expect(find.text('Profile photo URL (optional)'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('AI voice path waits for a user-controlled mic tap', (
    tester,
  ) async {
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          if (call.method == 'read') return 'test-access-token';
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null),
    );
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(
      _host(state, OnboardingScreen(realtime: _FakeRealtimeClient())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    final voiceButton = find.widgetWithText(FilledButton, 'Start with voice');
    await tester.ensureVisible(voiceButton);
    await tester.tap(voiceButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Let’s shape your goal'), findsOneWidget);
    expect(find.text('Tell me your goal in any language.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('voice-onboarding-mascot')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('voice-onboarding-mic')), findsOneWidget);
    expect(find.text('Tap to speak'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Hear again'), findsNothing);
    expect(find.text('Stop listening'), findsNothing);
    expect(find.text('3 of 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding stays light when the rest of the app is dark', (
    tester,
  ) async {
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await tester.pumpWidget(_host(state, const OnboardingScreen(), dark: true));
    await tester.pumpAndSettle();

    final heading = find.text('Choose your character');
    expect(Theme.of(tester.element(heading)).brightness, Brightness.light);
    expect(
      find.bySemanticsLabel('Whimsical garden background'),
      findsOneWidget,
    );
  });

  testWidgets('360x800 Today matches the Anova reference composition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(_host(state, const HomeShell()));
    await tester.pumpAndSettle();

    final header = tester.getRect(find.byKey(const ValueKey('today-header')));
    final week = tester.getRect(find.byKey(const ValueKey('today-week-strip')));
    final navSurface = tester.getRect(
      find.byKey(const ValueKey('bottom-nav-surface')),
    );
    final homePuck = tester.getRect(
      find.byKey(const ValueKey('bottom-nav-puck-Home')),
    );
    final taraPuck = tester.getRect(
      find.byKey(const ValueKey('bottom-nav-puck-Tara')),
    );

    expect(header.left, 20);
    expect(header.width, 320);
    expect(week.left, 20);
    expect(week.width, 320);
    expect(week.top, greaterThan(header.bottom));
    expect(find.text('Daily insight'), findsOneWidget);
    expect(find.text('Tara AI'), findsOneWidget);
    expect(find.text("Today's signals"), findsOneWidget);
    expect(find.byType(AppProgressRing), findsWidgets);
    expect(find.byTooltip('Open notifications'), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-tara')), findsOneWidget);
    expect(homePuck.top, greaterThan(navSurface.top));
    expect(taraPuck.top, lessThan(navSurface.top));
    expect(homePuck.size, const Size.square(26));
    expect(navSurface.left, 7);
    expect(navSurface.width, 346);
    final navBar = tester.widget<BottomAppBar>(
      find.byKey(const ValueKey('bottom-nav-surface')),
    );
    expect(navBar.shape, isA<AutomaticNotchedShape>());
    expect(navBar.notchMargin, 6);
    expect(navBar.elevation, 8);
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-puck-Activity')));
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsWidgets);
    expect(find.byType(AppProgressRing), findsOneWidget);
    expect(find.text('Quick action'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dark Today renders its core surfaces', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(_host(state, const HomeShell(), dark: true));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(TodayScreen))).brightness,
      Brightness.dark,
    );
    expect(find.text('Daily insight'), findsOneWidget);
    expect(find.text('Tara AI'), findsOneWidget);
    expect(find.byType(AppSurface), findsWidgets);
    expect(find.byKey(const ValueKey('bottom-nav-surface')), findsOneWidget);
    final darkNavBar = tester.widget<BottomAppBar>(
      find.byKey(const ValueKey('bottom-nav-surface')),
    );
    expect(darkNavBar.elevation, 0);
    expect(tester.takeException(), isNull);
  });
}
