import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../domain/models.dart';
import 'avatar.dart';
import 'theme.dart';
import 'widgets.dart';

enum _InsightsMode { progress, goals }

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  _InsightsMode _mode = _InsightsMode.progress;

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final currentReflection = state.currentWeekReflection;
    final completed = state.completedThisWeek;
    final planned = state.weekActions.length;
    final now = DateTime.now();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final previousCompleted = state.progressRecords.where((record) {
      return record.isCompleted &&
          !record.occurredAt.isBefore(lastMonday) &&
          record.occurredAt.isBefore(thisMonday);
    }).length;
    final goalWork = <String, int>{};
    for (final record in state.weekProgressRecords) {
      if (record.isCompleted) {
        goalWork.update(record.goalId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final strongest = goalWork.entries.isEmpty
        ? null
        : goalWork.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final detailed = state.progressStyle == 'Detailed';
    final balanced = state.progressStyle == 'Balanced';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 720,
                child: Padding(
                  padding: pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 14),
                      _ProgressIdentityCard(
                        name: state.user?.name ?? 'Friend',
                        email: state.user?.email ?? '',
                        avatarKey: state.user?.avatarKey,
                        profileImageUrl: state.user?.profileImageUrl,
                        completed: completed,
                        planned: planned,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_InsightsMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _InsightsMode.progress,
                              label: Text('Overview'),
                            ),
                            ButtonSegment(
                              value: _InsightsMode.goals,
                              label: Text('All goals'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (value) =>
                              setState(() => _mode = value.first),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_mode == _InsightsMode.progress) ...[
                        _InsightBubbles(
                          completed: completed,
                          planned: planned,
                          consistency: state.weeklyConsistency,
                          previousCompleted: previousCompleted,
                        ),
                        const SizedBox(height: 18),
                        const SectionTitle('Details'),
                        const SizedBox(height: 10),
                        _ProgressDetailsGrid(
                          goals: state.goals,
                          completed: completed,
                          planned: planned,
                          consistency: state.weeklyConsistency,
                          reflected: currentReflection != null,
                        ),
                        if (balanced || detailed) ...[
                          const SizedBox(height: 12),
                          _CompletionCalendar(records: state.progressRecords),
                        ],
                        if (detailed) ...[
                          const SizedBox(height: 12),
                          _TrendPanel(records: state.progressRecords),
                        ],
                        const SizedBox(height: 26),
                        const SectionTitle('Signal balance'),
                        const SizedBox(height: 12),
                        _InsightLine(
                          title: strongest == null
                              ? 'No strongest area yet'
                              : '${state.goalById(strongest.key)?.title ?? 'One goal'} carried the week',
                          body: strongest == null
                              ? 'Complete a few planned actions and a useful pattern will begin to appear.'
                              : '${strongest.value} completed ${strongest.value == 1 ? 'action' : 'actions'}—this plan is currently working.',
                        ),
                        const SizedBox(height: 10),
                        _InsightLine(
                          title: _attentionTitle(state),
                          body: _attentionBody(state),
                        ),
                      ] else ...[
                        const SectionTitle(
                          'Goal completion',
                          caption: 'Progress across your current goals',
                        ),
                        const SizedBox(height: 12),
                        _GoalProgressList(
                          goals: state.goals,
                          actions: state.actions,
                        ),
                      ],
                      const SizedBox(height: 34),
                      SectionTitle(
                        'Weekly reflection',
                        caption: currentReflection == null
                            ? 'A few honest sentences are enough.'
                            : 'Reflected through ${shortDate(currentReflection.periodEnd)}',
                        trailing: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WeeklyReflectionScreen(),
                            ),
                          ),
                          child: Text(
                            currentReflection == null ? 'Reflect' : 'Open',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ReflectionPrompt(
                        reflection: currentReflection,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WeeklyReflectionScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _attentionTitle(dynamic state) {
    final attention = state.goals
        .where(
          (Goal goal) =>
              goal.pace == 'Behind' || goal.pace == 'Needs attention',
        )
        .toList();
    return attention.isEmpty
        ? 'No goals need attention'
        : '${attention.first.title} may need a smaller next step';
  }

  String _attentionBody(dynamic state) {
    final attention = state.goals
        .where(
          (Goal goal) =>
              goal.pace == 'Behind' || goal.pace == 'Needs attention',
        )
        .toList();
    return attention.isEmpty
        ? 'Current completion rates are within the expected range.'
        : 'Its current pace is below the plan. Try moving, shortening, or skipping an action before adding more.';
  }
}

class _ProgressIdentityCard extends StatelessWidget {
  const _ProgressIdentityCard({
    required this.name,
    required this.email,
    required this.avatarKey,
    required this.profileImageUrl,
    required this.completed,
    required this.planned,
  });

  final String name;
  final String email;
  final String? avatarKey;
  final String? profileImageUrl;
  final int completed;
  final int planned;

  @override
  Widget build(BuildContext context) => AppSurface(
    radius: 20,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        OnwardAvatar(
          name: name,
          avatarKey: avatarKey,
          profileImageUrl: profileImageUrl,
          radius: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$completed/$planned',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProgressDetailsGrid extends StatelessWidget {
  const _ProgressDetailsGrid({
    required this.goals,
    required this.completed,
    required this.planned,
    required this.consistency,
    required this.reflected,
  });

  final List<Goal> goals;
  final int completed;
  final int planned;
  final double consistency;
  final bool reflected;

  @override
  Widget build(BuildContext context) {
    final active = goals.where((goal) => goal.status == GoalStatus.active);
    final goalProgress = active.isEmpty
        ? 0.0
        : active.map((goal) => goal.progress).reduce((a, b) => a + b) /
              active.length;
    final details = [
      (
        label: 'Goals',
        value: goalProgress,
        caption: '${active.length} active',
        color: OnwardColors.purple,
        icon: Icons.flag_outlined,
      ),
      (
        label: 'Actions',
        value: planned == 0 ? 0.0 : (completed / planned).clamp(0.0, 1.0),
        caption: '$completed of $planned complete',
        color: OnwardColors.aqua,
        icon: Icons.check_circle_outline_rounded,
      ),
      (
        label: 'Consistency',
        value: consistency,
        caption: '${(consistency * 100).round()}% this week',
        color: OnwardColors.orange,
        icon: Icons.local_fire_department_outlined,
      ),
      (
        label: 'Reflection',
        value: reflected ? 1.0 : 0.0,
        caption: reflected ? 'Week reviewed' : 'Ready when you are',
        color: OnwardColors.green,
        icon: Icons.auto_awesome_outlined,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .86,
      ),
      itemBuilder: (context, index) {
        final detail = details[index];
        return AppSurface(
          radius: 17,
          padding: const EdgeInsets.all(13),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: detail.color.withValues(alpha: .12),
                      foregroundColor: detail.color,
                      child: Icon(detail.icon, size: 15),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        detail.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${(detail.value * 100).round()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: detail.color),
                ),
                const SizedBox(height: 5),
                ProgressLine(
                  value: detail.value,
                  color: detail.color,
                  height: 5,
                ),
                const SizedBox(height: 6),
                Text(
                  detail.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompletionCalendar extends StatelessWidget {
  const _CompletionCalendar({required this.records});

  final List<ProgressRecord> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final completedDays = records
        .where((record) => record.isCompleted)
        .map((record) => record.occurredAt)
        .where((date) => date.year == month.year && date.month == month.month)
        .map((date) => date.day)
        .toSet();
    const monthNames = [
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
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      radius: 22,
      depth: 1.05,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${monthNames[month.month - 1]} ${month.year}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: labels
                  .map(
                    (label) => Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: onwardMuted(context)),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 5),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 34,
              ),
              itemCount: offset + days,
              itemBuilder: (context, index) {
                if (index < offset) return const SizedBox.shrink();
                final day = index - offset + 1;
                final completed = completedDays.contains(day);
                final today = day == now.day;
                return Semantics(
                  label:
                      '${monthNames[month.month - 1]} $day${completed ? ', completed action' : ''}',
                  child: Center(
                    child: Container(
                      width: 29,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: completed
                          ? AppSurfaceStyle.pressed(
                              context,
                              radius: 15,
                              depth: .5,
                              shape: BoxShape.circle,
                            )
                          : BoxDecoration(
                              shape: BoxShape.circle,
                              border: today
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                            ),
                      child: Text(
                        '$day',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: completed
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontWeight: completed
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightBubbles extends StatelessWidget {
  const _InsightBubbles({
    required this.completed,
    required this.planned,
    required this.consistency,
    required this.previousCompleted,
  });

  final int completed;
  final int planned;
  final double consistency;
  final int previousCompleted;

  @override
  Widget build(BuildContext context) {
    final delta = completed - previousCompleted;
    return Semantics(
      label:
          '$completed of $planned actions complete, ${(consistency * 100).round()} percent consistency',
      child: AppSurface(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Row(
          children: [
            AppProgressRing(
              key: const ValueKey('insight-completion'),
              value: consistency,
              size: 116,
              strokeWidth: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(consistency * 100).round()}',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    '/100',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: onwardMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consistency >= .8
                        ? 'Strong momentum'
                        : consistency >= .5
                        ? 'Building momentum'
                        : 'A fresh day to begin',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$completed of $planned planned actions complete',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onwardMuted(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${delta >= 0 ? '+' : ''}$delta vs last week',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.records});

  final List<ProgressRecord> records;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
    radius: 22,
    depth: 1.05,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Four-week trend', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(
          'Completed actions',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
        ),
        const SizedBox(height: 12),
        _FourWeekChart(records: records),
      ],
    ),
  );
}

class _GoalProgressList extends StatelessWidget {
  const _GoalProgressList({required this.goals, required this.actions});

  final List<Goal> goals;
  final List<GoalAction> actions;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const _InsightLine(
        title: 'No goals yet',
        body: 'Create a goal to see its completion here.',
      );
    }
    return Column(
      children: goals.map((goal) {
        final goalActions = actions.where((action) => action.goalId == goal.id);
        final total = goalActions.length;
        final completed = goalActions
            .where((action) => action.status == ActionStatus.completed)
            .length;
        return AppSurface(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          pressed: goal.status == GoalStatus.completed,
          radius: 18,
          depth: .7,
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: onwardCategorySurface(context, goal.category),
                foregroundColor: onwardCategoryColor(goal.category),
                child: const Icon(Icons.flag_outlined, size: 19),
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
                      total == 0
                          ? 'No actions added'
                          : '$completed of $total actions complete',
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
                child: Text(
                  '${(goal.progress * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FourWeekChart extends StatelessWidget {
  const _FourWeekChart({required this.records});

  final List<ProgressRecord> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final values = List.generate(4, (index) {
      final end = now.subtract(Duration(days: index * 7));
      final start = end.subtract(const Duration(days: 7));
      return records
          .where(
            (record) =>
                record.isCompleted &&
                !record.occurredAt.isBefore(start) &&
                record.occurredAt.isBefore(end.add(const Duration(days: 1))),
          )
          .length;
    }).reversed.toList();
    final maxValue = values.fold<int>(1, math.max);
    return Semantics(
      label:
          'Four week completion history: ${values.join(', ')} actions completed',
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: SizedBox(
          height: 138,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final value = values[index];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$value',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: .62,
                            heightFactor: value == 0
                                ? .08
                                : (value / maxValue).clamp(.16, 1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: index == 3
                                    ? Theme.of(context).colorScheme.primary
                                    : [
                                        OnwardColors.rose,
                                        OnwardColors.aqua,
                                        OnwardColors.purple,
                                      ][index],
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        index == 3 ? 'Now' : '-${3 - index}w',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: onwardMuted(context)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => AppSurface(
    margin: const EdgeInsets.symmetric(vertical: 5),
    padding: const EdgeInsets.all(16),
    radius: 18,
    depth: .65,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(
          body,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
        ),
      ],
    ),
  );
}

class _ReflectionPrompt extends StatelessWidget {
  const _ReflectionPrompt({required this.reflection, required this.onTap});

  final WeeklyReflection? reflection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurface(
    radius: 20,
    depth: .9,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reflection == null
                          ? 'What helped this week?'
                          : '“${reflection!.whatWentWell.isNotEmpty ? reflection!.whatWentWell : reflection!.nextFocus}”',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reflection == null
                          ? 'Review the week'
                          : 'Review or add a new reflection',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: onwardMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}

class WeeklyReflectionScreen extends StatefulWidget {
  const WeeklyReflectionScreen({super.key});

  @override
  State<WeeklyReflectionScreen> createState() => _WeeklyReflectionScreenState();
}

class _WeeklyReflectionScreenState extends State<WeeklyReflectionScreen> {
  final _wentWell = TextEditingController();
  final _difficult = TextEditingController();
  final _next = TextEditingController();
  WeeklyReflection? _current;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_current != null ||
        _wentWell.text.isNotEmpty ||
        _difficult.text.isNotEmpty ||
        _next.text.isNotEmpty) {
      return;
    }
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    for (final reflection in context.appRead.reflections) {
      if (reflection.periodStart.year == start.year &&
          reflection.periodStart.month == start.month &&
          reflection.periodStart.day == start.day) {
        _current = reflection;
        _wentWell.text = reflection.whatWentWell;
        _difficult.text = reflection.whatWasDifficult;
        _next.text = reflection.nextFocus;
        break;
      }
    }
  }

  @override
  void dispose() {
    _wentWell.dispose();
    _difficult.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final dailyCompleted = List<int>.filled(7, 0);
    final dailyMissed = List<int>.filled(7, 0);
    final completedKeys = <String>{};
    final missedKeys = <String>{};
    final completedByGoal = <String, int>{};
    final missedByGoal = <String, int>{};

    bool isInWeek(DateTime date) {
      final local = date.toLocal();
      return !local.isBefore(weekStart) && local.isBefore(weekEnd);
    }

    void addDaily(List<int> values, DateTime date) {
      final day = date.toLocal().difference(weekStart).inDays;
      if (day >= 0 && day < values.length) values[day]++;
    }

    for (final record in state.weekProgressRecords) {
      final key = record.actionId == null
          ? 'record:${record.id}'
          : 'action:${record.actionId}';
      if (record.isCompleted && completedKeys.add(key)) {
        addDaily(dailyCompleted, record.occurredAt);
        completedByGoal.update(
          record.goalId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (record.isMissed && missedKeys.add(key)) {
        addDaily(dailyMissed, record.occurredAt);
        missedByGoal.update(
          record.goalId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    for (final action in state.weekActions) {
      final key = 'action:${action.id}';
      final completedAt = action.completedAt?.toLocal() ?? action.dueDate;
      if (action.status == ActionStatus.completed &&
          isInWeek(completedAt) &&
          completedKeys.add(key)) {
        addDaily(dailyCompleted, completedAt);
        completedByGoal.update(
          action.goalId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (action.status == ActionStatus.missed &&
          isInWeek(action.dueDate) &&
          missedKeys.add(key)) {
        addDaily(dailyMissed, action.dueDate);
        missedByGoal.update(
          action.goalId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final workedGoalIds = <String>{
      ...completedByGoal.keys,
      ...missedByGoal.keys,
      ...state.weekActions
          .where((action) => action.status == ActionStatus.inProgress)
          .map((action) => action.goalId),
    };
    final goalIds = <String>{
      ...state.weekActions.map((action) => action.goalId),
      ...workedGoalIds,
    };
    final goalMetrics =
        <({Goal goal, int planned, int completed, int missed})>[];
    for (final goalId in goalIds) {
      final goal = state.goalById(goalId);
      if (goal == null) continue;
      goalMetrics.add((
        goal: goal,
        planned: state.weekActions
            .where((action) => action.goalId == goalId)
            .length,
        completed: completedByGoal[goalId] ?? 0,
        missed: missedByGoal[goalId] ?? 0,
      ));
    }
    goalMetrics.sort((a, b) {
      final result = b.completed.compareTo(a.completed);
      return result != 0 ? result : b.planned.compareTo(a.planned);
    });

    final strongest = completedByGoal.entries.isEmpty
        ? null
        : completedByGoal.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final attention = missedByGoal.entries.isEmpty
        ? null
        : missedByGoal.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final upcoming = state.upcomingActions.take(3).toList();
    final planned = state.weekActions.length;
    final completed = completedKeys.length;
    final missed = missedKeys.length;
    final previousStart = weekStart.subtract(const Duration(days: 7));
    final previousCompleted = state.progressRecords
        .where(
          (record) =>
              record.isCompleted &&
              !record.occurredAt.isBefore(previousStart) &&
              record.occurredAt.isBefore(weekStart),
        )
        .map((record) => record.actionId ?? record.id)
        .toSet()
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly reflection')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 640,
          child: ListView(
            padding: pagePadding,
            children: [
              Text(
                'A week is information.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              _WeekOverviewCard(
                key: const ValueKey('weekly-overview'),
                dateRange:
                    '${shortDate(weekStart)} – ${shortDate(weekEnd.subtract(const Duration(days: 1)))}',
                completed: completed,
                planned: planned,
                missed: missed,
                workedGoals: workedGoalIds.length,
                consistency: state.weeklyConsistency,
                previousCompleted: previousCompleted,
              ),
              const SizedBox(height: 26),
              const SectionTitle(
                'Daily activity',
                caption: 'Completed and missed actions across the week',
              ),
              const SizedBox(height: 12),
              _WeeklyActivityChart(
                key: const ValueKey('weekly-activity-chart'),
                weekStart: weekStart,
                completed: dailyCompleted,
                missed: dailyMissed,
              ),
              const SizedBox(height: 26),
              const SectionTitle(
                'Goal progress',
                caption: 'How each goal contributed this week',
              ),
              const SizedBox(height: 12),
              _WeeklyGoalProgress(
                key: const ValueKey('weekly-goal-progress'),
                metrics: goalMetrics,
              ),
              const SizedBox(height: 26),
              const SectionTitle(
                'What the week says',
                caption: 'Patterns worth carrying forward',
              ),
              const SizedBox(height: 12),
              _WeeklyHighlights(
                strongestTitle: strongest == null
                    ? 'Your strongest area is still emerging'
                    : '${state.goalById(strongest.key)?.title ?? 'A goal'} led the week',
                strongestBody: strongest == null
                    ? 'Complete an action and a useful pattern will appear here.'
                    : '${strongest.value} completed ${strongest.value == 1 ? 'action' : 'actions'} moved it forward.',
                attentionTitle: attention == null
                    ? 'Nothing needs urgent attention'
                    : '${state.goalById(attention.key)?.title ?? 'A goal'} needs a reset',
                attentionBody: attention == null
                    ? 'There were no missed actions in this week’s plan.'
                    : '${attention.value} missed ${attention.value == 1 ? 'action' : 'actions'} may need a smaller next step.',
                needsAttention: attention != null,
              ),
              const SizedBox(height: 26),
              const SectionTitle(
                'Coming up',
                caption: 'Your next scheduled priorities',
              ),
              const SizedBox(height: 12),
              _UpcomingPriorities(actions: upcoming),
              const SizedBox(height: 30),
              const SectionTitle(
                'Reflect on the pattern',
                caption: 'Add the context the numbers cannot capture',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _wentWell,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What went well?',
                  hintText:
                      'A small win, a supportive condition, a useful choice…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _difficult,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What made things difficult?',
                  hintText: 'Energy, time, the size of the plan…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _next,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Top priority next week',
                  hintText: 'One priority or an adjustment',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: state.busy ? null : _save,
                child: state.busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _current == null
                            ? 'Save reflection'
                            : 'Update reflection',
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'All prompts are optional. An honest fragment still counts.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
              ),
              if (state.reflections.isNotEmpty) ...[
                const SizedBox(height: 38),
                const SectionTitle('Reflection history'),
                const SizedBox(height: 10),
                for (final reflection in state.reflections)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      reflection.whatWentWell.isEmpty
                          ? reflection.nextFocus
                          : reflection.whatWentWell,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${shortDate(reflection.periodStart)} – ${shortDate(reflection.periodEnd)}',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_wentWell.text.trim().isEmpty &&
        _difficult.text.trim().isEmpty &&
        _next.text.trim().isEmpty) {
      showToast(context, 'Add one thought before saving.');
      return;
    }
    final ok = await context.appRead.saveReflection(
      whatWentWell: _wentWell.text,
      whatWasDifficult: _difficult.text,
      nextFocus: _next.text,
    );
    if (ok && mounted) {
      showToast(context, 'Reflection saved.');
      Navigator.of(context).pop();
    }
  }
}

class _WeekOverviewCard extends StatelessWidget {
  const _WeekOverviewCard({
    super.key,
    required this.dateRange,
    required this.completed,
    required this.planned,
    required this.missed,
    required this.workedGoals,
    required this.consistency,
    required this.previousCompleted,
  });

  final String dateRange;
  final int completed;
  final int planned;
  final int missed;
  final int workedGoals;
  final double consistency;
  final int previousCompleted;

  @override
  Widget build(BuildContext context) {
    final percent = (consistency * 100).round();
    final delta = completed - previousCompleted;
    final comparison = delta == 0
        ? 'Same number completed as last week'
        : '${delta > 0 ? '+' : ''}$delta completed vs last week';
    final title = planned == 0
        ? 'A fresh week to shape'
        : consistency >= .8
        ? 'Strong follow-through'
        : consistency >= .5
        ? 'Steady momentum'
        : 'Room to reset the plan';

    return Semantics(
      container: true,
      label:
          'Week overview, $dateRange. $completed of $planned actions completed, $missed missed, $workedGoals goals worked on, $percent percent progress.',
      child: AppSurface(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        radius: 22,
        depth: 1.05,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Week overview',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    dateRange,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: onwardMuted(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  AppProgressRing(
                    value: consistency,
                    size: 102,
                    strokeWidth: 9,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          'complete',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: onwardMuted(context)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$completed of $planned planned actions completed',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: onwardMuted(context)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          comparison,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OverviewStat(value: '$completed', label: 'Done'),
                  ),
                  Expanded(
                    child: _OverviewStat(value: '$missed', label: 'Missed'),
                  ),
                  Expanded(
                    child: _OverviewStat(
                      value: '$workedGoals',
                      label: workedGoals == 1 ? 'Goal' : 'Goals',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 2),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: onwardMuted(context)),
      ),
    ],
  );
}

class _WeeklyActivityChart extends StatelessWidget {
  const _WeeklyActivityChart({
    super.key,
    required this.weekStart,
    required this.completed,
    required this.missed,
  });

  final DateTime weekStart;
  final List<int> completed;
  final List<int> missed;

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const fullLabels = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final now = DateTime.now();
    final totals = List.generate(
      7,
      (index) => completed[index] + missed[index],
    );
    final maxValue = totals.fold<int>(1, math.max);
    final primary = Theme.of(context).colorScheme.primary;

    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      radius: 22,
      depth: 1.05,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _ChartLegend(color: primary, label: 'Completed'),
                const _ChartLegend(color: OnwardColors.orange, label: 'Missed'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 164,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final date = weekStart.add(Duration(days: index));
                  final total = totals[index];
                  final isToday =
                      date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day;
                  final barHeight = total == 0
                      ? 5.0
                      : math.max(16.0, 78 * total / maxValue);
                  return Expanded(
                    child: Semantics(
                      label:
                          '${fullLabels[index]} ${shortDate(date)}, ${completed[index]} completed, ${missed[index]} missed',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$total',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 78,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 15,
                                  height: barHeight,
                                  child: total == 0
                                      ? ColoredBox(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        )
                                      : Column(
                                          children: [
                                            if (completed[index] > 0)
                                              Expanded(
                                                flex: completed[index],
                                                child: ColoredBox(
                                                  color: primary,
                                                  child:
                                                      const SizedBox.expand(),
                                                ),
                                              ),
                                            if (missed[index] > 0)
                                              Expanded(
                                                flex: missed[index],
                                                child: const ColoredBox(
                                                  color: OnwardColors.orange,
                                                  child: SizedBox.expand(),
                                                ),
                                              ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labels[index],
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: isToday
                                      ? primary
                                      : onwardMuted(context),
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: isToday
                                ? BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Text(
                              '${date.day}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: isToday
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : onwardMuted(context),
                                  ),
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
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: onwardMuted(context)),
      ),
    ],
  );
}

class _WeeklyGoalProgress extends StatelessWidget {
  const _WeeklyGoalProgress({super.key, required this.metrics});

  final List<({Goal goal, int planned, int completed, int missed})> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return AppSurface(
        padding: const EdgeInsets.all(18),
        radius: 22,
        child: Row(
          children: [
            Icon(
              Icons.flag_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Schedule an action to see goal-level analytics here.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
              ),
            ),
          ],
        ),
      );
    }

    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      radius: 22,
      depth: 1.05,
      child: Column(
        children: List.generate(metrics.length, (index) {
          final metric = metrics[index];
          final total = math.max(
            metric.planned,
            metric.completed + metric.missed,
          );
          final progress = total == 0 ? 0.0 : metric.completed / total;
          final color = onwardCategoryColor(metric.goal.category);
          final detail = metric.planned == 0
              ? '${metric.completed} completed'
              : '${metric.completed} of ${metric.planned} planned completed';
          return Column(
            children: [
              if (index > 0)
                Divider(color: Theme.of(context).colorScheme.outline),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  label:
                      '${metric.goal.title}, ${(progress * 100).round()} percent this week, ${metric.missed} missed',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              metric.goal.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(progress * 100).round()}%',
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ProgressLine(value: progress, color: color, height: 7),
                      const SizedBox(height: 7),
                      Text(
                        '$detail${metric.missed == 0 ? '' : ' · ${metric.missed} missed'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onwardMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _WeeklyHighlights extends StatelessWidget {
  const _WeeklyHighlights({
    required this.strongestTitle,
    required this.strongestBody,
    required this.attentionTitle,
    required this.attentionBody,
    required this.needsAttention,
  });

  final String strongestTitle;
  final String strongestBody;
  final String attentionTitle;
  final String attentionBody;
  final bool needsAttention;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    radius: 22,
    depth: .9,
    child: Column(
      children: [
        _HighlightRow(
          icon: Icons.trending_up_rounded,
          color: OnwardColors.green,
          title: strongestTitle,
          body: strongestBody,
        ),
        Divider(color: Theme.of(context).colorScheme.outline),
        _HighlightRow(
          icon: needsAttention
              ? Icons.adjust_rounded
              : Icons.check_circle_outline_rounded,
          color: needsAttention ? OnwardColors.orange : OnwardColors.aqua,
          title: attentionTitle,
          body: attentionBody,
        ),
      ],
    ),
  );
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                body,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _UpcomingPriorities extends StatelessWidget {
  const _UpcomingPriorities({required this.actions});

  final List<GoalAction> actions;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    radius: 22,
    depth: .8,
    child: actions.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No upcoming actions are scheduled yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onwardMuted(context),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Column(
            children: List.generate(actions.length, (index) {
              final action = actions[index];
              return Column(
                children: [
                  if (index > 0)
                    Divider(color: Theme.of(context).colorScheme.outline),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            action.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          shortDate(action.dueDate),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: onwardMuted(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
  );
}
