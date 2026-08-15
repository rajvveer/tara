import 'package:flutter/material.dart';
import '../app_scope.dart';
import '../domain/models.dart';
import 'avatar.dart';
import 'goal_screens.dart';
import 'insights_screen.dart' show WeeklyReflectionScreen;
import 'theme.dart';
import 'widgets.dart';

enum _TodayMode { goals, actions }

enum _TaskFilter { all, open, done }

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.onCreateGoal,
    required this.onOpenGoals,
    required this.onOpenNotifications,
    this.onOpenCoach,
  });

  final VoidCallback onCreateGoal;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenNotifications;
  final VoidCallback? onOpenCoach;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  _TodayMode _mode = _TodayMode.actions;
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final pending = state.todayActions
        .where((action) => action.status != ActionStatus.completed)
        .toList();
    final completed = state.todayActions
        .where((action) => action.status == ActionStatus.completed)
        .toList();
    final visibleActions = switch (_filter) {
      _TaskFilter.all => [...pending, ...completed],
      _TaskFilter.open => pending,
      _TaskFilter.done => completed,
    };
    final activeGoals = state.goals
        .where((goal) => goal.status == GoalStatus.active)
        .toList();
    final averageGoalProgress = activeGoals.isEmpty
        ? 0.0
        : activeGoals.map((goal) => goal.progress).reduce((a, b) => a + b) /
              activeGoals.length;
    final todayProgress = state.todayActions.isEmpty
        ? 0.0
        : completed.length / state.todayActions.length;
    final currentReflection = state.currentWeekReflection;
    final signals = [
      _HomeSignal(
        label: 'Goals',
        title: '${activeGoals.length} active',
        caption: activeGoals.isEmpty
            ? 'Create a direction'
            : 'Overall progress',
        value: averageGoalProgress,
        color: OnwardColors.purple,
        icon: Icons.flag_outlined,
        onTap: widget.onOpenGoals,
      ),
      _HomeSignal(
        label: 'Actions',
        title: '${completed.length}/${state.todayActions.length} done',
        caption: pending.isEmpty
            ? 'Plan is clear'
            : '${pending.length} remaining',
        value: todayProgress,
        color: OnwardColors.aqua,
        icon: Icons.check_circle_outline_rounded,
        onTap: () => setState(() => _mode = _TodayMode.actions),
      ),
      _HomeSignal(
        label: 'Consistency',
        title: '${(state.weeklyConsistency * 100).round()}% this week',
        caption: 'Keep the rhythm steady',
        value: state.weeklyConsistency,
        color: OnwardColors.orange,
        icon: Icons.local_fire_department_outlined,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ScheduleScreen())),
      ),
      _HomeSignal(
        label: 'Reflection',
        title: currentReflection == null
            ? 'Ready when you are'
            : 'Week reviewed',
        caption: 'Notice what is working',
        value: currentReflection == null ? 0 : 1,
        color: OnwardColors.green,
        icon: Icons.auto_awesome_outlined,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const WeeklyReflectionScreen(),
          ),
        ),
      ),
    ];
    final firstName = (state.user?.name ?? 'Friend').trim().split(' ').first;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ContentWidth(
          maxWidth: 720,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 108),
            children: [
              _AnovaHomeHeader(
                name: state.user?.name ?? 'Friend',
                avatarKey: state.user?.avatarKey,
                profileImageUrl: state.user?.profileImageUrl,
                unreadNotifications: state.unreadNotifications,
                onOpenNotifications: widget.onOpenNotifications,
              ),
              const SizedBox(height: 18),
              WeekStrip(
                key: const ValueKey('today-week-strip'),
                actions: state.actions,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 148,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _HomeQuickCard(
                        key: const ValueKey('daily-insight-card'),
                        eyebrow: 'Daily insight',
                        title: pending.isEmpty
                            ? 'Your plan is clear for today'
                            : 'Start with ${pending.first.title}',
                        action: 'Explore',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DailyInsightScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HomeQuickCard(
                        eyebrow: 'Tara AI',
                        title: 'Begin with one small check-in',
                        action: 'Chat',
                        onTap: widget.onOpenCoach,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SectionTitle(
                "Today's signals",
                trailing: TextButton(
                  onPressed: widget.onOpenGoals,
                  child: const Text('View all goals'),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: signals.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .78,
                ),
                itemBuilder: (context, index) {
                  return _SignalCard(signal: signals[index]);
                },
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$firstName\'s plan',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _TodayModeSwitch(
                    key: const ValueKey('today-mode-switch'),
                    value: _mode,
                    onChanged: (value) => setState(() => _mode = value),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_mode == _TodayMode.goals)
                for (final goal in activeGoals)
                  _TodayHabitRow(
                    goal: goal,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GoalDetailScreen(goalId: goal.id),
                      ),
                    ),
                  )
              else ...[
                _TodayListHeader(
                  label: _filter.name,
                  caption: _filterCaption(
                    _filter,
                    open: pending.length,
                    done: completed.length,
                  ),
                  value: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
                if (visibleActions.isEmpty)
                  _ClearDayCard(onOpenGoals: widget.onOpenGoals)
                else
                  for (final action in visibleActions)
                    _buildActionRow(context, action),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, GoalAction action) {
    final state = context.app;
    final goal = state.goalById(action.goalId);
    return ActionRow(
      key: ValueKey('today-action-${action.id}'),
      action: action,
      goal: goal,
      icon: _categoryIcon(goal?.category ?? 'Personal'),
      floating: true,
      onComplete: () async {
        if (await state.completeAction(action.id) && context.mounted) {
          showToast(context, 'Action completed.');
        }
      },
      onSkip: action.status == ActionStatus.completed
          ? null
          : () async {
              if (await state.skipAction(action.id) && context.mounted) {
                showToast(context, 'Action skipped.');
              }
            },
      onStart: () => state.startAction(action.id),
      onReopen: () => state.reopenAction(action.id),
      onMiss: () => state.missAction(action.id),
      onEdit: goal == null
          ? null
          : () => showEditActionSheet(context, goal, action),
      onDelete: () => confirmDeleteAction(context, action),
    );
  }
}

class DailyInsightScreen extends StatelessWidget {
  const DailyInsightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final actions = state.todayActions;
    final completed = actions
        .where((action) => action.status == ActionStatus.completed)
        .toList();
    final started = actions
        .where(
          (action) =>
              action.status == ActionStatus.inProgress ||
              action.status == ActionStatus.completed,
        )
        .length;
    final pending = actions
        .where((action) => action.status != ActionStatus.completed)
        .toList();
    final completion = actions.isEmpty
        ? 0.0
        : completed.length / actions.length;
    final completedMinutes = completed.fold<int>(
      0,
      (total, action) => total + action.estimatedDuration,
    );
    final leadGoal = actions.isEmpty
        ? null
        : state.goalById(actions.first.goalId);
    final accent = leadGoal == null
        ? Theme.of(context).colorScheme.primary
        : onwardCategoryColor(leadGoal.category);
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      key: const ValueKey('daily-insight-screen'),
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Daily insights'),
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Today',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 640,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.25,
            child: ListView(
              key: const ValueKey('daily-insight-scroll'),
              padding: pagePadding,
              children: [
                _DailyActionsChart(
                  stageCounts: [actions.length, started, completed.length],
                  completed: completed.length,
                  completion: completion,
                  color: accent,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InsightStatCard(
                        key: const ValueKey('daily-insight-completion'),
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Completion',
                        value: '${(completion * 100).round()}%',
                        supporting:
                            '${completed.length} of ${actions.length} actions',
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InsightStatCard(
                        key: const ValueKey('daily-insight-effort'),
                        icon: Icons.timer_outlined,
                        label: 'Completed effort',
                        value: '$completedMinutes min',
                        supporting: completed.isEmpty
                            ? 'Nothing completed yet'
                            : 'estimated time done',
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _GoalBreakdownCard(actions: actions),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DailyFocusCard(
                    action: pending.first,
                    goal: state.goalById(pending.first.goalId),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyActionsChart extends StatelessWidget {
  const _DailyActionsChart({
    required this.stageCounts,
    required this.completed,
    required this.completion,
    required this.color,
  });

  final List<int> stageCounts;
  final int completed;
  final double completion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highest = stageCounts.fold<int>(
      1,
      (current, value) => value > current ? value : current,
    );
    const labels = ['Planned', 'Started', 'Done'];
    return AppSurface(
      key: const ValueKey('daily-insight-chart'),
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's actions completed",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onwardMuted(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completed',
                      key: const ValueKey('daily-insight-total'),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(completion * 100).round()}% complete',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(stageCounts.length, (index) {
                final count = stageCounts[index];
                final barColor = color.withValues(alpha: .55 + (index * .22));
                final heightFactor = count == 0
                    ? .045
                    : .20 + (.80 * count / highest);
                return Expanded(
                  child: Semantics(
                    label:
                        '${labels[index]} stage, $count ${count == 1 ? 'action' : 'actions'}',
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: .45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: heightFactor,
                                child: AnimatedContainer(
                                  key: ValueKey('daily-insight-bar-$index'),
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    color: count == 0
                                        ? barColor.withValues(alpha: .12)
                                        : barColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[index],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: index == labels.length - 1
                                ? color
                                : onwardMuted(context),
                            fontWeight: index == labels.length - 1
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightStatCard extends StatelessWidget {
  const _InsightStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.supporting,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final String supporting;
  final Color color;

  @override
  Widget build(BuildContext context) => AppSurface(
    radius: 20,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          supporting,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: onwardMuted(context)),
        ),
      ],
    ),
  );
}

class _GoalBreakdownCard extends StatelessWidget {
  const _GoalBreakdownCard({required this.actions});

  final List<GoalAction> actions;

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final plannedByGoal = <String, int>{};
    final completedByGoal = <String, int>{};
    for (final action in actions) {
      plannedByGoal.update(
        action.goalId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (action.status == ActionStatus.completed) {
        completedByGoal.update(
          action.goalId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final entries = plannedByGoal.entries.toList()
      ..sort(
        (a, b) => (completedByGoal[b.key] ?? 0).compareTo(
          completedByGoal[a.key] ?? 0,
        ),
      );
    final cardColor = entries.isEmpty
        ? Theme.of(context).colorScheme.primary
        : onwardCategoryColor(
            state.goalById(entries.first.key)?.category ?? 'Personal',
          );
    return AppSurface(
      key: const ValueKey('daily-insight-goal-breakdown'),
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's goals",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 17,
                  color: cardColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'No actions are planned for today.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
              ),
            )
          else
            ...List.generate(entries.length, (index) {
              final entry = entries[index];
              final goal = state.goalById(entry.key);
              final color = onwardCategoryColor(goal?.category ?? 'Personal');
              final completed = completedByGoal[entry.key] ?? 0;
              final progress = completed / entry.value;
              return Column(
                children: [
                  if (index > 0) const Divider(height: 1, indent: 46),
                  Padding(
                    key: ValueKey('daily-insight-goal-${entry.key}'),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .11),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            _categoryIcon(goal?.category ?? 'Personal'),
                            size: 18,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal?.title ?? 'Personal goal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$completed of ${entry.value} complete',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: onwardMuted(context)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 76,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(progress * 100).round()}%',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 8),
                              ProgressLine(
                                value: progress,
                                height: 4,
                                color: color,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _DailyFocusCard extends StatelessWidget {
  const _DailyFocusCard({required this.action, required this.goal});

  final GoalAction action;
  final Goal? goal;

  @override
  Widget build(BuildContext context) {
    final state = context.appRead;
    final inProgress = action.status == ActionStatus.inProgress;
    final color = onwardCategoryColor(goal?.category ?? 'Personal');
    return AppSurface(
      key: const ValueKey('daily-insight-next-action'),
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: .13),
                  foregroundColor: color,
                  child: Icon(_categoryIcon(goal?.category ?? 'Personal')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inProgress ? 'IN PROGRESS' : 'DO THIS NEXT',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: color, letterSpacing: .7),
                      ),
                      Text(
                        goal?.title ?? 'Personal plan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onwardMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(action.title, style: Theme.of(context).textTheme.titleLarge),
            if (action.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                action.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _InsightMetadata(
                  icon: Icons.schedule_rounded,
                  label: action.preferredTime,
                ),
                _InsightMetadata(
                  icon: Icons.timer_outlined,
                  label: '${action.estimatedDuration} min',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('daily-insight-primary-action'),
                onPressed: () async {
                  final success = inProgress
                      ? await state.completeAction(action.id)
                      : await state.startAction(action.id);
                  if (success && context.mounted) {
                    showToast(
                      context,
                      inProgress ? 'Action completed.' : 'Action started.',
                    );
                  }
                },
                icon: Icon(
                  inProgress ? Icons.check_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(inProgress ? 'Mark complete' : 'Start this action'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightMetadata extends StatelessWidget {
  const _InsightMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: onwardMuted(context)),
      const SizedBox(width: 5),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
      ),
    ],
  );
}

class _AnovaHomeHeader extends StatelessWidget {
  const _AnovaHomeHeader({
    required this.name,
    required this.avatarKey,
    required this.profileImageUrl,
    required this.unreadNotifications,
    required this.onOpenNotifications,
  });

  final String name;
  final String? avatarKey;
  final String? profileImageUrl;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('today-header'),
    children: [
      OnwardAvatar(
        name: name,
        avatarKey: avatarKey,
        profileImageUrl: profileImageUrl,
        radius: 23,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${greeting()}, ${name.trim().split(' ').first}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Small choices today, better tomorrow.',
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: onwardMuted(context),
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
      AppCircleButton(
        icon: Icons.schedule_rounded,
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ScheduleScreen())),
        tooltip: 'Open schedule',
      ),
      const SizedBox(width: 8),
      _NotificationButton(
        unread: unreadNotifications,
        onPressed: onOpenNotifications,
      ),
    ],
  );
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unread, required this.onPressed});

  final int unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      AppCircleButton(
        icon: Icons.notifications_none_rounded,
        onPressed: onPressed,
        tooltip: 'Open notifications',
      ),
      if (unread > 0)
        Positioned(
          key: const ValueKey('notification-badge'),
          top: -3,
          right: -3,
          child: Container(
            constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              unread > 9 ? '9+' : '$unread',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 9,
                height: 1,
              ),
            ),
          ),
        ),
    ],
  );
}

class _HomeQuickCard extends StatelessWidget {
  const _HomeQuickCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppSurface(
    constraints: const BoxConstraints(minHeight: 132),
    radius: 18,
    padding: const EdgeInsets.all(16),
    child: MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.25,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: onwardMuted(context)),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '$action  ›',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeSignal {
  const _HomeSignal({
    required this.label,
    required this.title,
    required this.caption,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String title;
  final String caption;
  final double value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});

  final _HomeSignal signal;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      key: ValueKey('home-signal-${signal.label.toLowerCase()}'),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: InkWell(
          onTap: signal.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: signal.color.withValues(alpha: .13),
                    foregroundColor: signal.color,
                    child: Icon(signal.icon, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      signal.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: AppProgressRing(
                  value: signal.value,
                  color: signal.color,
                  size: 64,
                  strokeWidth: 6,
                  child: Text(
                    '${(signal.value * 100).round()}%',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: signal.color),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                signal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                signal.caption,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayModeSwitch extends StatelessWidget {
  const _TodayModeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final _TodayMode value;
  final ValueChanged<_TodayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    const curve = Curves.easeOutCubic;
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.center,
      child: Container(
        key: const ValueKey('today-mode-switch-control'),
        width: 176,
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: AppSurfaceStyle.raised(
          context,
          color: theme.colorScheme.surface,
          radius: 20,
          depth: .45,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedAlign(
              alignment: value == _TodayMode.goals
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: duration,
              curve: curve,
              child: FractionallySizedBox(
                key: const ValueKey('today-mode-thumb'),
                widthFactor: .5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: AppSurfaceStyle.raised(
                    context,
                    color: theme.colorScheme.primary,
                    radius: 16,
                    depth: .65,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final option in _TodayMode.values)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: value == option,
                      child: InkWell(
                        onTap: () => onChanged(option),
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            curve: curve,
                            style:
                                theme.textTheme.labelMedium?.copyWith(
                                  color: value == option
                                      ? Colors.white
                                      : onwardMuted(context),
                                ) ??
                                TextStyle(
                                  color: value == option
                                      ? Colors.white
                                      : onwardMuted(context),
                                ),
                            child: Text(
                              option == _TodayMode.goals ? 'HABITS' : 'TASKS',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayListHeader extends StatelessWidget {
  const _TodayListHeader({
    required this.label,
    required this.caption,
    this.value,
    this.onChanged,
  });

  final String label;
  final String caption;
  final _TaskFilter? value;
  final ValueChanged<_TaskFilter>? onChanged;

  @override
  Widget build(BuildContext context) {
    final filter = AppPopupMenuButton<_TaskFilter>(
      enabled: value != null,
      initialValue: value,
      onSelected: onChanged,
      tooltip: 'Filter actions',
      padding: EdgeInsets.zero,
      itemBuilder: (_) => _TaskFilter.values
          .map(
            (item) => PopupMenuItem(
              value: item,
              child: Text(item.name.toUpperCase()),
            ),
          )
          .toList(),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filter,
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
          child: Text(
            caption.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: onwardMuted(context).withValues(alpha: .52),
              letterSpacing: .45,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

String _filterCaption(
  _TaskFilter filter, {
  required int open,
  required int done,
}) => switch (filter) {
  _TaskFilter.all => '$done complete · $open to do',
  _TaskFilter.open => '$open to do',
  _TaskFilter.done => '$done complete',
};

class _TodayHabitRow extends StatelessWidget {
  const _TodayHabitRow({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = onwardCategoryColor(goal.category);
    final progressPercent = (goal.progress * 100).round();
    return Semantics(
      button: true,
      label: '${goal.title}, $progressPercent percent',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 76),
                    padding: const EdgeInsets.fromLTRB(11, 10, 14, 10),
                    decoration: AppSurfaceStyle.raised(
                      context,
                      color: Theme.of(context).colorScheme.surface,
                      radius: 24,
                      depth: .8,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: categoryColor,
                          foregroundColor: Colors.white,
                          child: Icon(_categoryIcon(goal.category), size: 22),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                goal.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${goal.frequency} · ${goal.preferredTime}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: onwardMuted(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: ExcludeSemantics(
                  child: AppProgressRing(
                    key: ValueKey('today-habit-progress-${goal.id}'),
                    value: goal.progress,
                    color: categoryColor,
                    size: 36,
                    strokeWidth: 3,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1,
                      child: Text(
                        '$progressPercent%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: categoryColor,
                          fontSize: 8.5,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearDayCard extends StatelessWidget {
  const _ClearDayCard({required this.onOpenGoals});

  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) => AppSurface(
    constraints: const BoxConstraints(minWidth: double.infinity),
    padding: const EdgeInsets.all(18),
    radius: 18,
    depth: .75,
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline_rounded),
        const SizedBox(width: 12),
        const Expanded(child: Text('No actions due today.')),
        TextButton(onPressed: onOpenGoals, child: const Text('View goals')),
      ],
    ),
  );
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    required this.onCreateGoal,
    required this.onOpenNotifications,
  });

  final VoidCallback onCreateGoal;
  final VoidCallback onOpenNotifications;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  GoalStatus _filter = GoalStatus.active;

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final filtered = state.goals
        .where((goal) => goal.status == _filter)
        .toList();
    final overall = filtered.isEmpty
        ? 0.0
        : filtered.map((goal) => goal.progress).reduce((a, b) => a + b) /
              filtered.length;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ContentWidth(
          maxWidth: 720,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 108),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Activity',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  _NotificationButton(
                    unread: state.unreadNotifications,
                    onPressed: widget.onOpenNotifications,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppSurface(
                radius: 24,
                padding: const EdgeInsets.all(6),
                depth: .65,
                child: Row(
                  children: [
                    for (final option in const [
                      (GoalStatus.active, 'Active', Icons.bolt_rounded),
                      (GoalStatus.paused, 'Paused', Icons.pause_rounded),
                      (
                        GoalStatus.completed,
                        'Complete',
                        Icons.done_all_rounded,
                      ),
                    ])
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: _filter == option.$1,
                          child: InkWell(
                            onTap: () => setState(() => _filter = option.$1),
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                gradient: _filter == option.$1
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF77A2FF),
                                          Color(0xFF5578EC),
                                        ],
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    option.$3,
                                    size: 18,
                                    color: _filter == option.$1
                                        ? Colors.white
                                        : onwardMuted(context),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    option.$2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: _filter == option.$1
                                              ? Colors.white
                                              : onwardMuted(context),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppSurface(
                radius: 22,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                child: Column(
                  children: [
                    AppProgressRing(
                      value: overall,
                      size: 150,
                      strokeWidth: 12,
                      child: Text(
                        '${(overall * 100).round()}%',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${filtered.length} ${_filter.name} goals',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      _filter == GoalStatus.active
                          ? 'Keep the next action small and repeatable.'
                          : 'Review the goals in this part of your journey.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onwardMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppSurface(
                radius: 18,
                child: InkWell(
                  onTap: widget.onCreateGoal,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick action',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: onwardMuted(context)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create a new goal',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              SectionTitle(
                '${_filter.name[0].toUpperCase()}${_filter.name.substring(1)} goals',
                caption: 'Tap a goal to open its activity details',
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                EmptyView(
                  icon: _filter == GoalStatus.active
                      ? Icons.flag_outlined
                      : Icons.inventory_2_outlined,
                  title: _filter == GoalStatus.active
                      ? 'No active goals'
                      : 'Nothing here yet',
                  body: _filter == GoalStatus.active
                      ? 'Add a goal and define its first action.'
                      : 'Goals appear here when their status changes.',
                  action: _filter == GoalStatus.active
                      ? FilledButton(
                          onPressed: widget.onCreateGoal,
                          child: const Text('Set a goal'),
                        )
                      : null,
                )
              else
                for (final goal in filtered) ...[
                  _GoalCard(
                    goal: goal,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GoalDetailScreen(goalId: goal.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurface(
    radius: 18,
    depth: .8,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: onwardCategoryColor(goal.category),
                  child: Icon(_categoryIcon(goal.category), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        goal.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${goal.category} · ${goal.pace}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onwardMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(goal.progress * 100).round()}%',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 42,
                        child: ProgressLine(
                          value: goal.progress,
                          height: 4,
                          color: onwardCategoryColor(goal.category),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _month;
  late DateTime _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedule());
  }

  Future<void> _loadSchedule() async {
    if (mounted) setState(() => _loading = true);
    await context.appRead.loadSchedule(_month);
    if (mounted) setState(() => _loading = false);
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selected = DateTime(_month.year, _month.month, 1);
    });
    _loadSchedule();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final selectedActions = state.actions
        .where(
          (action) =>
              action.dueDate.year == _selected.year &&
              action.dueDate.month == _selected.month &&
              action.dueDate.day == _selected.day,
        )
        .toList();
    final selectedMilestones = state.scheduledMilestones
        .where((milestone) => _sameDay(milestone.targetDate, _selected))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: ListView(
            padding: pagePadding,
            children: [
              if (_loading) ...[
                const LinearProgressIndicator(minHeight: 3),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                decoration: AppSurfaceStyle.raised(
                  context,
                  radius: 22,
                  depth: 1,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          tooltip: 'Previous month',
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            _monthName(_month),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeMonth(1),
                          tooltip: 'Next month',
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _CalendarGrid(
                      month: _month,
                      selected: _selected,
                      actions: state.actions,
                      milestones: state.scheduledMilestones,
                      onSelected: (date) => setState(() => _selected = date),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SectionTitle(
                shortDate(_selected),
                caption: selectedActions.isEmpty
                    ? selectedMilestones.isEmpty
                          ? 'No goal activity planned'
                          : '${selectedMilestones.length} milestone due'
                    : '${selectedActions.length} actions · ${selectedMilestones.length} milestones',
              ),
              const SizedBox(height: 10),
              if (selectedActions.isEmpty && selectedMilestones.isEmpty)
                const EmptyView(
                  icon: Icons.event_available_outlined,
                  title: 'Nothing scheduled',
                  body: 'Nothing goal-related is planned for this day.',
                )
              else
                for (final action in selectedActions)
                  ActionRow(
                    action: action,
                    goal: state.goalById(action.goalId),
                    onComplete: () => state.completeAction(action.id),
                    onSkip: () => state.skipAction(action.id),
                    onStart: () => state.startAction(action.id),
                    onReopen: () => state.reopenAction(action.id),
                    onMiss: () => state.missAction(action.id),
                    onEdit: () {
                      final goal = state.goalById(action.goalId);
                      if (goal != null) {
                        showEditActionSheet(context, goal, action);
                      }
                    },
                    onDelete: () => confirmDeleteAction(context, action),
                  ),
              for (final milestone in selectedMilestones)
                AppSurface(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: EdgeInsets.zero,
                  radius: 18,
                  child: ListTile(
                    leading: const Icon(Icons.flag_rounded),
                    title: Text(milestone.title),
                    subtitle: Text(
                      state.goalById(milestone.goalId)?.title ?? 'Milestone',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.selected,
    required this.actions,
    required this.milestones,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selected;
  final List<GoalAction> actions;
  final List<Milestone> milestones;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.25,
      child: Column(
        children: [
          Row(
            children: labels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: onwardMuted(context)),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemCount: offset + days,
            itemBuilder: (context, index) {
              if (index < offset) return const SizedBox.shrink();
              final date = DateTime(
                month.year,
                month.month,
                index - offset + 1,
              );
              final isSelected = _sameDay(date, selected);
              final scheduled =
                  actions.any((action) => _sameDay(action.dueDate, date)) ||
                  milestones.any(
                    (milestone) => _sameDay(milestone.targetDate, date),
                  );
              return Semantics(
                button: true,
                selected: isSelected,
                label:
                    '${shortDate(date)}${scheduled ? ', has actions or milestones' : ''}',
                child: InkResponse(
                  onTap: () => onSelected(date),
                  radius: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : scheduled
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: .13)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${date.day}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : null,
                              ),
                        ),
                      ),
                      if (scheduled && !isSelected)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _monthName(DateTime date) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[date.month - 1]} ${date.year}';
}

IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
  'health' || 'fitness' => Icons.directions_run_rounded,
  'learning' || 'study' => Icons.menu_book_rounded,
  'career' => Icons.work_outline_rounded,
  'finance' => Icons.savings_outlined,
  'relationships' => Icons.favorite_outline_rounded,
  'productivity' => Icons.bolt_rounded,
  _ => Icons.person_outline_rounded,
};
