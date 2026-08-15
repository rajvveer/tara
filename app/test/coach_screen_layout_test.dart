import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onward/app_scope.dart';
import 'package:onward/app_state.dart';
import 'package:onward/data/api.dart';
import 'package:onward/domain/models.dart';
import 'package:onward/ui/coach_screen.dart';
import 'package:onward/ui/home_shell.dart';
import 'package:onward/ui/theme.dart';
import 'package:onward/ui/widgets.dart';

void main() {
  testWidgets('Tara welcome uses plain cards and clears compact navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state =
        AppState(api: ApiClient(baseUrl: 'http://example.test/api/v1'))
          ..user = const AppUser(
            id: 'user-1',
            name: 'Rajveer',
            email: 'rajveer@example.test',
          );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: onwardMainAppTheme(dark: false),
          home: Scaffold(body: CoachScreen(session: CoachSession())),
        ),
      ),
    );

    expect(find.text('Online'), findsNothing);
    expect(find.byIcon(Icons.route_rounded), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    final welcomeFinder = find.byKey(const ValueKey('coach-welcome-card'));
    final welcome = tester.widget<AppSurface>(welcomeFinder);
    expect(
      welcome.color,
      Theme.of(tester.element(welcomeFinder)).colorScheme.surface,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('coach-composer'))).bottom,
      lessThanOrEqualTo(768),
    );
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('coach-composer')),
    );
    expect(composer.decoration?.enabledBorder, InputBorder.none);
    expect(composer.decoration?.focusedBorder, InputBorder.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tara lists, opens, deletes, and starts chat threads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'coach_conversations_user-1': jsonEncode([
        {
          'id': 'chat-1',
          'title': 'Help me focus',
          'updatedAt': '2026-08-14T10:00:00.000',
          'messages': [
            {'role': 'user', 'content': 'I need help focusing'},
            {'role': 'assistant', 'content': 'Start with **ten minutes**.'},
          ],
        },
        {
          'id': 'chat-2',
          'title': 'Plan my week',
          'updatedAt': '2026-08-15T10:00:00.000',
          'messages': [
            {'role': 'user', 'content': 'Plan this week for me'},
            {'role': 'assistant', 'content': 'Let’s choose three priorities.'},
          ],
        },
      ]),
    });
    final state =
        AppState(api: ApiClient(baseUrl: 'http://example.test/api/v1'))
          ..user = const AppUser(
            id: 'user-1',
            name: 'Rajveer',
            email: 'rajveer@example.test',
          );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: onwardMainAppTheme(dark: false),
          home: Scaffold(body: CoachScreen(session: CoachSession())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan this week for me'), findsOneWidget);
    expect(
      find.text('Let’s choose three priorities.', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('coach-history')));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Help me focus'), findsOneWidget);
    expect(find.text('Plan my week'), findsOneWidget);

    await tester.tap(find.text('Help me focus'));
    await tester.pumpAndSettle();
    expect(find.text('I need help focusing'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coach-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coach-thread-menu-chat-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete chat?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Help me focus'), findsNothing);
    expect(find.text('Plan my week'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coach-new-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coach-welcome-card')), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(preferences.getString('coach_conversations_user-1')!)
            as List<dynamic>;
    expect(stored, hasLength(1));
    expect((stored.single as Map<String, dynamic>)['title'], 'Plan my week');
  });

  testWidgets('Tara opens above the shell with back and no navbar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(
      api: ApiClient(baseUrl: 'http://example.test/api/v1'),
    );
    await state.exploreDemo();
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: onwardMainAppTheme(dark: false),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-puck-Tara')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coach-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-surface')), findsNothing);
    expect(find.text('Tara AI'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coach-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bottom-nav-surface')), findsOneWidget);
  });
}
