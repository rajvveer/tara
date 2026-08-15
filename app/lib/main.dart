import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_scope.dart';
import 'app_state.dart';
import 'ui/auth_onboarding.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

void main() {
  final state = AppState();
  runApp(OnwardApp(state: state));
  state.bootstrap();
}

class OnwardApp extends StatelessWidget {
  const OnwardApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final mainApp = state.stage == AppStage.ready;
        return MaterialApp(
          title: 'GoalSpring',
          debugShowCheckedModeBanner: false,
          theme: mainApp
              ? onwardMainAppTheme(dark: false)
              : onwardTheme(dark: false),
          darkTheme: mainApp
              ? onwardMainAppTheme(dark: true)
              : onwardTheme(dark: true),
          themeMode: state.themeMode,
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: onwardSystemUiOverlayStyle(dark: dark),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: switch (state.stage) {
              AppStage.splash => const SplashScreen(key: ValueKey('splash')),
              AppStage.signedOut => const AuthLanding(key: ValueKey('auth')),
              AppStage.onboarding => const OnboardingScreen(
                key: ValueKey('onboarding'),
              ),
              AppStage.ready => const HomeShell(key: ValueKey('home')),
            },
          ),
        );
      },
    ),
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OnwardWordmark(),
            const SizedBox(height: 18),
            Text(
              'Goals. Actions. Progress.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .58),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
