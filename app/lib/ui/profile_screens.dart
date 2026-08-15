import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../domain/models.dart';
import 'avatar.dart';
import 'theme.dart';
import 'widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final name = state.user?.name ?? 'Friend';
    return SafeArea(
      child: ContentWidth(
        maxWidth: 700,
        child: ListView(
          padding: pagePadding,
          children: [
            Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 3),
            Text(
              'Manage your account and preferences',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
            ),
            const SizedBox(height: 18),
            AppSurface(
              padding: const EdgeInsets.all(18),
              radius: 24,
              depth: 1.05,
              child: Row(
                children: [
                  OnwardAvatar(
                    name: name,
                    avatarKey: state.user?.avatarKey,
                    profileImageUrl: state.user?.profileImageUrl,
                    radius: 34,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          state.demo
                              ? 'Exploring GoalSpring'
                              : state.user?.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: onwardMuted(context)),
                        ),
                      ],
                    ),
                  ),
                  if (!state.demo)
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                      tooltip: 'Edit profile',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppSurface(
              padding: const EdgeInsets.symmetric(vertical: 16),
              radius: 22,
              depth: .9,
              child: Row(
                children: [
                  Expanded(
                    child: _ProfileStat(
                      value: '${state.activeGoals}',
                      label: 'Active goals',
                    ),
                  ),
                  Expanded(
                    child: _ProfileStat(
                      value: '${state.completedThisWeek}',
                      label: 'This week',
                    ),
                  ),
                  Expanded(
                    child: _ProfileStat(
                      value: '${(state.weeklyConsistency * 100).round()}%',
                      label: 'Plan kept',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const _GroupLabel('SUPPORT'),
            _SettingsRow(
              icon: Icons.person_outline_rounded,
              title: 'Personal details',
              subtitle: 'Account identity and profile',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EditProfileScreen(),
                ),
              ),
            ),
            _SettingsRow(
              icon: Icons.nightlight_outlined,
              title: 'Preferences',
              subtitle: 'Your schedule and planning details',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PreferencesScreen(),
                ),
              ),
            ),
            _SettingsRow(
              icon: Icons.tune_rounded,
              title: 'Profile controls',
              subtitle: 'Manage preferences and account',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
            _SettingsRow(
              icon: Icons.notifications_none_rounded,
              title: 'Notification settings',
              subtitle: 'Reminders that respect your day',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationPreferencesScreen(),
                ),
              ),
            ),
            _SettingsRow(
              icon: Icons.shield_outlined,
              title: 'Privacy preferences',
              subtitle: 'Manage your data and privacy',
              onTap: () => _showInfo(
                context,
                'Privacy preferences',
                'Your account data is isolated on the server. Passwords never enter the app after authentication, and session tokens are kept in secure device storage.',
              ),
            ),
            const SizedBox(height: 24),
            const _GroupLabel('SUPPORT'),
            _SettingsRow(
              icon: Icons.help_outline_rounded,
              title: 'Help & support',
              onTap: () => _showInfo(
                context,
                'How GoalSpring works',
                'GoalSpring organizes your direction into milestones and concrete actions, then brings only the useful next steps into Today. Progress considers timing, planned actions, and follow-through—not just a percentage.',
              ),
            ),
            _SettingsRow(
              icon: Icons.lock_outline_rounded,
              title: 'Privacy & data',
              onTap: () => _showInfo(
                context,
                'Privacy',
                'Your account data is isolated on the server. Passwords never enter the app after authentication, and session tokens are kept in secure device storage.',
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: Text(state.demo ? 'Exit preview' : 'Sign out'),
            ),
            const SizedBox(height: 12),
            Text(
              'GoalSpring 1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .68),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final state = context.appRead;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(state.demo ? 'Exit preview?' : 'Sign out?'),
        content: Text(
          state.demo
              ? 'Your sample changes will be cleared.'
              : 'Your saved goals will remain safely in your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(state.demo ? 'Leave' : 'Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.signOut();
  }

  Future<void> _showInfo(BuildContext context, String title, String body) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: ContentWidth(
            maxWidth: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),
                Text(body, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: onwardMuted(context)),
      ),
    ],
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppSurface(
    margin: const EdgeInsets.symmetric(vertical: 5),
    radius: 18,
    depth: .6,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        minTileHeight: 64,
        leading: AppSurface(
          pressed: true,
          shape: BoxShape.circle,
          depth: .5,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: onTap == null ? Theme.of(context).disabledColor : null,
        ),
        onTap: onTap,
      ),
    ),
  );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _profileImageUrl;
  late String _avatarKey;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.appRead.user?.name ?? '');
    _profileImageUrl = TextEditingController(
      text: context.appRead.user?.profileImageUrl ?? '',
    );
    _avatarKey = normalizeOnwardAvatar(context.appRead.user?.avatarKey);
  }

  @override
  void dispose() {
    _name.dispose();
    _profileImageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 560,
          child: ListView(
            padding: pagePadding,
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _profileImageUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Profile photo URL (optional)',
                  hintText: 'https://example.com/photo.jpg',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Choose your avatar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              OnwardAvatarHeadPicker(
                avatarKey: _avatarKey,
                onChanged: (value) => setState(() => _avatarKey = value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                enabled: false,
                initialValue: context.app.user?.email ?? '',
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Save profile')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      showToast(context, 'Enter your name.');
      return;
    }
    final photo = _profileImageUrl.text.trim();
    final uri = Uri.tryParse(photo);
    if (photo.isNotEmpty &&
        (uri == null ||
            (uri.scheme != 'http' && uri.scheme != 'https') ||
            uri.host.isEmpty)) {
      showToast(context, 'Use a valid http or https profile photo URL.');
      return;
    }
    final ok = await context.appRead.updateProfileName(
      _name.text.trim(),
      avatarKey: _avatarKey,
      profileImageUrl: photo,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }
}

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late Set<String> _days;
  late String _time;
  late String _style;
  late int _frequency;
  late final TextEditingController _constraints;

  @override
  void initState() {
    super.initState();
    final state = context.appRead;
    _days = state.preferredDays.toSet();
    _time = state.preferredTime;
    _style = state.progressStyle;
    _frequency = state.workingFrequency;
    _constraints = TextEditingController(text: state.personalConstraints);
  }

  @override
  void dispose() {
    _constraints.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeOptions = ['Morning', 'Afternoon', 'Evening', 'Flexible'];
    if (!timeOptions.contains(_time)) timeOptions.add(_time);
    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 600,
          child: ListView(
            padding: pagePadding,
            children: [
              Text(
                'Default schedule',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'New goals can begin here, then be adjusted individually.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .6),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Days that usually work',
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
              const SizedBox(height: 22),
              AppDropdownButtonFormField<String>(
                initialValue: _time,
                decoration: const InputDecoration(labelText: 'Preferred time'),
                items: timeOptions
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _time = value!),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _constraints,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Scheduling constraints',
                  hintText: 'Shift work, unavailable days, fixed commitments…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              AppDropdownButtonFormField<int>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Times per week'),
                items: const [1, 2, 3, 4, 7]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value == 7 ? 'Most days' : '$value times'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _frequency = value!),
              ),
              const SizedBox(height: 14),
              AppDropdownButtonFormField<String>(
                initialValue: _style,
                decoration: const InputDecoration(labelText: 'Progress style'),
                items: const ['Gentle', 'Balanced', 'Detailed']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _style = value!),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final ok = await context.appRead.updatePreferences(
                    days: _days.toList(),
                    time: _time,
                    style: _style,
                    frequency: _frequency,
                    constraints: _constraints.text,
                  );
                  if (ok && context.mounted) {
                    showToast(context, 'Preferences updated.');
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save preferences'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final settings = state.notificationSettings;
    final quietStarts = <String>{
      '20:00',
      '21:00',
      '22:00',
      '23:00',
      settings.quietHoursStart,
    }.toList()..sort();
    final quietEnds = <String>{
      '06:00',
      '07:00',
      '08:00',
      '09:00',
      settings.quietHoursEnd,
    }.toList()..sort();
    Future<void> update(NotificationSettings value) async {
      final ok = await state.updateNotifications(value);
      if (!ok && context.mounted) {
        showToast(
          context,
          state.message ?? 'Could not save notification settings.',
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 640,
          child: ListView(
            padding: pagePadding,
            children: [
              Text(
                'Helpful, never relentless.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose which moments deserve a nudge. GoalSpring will never use reminders to shame a missed day.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .6),
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                value: settings.pushEnabled,
                onChanged: (value) =>
                    update(settings.copyWith(pushEnabled: value)),
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow notifications'),
                subtitle: const Text('Master control for GoalSpring reminders'),
              ),
              const Divider(),
              SwitchListTile(
                value: settings.actionReminders && settings.pushEnabled,
                onChanged: settings.pushEnabled
                    ? (value) =>
                          update(settings.copyWith(actionReminders: value))
                    : null,
                contentPadding: EdgeInsets.zero,
                title: const Text('Upcoming actions'),
                subtitle: const Text('A gentle reminder before planned work'),
              ),
              SwitchListTile(
                value: settings.dueActionReminders && settings.pushEnabled,
                onChanged: settings.pushEnabled
                    ? (value) =>
                          update(settings.copyWith(dueActionReminders: value))
                    : null,
                contentPadding: EdgeInsets.zero,
                title: const Text('Due actions'),
                subtitle: const Text('When an action reaches its due day'),
              ),
              SwitchListTile(
                value: settings.milestoneReminders && settings.pushEnabled,
                onChanged: settings.pushEnabled
                    ? (value) =>
                          update(settings.copyWith(milestoneReminders: value))
                    : null,
                contentPadding: EdgeInsets.zero,
                title: const Text('Milestones'),
                subtitle: const Text('When a meaningful stage is approaching'),
              ),
              SwitchListTile(
                value: settings.progressSummaries && settings.pushEnabled,
                onChanged: settings.pushEnabled
                    ? (value) =>
                          update(settings.copyWith(progressSummaries: value))
                    : null,
                contentPadding: EdgeInsets.zero,
                title: const Text('Progress summaries'),
                subtitle: const Text('A concise view of what moved'),
              ),
              SwitchListTile(
                value: settings.weeklyReflection && settings.pushEnabled,
                onChanged: settings.pushEnabled
                    ? (value) =>
                          update(settings.copyWith(weeklyReflection: value))
                    : null,
                contentPadding: EdgeInsets.zero,
                title: const Text('Weekly reflection'),
                subtitle: const Text('Sunday evening by default'),
              ),
              const SizedBox(height: 18),
              const _GroupLabel('QUIET HOURS'),
              SwitchListTile(
                value: settings.quietHours,
                onChanged: (value) =>
                    update(settings.copyWith(quietHours: value)),
                contentPadding: EdgeInsets.zero,
                title: const Text('Protect quiet hours'),
                subtitle: Text(
                  settings.quietHours
                      ? 'No reminders from ${settings.quietHoursStart} to ${settings.quietHoursEnd}'
                      : 'Reminders may arrive at any time',
                ),
              ),
              if (settings.quietHours) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownButtonFormField<String>(
                        initialValue: settings.quietHoursStart,
                        decoration: const InputDecoration(labelText: 'From'),
                        items: quietStarts
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            update(settings.copyWith(quietHoursStart: value)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownButtonFormField<String>(
                        initialValue: settings.quietHoursEnd,
                        decoration: const InputDecoration(labelText: 'Until'),
                        items: quietEnds
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            update(settings.copyWith(quietHoursEnd: value)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const _GroupLabel('REMINDER LEAD TIME'),
              AppDropdownButtonFormField<int>(
                initialValue: settings.reminderMinutesBefore,
                decoration: const InputDecoration(
                  labelText: 'Remind me before an action',
                ),
                items:
                    <int>{0, 15, 30, 60, 1440, settings.reminderMinutesBefore}
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value == 0
                                  ? 'At the scheduled time'
                                  : value == 1440
                                  ? '1 day before'
                                  : value >= 60
                                  ? '${value ~/ 60} hour before'
                                  : '$value minutes before',
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    update(settings.copyWith(reminderMinutesBefore: value)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 620,
          child: ListView(
            padding: pagePadding,
            children: [
              const _GroupLabel('APPEARANCE'),
              RadioGroup<ThemeMode>(
                groupValue: state.themeMode,
                onChanged: (value) {
                  if (value != null) state.setTheme(value);
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text('Use device setting'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text('Light'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text('Dark'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _GroupLabel('ACCESSIBILITY'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.text_fields_rounded),
                title: Text('Text size'),
                subtitle: Text('GoalSpring follows your device text setting'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.motion_photos_off_outlined),
                title: Text('Reduced motion'),
                subtitle: Text('Follows your device accessibility setting'),
              ),
              const SizedBox(height: 20),
              const _GroupLabel('DATA'),
              _SettingsRow(
                icon: Icons.sync_rounded,
                title: 'Refresh saved data',
                subtitle: state.offline
                    ? 'Currently showing offline data'
                    : 'Last changes are synchronized',
                onTap: () async {
                  await state.refresh();
                  if (context.mounted) {
                    showToast(
                      context,
                      state.offline
                          ? 'Still offline. Saved data is available.'
                          : 'Everything is up to date.',
                    );
                  }
                },
              ),
              _SettingsRow(
                icon: Icons.file_download_outlined,
                title: 'Export my data',
                subtitle: state.demo
                    ? 'Unavailable in preview mode'
                    : 'Review and copy your GoalSpring data as JSON',
                onTap: state.demo || state.busy
                    ? null
                    : () => _showExport(context, state),
              ),
              _SettingsRow(
                icon: Icons.delete_outline_rounded,
                title: 'Delete account',
                subtitle: state.demo
                    ? 'Unavailable in preview mode'
                    : 'Permanently remove your account and saved data',
                onTap: state.demo || state.busy
                    ? null
                    : () => _confirmDelete(context, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExport(BuildContext context, AppState state) async {
    final data = await state.exportAccountData();
    if (!context.mounted) return;
    if (data == null) {
      showToast(context, state.message ?? 'Could not export your data.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DataExportScreen(
          source: const JsonEncoder.withIndent('  ').convert(data),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final continueDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account and data?'),
        content: const Text(
          'This removes your goals, actions, reflections, and account. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep account'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (continueDelete != true || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await state.deleteAccount();
    if (deleted && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (context.mounted) {
      showToast(context, state.message ?? 'Could not delete your account.');
    }
  }
}

class _DataExportScreen extends StatelessWidget {
  const _DataExportScreen({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your data'),
      actions: [
        IconButton(
          tooltip: 'Copy export',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: source));
            if (context.mounted) showToast(context, 'Export copied.');
          },
          icon: const Icon(Icons.copy_all_outlined),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: pagePadding,
        child: SelectableText(
          source,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ),
    ),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm permanent deletion'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Type DELETE to confirm. This is your final check.'),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmation,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Type DELETE to confirm',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: _confirmation.text == 'DELETE'
            ? () => Navigator.pop(context, true)
            : null,
        child: const Text('Delete forever'),
      ),
    ],
  );
}
