import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../domain/models.dart';
import 'goal_screens.dart';
import 'insights_screen.dart';
import 'profile_screens.dart';
import 'theme.dart';
import 'widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loaded = false;
  bool _unreadOnly = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.appRead.loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final visible = _unreadOnly
        ? state.notifications.where((item) => !item.isRead).toList()
        : state.notifications;
    return Scaffold(
      key: const ValueKey('notifications-screen'),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            key: const ValueKey('notification-settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationPreferencesScreen(),
              ),
            ),
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: state.loadNotifications,
          child: ContentWidth(
            maxWidth: 640,
            child: ListView(
              key: const ValueKey('notifications-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding,
              children: [
                _NotificationOverview(
                  unread: state.unreadNotifications,
                  onMarkAllRead: state.unreadNotifications == 0
                      ? null
                      : state.markAllNotificationsRead,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: !_unreadOnly,
                      onSelected: (_) => setState(() => _unreadOnly = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Unread'),
                      selected: _unreadOnly,
                      onSelected: (_) => setState(() => _unreadOnly = true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (state.notificationsLoading && state.notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visible.isEmpty)
                  EmptyView(
                    icon: _unreadOnly
                        ? Icons.mark_email_read_outlined
                        : Icons.notifications_none_rounded,
                    title: _unreadOnly ? 'All caught up' : 'No notifications',
                    body: _unreadOnly
                        ? 'You have read everything for now.'
                        : 'Reminders and progress updates will appear here.',
                  )
                else
                  for (final notification in visible) ...[
                    _NotificationCard(
                      notification: notification,
                      onTap: () => _openNotification(notification),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
    final state = context.appRead;
    await state.markNotificationRead(notification.id);
    if (!mounted) return;
    final goalId = notification.data['goalId']?.toString();
    final Widget? destination = goalId != null && goalId.isNotEmpty
        ? GoalDetailScreen(goalId: goalId)
        : switch (notification.type) {
            'PROGRESS_SUMMARY' => const InsightsScreen(),
            'WEEKLY_REFLECTION' => const WeeklyReflectionScreen(),
            _ => null,
          };
    if (destination != null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => destination));
    }
  }
}

class _NotificationOverview extends StatelessWidget {
  const _NotificationOverview({required this.unread, this.onMarkAllRead});

  final int unread;
  final Future<bool> Function()? onMarkAllRead;

  @override
  Widget build(BuildContext context) => AppSurface(
    radius: 22,
    color: Color.alphaBlend(
      Theme.of(context).colorScheme.primary.withValues(alpha: .06),
      Theme.of(context).colorScheme.surface,
    ),
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .12),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.notifications_active_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unread == 0
                    ? 'You are all caught up'
                    : '$unread unread ${unread == 1 ? 'update' : 'updates'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Reminders, milestones, and progress notes',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
              ),
            ],
          ),
        ),
        if (onMarkAllRead != null)
          TextButton(
            key: const ValueKey('mark-all-notifications-read'),
            onPressed: onMarkAllRead,
            child: const Text('Mark all read'),
          ),
      ],
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final goalId = notification.data['goalId']?.toString();
    final goal = goalId == null ? null : state.goalById(goalId);
    final color = goal == null
        ? _notificationColor(notification.type)
        : onwardCategoryColor(goal.category);
    final hasDestination =
        goalId != null ||
        notification.type == 'PROGRESS_SUMMARY' ||
        notification.type == 'WEEKLY_REFLECTION';
    final surface = Theme.of(context).colorScheme.surface;
    return AppSurface(
      key: ValueKey('notification-${notification.id}'),
      radius: 20,
      color: notification.isRead
          ? surface
          : Color.alphaBlend(color.withValues(alpha: .055), surface),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _notificationIcon(notification.type),
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: onwardMuted(context),
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          _notificationLabel(notification.type),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: color),
                        ),
                        Text(
                          '  ·  ${_notificationTime(context, notification)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: onwardMuted(context)),
                        ),
                        const Spacer(),
                        if (hasDestination)
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 19,
                            color: onwardMuted(context),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _notificationIcon(String type) => switch (type) {
  'ACTION_REMINDER' => Icons.check_circle_outline_rounded,
  'DUE_ACTION' => Icons.schedule_rounded,
  'MILESTONE' => Icons.flag_outlined,
  'PROGRESS_SUMMARY' => Icons.insights_rounded,
  'WEEKLY_REFLECTION' => Icons.auto_awesome_outlined,
  _ => Icons.notifications_none_rounded,
};

Color _notificationColor(String type) => switch (type) {
  'ACTION_REMINDER' => OnwardColors.aqua,
  'DUE_ACTION' => OnwardColors.orange,
  'MILESTONE' => OnwardColors.purple,
  'PROGRESS_SUMMARY' => OnwardColors.green,
  'WEEKLY_REFLECTION' => OnwardColors.purple,
  _ => OnwardColors.primary,
};

String _notificationLabel(String type) => switch (type) {
  'ACTION_REMINDER' => 'Action',
  'DUE_ACTION' => 'Due today',
  'MILESTONE' => 'Milestone',
  'PROGRESS_SUMMARY' => 'Progress',
  'WEEKLY_REFLECTION' => 'Reflection',
  _ => 'GoalSpring',
};

String _notificationTime(BuildContext context, AppNotification notification) {
  final date = (notification.scheduledAt ?? notification.createdAt).toLocal();
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24 &&
      now.year == date.year &&
      now.month == date.month &&
      now.day == date.day) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }
  return shortDate(date);
}
