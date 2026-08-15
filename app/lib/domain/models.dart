import 'dart:math';

enum GoalStatus { active, paused, completed }

enum ActionStatus { upcoming, inProgress, completed, missed, skipped }

String _statusName(Enum value) => value.name;

String newClientId() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  return 'c$timestamp${List.generate(16, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
}

DateTime _date(Object? value, [DateTime? fallback]) =>
    DateTime.tryParse(value?.toString() ?? '') ?? fallback ?? DateTime.now();

/// Serializes a user-selected calendar date without leaking the device offset.
String utcDateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day).toIso8601String();

List<String> _strings(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];

String _titleCase(String value) {
  if (value.isEmpty) return value;
  final lower = value.toLowerCase().replaceAll('_', ' ');
  return lower[0].toUpperCase() + lower.substring(1);
}

String _displayActionFrequency(String value) => switch (value.toUpperCase()) {
  'DAILY' => 'Daily',
  'WEEKLY' => 'Weekly',
  'MONTHLY' => 'Monthly',
  'CUSTOM' => 'Custom',
  _ => 'Once',
};

String _dayLabel(String value) => switch (value.toUpperCase()) {
  'MONDAY' => 'Mon',
  'TUESDAY' => 'Tue',
  'WEDNESDAY' => 'Wed',
  'THURSDAY' => 'Thu',
  'FRIDAY' => 'Fri',
  'SATURDAY' => 'Sat',
  'SUNDAY' => 'Sun',
  _ => value,
};

String _apiDay(String value) => switch (value.substring(0, 3).toLowerCase()) {
  'mon' => 'MONDAY',
  'tue' => 'TUESDAY',
  'wed' => 'WEDNESDAY',
  'thu' => 'THURSDAY',
  'fri' => 'FRIDAY',
  'sat' => 'SATURDAY',
  _ => 'SUNDAY',
};

String _displayFrequency(String value, int weeklyTarget) =>
    switch (value.toUpperCase()) {
      'ONCE' => 'Once',
      'DAILY' => 'Most days',
      'MONTHLY' => 'Monthly',
      'CUSTOM' || 'WEEKLY' => '$weeklyTarget times a week',
      _ => value,
    };

String _apiFrequency(String value) {
  final lower = value.toLowerCase();
  if (lower == 'custom') return 'CUSTOM';
  if (lower == 'weekly') return 'WEEKLY';
  if (lower == 'daily') return 'DAILY';
  if (lower.contains('most') || lower.contains('daily')) return 'DAILY';
  if (lower.contains('month')) return 'MONTHLY';
  if (lower == 'once') return 'ONCE';
  return 'WEEKLY';
}

String? _apiTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'flexible') return null;
  if (RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(trimmed)) {
    return trimmed;
  }
  final preset = switch (trimmed.toLowerCase()) {
    'morning' => '08:00',
    'afternoon' => '14:00',
    'evening' => '19:00',
    'night' => '21:00',
    'anytime' => null,
    _ => '',
  };
  if (preset != '') return preset;
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  final period = match.group(3)!.toUpperCase();
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return '${hour.toString().padLeft(2, '0')}:$minute';
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.avatarKey = 'neutral-violet-navy',
    this.timezone = 'UTC',
    this.onboardingCompleted = false,
  });

  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String avatarKey;
  final String timezone;
  final bool onboardingCompleted;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Friend',
    email: json['email']?.toString() ?? '',
    profileImageUrl: (json['profileImageUrl'] ?? json['profileImage'])
        ?.toString(),
    avatarKey: json['avatarKey']?.toString() ?? 'neutral-violet-navy',
    timezone: json['timezone']?.toString() ?? 'UTC',
    onboardingCompleted:
        json['onboardingCompleted'] == true ||
        json['onboardingComplete'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'profileImageUrl': profileImageUrl,
    'avatarKey': avatarKey,
    'timezone': timezone,
    'onboardingCompleted': onboardingCompleted,
  };

  AppUser copyWith({
    String? name,
    String? profileImageUrl,
    bool clearProfileImage = false,
    String? avatarKey,
    String? timezone,
    bool? onboardingCompleted,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    email: email,
    profileImageUrl: clearProfileImage
        ? null
        : profileImageUrl ?? this.profileImageUrl,
    avatarKey: avatarKey ?? this.avatarKey,
    timezone: timezone ?? this.timezone,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.why,
    required this.category,
    required this.startDate,
    required this.targetDate,
    required this.frequency,
    required this.preferredDays,
    required this.preferredTime,
    this.description = '',
    this.priority = 'medium',
    this.status = GoalStatus.active,
    this.progress = 0,
    this.milestones = const [],
    this.actions = const [],
    this.colorValue = 0xFF315D4C,
    this.weeklyTarget = 3,
    this.paceStatus,
    this.customCategory,
    this.activeRoutineId,
    this.routineDurationMinutes = 30,
    this.ongoing = false,
    this.progressRecords = const [],
  });

  final String id;
  final String title;
  final String why;
  final String description;
  final String category;
  final String priority;
  final GoalStatus status;
  final DateTime startDate;
  final DateTime targetDate;
  final String frequency;
  final List<String> preferredDays;
  final String preferredTime;
  final double progress;
  final List<Milestone> milestones;
  final List<GoalAction> actions;
  final int colorValue;
  final int weeklyTarget;
  final String? paceStatus;
  final String? customCategory;
  final String? activeRoutineId;
  final int routineDurationMinutes;
  final bool ongoing;
  final List<ProgressRecord> progressRecords;

  factory Goal.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString().toLowerCase();
    final status = statusName == 'completed'
        ? GoalStatus.completed
        : statusName == 'paused'
        ? GoalStatus.paused
        : GoalStatus.active;
    final rawProgress = json['progress'];
    final progressValue = rawProgress is Map
        ? rawProgress['progress']
        : rawProgress;
    final progress = progressValue is num
        ? (progressValue > 1 ? progressValue / 100 : progressValue).toDouble()
        : 0.0;
    final weeklyTarget = (json['weeklyTarget'] as num?)?.toInt() ?? 3;
    final rawColor = json['color']?.toString();
    final parsedColor = rawColor != null && rawColor.startsWith('#')
        ? int.tryParse('FF${rawColor.substring(1)}', radix: 16)
        : null;
    final routines = json['routines'];
    final activeRoutine =
        routines is List && routines.isNotEmpty && routines.first is Map
        ? Map<String, dynamic>.from(routines.first as Map)
        : const <String, dynamic>{};
    return Goal(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled goal',
      why:
          json['whyItMatters']?.toString() ??
          json['why']?.toString() ??
          json['motivation']?.toString() ??
          '',
      description: json['description']?.toString() ?? '',
      category: _titleCase(json['category']?.toString() ?? 'Personal'),
      customCategory: json['customCategory']?.toString(),
      priority: json['priority']?.toString().toLowerCase() ?? 'medium',
      status: status,
      startDate: _date(json['startDate']),
      targetDate: _date(
        json['targetDate'],
        DateTime.now().add(const Duration(days: 90)),
      ),
      frequency: _displayFrequency(
        json['frequency']?.toString() ?? 'WEEKLY',
        weeklyTarget,
      ),
      preferredDays: _strings(json['preferredDays']).map(_dayLabel).toList(),
      preferredTime: json['preferredTime']?.toString() ?? 'Flexible',
      progress: progress.clamp(0, 1),
      milestones: (json['milestones'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Milestone.fromJson)
          .toList(),
      actions: (json['actions'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GoalAction.fromJson)
          .toList(),
      colorValue:
          (json['colorValue'] as num?)?.toInt() ?? parsedColor ?? 0xFF315D4C,
      weeklyTarget: weeklyTarget,
      paceStatus: rawProgress is Map
          ? _titleCase(rawProgress['status']?.toString() ?? '')
          : json['paceStatus']?.toString(),
      activeRoutineId:
          activeRoutine['id']?.toString() ??
          json['activeRoutineId']?.toString(),
      routineDurationMinutes:
          (activeRoutine['durationMinutes'] as num?)?.toInt() ??
          (json['routineDurationMinutes'] as num?)?.toInt() ??
          30,
      ongoing: json['ongoing'] == true || json['targetDate'] == null,
      progressRecords: (json['progressRecords'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ProgressRecord.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'whyItMatters': why,
    'description': description,
    'category': category,
    'priority': priority,
    'status': _statusName(status),
    'startDate': utcDateOnly(startDate),
    'targetDate': ongoing ? null : utcDateOnly(targetDate),
    'frequency': frequency,
    'preferredDays': preferredDays,
    'preferredTime': preferredTime,
    'progress': progress,
    'milestones': milestones.map((item) => item.toJson()).toList(),
    'actions': actions.map((item) => item.toJson()).toList(),
    'colorValue': colorValue,
    'weeklyTarget': weeklyTarget,
    'paceStatus': paceStatus,
    'customCategory': customCategory,
    'activeRoutineId': activeRoutineId,
    'routineDurationMinutes': routineDurationMinutes,
    'ongoing': ongoing,
    'progressRecords': progressRecords.map((item) => item.toJson()).toList(),
  };

  Map<String, dynamic> toApiJson() => {
    'title': title,
    'description': description.isEmpty ? null : description,
    'whyItMatters': why.isEmpty ? null : why,
    'category': category.toUpperCase().replaceAll(' ', '_'),
    'customCategory': category.toUpperCase() == 'CUSTOM'
        ? customCategory
        : null,
    'priority': priority.toUpperCase(),
    'status': status.name.toUpperCase(),
    'startDate': utcDateOnly(startDate),
    'targetDate': ongoing ? null : utcDateOnly(targetDate),
    'frequency': _apiFrequency(frequency),
    'preferredDays': preferredDays.map(_apiDay).toList(),
    'preferredTime': _apiTime(preferredTime),
    'weeklyTarget': weeklyTarget,
    'color':
        '#${colorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
  };

  Goal copyWith({
    String? title,
    String? why,
    String? description,
    String? category,
    String? priority,
    GoalStatus? status,
    DateTime? startDate,
    DateTime? targetDate,
    String? frequency,
    List<String>? preferredDays,
    String? preferredTime,
    double? progress,
    List<Milestone>? milestones,
    List<GoalAction>? actions,
    int? weeklyTarget,
    String? paceStatus,
    String? customCategory,
    String? activeRoutineId,
    int? routineDurationMinutes,
    bool? ongoing,
    List<ProgressRecord>? progressRecords,
  }) => Goal(
    id: id,
    title: title ?? this.title,
    why: why ?? this.why,
    description: description ?? this.description,
    category: category ?? this.category,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
    targetDate: targetDate ?? this.targetDate,
    frequency: frequency ?? this.frequency,
    preferredDays: preferredDays ?? this.preferredDays,
    preferredTime: preferredTime ?? this.preferredTime,
    progress: progress ?? this.progress,
    milestones: milestones ?? this.milestones,
    actions: actions ?? this.actions,
    colorValue: colorValue,
    weeklyTarget: weeklyTarget ?? this.weeklyTarget,
    paceStatus: paceStatus ?? this.paceStatus,
    customCategory: customCategory ?? this.customCategory,
    activeRoutineId: activeRoutineId ?? this.activeRoutineId,
    routineDurationMinutes:
        routineDurationMinutes ?? this.routineDurationMinutes,
    ongoing: ongoing ?? this.ongoing,
    progressRecords: progressRecords ?? this.progressRecords,
  );

  String get pace {
    if (status == GoalStatus.completed) return 'Completed';
    if (status == GoalStatus.paused) return 'Paused';
    if (paceStatus != null && paceStatus!.isNotEmpty) return paceStatus!;
    if (ongoing) return 'On track';
    final total = targetDate.difference(startDate).inDays.clamp(1, 99999);
    final elapsed = DateTime.now().difference(startDate).inDays.clamp(0, total);
    final expected = elapsed / total;
    if (progress >= expected + .12) return 'Ahead';
    if (progress >= expected - .08) return 'On track';
    if (progress >= expected - .2) return 'Needs attention';
    return 'Behind';
  }
}

class Milestone {
  const Milestone({
    required this.id,
    required this.goalId,
    required this.title,
    required this.targetDate,
    this.description = '',
    this.isCompleted = false,
    this.order = 0,
  });

  final String id;
  final String goalId;
  final String title;
  final String description;
  final DateTime targetDate;
  final bool isCompleted;
  final int order;

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
    id: json['id']?.toString() ?? '',
    goalId: json['goalId']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Milestone',
    description: json['description']?.toString() ?? '',
    targetDate: _date(json['targetDate']),
    isCompleted:
        json['isCompleted'] == true ||
        json['status']?.toString().toUpperCase() == 'COMPLETED',
    order:
        (json['position'] as num?)?.toInt() ??
        (json['order'] as num?)?.toInt() ??
        0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'goalId': goalId,
    'title': title,
    'description': description,
    'targetDate': targetDate.toIso8601String(),
    'status': isCompleted ? 'COMPLETED' : 'UPCOMING',
    'position': order,
  };

  Map<String, dynamic> toApiJson() => {
    'title': title,
    'description': description.isEmpty ? null : description,
    'targetDate': utcDateOnly(targetDate),
    'status': isCompleted ? 'COMPLETED' : 'UPCOMING',
    'position': order,
  };

  Milestone copyWith({
    String? title,
    String? description,
    DateTime? targetDate,
    bool? isCompleted,
    int? order,
  }) => Milestone(
    id: id,
    goalId: goalId,
    title: title ?? this.title,
    description: description ?? this.description,
    targetDate: targetDate ?? this.targetDate,
    isCompleted: isCompleted ?? this.isCompleted,
    order: order ?? this.order,
  );
}

class GoalAction {
  const GoalAction({
    required this.id,
    required this.goalId,
    required this.title,
    required this.dueDate,
    this.milestoneId,
    this.description = '',
    this.status = ActionStatus.upcoming,
    this.priority = 'medium',
    this.preferredTime = 'Anytime',
    this.estimatedDuration = 20,
    this.difficulty = 2,
    this.frequency = 'Once',
    this.completedAt,
  });

  final String id;
  final String goalId;
  final String? milestoneId;
  final String title;
  final String description;
  final ActionStatus status;
  final String priority;
  final DateTime dueDate;
  final String preferredTime;
  final int estimatedDuration;
  final int difficulty;
  final String frequency;
  final DateTime? completedAt;

  factory GoalAction.fromJson(Map<String, dynamic> json) {
    final value = json['status']?.toString().toLowerCase();
    final status = switch (value) {
      'completed' => ActionStatus.completed,
      'missed' => ActionStatus.missed,
      'skipped' => ActionStatus.skipped,
      'in_progress' || 'inprogress' => ActionStatus.inProgress,
      _ => ActionStatus.upcoming,
    };
    return GoalAction(
      id: json['id']?.toString() ?? '',
      goalId: json['goalId']?.toString() ?? '',
      milestoneId: json['milestoneId']?.toString(),
      title: json['title']?.toString() ?? 'Action',
      description: json['description']?.toString() ?? '',
      status: status,
      priority: json['priority']?.toString().toLowerCase() ?? 'medium',
      dueDate: _date(json['scheduledFor'] ?? json['dueDate']).toLocal(),
      preferredTime: json['preferredTime']?.toString() ?? 'Anytime',
      estimatedDuration:
          (json['estimatedMinutes'] as num?)?.toInt() ??
          (json['estimatedDuration'] as num?)?.toInt() ??
          20,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 2,
      frequency: _displayActionFrequency(
        json['frequency']?.toString() ?? 'ONCE',
      ),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goalId': goalId,
    'milestoneId': milestoneId,
    'title': title,
    'description': description,
    'status': status == ActionStatus.inProgress
        ? 'in_progress'
        : _statusName(status),
    'priority': priority,
    'scheduledFor': dueDate.toUtc().toIso8601String(),
    'preferredTime': preferredTime,
    'estimatedMinutes': estimatedDuration,
    'difficulty': difficulty,
    'frequency': frequency,
    'completedAt': completedAt?.toIso8601String(),
  };

  Map<String, dynamic> toApiJson() => {
    'goalId': goalId,
    'milestoneId': milestoneId,
    'title': title,
    'description': description.isEmpty ? null : description,
    'status': status == ActionStatus.inProgress
        ? 'IN_PROGRESS'
        : status.name.toUpperCase(),
    'priority': priority.toUpperCase(),
    'scheduledFor': dueDate.toUtc().toIso8601String(),
    'dueDate': dueDate.toUtc().toIso8601String(),
    'preferredTime': _apiTime(preferredTime),
    'estimatedMinutes': estimatedDuration,
    'difficulty': difficulty,
    'frequency': _apiFrequency(frequency),
  };

  GoalAction copyWith({
    String? title,
    String? description,
    String? milestoneId,
    bool clearMilestone = false,
    ActionStatus? status,
    String? priority,
    DateTime? dueDate,
    String? preferredTime,
    int? estimatedDuration,
    int? difficulty,
    String? frequency,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => GoalAction(
    id: id,
    goalId: goalId,
    milestoneId: clearMilestone ? null : milestoneId ?? this.milestoneId,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    dueDate: dueDate ?? this.dueDate,
    preferredTime: preferredTime ?? this.preferredTime,
    estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    difficulty: difficulty ?? this.difficulty,
    frequency: frequency ?? this.frequency,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );
}

class ProgressRecord {
  const ProgressRecord({
    required this.id,
    required this.goalId,
    required this.status,
    required this.occurredAt,
    this.actionId,
    this.actionTitle,
    this.goalTitle,
  });

  final String id;
  final String goalId;
  final String? actionId;
  final String status;
  final DateTime occurredAt;
  final String? actionTitle;
  final String? goalTitle;

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isMissed => status.toUpperCase() == 'MISSED';
  bool get isSkipped => status.toUpperCase() == 'SKIPPED';

  factory ProgressRecord.fromJson(Map<String, dynamic> json) {
    final action = json['action'];
    final goal = json['goal'];
    return ProgressRecord(
      id: json['id']?.toString() ?? newClientId(),
      goalId: json['goalId']?.toString() ?? '',
      actionId: json['actionId']?.toString(),
      status: json['status']?.toString() ?? 'UPCOMING',
      occurredAt: _date(json['occurredAt']).toLocal(),
      actionTitle: action is Map ? action['title']?.toString() : null,
      goalTitle: goal is Map ? goal['title']?.toString() : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goalId': goalId,
    'actionId': actionId,
    'status': status,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'action': actionTitle == null ? null : {'title': actionTitle},
    'goal': goalTitle == null ? null : {'title': goalTitle},
  };
}

class WeeklyReflection {
  const WeeklyReflection({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    this.whatWentWell = '',
    this.whatWasDifficult = '',
    this.nextFocus = '',
  });

  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String whatWentWell;
  final String whatWasDifficult;
  final String nextFocus;

  factory WeeklyReflection.fromJson(Map<String, dynamic> json) =>
      WeeklyReflection(
        id: json['id']?.toString() ?? '',
        periodStart: _date(json['periodStart']),
        periodEnd: _date(json['periodEnd']),
        whatWentWell: json['whatWentWell']?.toString() ?? '',
        whatWasDifficult: json['whatWasDifficult']?.toString() ?? '',
        nextFocus: json['nextFocus']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'whatWentWell': whatWentWell,
    'whatWasDifficult': whatWasDifficult,
    'nextFocus': nextFocus,
  };

  Map<String, dynamic> toApiJson() => {
    'periodStart': utcDateOnly(periodStart),
    'periodEnd': utcDateOnly(periodEnd),
    'whatWentWell': whatWentWell.trim(),
    'whatWasDifficult': whatWasDifficult.trim(),
    'nextFocus': nextFocus.trim(),
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.scheduledAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? scheduledAt;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? 'SYSTEM',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
      scheduledAt: json['scheduledAt'] == null
          ? null
          : _date(json['scheduledAt']).toLocal(),
      readAt: json['readAt'] == null ? null : _date(json['readAt']).toLocal(),
      createdAt: _date(json['createdAt']).toLocal(),
    );
  }

  AppNotification markRead(DateTime value) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    data: data,
    scheduledAt: scheduledAt,
    readAt: value,
    createdAt: createdAt,
  );
}

class NotificationSettings {
  const NotificationSettings({
    this.actionReminders = true,
    this.dueActionReminders = true,
    this.milestoneReminders = true,
    this.progressSummaries = true,
    this.weeklyReflection = true,
    this.quietHours = true,
    this.pushEnabled = true,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.reminderMinutesBefore = 15,
  });

  final bool actionReminders;
  final bool dueActionReminders;
  final bool milestoneReminders;
  final bool progressSummaries;
  final bool weeklyReflection;
  final bool quietHours;
  final bool pushEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final int reminderMinutesBefore;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        actionReminders: json['actionReminders'] != false,
        dueActionReminders: json['dueActionReminders'] != false,
        milestoneReminders: json['milestoneReminders'] != false,
        progressSummaries: json['progressSummaries'] != false,
        weeklyReflection: json['weeklyReflection'] != false,
        quietHours:
            json['quietHours'] == true ||
            json['quietHoursStart'] != null ||
            json['quietHoursEnd'] != null,
        pushEnabled: json['pushEnabled'] != false,
        quietHoursStart: json['quietHoursStart']?.toString() ?? '22:00',
        quietHoursEnd: json['quietHoursEnd']?.toString() ?? '07:00',
        reminderMinutesBefore:
            (json['reminderMinutesBefore'] as num?)?.toInt() ?? 15,
      );

  Map<String, dynamic> toJson() => {
    'actionReminders': actionReminders,
    'dueActionReminders': dueActionReminders,
    'milestoneReminders': milestoneReminders,
    'progressSummaries': progressSummaries,
    'weeklyReflection': weeklyReflection,
    'quietHours': quietHours,
    'pushEnabled': pushEnabled,
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
    'reminderMinutesBefore': reminderMinutesBefore,
  };

  NotificationSettings copyWith({
    bool? actionReminders,
    bool? dueActionReminders,
    bool? milestoneReminders,
    bool? progressSummaries,
    bool? weeklyReflection,
    bool? quietHours,
    bool? pushEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    int? reminderMinutesBefore,
  }) => NotificationSettings(
    actionReminders: actionReminders ?? this.actionReminders,
    dueActionReminders: dueActionReminders ?? this.dueActionReminders,
    milestoneReminders: milestoneReminders ?? this.milestoneReminders,
    progressSummaries: progressSummaries ?? this.progressSummaries,
    weeklyReflection: weeklyReflection ?? this.weeklyReflection,
    quietHours: quietHours ?? this.quietHours,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    quietHoursStart: quietHoursStart ?? this.quietHoursStart,
    quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
  );
}
