export 'goal_wizard.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../domain/models.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showEditActionSheet(
  BuildContext context,
  Goal goal,
  GoalAction action,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => AddActionSheet(goal: goal, action: action),
);

Future<void> confirmDeleteAction(
  BuildContext context,
  GoalAction action,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this action?'),
      content: Text('“${action.title}” will be removed from the plan.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep action'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await context.appRead.deleteAction(action.id);
  }
}

class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.appRead.loadGoalDetail(widget.goalId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final goal = state.goalById(widget.goalId);
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(
          icon: Icons.search_off_rounded,
          title: 'Goal not found',
          body: 'It may have been removed on another device.',
        ),
      );
    }
    final actions = state.actionsForGoal(goal.id)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final openActions = actions
        .where(
          (action) =>
              action.status == ActionStatus.upcoming ||
              action.status == ActionStatus.inProgress,
        )
        .toList();
    final history = state
        .recordsForGoal(goal.id)
        .where(
          (record) => record.isCompleted || record.isSkipped || record.isMissed,
        )
        .toList();
    final otherActions = actions
        .where(
          (action) =>
              action.milestoneId == null &&
              (openActions.isEmpty || action.id != openActions.first.id),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          AppPopupMenuButton<String>(
            tooltip: 'Goal options',
            onSelected: (value) => _onOption(context, goal, value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit goal')),
              PopupMenuItem(
                value: goal.status == GoalStatus.paused ? 'resume' : 'pause',
                child: Text(
                  goal.status == GoalStatus.paused
                      ? 'Resume goal'
                      : 'Pause goal',
                ),
              ),
              if (goal.status != GoalStatus.completed)
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Mark goal complete'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Delete goal')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 720,
          child: ListView(
            padding: pagePadding,
            children: [
              _GoalTitlePill(goal: goal),
              const SizedBox(height: 12),
              _GoalStats(
                goal: goal,
                completed: actions
                    .where((action) => action.status == ActionStatus.completed)
                    .length,
                open: openActions.length,
              ),
              const SizedBox(height: 12),
              _GoalScheduleCard(goal: goal),
              if (goal.description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'What progress looks like',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  goal.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: onwardMuted(context)),
                ),
              ],
              if (openActions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailNextAction(
                  action: openActions.first,
                  onComplete: () async {
                    if (await state.completeAction(openActions.first.id) &&
                        context.mounted) {
                      showToast(context, 'Action complete.');
                    }
                  },
                ),
              ],
              const SizedBox(height: 24),
              SectionTitle(
                'Milestones',
                caption: goal.milestones.isEmpty
                    ? 'Break the goal into milestones.'
                    : '${goal.milestones.where((item) => item.isCompleted).length} of ${goal.milestones.length} reached',
                trailing: IconButton(
                  onPressed: () => _showMilestone(context, goal),
                  tooltip: 'Add milestone',
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              const SizedBox(height: 15),
              if (goal.milestones.isEmpty)
                _InlineEmpty(
                  text: 'No milestones yet.',
                  action: 'Add the first one',
                  onTap: () => _showMilestone(context, goal),
                )
              else
                for (final milestone in goal.milestones) ...[
                  Builder(
                    builder: (context) {
                      final linked = actions
                          .where((action) => action.milestoneId == milestone.id)
                          .toList();
                      return Column(
                        children: [
                          _MilestoneRow(
                            milestone: milestone,
                            completed: linked
                                .where(
                                  (action) =>
                                      action.status == ActionStatus.completed,
                                )
                                .length,
                            total: linked.length,
                            onToggle: () => state.updateMilestone(
                              milestone.copyWith(
                                isCompleted: !milestone.isCompleted,
                              ),
                            ),
                            onEdit: () => _showMilestone(
                              context,
                              goal,
                              milestone: milestone,
                            ),
                            onDelete: () =>
                                _deleteMilestone(context, milestone),
                          ),
                          for (final action in linked)
                            Padding(
                              padding: const EdgeInsets.only(left: 18),
                              child: _actionRow(context, goal, action),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              const SizedBox(height: 34),
              SectionTitle(
                'Other actions',
                caption: otherActions.isEmpty
                    ? 'No unassigned actions'
                    : '${otherActions.length} not linked to a milestone',
                trailing: IconButton(
                  onPressed: () => _showAction(context, goal),
                  tooltip: 'Add action',
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              const SizedBox(height: 10),
              if (otherActions.isEmpty)
                _InlineEmpty(
                  text: 'No additional unassigned actions yet.',
                  action: 'Add an action',
                  onTap: () => _showAction(context, goal),
                )
              else
                for (final action in otherActions)
                  _actionRow(context, goal, action),
              if (goal.why.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Purpose', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  goal.why,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .72),
                  ),
                ),
              ],
              const SizedBox(height: 34),
              const SectionTitle(
                'Recent history',
                caption: 'Progress stays visible, even when plans change.',
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                Text(
                  'Your completed and skipped actions will appear here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .68),
                  ),
                )
              else
                for (final action in history.take(5))
                  _HistoryRow(record: action),
              if (state.reflections.isNotEmpty) ...[
                const SizedBox(height: 34),
                const SectionTitle('Latest reflection'),
                const SizedBox(height: 12),
                _ReflectionExcerpt(reflection: state.reflections.first),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onOption(BuildContext context, Goal goal, String value) async {
    final state = context.appRead;
    if (value == 'edit') {
      await state.loadGoalDetail(goal.id);
      if (!context.mounted) return;
      final current = state.goalById(goal.id) ?? goal;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EditGoalScreen(goal: current)),
      );
      return;
    }
    if (value == 'pause' || value == 'resume') {
      final status = value == 'pause' ? GoalStatus.paused : GoalStatus.active;
      if (await state.setGoalStatus(goal.id, status) && context.mounted) {
        showToast(context, value == 'pause' ? 'Goal paused.' : 'Goal resumed.');
      }
      return;
    }
    if (value == 'complete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mark this goal complete?'),
          content: const Text('Its history will stay available for review.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Complete goal'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await state.setGoalStatus(goal.id, GoalStatus.completed);
      }
      return;
    }
    if (value == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete this goal?'),
          content: const Text(
            'This removes its milestones and actions. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep goal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final deleted = await state.deleteGoal(goal.id);
        if (deleted && context.mounted) Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showMilestone(
    BuildContext context,
    Goal goal, {
    Milestone? milestone,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddMilestoneSheet(goal: goal, milestone: milestone),
  );

  Future<void> _deleteMilestone(
    BuildContext context,
    Milestone milestone,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this milestone?'),
        content: const Text(
          'Its actions will stay in the goal and become unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep milestone'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.appRead.deleteMilestone(milestone);
    }
  }

  Future<void> _showAction(BuildContext context, Goal goal) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => AddActionSheet(goal: goal),
      );

  Widget _actionRow(BuildContext context, Goal goal, GoalAction action) =>
      ActionRow(
        action: action,
        goal: null,
        onComplete: () async {
          if (await context.appRead.completeAction(action.id) &&
              context.mounted) {
            showToast(context, 'Action complete.');
          }
        },
        onStart: () => context.appRead.startAction(action.id),
        onReopen: () => context.appRead.reopenAction(action.id),
        onMiss: () => context.appRead.missAction(action.id),
        onSkip: () => context.appRead.skipAction(action.id),
        onEdit: () => showEditActionSheet(context, goal, action),
        onDelete: () => confirmDeleteAction(context, action),
      );
}

class _GoalTitlePill extends StatelessWidget {
  const _GoalTitlePill({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final reflow = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final identity = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            goal.category.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: onwardMuted(context),
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 2),
          Text(goal.title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
    final avatar = CircleAvatar(
      radius: 20,
      backgroundColor: onwardCategorySurface(context, goal.category),
      foregroundColor: onwardCategoryColor(goal.category),
      child: const Icon(Icons.flag_outlined, size: 20),
    );

    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      radius: 24,
      depth: 1.1,
      child: reflow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [avatar, const SizedBox(width: 12), identity]),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: StatusBadge(goal.pace),
                ),
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                identity,
                const SizedBox(width: 8),
                StatusBadge(goal.pace),
              ],
            ),
    );
  }
}

class _GoalStats extends StatelessWidget {
  const _GoalStats({
    required this.goal,
    required this.completed,
    required this.open,
  });

  final Goal goal;
  final int completed;
  final int open;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${(goal.progress * 100).round()} percent progress, $completed completed actions, $open open actions',
    child: ExcludeSemantics(
      child: AppSurface(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(
          children: [
            AppProgressRing(
              value: goal.progress,
              size: 154,
              strokeWidth: 12,
              color: onwardCategoryColor(goal.category),
              child: Text(
                '${(goal.progress * 100).round()}%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: onwardCategoryColor(goal.category),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Current progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              '$completed actions complete · $open remaining',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _GoalMiniStat(
                    icon: Icons.check_circle_outline_rounded,
                    value: '$completed',
                    label: 'Done',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GoalMiniStat(
                    icon: Icons.timelapse_rounded,
                    value: '$open',
                    label: 'Open',
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

class _GoalMiniStat extends StatelessWidget {
  const _GoalMiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(15),
    ),
    child: MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$value $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailNextAction extends StatelessWidget {
  const _DetailNextAction({required this.action, required this.onComplete});

  final GoalAction action;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.fromLTRB(15, 11, 10, 11),
    radius: 18,
    depth: .85,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT ACTION',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: onwardMuted(context),
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                action.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${action.estimatedDuration} min  ·  ${action.preferredTime}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Mark complete',
          child: Checkbox(
            value: false,
            onChanged: (_) => onComplete(),
            shape: const CircleBorder(),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GoalScheduleCard extends StatelessWidget {
  const _GoalScheduleCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      radius: 22,
      depth: 1.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                'Schedule',
                style: Theme.of(context).textTheme.titleMedium,
              );
              final target = Text(
                goal.ongoing
                    ? 'Ongoing practice'
                    : 'Target ${shortDate(goal.targetDate)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
              );
              if (MediaQuery.textScalerOf(context).scale(1) >= 1.6) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 4), target],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  target,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.25,
            child: Row(
              children: List.generate(7, (index) {
                final date = monday.add(Duration(days: index));
                final planned = goal.preferredDays.contains(names[index]);
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        labels[index],
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: onwardMuted(context)),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: planned
                            ? AppSurfaceStyle.pressed(
                                context,
                                radius: 17,
                                depth: .55,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          '${date.day}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: planned
                                    ? Theme.of(context).colorScheme.primary
                                    : onwardMuted(context),
                                fontWeight: planned
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${goal.frequency} · ${goal.preferredTime}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.completed,
    required this.total,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Milestone milestone;
  final int completed;
  final int total;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AppSurface(
    margin: const EdgeInsets.symmetric(vertical: 5),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    pressed: milestone.isCompleted,
    radius: 16,
    depth: .7,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onToggle,
          tooltip: milestone.isCompleted
              ? 'Mark milestone upcoming'
              : 'Mark milestone complete',
          icon: Icon(
            milestone.isCompleted
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            color: milestone.isCompleted
                ? Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF60D5A3)
                      : const Color(0xFF0D7A4F)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                milestone.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (milestone.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(milestone.description),
              ],
              const SizedBox(height: 4),
              Text(
                'Due ${shortDate(milestone.targetDate)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (total > 0) ...[
                const SizedBox(height: 8),
                ProgressLine(value: completed / total, height: 5),
                const SizedBox(height: 4),
                Text(
                  '$completed of $total actions complete',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
        AppPopupMenuButton<String>(
          tooltip: 'Milestone options',
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit milestone')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'delete', child: Text('Delete milestone')),
          ],
        ),
      ],
    ),
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.text,
    required this.action,
    required this.onTap,
  });

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(18),
    pressed: true,
    radius: 18,
    depth: .6,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(action),
        ),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final ProgressRecord record;

  @override
  Widget build(BuildContext context) {
    final completed = record.isCompleted;
    final label = record.status.toLowerCase().replaceAll('_', ' ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        completed ? Icons.check_circle_rounded : Icons.remove_circle_outline,
        color: completed
            ? Theme.of(context).colorScheme.primary
            : onwardMuted(context),
      ),
      title: Text(record.actionTitle ?? 'Action update'),
      subtitle: Text(
        '${label[0].toUpperCase()}${label.substring(1)} · ${shortDate(record.occurredAt)}',
      ),
    );
  }
}

class _ReflectionExcerpt extends StatelessWidget {
  const _ReflectionExcerpt({required this.reflection});

  final WeeklyReflection reflection;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(18),
    radius: 20,
    depth: .75,
    child: Text(
      reflection.whatWentWell.isNotEmpty
          ? reflection.whatWentWell
          : reflection.nextFocus,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}

class EditGoalScreen extends StatefulWidget {
  const EditGoalScreen({super.key, required this.goal});

  final Goal goal;

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _why;
  late final TextEditingController _time;
  late final TextEditingController _customCategory;
  late String _category;
  late String _priority;
  late String _frequency;
  late Set<String> _days;
  late DateTime _targetDate;
  late bool _ongoing;
  late int _duration;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.goal.title);
    _description = TextEditingController(text: widget.goal.description);
    _why = TextEditingController(text: widget.goal.why);
    _frequency = _frequencyLabel(widget.goal.weeklyTarget);
    _time = TextEditingController(text: widget.goal.preferredTime);
    _customCategory = TextEditingController(
      text: widget.goal.customCategory ?? '',
    );
    _category = widget.goal.category;
    _priority = widget.goal.priority;
    _days = widget.goal.preferredDays.toSet();
    _targetDate = widget.goal.targetDate;
    _ongoing = widget.goal.ongoing;
    _duration = widget.goal.routineDurationMinutes;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _why.dispose();
    _time.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit goal')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 640,
          child: ListView(
            padding: pagePadding,
            children: [
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Goal title'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What progress looks like',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _why,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Why this matters',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              AppDropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items:
                    const [
                          'Health',
                          'Learning',
                          'Career',
                          'Personal',
                          'Finance',
                          'Relationships',
                          'Productivity',
                          'Custom',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              if (_category == 'Custom') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _customCategory,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Custom category',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Priority', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const ['Low', 'Medium', 'High']
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: _priority == value.toLowerCase(),
                        onSelected: (_) =>
                            setState(() => _priority = value.toLowerCase()),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Preferred days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map(
                          (day) => FilterChip(
                            label: Text(day),
                            selected: _days.contains(day),
                            onSelected: (_) => setState(
                              () => _days.contains(day)
                                  ? _days.remove(day)
                                  : _days.add(day),
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 18),
              AppDropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items:
                    const [
                          'Once a week',
                          '2 times a week',
                          '3 times a week',
                          '4 times a week',
                          'Most days',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _frequency = value!),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _time,
                decoration: const InputDecoration(labelText: 'Preferred time'),
              ),
              const SizedBox(height: 14),
              if (widget.goal.activeRoutineId != null) ...[
                AppDropdownButtonFormField<int>(
                  initialValue: _duration,
                  decoration: const InputDecoration(
                    labelText: 'Typical session',
                  ),
                  items: const [10, 15, 20, 30, 45, 60, 90]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _duration = value!),
                ),
                const SizedBox(height: 14),
              ],
              SwitchListTile(
                value: _ongoing,
                onChanged: (value) => setState(() => _ongoing = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Ongoing practice'),
                subtitle: const Text('No hard deadline'),
              ),
              if (!_ongoing)
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Target · ${shortDate(_targetDate)}'),
                ),
              const SizedBox(height: 28),
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
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) setState(() => _targetDate = value);
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3 || _days.isEmpty) {
      showToast(context, 'Add a title and at least one preferred day.');
      return;
    }
    if (!_validPreferredTime(_time.text)) {
      showToast(
        context,
        'Use Morning, Afternoon, Evening, Night, Flexible, or a valid time.',
      );
      return;
    }
    if (_category == 'Custom' && _customCategory.text.trim().length < 2) {
      showToast(context, 'Name the custom category.');
      return;
    }
    final ok = await context.appRead.updateGoal(
      widget.goal.copyWith(
        title: _title.text.trim(),
        description: _description.text.trim(),
        why: _why.text.trim(),
        category: _category,
        customCategory: _category == 'Custom'
            ? _customCategory.text.trim()
            : null,
        priority: _priority,
        frequency: _frequency,
        weeklyTarget: _weeklyTarget(_frequency),
        preferredDays: _days.toList(),
        preferredTime: _time.text.trim(),
        targetDate: _targetDate,
        ongoing: _ongoing,
        routineDurationMinutes: _duration,
      ),
      routineDurationMinutes: _duration,
    );
    if (ok && mounted) {
      final warning = context.appRead.message;
      if (warning != null) showToast(context, warning);
      Navigator.of(context).pop();
    }
  }

  String _frequencyLabel(int target) => switch (target) {
    1 => 'Once a week',
    2 => '2 times a week',
    4 => '4 times a week',
    >= 5 => 'Most days',
    _ => '3 times a week',
  };

  int _weeklyTarget(String value) => switch (value) {
    'Once a week' => 1,
    '2 times a week' => 2,
    '4 times a week' => 4,
    'Most days' => 7,
    _ => 3,
  };
}

class AddMilestoneSheet extends StatefulWidget {
  const AddMilestoneSheet({super.key, required this.goal, this.milestone});

  final Goal goal;
  final Milestone? milestone;

  @override
  State<AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<AddMilestoneSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.milestone?.title ?? '');
    _description = TextEditingController(
      text: widget.milestone?.description ?? '',
    );
    _date =
        widget.milestone?.targetDate ??
        (widget.goal.ongoing
            ? DateTime.now().add(const Duration(days: 90))
            : widget.goal.targetDate);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: ContentWidth(
      maxWidth: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.milestone == null ? 'Add a milestone' : 'Edit milestone',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Name a meaningful stage, not every tiny checkpoint.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Milestone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Target · ${shortDate(_date)}'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              child: Text(
                widget.milestone == null ? 'Add milestone' : 'Save milestone',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: widget.goal.ongoing
          ? DateTime.now().add(const Duration(days: 3650))
          : widget.goal.targetDate.add(const Duration(days: 365)),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      showToast(context, 'Give the milestone a clear name.');
      return;
    }
    final milestone = widget.milestone;
    final state = context.appRead;
    final saved = milestone == null
        ? await state.addMilestone(
                widget.goal.id,
                _title.text.trim(),
                description: _description.text.trim(),
                targetDate: _date,
              ) !=
              null
        : await state.updateMilestone(
            milestone.copyWith(
              title: _title.text.trim(),
              description: _description.text.trim(),
              targetDate: _date,
            ),
          );
    if (saved && mounted) Navigator.of(context).pop();
  }
}

class AddActionSheet extends StatefulWidget {
  const AddActionSheet({super.key, required this.goal, this.action});

  final Goal goal;
  final GoalAction? action;

  @override
  State<AddActionSheet> createState() => _AddActionSheetState();
}

class _AddActionSheetState extends State<AddActionSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _time;
  DateTime _date = DateTime.now();
  String _priority = 'medium';
  String? _milestoneId;
  int _minutes = 20;
  int _difficulty = 2;
  String _frequency = 'Once';

  @override
  void initState() {
    super.initState();
    final action = widget.action;
    _title = TextEditingController(text: action?.title ?? '');
    _description = TextEditingController(text: action?.description ?? '');
    _time = TextEditingController(
      text: action?.preferredTime ?? widget.goal.preferredTime,
    );
    _date = action?.dueDate ?? DateTime.now();
    _priority = action?.priority ?? 'medium';
    _milestoneId = action?.milestoneId;
    _minutes = action?.estimatedDuration ?? 20;
    _difficulty = action?.difficulty ?? 2;
    _frequency = action?.frequency ?? 'Once';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: ContentWidth(
      maxWidth: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.action == null ? 'Add an action' : 'Edit action',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Make it small enough to start without negotiating.'),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Action'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Helpful detail (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (widget.goal.milestones.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppDropdownButtonFormField<String?>(
                initialValue: _milestoneId,
                decoration: const InputDecoration(labelText: 'Milestone'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No milestone'),
                  ),
                  ...widget.goal.milestones.map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.title),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _milestoneId = value),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(shortDate(_date)),
                  ),
                  AppDropdownButtonFormField<int>(
                    initialValue: _minutes,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                    items: const [10, 15, 20, 30, 45, 60]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value min'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _minutes = value!),
                  ),
                ];
                if (constraints.maxWidth < 390) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fields[0],
                      const SizedBox(height: 12),
                      fields[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 10),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _time,
              decoration: const InputDecoration(labelText: 'Preferred time'),
            ),
            const SizedBox(height: 12),
            AppDropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const ['Once', 'Daily', 'Weekly', 'Monthly', 'Custom']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _frequency = value!),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low')),
                ButtonSegment(value: 'medium', label: Text('Normal')),
                ButtonSegment(value: 'high', label: Text('High')),
              ],
              selected: {_priority},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _priority = value.first),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Light')),
                ButtonSegment(value: 2, label: Text('Standard')),
                ButtonSegment(value: 3, label: Text('Stretch')),
              ],
              selected: {_difficulty},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _difficulty = value.first),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(
                widget.action == null ? 'Add action' : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: widget.goal.ongoing
          ? DateTime.now().add(const Duration(days: 3650))
          : widget.goal.targetDate.add(const Duration(days: 365)),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      showToast(context, 'Name the next concrete action.');
      return;
    }
    if (!_validPreferredTime(_time.text)) {
      showToast(
        context,
        'Use Morning, Afternoon, Evening, Night, Flexible, or a valid time.',
      );
      return;
    }
    final existing = widget.action;
    final action = existing == null
        ? GoalAction(
            id: newClientId(),
            goalId: widget.goal.id,
            milestoneId: _milestoneId,
            title: _title.text.trim(),
            description: _description.text.trim(),
            dueDate: _scheduledInstant(_date, _time.text),
            preferredTime: _time.text.trim(),
            estimatedDuration: _minutes,
            priority: _priority,
            difficulty: _difficulty,
            frequency: _frequency,
          )
        : existing.copyWith(
            title: _title.text.trim(),
            description: _description.text.trim(),
            milestoneId: _milestoneId,
            clearMilestone: _milestoneId == null,
            dueDate: _scheduledInstant(_date, _time.text),
            preferredTime: _time.text.trim(),
            estimatedDuration: _minutes,
            priority: _priority,
            difficulty: _difficulty,
            frequency: _frequency,
          );
    final state = context.appRead;
    final success = existing == null
        ? await state.addAction(action) != null
        : await state.updateAction(action);
    if (success && mounted) Navigator.of(context).pop();
  }

  DateTime _scheduledInstant(DateTime day, String preferredTime) {
    final trimmed = preferredTime.trim();
    final twentyFourHour = RegExp(
      r'^([01]\d|2[0-3]):([0-5]\d)$',
    ).firstMatch(trimmed);
    if (twentyFourHour != null) {
      return DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(twentyFourHour.group(1)!),
        int.parse(twentyFourHour.group(2)!),
      );
    }
    final twelveHour = RegExp(
      r'^(\d{1,2}):([0-5]\d)\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (twelveHour != null) {
      var hour = int.parse(twelveHour.group(1)!);
      final isPm = twelveHour.group(3)!.toUpperCase() == 'PM';
      if (hour == 12) hour = 0;
      if (isPm) hour += 12;
      return DateTime(
        day.year,
        day.month,
        day.day,
        hour,
        int.parse(twelveHour.group(2)!),
      );
    }
    final hour = switch (trimmed.toLowerCase()) {
      'morning' => 8,
      'afternoon' => 14,
      'evening' => 19,
      'night' => 21,
      _ => 9,
    };
    return DateTime(day.year, day.month, day.day, hour);
  }
}

bool _validPreferredTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      const {
        'morning',
        'afternoon',
        'evening',
        'night',
        'flexible',
        'anytime',
      }.contains(trimmed.toLowerCase())) {
    return true;
  }
  if (RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(trimmed)) return true;
  final twelveHour = RegExp(
    r'^(\d{1,2}):[0-5]\d\s*([AP]M)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (twelveHour == null) return false;
  final hour = int.parse(twelveHour.group(1)!);
  return hour >= 1 && hour <= 12;
}
