import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'coach_screen.dart';
import 'goal_screens.dart';
import 'insights_screen.dart';
import 'notifications_screen.dart';
import 'profile_screens.dart';
import 'theme.dart';
import 'today_goals_screens.dart';
import 'widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _coachSession = CoachSession();

  Future<void> _newGoal() async {
    final goal = await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const GoalWizardScreen(),
      ),
    );
    if (goal != null && mounted) {
      setState(() => _index = 1);
      showToast(context, 'Goal created.');
    }
  }

  void _openNotifications() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));

  void _openCoach() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: CoachScreen(session: _coachSession)),
      ),
    );
  }

  void _selectDestination(int value) {
    if (value == 2) {
      _openCoach();
    } else {
      setState(() => _index = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final compact = MediaQuery.sizeOf(context).width < 820;
    final pages = [
      TodayScreen(
        onCreateGoal: _newGoal,
        onOpenGoals: () => setState(() => _index = 1),
        onOpenCoach: _openCoach,
        onOpenNotifications: _openNotifications,
      ),
      GoalsScreen(
        onCreateGoal: _newGoal,
        onOpenNotifications: _openNotifications,
      ),
      const SizedBox.shrink(),
      const InsightsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: Column(
        children: [
          if (state.offline) const OfflineBanner(),
          if (state.message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ErrorNotice(
                message: state.message!,
                onDismiss: state.clearMessage,
                onRetry: state.offline ? state.refresh : null,
              ),
            ),
          if (state.syncWarning != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ErrorNotice(
                message: state.syncWarning!,
                onDismiss: state.clearSyncWarning,
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 820) {
                  return Row(
                    children: [
                      SafeArea(
                        child: NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: _selectDestination,
                          extended: constraints.maxWidth >= 1080,
                          groupAlignment: -.7,
                          leading: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 26),
                            child: constraints.maxWidth >= 1080
                                ? const OnwardWordmark(compact: true)
                                : const OnwardWordmark(compact: true),
                          ),
                          destinations: _destinations
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Icon(item.icon),
                                  selectedIcon: Icon(item.selectedIcon),
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: KeyedSubtree(
                          key: ValueKey(_index),
                          child: pages[_index],
                        ),
                      ),
                    ],
                  );
                }
                return KeyedSubtree(
                  key: ValueKey(_index),
                  child: pages[_index],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: compact
          ? _TaraNavigationButton(selected: false, onPressed: _openCoach)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: compact
          ? _FloatingNavigation(
              selectedIndex: _index,
              onSelected: _selectDestination,
            )
          : null,
    );
  }
}

const _destinations = [
  (label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
  (
    label: 'Activity',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  (
    label: 'Tara',
    icon: Icons.smart_toy_outlined,
    selectedIcon: Icons.smart_toy_rounded,
  ),
  (
    label: 'Progress',
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart_rounded,
  ),
  (
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

class _FloatingNavigation extends StatelessWidget {
  const _FloatingNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceLeftInset = MediaQuery.paddingOf(context).left;
    final navLeftInset = deviceLeftInset > 7 ? deviceLeftInset : 7.0;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(7, 0, 7, 7),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: SizedBox(
          height: 68,
          child: BottomAppBar(
            key: const ValueKey('bottom-nav-surface'),
            height: 68,
            padding: EdgeInsets.zero,
            elevation: isDark ? 0 : 8,
            shadowColor: const Color(0xFF41587E).withValues(alpha: .2),
            color: scheme.surface,
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: _SafeAreaNotchedShape(navLeftInset),
            notchMargin: 6,
            // Liquid-glass BackdropFilter paused while using a solid navbar.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(_destinations.length, (index) {
                if (index == 2) return const Expanded(child: SizedBox());
                final item = _destinations[index];
                final selected = index == selectedIndex;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: InkResponse(
                      onTap: () => onSelected(index),
                      radius: 30,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            key: ValueKey('bottom-nav-puck-${item.label}'),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: selected
                                  ? scheme.primary.withValues(alpha: .12)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selected ? item.selectedIcon : item.icon,
                              color: selected
                                  ? scheme.primary
                                  : onwardMuted(context),
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: scheme.onSurface,
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  height: 1,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafeAreaNotchedShape extends NotchedShape {
  const _SafeAreaNotchedShape(this.leftInset);

  final double leftInset;

  static const _delegate = AutomaticNotchedShape(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    CircleBorder(),
  );

  @override
  Path getOuterPath(Rect host, Rect? guest) =>
      _delegate.getOuterPath(host, guest?.translate(-leftInset, 0));

  @override
  bool operator ==(Object other) =>
      other is _SafeAreaNotchedShape && other.leftInset == leftInset;

  @override
  int get hashCode => leftInset.hashCode;
}

class _TaraNavigationButton extends StatelessWidget {
  const _TaraNavigationButton({
    required this.selected,
    required this.onPressed,
  });

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tara',
      child: AnimatedContainer(
        key: const ValueKey('bottom-nav-puck-Tara'),
        duration: const Duration(milliseconds: 220),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: isDark ? .9 : .96),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? .3 : .96),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: selected ? .3 : .2),
              blurRadius: selected ? 18 : 14,
              spreadRadius: selected ? 2 : 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/illustrations/tara-nav-v1.png',
                key: const ValueKey('bottom-nav-tara'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
