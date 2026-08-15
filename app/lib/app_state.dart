import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/api.dart';
import 'data/demo_data.dart';
import 'data/google_calendar.dart';
import 'data/push_notifications.dart';
import 'data/social_auth.dart';
import 'domain/models.dart';

enum AppStage { splash, signedOut, onboarding, ready }

String formatUtcOffset(Duration offset) {
  final minutes = offset.inMinutes;
  final sign = minutes < 0 ? '-' : '+';
  final absolute = minutes.abs();
  final hours = (absolute ~/ 60).toString().padLeft(2, '0');
  final remainder = (absolute % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$remainder';
}

String get _platformName => kIsWeb ? 'web' : defaultTargetPlatform.name;

class AppState extends ChangeNotifier {
  AppState({
    ApiClient? api,
    CacheStore? cache,
    SocialAuthClient? socialAuth,
    PushNotifications? pushNotifications,
    GoogleCalendarSync? calendarSync,
  }) : api = api ?? ApiClient(),
       cache = cache ?? CacheStore(),
       socialAuth = socialAuth ?? SocialAuthClient(),
       pushNotifications = pushNotifications ?? PushNotifications() {
    this.api.onSessionExpired = _expireSession;
    this.calendarSync =
        calendarSync ??
        GoogleCalendarSync(
          authorizationHeaders: this.socialAuth.googleCalendarHeaders,
        );
  }

  final ApiClient api;
  final CacheStore cache;
  final SocialAuthClient socialAuth;
  final PushNotifications pushNotifications;
  late final GoogleCalendarSync calendarSync;

  AppStage stage = AppStage.splash;
  AppUser? user;
  List<Goal> goals = [];
  List<GoalAction> actions = [];
  List<ProgressRecord> progressRecords = [];
  List<WeeklyReflection> reflections = [];
  List<Milestone> scheduledMilestones = [];
  NotificationSettings notificationSettings = const NotificationSettings();
  List<AppNotification> notifications = [];
  int unreadNotifications = 0;
  bool notificationsLoading = false;
  List<String> preferredDays = const ['Mon', 'Wed', 'Fri'];
  String preferredTime = 'Evening';
  int workingFrequency = 3;
  String progressStyle = 'Gentle';
  String personalConstraints = '';
  ThemeMode themeMode = ThemeMode.light;
  bool busy = false;
  bool refreshing = false;
  bool offline = false;
  bool demo = false;
  String? message;
  String? developmentResetToken;
  String? syncWarning;
  SocialProvider? activeSocialProvider;

  int get activeGoals =>
      goals.where((goal) => goal.status == GoalStatus.active).length;

  List<GoalAction> get todayActions {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day + 1);
    return actions.where((action) {
      if (action.status == ActionStatus.skipped ||
          action.status == ActionStatus.missed) {
        return false;
      }
      if (action.status == ActionStatus.completed) {
        return _sameDay(action.completedAt ?? action.dueDate, now);
      }
      return action.dueDate.isBefore(endOfToday);
    }).toList()..sort((a, b) {
      if (a.status == ActionStatus.completed &&
          b.status != ActionStatus.completed) {
        return 1;
      }
      if (b.status == ActionStatus.completed &&
          a.status != ActionStatus.completed) {
        return -1;
      }
      return a.preferredTime.compareTo(b.preferredTime);
    });
  }

  List<GoalAction> get upcomingActions {
    final now = DateTime.now();
    return actions
        .where(
          (action) =>
              action.dueDate.isAfter(DateTime(now.year, now.month, now.day)) &&
              action.status == ActionStatus.upcoming,
        )
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<GoalAction> get weekActions {
    final completedRecordIds = weekProgressRecords
        .where((record) => record.isCompleted && record.actionId != null)
        .map((record) => record.actionId!)
        .toSet();
    return actions
        .where(
          (action) =>
              _isThisWeek(action.dueDate) ||
              (action.completedAt != null &&
                  _isThisWeek(action.completedAt!)) ||
              completedRecordIds.contains(action.id),
        )
        .toList();
  }

  List<ProgressRecord> get weekProgressRecords {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return progressRecords
        .where(
          (record) =>
              !record.occurredAt.isBefore(start) &&
              record.occurredAt.isBefore(end),
        )
        .toList();
  }

  int get completedThisWeek {
    final completedIds = actions
        .where(
          (action) =>
              action.status == ActionStatus.completed &&
              _isThisWeek(action.completedAt ?? action.dueDate),
        )
        .map((action) => action.id)
        .toSet();
    final recordsWithoutActions = <String>{};
    for (final record in weekProgressRecords.where(
      (record) => record.isCompleted,
    )) {
      if (record.actionId == null) {
        recordsWithoutActions.add(record.id);
      } else {
        completedIds.add(record.actionId!);
      }
    }
    return completedIds.length + recordsWithoutActions.length;
  }

  double get weeklyConsistency {
    final plannedIds = weekActions.map((action) => action.id).toSet();
    if (plannedIds.isEmpty) return 0;
    final completedIds = actions
        .where(
          (action) =>
              action.status == ActionStatus.completed &&
              _isThisWeek(action.completedAt ?? action.dueDate),
        )
        .map((action) => action.id)
        .toSet();
    completedIds.addAll(
      weekProgressRecords
          .where((record) => record.isCompleted && record.actionId != null)
          .map((record) => record.actionId!),
    );
    return completedIds.where(plannedIds.contains).length / plannedIds.length;
  }

  WeeklyReflection? get currentWeekReflection {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final reflection in reflections) {
      final start = DateTime(
        reflection.periodStart.year,
        reflection.periodStart.month,
        reflection.periodStart.day,
      );
      final end = DateTime(
        reflection.periodEnd.year,
        reflection.periodEnd.month,
        reflection.periodEnd.day,
      );
      if (!today.isBefore(start) && !today.isAfter(end)) return reflection;
    }
    return null;
  }

  Goal? goalById(String id) {
    for (final goal in goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  List<GoalAction> actionsForGoal(String id) =>
      actions.where((action) => action.goalId == id).toList();

  List<ProgressRecord> recordsForGoal(String id) =>
      progressRecords.where((record) => record.goalId == id).toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  Future<void> bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final cachedTheme = await cache.read('theme');
    themeMode = cachedTheme == 'dark'
        ? ThemeMode.dark
        : cachedTheme == 'light'
        ? ThemeMode.light
        : ThemeMode.light;
    final token = await api.tokens.accessToken;
    if (token == null) {
      stage = AppStage.signedOut;
      notifyListeners();
      return;
    }
    await _restoreCache();
    stage = user == null || !user!.onboardingCompleted
        ? AppStage.onboarding
        : AppStage.ready;
    notifyListeners();
    await refresh(silent: true);
    await _syncTimezoneBestEffort();
    await _registerPushBestEffort();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) => _auth('/auth/register', {
    'name': name.trim(),
    'email': email.trim().toLowerCase(),
    'password': password,
    'timezone': formatUtcOffset(DateTime.now().timeZoneOffset),
  }, newAccount: true);

  Future<bool> login({required String email, required String password}) =>
      _auth('/auth/login', {
        'email': email.trim().toLowerCase(),
        'password': password,
      });

  Future<bool> socialLogin(SocialProvider provider) async {
    activeSocialProvider = provider;
    _start();
    try {
      final credential = await socialAuth.signIn(provider);
      if (credential == null) {
        _finish();
        return false;
      }
      final timezone = formatUtcOffset(DateTime.now().timeZoneOffset);
      return provider == SocialProvider.google
          ? _auth('/auth/google', {
              'idToken': credential.idToken,
              'timezone': timezone,
            })
          : _auth('/auth/apple', {
              'authorizationCode': credential.authorizationCode,
              'identityToken': credential.idToken,
              if (credential.givenName?.trim().isNotEmpty == true)
                'givenName': credential.givenName!.trim(),
              if (credential.familyName?.trim().isNotEmpty == true)
                'familyName': credential.familyName!.trim(),
              'timezone': timezone,
              'platform': _platformName,
            });
    } on SocialAuthException catch (error) {
      _fail(error.message);
      return false;
    } catch (_) {
      _fail('Sign-in could not be completed. Please try again.');
      return false;
    }
  }

  Future<bool> _auth(
    String path,
    Map<String, dynamic> fields, {
    bool newAccount = false,
  }) async {
    _start();
    try {
      final response = payloadOf(await api.post(path, fields));
      final access = response['accessToken']?.toString();
      final refreshToken = response['refreshToken']?.toString();
      final userJson = response['user'];
      if (access == null || refreshToken == null || userJson is! Map) {
        throw const ApiException('The server returned an incomplete session.');
      }
      await api.tokens.save(access, refreshToken);
      user = AppUser.fromJson(Map<String, dynamic>.from(userJson));
      await _syncTimezoneBestEffort();
      await _registerPushBestEffort();
      stage = newAccount || !user!.onboardingCompleted
          ? AppStage.onboarding
          : AppStage.ready;
      await _saveCache();
      _finish();
      if (stage == AppStage.ready) await refresh(silent: true);
      return true;
    } on ApiException catch (error) {
      _fail(error.message);
      return false;
    }
  }

  Future<void> exploreDemo() async {
    demo = true;
    user = const AppUser(
      id: 'demo-user',
      name: 'Maya',
      email: 'maya@example.com',
      onboardingCompleted: true,
    );
    final sample = createDemoData();
    goals = sample.goals;
    actions = sample.actions;
    progressRecords = actions
        .where(
          (action) =>
              action.status == ActionStatus.completed ||
              action.status == ActionStatus.missed ||
              action.status == ActionStatus.skipped,
        )
        .map(
          (action) => ProgressRecord(
            id: newClientId(),
            goalId: action.goalId,
            actionId: action.id,
            status: action.status.name.toUpperCase(),
            occurredAt: action.completedAt ?? action.dueDate,
            actionTitle: action.title,
            goalTitle: goalById(action.goalId)?.title,
          ),
        )
        .toList();
    final demoGoal = goals.isEmpty ? null : goals.first;
    notifications = [
      AppNotification(
        id: 'demo-notification-action',
        type: 'ACTION_REMINDER',
        title: 'A small step is ready',
        body: actions.isEmpty
            ? 'Choose one useful action for today.'
            : actions.first.title,
        data: demoGoal == null ? const {} : {'goalId': demoGoal.id},
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
      AppNotification(
        id: 'demo-notification-summary',
        type: 'PROGRESS_SUMMARY',
        title: 'Your progress is taking shape',
        body: 'See what moved and what may need a smaller next step.',
        readAt: DateTime.now().subtract(const Duration(hours: 2)),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
    unreadNotifications = 1;
    if (goals.isNotEmpty) {
      preferredDays = List.of(goals.first.preferredDays);
      preferredTime = goals.first.preferredTime;
      workingFrequency = goals.first.weeklyTarget;
    }
    progressStyle = 'Detailed';
    stage = AppStage.ready;
    message = null;
    notifyListeners();
  }

  Future<bool> forgotPassword(String email) async {
    developmentResetToken = null;
    _start();
    try {
      final response = payloadOf(
        await api.post('/auth/forgot-password', {
          'email': email.trim().toLowerCase(),
        }),
      );
      developmentResetToken = response['developmentResetToken']?.toString();
      _finish();
      return true;
    } on ApiException catch (error) {
      _fail(error.message);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    _start();
    try {
      await api.post('/auth/reset-password', {
        'token': token.trim(),
        'password': newPassword,
      });
      developmentResetToken = null;
      _finish();
      return true;
    } on ApiException catch (error) {
      _fail(error.message);
      return false;
    }
  }

  Future<bool> finishOnboarding({
    required String name,
    String profileImageUrl = '',
    required String objective,
    required DateTime targetDate,
    required String avatarKey,
    required String progressStyle,
    required List<String> preferredDays,
    required String preferredTime,
    required int workingFrequency,
    String constraints = '',
  }) async {
    _start();
    try {
      if (!demo) {
        final normalizedPhoto = profileImageUrl.trim();
        final goalId = newClientId();
        final response = payloadOf(
          await api.post('/users/me/onboarding', {
            'name': name.trim(),
            'profileImageUrl': normalizedPhoto.isEmpty ? null : normalizedPhoto,
            'mainObjective': objective,
            'avatarKey': avatarKey,
            'preferences': {
              'preferredDays': preferredDays.map(_apiDay).toList(),
              'preferredTime': _apiTime(preferredTime),
              'workingFrequency': workingFrequency,
              'personalConstraints': constraints.trim().isEmpty
                  ? null
                  : constraints.trim(),
              'progressStyle': _progressStyle(progressStyle),
              'weekStartsOn': 1,
            },
            'firstGoal': {
              'id': goalId,
              'title': objective.trim(),
              'targetDate': utcDateOnly(targetDate),
              'frequency': _apiFrequency(
                workingFrequency >= 5 ? 'Daily' : 'Weekly',
              ),
              'preferredDays': preferredDays.map(_apiDay).toList(),
              'preferredTime': _apiTime(preferredTime),
              'weeklyTarget': workingFrequency,
            },
          }),
        );
        final rawUser = response['user'];
        user = rawUser is Map
            ? AppUser.fromJson(Map<String, dynamic>.from(rawUser))
            : user?.copyWith(name: name, onboardingCompleted: true);
        _applyPreferences(response['preferences']);
        final rawGoal = response['goal'];
        if (rawGoal is Map) {
          final createdGoal = Goal.fromJson(Map<String, dynamic>.from(rawGoal));
          goals = [createdGoal, ...goals.where((goal) => goal.id != goalId)];
          actions = [
            ...actions.where((action) => action.goalId != createdGoal.id),
            ...createdGoal.actions,
          ];
        }
      } else {
        user = user?.copyWith(
          name: name,
          profileImageUrl: profileImageUrl.trim().isEmpty
              ? null
              : profileImageUrl.trim(),
          clearProfileImage: profileImageUrl.trim().isEmpty,
          avatarKey: avatarKey,
          onboardingCompleted: true,
        );
        goals = [
          Goal(
            id: newClientId(),
            title: objective.trim(),
            why: '',
            category: 'Personal',
            startDate: DateTime.now(),
            targetDate: targetDate,
            frequency: workingFrequency >= 5 ? 'Most days' : 'Weekly',
            preferredDays: preferredDays,
            preferredTime: preferredTime,
            weeklyTarget: workingFrequency,
          ),
          ...goals,
        ];
      }
      this.preferredDays = List.of(preferredDays);
      this.preferredTime = preferredTime;
      this.workingFrequency = workingFrequency;
      this.progressStyle = _friendlyProgressStyle(
        _progressStyle(progressStyle),
      );
      personalConstraints = constraints.trim();
      stage = AppStage.ready;
      await _saveCache();
      _finish();
      return true;
    } on ApiException catch (error) {
      _fail(error.message);
      return false;
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (demo) return;
    if (!silent) {
      refreshing = true;
      notifyListeners();
    }
    try {
      await _flushOfflineQueue();
      final historyFrom = DateTime.now()
          .subtract(const Duration(days: 35))
          .toUtc()
          .toIso8601String();
      final responses = await Future.wait<Object>([
        _allPages('/goals'),
        _allPages('/actions'),
        _allPages('/reflections'),
        api.get(
          '/progress/history?from=${Uri.encodeQueryComponent(historyFrom)}',
        ),
        api.get('/users/me'),
        api.get('/users/me/preferences'),
        api.get('/notifications/preferences'),
        api.get('/notifications?page=1&limit=50'),
      ]);
      goals = (responses[0] as List<dynamic>)
          .whereType<Map>()
          .map((item) => Goal.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      actions = (responses[1] as List<dynamic>)
          .whereType<Map>()
          .map((item) => GoalAction.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      reflections = (responses[2] as List<dynamic>)
          .whereType<Map>()
          .map(
            (item) =>
                WeeklyReflection.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      progressRecords = listOf(responses[3] as Map<String, dynamic>, 'history')
          .whereType<Map>()
          .map(
            (item) => ProgressRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      final profile = payloadOf(responses[4] as Map<String, dynamic>);
      user = AppUser.fromJson(profile);
      // The server is authoritative after a restart. This also recovers when
      // onboarding reached the API but the process ended before caching it.
      if (stage == AppStage.onboarding || stage == AppStage.ready) {
        stage = user!.onboardingCompleted
            ? AppStage.ready
            : AppStage.onboarding;
      }
      await _syncTimezoneBestEffort();
      _applyPreferences(profile['preferences']);
      final preferenceResponse = responses[5] as Map<String, dynamic>;
      _applyPreferences(preferenceResponse['data']);
      final notificationResponse = responses[6] as Map<String, dynamic>;
      final notificationPrefs =
          notificationResponse['data'] ?? profile['notificationPrefs'];
      if (notificationPrefs is Map) {
        notificationSettings = NotificationSettings.fromJson(
          Map<String, dynamic>.from(notificationPrefs),
        );
      }
      _applyNotificationResponse(responses[7] as Map<String, dynamic>);
      offline = false;
      message = null;
      await _saveCache();
    } on ApiException catch (error) {
      offline = error.offline;
      if (!silent || goals.isEmpty) message = error.message;
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<List<dynamic>> _allPages(String path) async {
    final first = await api.get('$path?page=1&limit=100');
    final all = <dynamic>[...listOf(first, 'items')];
    final meta = first['meta'];
    final pages = meta is Map ? (meta['pages'] as num?)?.toInt() ?? 1 : 1;
    if (pages <= 1) return all;
    final remaining = await Future.wait([
      for (var page = 2; page <= pages; page++)
        api.get('$path?page=$page&limit=100'),
    ]);
    for (final response in remaining) {
      all.addAll(listOf(response, 'items'));
    }
    return all;
  }

  Future<void> loadGoalDetail(String id) async {
    if (demo) return;
    try {
      final response = payloadOf(await api.get('/goals/$id'));
      final detailed = Goal.fromJson(response);
      final index = goals.indexWhere((goal) => goal.id == id);
      if (index >= 0) {
        goals[index] = detailed;
      } else {
        goals = [detailed, ...goals];
      }
      actions = [
        ...actions.where((action) => action.goalId != id),
        ...detailed.actions,
      ];
      progressRecords = [
        ...progressRecords.where((record) => record.goalId != id),
        ...detailed.progressRecords,
      ];
      await _saveCache();
      notifyListeners();
    } on ApiException catch (error) {
      message = error.message;
      notifyListeners();
    }
  }

  Future<void> loadSchedule(DateTime month) async {
    final from = DateTime(month.year, month.month);
    final to = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    List<Milestone> localMilestones() =>
        goals
            .expand((goal) => goal.milestones)
            .where(
              (milestone) =>
                  !milestone.targetDate.isBefore(from) &&
                  !milestone.targetDate.isAfter(to),
            )
            .toList()
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    if (demo) {
      scheduledMilestones = localMilestones();
      notifyListeners();
      return;
    }
    try {
      final response = payloadOf(
        await api.get(
          '/schedule?from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}'
          '&to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}',
        ),
      );
      scheduledMilestones = listOf(response, 'milestones')
          .whereType<Map>()
          .map((item) => Milestone.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      notifyListeners();
    } on ApiException catch (error) {
      scheduledMilestones = localMilestones();
      offline = error.offline;
      if (!error.offline) message = error.message;
      notifyListeners();
    }
  }

  Future<Goal?> createGoal(
    Goal draft, {
    List<String> milestoneTitles = const [],
    List<String> actionTitles = const [],
    List<int?> actionMilestoneIndexes = const [],
    int actionDuration = 20,
  }) async {
    final milestoneDrafts = [
      for (var index = 0; index < milestoneTitles.length; index++)
        Milestone(
          id: newClientId(),
          goalId: draft.id,
          title: milestoneTitles[index],
          targetDate: draft.ongoing
              ? DateTime.now().add(const Duration(days: 90))
              : draft.targetDate,
          order: index,
        ),
    ];
    var nextActionDate = DateTime.now();
    final actionDrafts = <GoalAction>[];
    for (var index = 0; index < actionTitles.length; index++) {
      final title = actionTitles[index];
      final milestoneIndex = index < actionMilestoneIndexes.length
          ? actionMilestoneIndexes[index]
          : null;
      nextActionDate = _nextPreferredDate(
        draft.preferredDays,
        from: nextActionDate,
      );
      actionDrafts.add(
        GoalAction(
          id: newClientId(),
          goalId: draft.id,
          milestoneId:
              milestoneIndex != null &&
                  milestoneIndex >= 0 &&
                  milestoneIndex < milestoneDrafts.length
              ? milestoneDrafts[milestoneIndex].id
              : null,
          title: title,
          dueDate: _scheduledInstant(nextActionDate, draft.preferredTime),
          preferredTime: draft.preferredTime,
          estimatedDuration: actionDuration,
        ),
      );
      nextActionDate = nextActionDate.add(const Duration(days: 1));
    }
    final body = draft.toApiJson()
      ..['id'] = draft.id
      ..['plan'] = {
        'milestones': milestoneDrafts
            .map(
              (item) => ({...item.toApiJson(), 'id': item.id}
                ..remove('status')
                ..remove('position')),
            )
            .toList(),
        'actions': actionDrafts
            .map(
              (item) => ({...item.toApiJson(), 'id': item.id}
                ..remove('goalId')
                ..remove('status')),
            )
            .toList(),
        'routine': {
          'name': '${draft.title} rhythm',
          'frequency': _apiFrequency(draft.frequency),
          'days': draft.preferredDays.map(_apiDay).toList(),
          'preferredTime': _apiTime(draft.preferredTime),
          'durationMinutes': actionDuration,
          'timesPerWeek': draft.weeklyTarget,
        },
      };
    _start();
    try {
      Goal goal;
      if (demo) {
        goal = draft.copyWith(
          activeRoutineId: _localId(),
          routineDurationMinutes: actionDuration,
          milestones: milestoneDrafts,
          actions: actionDrafts,
        );
        goals = [goal, ...goals];
        actions = [...actions, ...actionDrafts];
      } else {
        final response = payloadOf(await api.post('/goals', body));
        final raw = response['goal'] ?? response;
        goal = Goal.fromJson(Map<String, dynamic>.from(raw as Map));
        goals = [goal, ...goals];
        actions = [...actions, ...goal.actions];
      }
      await _saveCache();
      message = null;
      busy = false;
      notifyListeners();
      return goalById(goal.id);
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        final goal = draft.copyWith(
          milestones: milestoneDrafts,
          actions: actionDrafts,
          routineDurationMinutes: actionDuration,
        );
        goals = [goal, ...goals.where((item) => item.id != goal.id)];
        actions = [...actions, ...actionDrafts];
        await _queueMutation('POST', '/goals', body);
        await _savedOffline();
        return goal;
      }
      _fail(error.message);
      return null;
    }
  }

  Future<bool> updateGoal(Goal updated, {int? routineDurationMinutes}) async {
    _start();
    final index = goals.indexWhere((goal) => goal.id == updated.id);
    if (index < 0) {
      _fail('We could not find that goal.');
      return false;
    }
    final previous = goals[index];
    goals[index] = updated;
    notifyListeners();
    try {
      String? warning;
      if (!demo) {
        final body = updated.toApiJson();
        await api.patch('/goals/${updated.id}', body);
        final routineId = previous.activeRoutineId;
        if (routineId != null &&
            routineDurationMinutes != null &&
            routineDurationMinutes != previous.routineDurationMinutes) {
          try {
            await api.patch('/routines/$routineId', {
              'durationMinutes': routineDurationMinutes,
            });
          } on ApiException catch (error) {
            if (error.offline) {
              await _queueMutation('PATCH', '/routines/$routineId', {
                'durationMinutes': routineDurationMinutes,
              });
              warning = 'Goal rhythm saved offline and will sync later.';
            } else {
              goals[index] = updated.copyWith(
                routineDurationMinutes: previous.routineDurationMinutes,
              );
              warning =
                  'Goal rhythm saved, but the session length did not sync.';
            }
          }
        }
      }
      await _saveCache();
      busy = false;
      message = warning;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        await _queueMutation(
          'PATCH',
          '/goals/${updated.id}',
          updated.toApiJson(),
        );
        if (previous.activeRoutineId != null &&
            routineDurationMinutes != null) {
          await _queueMutation(
            'PATCH',
            '/routines/${previous.activeRoutineId}',
            {'durationMinutes': routineDurationMinutes},
          );
        }
        await _savedOffline();
        return true;
      }
      goals[index] = previous;
      _fail(error.message);
      return false;
    }
  }

  Future<bool> setGoalStatus(String id, GoalStatus status) async {
    final goal = goalById(id);
    if (goal == null) return false;
    return updateGoal(
      goal.copyWith(
        status: status,
        progress: status == GoalStatus.completed ? 1 : goal.progress,
      ),
    );
  }

  Future<Milestone?> addMilestone(
    String goalId,
    String title, {
    required DateTime targetDate,
    String description = '',
    bool notify = true,
  }) async {
    final draft = Milestone(
      id: newClientId(),
      goalId: goalId,
      title: title,
      description: description,
      targetDate: targetDate,
    );
    final body = {...draft.toApiJson(), 'id': draft.id};
    try {
      Milestone milestone;
      if (demo) {
        milestone = draft;
      } else {
        final response = payloadOf(
          await api.post('/goals/$goalId/milestones', body),
        );
        final raw = response['milestone'] ?? response;
        milestone = Milestone.fromJson(Map<String, dynamic>.from(raw as Map));
      }
      final index = goals.indexWhere((goal) => goal.id == goalId);
      if (index >= 0) {
        goals[index] = goals[index].copyWith(
          milestones: [...goals[index].milestones, milestone],
        );
      }
      await _saveCache();
      if (notify) notifyListeners();
      return milestone;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        final index = goals.indexWhere((goal) => goal.id == goalId);
        if (index >= 0) {
          goals[index] = goals[index].copyWith(
            milestones: [...goals[index].milestones, draft],
          );
        }
        await _queueMutation('POST', '/goals/$goalId/milestones', body);
        await _savedOffline(notify: notify);
        return draft;
      }
      message = error.message;
      if (notify) notifyListeners();
      return null;
    }
  }

  Future<bool> updateMilestone(Milestone updated) async {
    final goalIndex = goals.indexWhere((goal) => goal.id == updated.goalId);
    if (goalIndex < 0) return false;
    final milestoneIndex = goals[goalIndex].milestones.indexWhere(
      (milestone) => milestone.id == updated.id,
    );
    if (milestoneIndex < 0) return false;
    final previous = goals[goalIndex].milestones[milestoneIndex];
    final milestones = [...goals[goalIndex].milestones]
      ..[milestoneIndex] = updated;
    goals[goalIndex] = goals[goalIndex].copyWith(milestones: milestones);
    notifyListeners();
    try {
      Milestone saved = updated;
      if (!demo) {
        final response = payloadOf(
          await api.patch('/milestones/${updated.id}', updated.toApiJson()),
        );
        saved = Milestone.fromJson(response);
      }
      milestones[milestoneIndex] = saved;
      goals[goalIndex] = goals[goalIndex].copyWith(milestones: milestones);
      await _saveCache();
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        await _queueMutation(
          'PATCH',
          '/milestones/${updated.id}',
          updated.toApiJson(),
        );
        await _savedOffline();
        return true;
      }
      milestones[milestoneIndex] = previous;
      goals[goalIndex] = goals[goalIndex].copyWith(milestones: milestones);
      _fail(error.message);
      return false;
    }
  }

  Future<bool> deleteMilestone(Milestone milestone) async {
    final goalIndex = goals.indexWhere((goal) => goal.id == milestone.goalId);
    if (goalIndex < 0) return false;
    final previousMilestones = [...goals[goalIndex].milestones];
    final previousActions = [...actions];
    goals[goalIndex] = goals[goalIndex].copyWith(
      milestones: previousMilestones
          .where((item) => item.id != milestone.id)
          .toList(),
    );
    actions = actions
        .map(
          (action) => action.milestoneId == milestone.id
              ? action.copyWith(clearMilestone: true)
              : action,
        )
        .toList();
    notifyListeners();
    try {
      if (!demo) await api.delete('/milestones/${milestone.id}');
      await _saveCache();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        await _queueMutation('DELETE', '/milestones/${milestone.id}', null);
        await _savedOffline();
        return true;
      }
      goals[goalIndex] = goals[goalIndex].copyWith(
        milestones: previousMilestones,
      );
      actions = previousActions;
      _fail(error.message);
      return false;
    }
  }

  Future<GoalAction?> addAction(GoalAction draft, {bool notify = true}) async {
    final body = {...draft.toApiJson(), 'id': draft.id};
    try {
      GoalAction action;
      if (demo) {
        action = draft;
      } else {
        final response = payloadOf(await api.post('/actions', body));
        final raw = response['action'] ?? response;
        action = GoalAction.fromJson(Map<String, dynamic>.from(raw as Map));
      }
      actions = [...actions, action];
      _recalculateGoal(action.goalId);
      _syncLocalMilestone(action.milestoneId);
      await _saveCache();
      if (!demo) unawaited(calendarSync.upsert(action));
      if (notify) notifyListeners();
      return action;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        actions = [...actions, draft];
        _recalculateGoal(draft.goalId);
        _syncLocalMilestone(draft.milestoneId);
        await _queueMutation('POST', '/actions', body);
        await _savedOffline(notify: notify);
        return draft;
      }
      message = error.message;
      if (notify) notifyListeners();
      return null;
    }
  }

  Future<bool> completeAction(String id) =>
      _setActionStatus(id, ActionStatus.completed);

  Future<bool> skipAction(String id) =>
      _setActionStatus(id, ActionStatus.skipped);

  Future<bool> startAction(String id) =>
      _setActionStatus(id, ActionStatus.inProgress);

  Future<bool> reopenAction(String id) =>
      _setActionStatus(id, ActionStatus.upcoming);

  Future<bool> missAction(String id) =>
      _setActionStatus(id, ActionStatus.missed);

  Future<bool> _setActionStatus(String id, ActionStatus status) async {
    final index = actions.indexWhere((action) => action.id == id);
    if (index < 0) return false;
    final previous = actions[index];
    final occurredAt = DateTime.now();
    final event = previous.status == status
        ? null
        : ProgressRecord(
            id: newClientId(),
            goalId: previous.goalId,
            actionId: previous.id,
            status: status == ActionStatus.inProgress
                ? 'IN_PROGRESS'
                : status.name.toUpperCase(),
            occurredAt: occurredAt,
            actionTitle: previous.title,
            goalTitle: goalById(previous.goalId)?.title,
          );
    actions[index] = previous.copyWith(
      status: status,
      completedAt: status == ActionStatus.completed ? occurredAt : null,
      clearCompletedAt: status != ActionStatus.completed,
    );
    if (event != null) progressRecords = [event, ...progressRecords];
    _recalculateGoal(previous.goalId);
    _syncLocalMilestone(previous.milestoneId);
    notifyListeners();
    try {
      if (!demo) {
        final operation = switch (status) {
          ActionStatus.completed => 'complete',
          ActionStatus.skipped => 'skip',
          ActionStatus.inProgress => 'start',
          ActionStatus.missed => 'miss',
          ActionStatus.upcoming => 'reopen',
        };
        await api.post('/actions/$id/$operation');
      }
      await _saveCache();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        final operation = switch (status) {
          ActionStatus.completed => 'complete',
          ActionStatus.skipped => 'skip',
          ActionStatus.inProgress => 'start',
          ActionStatus.missed => 'miss',
          ActionStatus.upcoming => 'reopen',
        };
        await _queueMutation('POST', '/actions/$id/$operation', null);
        await _savedOffline();
        return true;
      }
      actions[index] = previous;
      if (event != null) {
        progressRecords.removeWhere((record) => record.id == event.id);
      }
      _recalculateGoal(previous.goalId);
      _syncLocalMilestone(previous.milestoneId);
      _fail(error.message);
      return false;
    }
  }

  Future<bool> updateAction(GoalAction updated) async {
    final index = actions.indexWhere((action) => action.id == updated.id);
    if (index < 0) return false;
    final previous = actions[index];
    final body = updated.toApiJson()
      ..remove('goalId')
      ..remove('id');
    actions[index] = updated;
    _recalculateGoal(updated.goalId);
    _syncLocalMilestone(previous.milestoneId);
    _syncLocalMilestone(updated.milestoneId);
    notifyListeners();
    try {
      if (!demo) {
        final raw = payloadOf(await api.patch('/actions/${updated.id}', body));
        actions[index] = GoalAction.fromJson(raw);
      }
      await _saveCache();
      if (!demo) unawaited(calendarSync.upsert(actions[index]));
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        await _queueMutation('PATCH', '/actions/${updated.id}', body);
        await _savedOffline();
        return true;
      }
      actions[index] = previous;
      _recalculateGoal(previous.goalId);
      _syncLocalMilestone(updated.milestoneId);
      _syncLocalMilestone(previous.milestoneId);
      _fail(error.message);
      return false;
    }
  }

  Future<bool> deleteAction(String id) async {
    final index = actions.indexWhere((action) => action.id == id);
    if (index < 0) return false;
    final removed = actions.removeAt(index);
    _recalculateGoal(removed.goalId);
    _syncLocalMilestone(removed.milestoneId);
    notifyListeners();
    try {
      if (!demo) await api.delete('/actions/$id');
      await _saveCache();
      if (!demo) unawaited(calendarSync.delete(id));
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        await _queueMutation('DELETE', '/actions/$id', null);
        await _savedOffline();
        return true;
      }
      actions.insert(index, removed);
      _recalculateGoal(removed.goalId);
      _syncLocalMilestone(removed.milestoneId);
      _fail(error.message);
      return false;
    }
  }

  Future<bool> saveReflection({
    required String whatWentWell,
    required String whatWasDifficult,
    required String nextFocus,
  }) async {
    _start();
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    final existingIndex = reflections.indexWhere(
      (reflection) =>
          _sameDay(reflection.periodStart, start) &&
          _sameDay(reflection.periodEnd, end),
    );
    final existing = existingIndex < 0 ? null : reflections[existingIndex];
    final draft = WeeklyReflection(
      id: existing?.id ?? newClientId(),
      periodStart: start,
      periodEnd: end,
      whatWentWell: whatWentWell,
      whatWasDifficult: whatWasDifficult,
      nextFocus: nextFocus,
    );
    final payload = draft.toApiJson();
    if (existing == null) payload['id'] = draft.id;
    try {
      WeeklyReflection reflection;
      if (demo) {
        reflection = draft;
      } else {
        final response = payloadOf(
          existing == null
              ? await api.post('/reflections', payload)
              : await api.patch('/reflections/${existing.id}', payload),
        );
        final raw = response['reflection'] ?? response;
        reflection = WeeklyReflection.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
      }
      if (existingIndex < 0) {
        reflections = [reflection, ...reflections];
      } else {
        reflections[existingIndex] = reflection;
      }
      await _saveCache();
      _finish();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        if (existingIndex < 0) {
          reflections = [draft, ...reflections];
          await _queueMutation('POST', '/reflections', payload);
        } else {
          reflections[existingIndex] = draft;
          await _queueMutation(
            'PATCH',
            '/reflections/${existing!.id}',
            payload,
          );
        }
        await _savedOffline();
        return true;
      }
      _fail(error.message);
      return false;
    }
  }

  Future<void> loadNotifications() async {
    if (demo) {
      notifyListeners();
      return;
    }
    notificationsLoading = true;
    message = null;
    notifyListeners();
    try {
      _applyNotificationResponse(
        await api.get('/notifications?page=1&limit=50'),
      );
      offline = false;
    } on ApiException catch (error) {
      offline = error.offline;
      message = error.message;
    } finally {
      notificationsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markNotificationRead(String id) async {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index < 0 || notifications[index].isRead) return true;
    final previous = notifications[index];
    notifications[index] = previous.markRead(DateTime.now());
    if (unreadNotifications > 0) unreadNotifications--;
    notifyListeners();
    if (demo) return true;
    try {
      await api.patch('/notifications/$id/read', const {});
      return true;
    } on ApiException catch (error) {
      if (error.offline) {
        await _queueMutation('PATCH', '/notifications/$id/read', const {});
        await _savedOffline();
        return true;
      }
      notifications[index] = previous;
      unreadNotifications++;
      message = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAllNotificationsRead() async {
    if (unreadNotifications == 0) return true;
    final previous = List<AppNotification>.of(notifications);
    final previousUnread = unreadNotifications;
    final now = DateTime.now();
    notifications = notifications
        .map((item) => item.isRead ? item : item.markRead(now))
        .toList();
    unreadNotifications = 0;
    notifyListeners();
    if (demo) return true;
    try {
      await api.post('/notifications/read-all');
      return true;
    } on ApiException catch (error) {
      if (error.offline) {
        await _queueMutation('POST', '/notifications/read-all', null);
        await _savedOffline();
        return true;
      }
      notifications = previous;
      unreadNotifications = previousUnread;
      message = error.message;
      notifyListeners();
      return false;
    }
  }

  void _applyNotificationResponse(Map<String, dynamic> response) {
    notifications = listOf(response, 'items')
        .whereType<Map>()
        .map(
          (item) => AppNotification.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final meta = response['meta'];
    unreadNotifications = meta is Map
        ? (meta['unread'] as num?)?.toInt() ??
              notifications.where((item) => !item.isRead).length
        : notifications.where((item) => !item.isRead).length;
  }

  Future<bool> updateNotifications(NotificationSettings value) async {
    final previous = notificationSettings;
    notificationSettings = value;
    message = null;
    notifyListeners();
    final body = {
      'actionReminders': value.actionReminders,
      'dueActionReminders': value.dueActionReminders,
      'milestoneReminders': value.milestoneReminders,
      'progressSummaries': value.progressSummaries,
      'weeklyReflection': value.weeklyReflection,
      'quietHoursStart': value.quietHours ? value.quietHoursStart : null,
      'quietHoursEnd': value.quietHours ? value.quietHoursEnd : null,
      'reminderMinutesBefore': value.reminderMinutesBefore,
      'pushEnabled': value.pushEnabled,
    };
    try {
      if (!demo) {
        await api.patch('/notifications/preferences', body);
        if (value.pushEnabled) {
          await _registerPushBestEffort();
        } else {
          await pushNotifications.unregister(api);
        }
      }
      await cache.write('notificationSettings', value.toJson());
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        await _queueMutation('PATCH', '/notifications/preferences', body);
        await _savedOffline();
        return true;
      }
      notificationSettings = previous;
      message = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> setTheme(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    await cache.write('theme', value.name);
  }

  Future<bool> updateProfileName(
    String name, {
    required String avatarKey,
    String profileImageUrl = '',
  }) async {
    _start();
    final previous = user;
    final normalizedPhoto = profileImageUrl.trim();
    final body = {
      'name': name.trim(),
      'avatarKey': avatarKey,
      'profileImageUrl': normalizedPhoto.isEmpty ? null : normalizedPhoto,
    };
    try {
      if (demo) {
        user = user?.copyWith(
          name: name,
          avatarKey: avatarKey,
          profileImageUrl: normalizedPhoto.isEmpty ? null : normalizedPhoto,
          clearProfileImage: normalizedPhoto.isEmpty,
        );
      } else {
        final response = payloadOf(await api.patch('/users/me', body));
        user = AppUser.fromJson(response);
      }
      await _saveCache();
      _finish();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        user = user?.copyWith(
          name: name,
          avatarKey: avatarKey,
          profileImageUrl: normalizedPhoto.isEmpty ? null : normalizedPhoto,
          clearProfileImage: normalizedPhoto.isEmpty,
        );
        await _queueMutation('PATCH', '/users/me', body);
        await _savedOffline();
        return true;
      }
      user = previous;
      _fail(error.message);
      return false;
    }
  }

  Future<bool> updatePreferences({
    required List<String> days,
    required String time,
    required String style,
    required int frequency,
    String constraints = '',
  }) async {
    _start();
    final previousDays = preferredDays;
    final previousTime = preferredTime;
    final previousFrequency = workingFrequency;
    final previousStyle = progressStyle;
    final previousConstraints = personalConstraints;
    final body = {
      'preferredDays': days.map(_apiDay).toList(),
      'preferredTime': _apiTime(time),
      'workingFrequency': frequency,
      'progressStyle': style.toUpperCase(),
      'personalConstraints': constraints.trim().isEmpty
          ? null
          : constraints.trim(),
    };
    try {
      if (!demo) {
        await api.patch('/users/me/preferences', body);
      }
      preferredDays = List.of(days);
      preferredTime = time;
      workingFrequency = frequency;
      progressStyle = style;
      personalConstraints = constraints.trim();
      await _saveCache();
      _finish();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        preferredDays = List.of(days);
        preferredTime = time;
        workingFrequency = frequency;
        progressStyle = style;
        personalConstraints = constraints.trim();
        await _queueMutation('PATCH', '/users/me/preferences', body);
        await _savedOffline();
        return true;
      }
      preferredDays = previousDays;
      preferredTime = previousTime;
      workingFrequency = previousFrequency;
      progressStyle = previousStyle;
      personalConstraints = previousConstraints;
      _fail(error.message);
      return false;
    }
  }

  Future<Map<String, dynamic>?> exportAccountData() async {
    if (demo) return null;
    _start();
    try {
      final exported = payloadOf(await api.get('/users/me/export'));
      _finish();
      return exported;
    } on ApiException catch (error) {
      _fail(error.message);
      return null;
    }
  }

  Future<bool> deleteAccount() async {
    if (demo) return false;
    _start();
    try {
      final queueKey = _offlineQueueKey;
      await pushNotifications.unregister(api);
      await api.delete('/users/me');
      await api.tokens.clear();
      if (queueKey != null) await cache.remove(queueKey);
      await _clearLocalSession();
      return true;
    } on ApiException catch (error) {
      _fail(error.message);
      return false;
    }
  }

  Future<void> signOut() async {
    if (!demo) {
      try {
        await pushNotifications.unregister(api);
        final refreshToken = await api.tokens.refreshToken;
        if (refreshToken != null) {
          await api.post('/auth/logout', {'refreshToken': refreshToken});
        }
      } catch (_) {}
      await api.tokens.clear();
    }
    await socialAuth.signOut();
    await _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
    await Future.wait([
      cache.remove('session'),
      cache.remove('goals'),
      cache.remove('actions'),
      cache.remove('progressRecords'),
      cache.remove('reflections'),
      cache.remove('preferences'),
      cache.remove('notificationSettings'),
    ]);
    user = null;
    goals = [];
    actions = [];
    progressRecords = [];
    reflections = [];
    scheduledMilestones = [];
    notifications = [];
    unreadNotifications = 0;
    notificationsLoading = false;
    demo = false;
    offline = false;
    busy = false;
    message = null;
    developmentResetToken = null;
    syncWarning = null;
    stage = AppStage.signedOut;
    notifyListeners();
  }

  void clearMessage() {
    message = null;
    notifyListeners();
  }

  void clearSyncWarning() {
    syncWarning = null;
    notifyListeners();
  }

  void _recalculateGoal(String goalId) {
    final goalIndex = goals.indexWhere((goal) => goal.id == goalId);
    if (goalIndex < 0) return;
    final related = actions.where((action) => action.goalId == goalId).toList();
    final complete = related
        .where((action) => action.status == ActionStatus.completed)
        .length;
    final current = goals[goalIndex];
    final progress = related.isEmpty
        ? current.progress
        : complete / related.length;
    goals[goalIndex] = current.copyWith(
      progress: progress,
      paceStatus: _localPace(current, related, progress),
    );
  }

  void _syncLocalMilestone(String? milestoneId) {
    if (milestoneId == null) return;
    final goalIndex = goals.indexWhere(
      (goal) => goal.milestones.any((item) => item.id == milestoneId),
    );
    if (goalIndex < 0) return;
    final milestoneIndex = goals[goalIndex].milestones.indexWhere(
      (item) => item.id == milestoneId,
    );
    final related = actions
        .where((action) => action.milestoneId == milestoneId)
        .toList();
    if (related.isEmpty) return;
    final completed = related.every(
      (action) => action.status == ActionStatus.completed,
    );
    final milestones = [...goals[goalIndex].milestones];
    milestones[milestoneIndex] = milestones[milestoneIndex].copyWith(
      isCompleted: completed,
    );
    goals[goalIndex] = goals[goalIndex].copyWith(milestones: milestones);
  }

  Future<void> _restoreCache() async {
    final rawUser = await cache.read('session');
    final rawGoals = await cache.read('goals');
    final rawActions = await cache.read('actions');
    final rawProgressRecords = await cache.read('progressRecords');
    final rawReflections = await cache.read('reflections');
    final rawPreferences = await cache.read('preferences');
    final rawNotifications = await cache.read('notificationSettings');
    if (rawUser is Map) {
      user = AppUser.fromJson(Map<String, dynamic>.from(rawUser));
    }
    if (rawGoals is List) {
      goals = rawGoals
          .whereType<Map>()
          .map((item) => Goal.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (rawActions is List) {
      actions = rawActions
          .whereType<Map>()
          .map((item) => GoalAction.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (rawProgressRecords is List) {
      progressRecords = rawProgressRecords
          .whereType<Map>()
          .map(
            (item) => ProgressRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
    if (rawReflections is List) {
      reflections = rawReflections
          .whereType<Map>()
          .map(
            (item) =>
                WeeklyReflection.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
    _applyPreferences(rawPreferences);
    if (rawNotifications is Map) {
      notificationSettings = NotificationSettings.fromJson(
        Map<String, dynamic>.from(rawNotifications),
      );
    }
  }

  Future<void> _saveCache() async {
    await Future.wait([
      if (user != null) cache.write('session', user!.toJson()),
      cache.write('goals', goals.map((goal) => goal.toJson()).toList()),
      cache.write('actions', actions.map((action) => action.toJson()).toList()),
      cache.write(
        'progressRecords',
        progressRecords.map((record) => record.toJson()).toList(),
      ),
      cache.write(
        'reflections',
        reflections.map((reflection) => reflection.toJson()).toList(),
      ),
      cache.write('preferences', {
        'preferredDays': preferredDays,
        'preferredTime': preferredTime,
        'workingFrequency': workingFrequency,
        'progressStyle': progressStyle,
        'personalConstraints': personalConstraints,
      }),
      cache.write('notificationSettings', notificationSettings.toJson()),
    ]);
  }

  void _start() {
    busy = true;
    message = null;
    notifyListeners();
  }

  void _finish() {
    busy = false;
    activeSocialProvider = null;
    message = null;
    notifyListeners();
  }

  void _fail(String value) {
    busy = false;
    activeSocialProvider = null;
    message = value;
    notifyListeners();
  }

  void _expireSession() {
    user = null;
    goals = [];
    actions = [];
    progressRecords = [];
    reflections = [];
    notifications = [];
    unreadNotifications = 0;
    notificationsLoading = false;
    stage = AppStage.signedOut;
    message = 'Your session expired. Sign in again to continue.';
    notifyListeners();
  }

  String? get _offlineQueueKey =>
      user == null ? null : 'offlineQueue:${user!.id}';

  Future<void> _queueMutation(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final key = _offlineQueueKey;
    if (key == null) return;
    final raw = await cache.read(key);
    final queue = raw is List
        ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
    queue.add({
      'method': method,
      'path': path,
      'body': ?body,
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await cache.write(key, queue);
  }

  Future<void> _flushOfflineQueue() async {
    final key = _offlineQueueKey;
    if (key == null) return;
    final raw = await cache.read(key);
    if (raw is! List || raw.isEmpty) return;
    final queue = raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
    final remaining = <Map<String, dynamic>>[];
    var rejected = 0;
    for (var index = 0; index < queue.length; index++) {
      final item = queue[index];
      final method = item['method']?.toString();
      final path = item['path']?.toString();
      if (method == null || path == null) continue;
      final rawBody = item['body'];
      final body = rawBody is Map ? Map<String, dynamic>.from(rawBody) : null;
      try {
        await api.request(method, path, body);
      } on ApiException catch (error) {
        final permanent =
            error.statusCode != null &&
            error.statusCode! >= 400 &&
            error.statusCode! < 500;
        if (!permanent) {
          remaining.addAll(queue.skip(index));
          break;
        }
        rejected++;
      }
    }
    if (remaining.isEmpty) {
      await cache.remove(key);
    } else {
      await cache.write(key, remaining);
    }
    if (rejected > 0) {
      syncWarning = rejected == 1
          ? 'One offline change was rejected by the server and was restored to the saved server version.'
          : '$rejected offline changes were rejected by the server and were restored to the saved server version.';
    }
  }

  Future<void> _savedOffline({bool notify = true}) async {
    offline = true;
    busy = false;
    message = 'Saved offline. Your changes will sync when you reconnect.';
    await _saveCache();
    if (notify) notifyListeners();
  }

  Future<void> _registerPushBestEffort() async {
    if (demo || user == null || !notificationSettings.pushEnabled) return;
    try {
      await pushNotifications.register(api);
    } catch (_) {
      // Push setup must never block sign-in or otherwise usable app features.
    }
  }

  Future<void> _syncTimezoneBestEffort() async {
    if (demo || user == null) return;
    final timezone = formatUtcOffset(DateTime.now().timeZoneOffset);
    if (user!.timezone == timezone) return;
    try {
      final response = payloadOf(
        await api.patch('/users/me', {'timezone': timezone}),
      );
      user = AppUser.fromJson(response);
    } on ApiException {
      // Authentication and cached data remain usable if timezone sync is down.
    }
  }

  String _localId() => newClientId();

  DateTime _nextPreferredDate(List<String> days, {DateTime? from}) {
    final anchor = from ?? DateTime.now();
    if (days.isEmpty) return anchor;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (var offset = 0; offset < 7; offset++) {
      final date = anchor.add(Duration(days: offset));
      if (days.any((day) => day.startsWith(names[date.weekday - 1]))) {
        return date;
      }
    }
    return anchor;
  }

  DateTime _scheduledInstant(DateTime day, String preferredTime) {
    final value = _apiTime(preferredTime);
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value ?? '');
    return DateTime(
      day.year,
      day.month,
      day.day,
      match == null ? 9 : int.parse(match.group(1)!),
      match == null ? 0 : int.parse(match.group(2)!),
    );
  }

  String _localPace(Goal goal, List<GoalAction> related, double progress) {
    if (goal.status == GoalStatus.completed ||
        (related.isNotEmpty &&
            related.every(
              (action) => action.status == ActionStatus.completed,
            ))) {
      return 'Completed';
    }
    if (goal.status == GoalStatus.paused) return 'Paused';
    final now = DateTime.now();
    final due = related
        .where((action) => !action.dueDate.isAfter(now))
        .toList();
    final dueCompleted = due
        .where((action) => action.status == ActionStatus.completed)
        .length;
    final adherence = due.isEmpty ? 1.0 : dueCompleted / due.length;
    final totalDays = goal.ongoing
        ? 0
        : goal.targetDate.difference(goal.startDate).inDays;
    final elapsedDays = now.difference(goal.startDate).inDays.clamp(0, 99999);
    final timeframeExpected = totalDays <= 0
        ? 0.0
        : (elapsedDays / totalDays).clamp(0.0, 1.0);
    final cadenceExpected = related.isEmpty
        ? 0.0
        : ((elapsedDays / 7) * goal.weeklyTarget / related.length).clamp(
            0.0,
            1.0,
          );
    final expected = timeframeExpected > cadenceExpected
        ? timeframeExpected
        : cadenceExpected;
    if (progress >= expected + .1 && adherence >= .75) return 'Ahead';
    if (progress + .15 < expected || (due.isNotEmpty && adherence < .5)) {
      return 'Behind';
    }
    if (progress + .05 < expected || (due.isNotEmpty && adherence < .7)) {
      return 'Needs attention';
    }
    return 'On track';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return !date.isBefore(monday) &&
        date.isBefore(monday.add(const Duration(days: 7)));
  }

  String _apiDay(String value) => switch (value.substring(0, 3).toLowerCase()) {
    'mon' => 'MONDAY',
    'tue' => 'TUESDAY',
    'wed' => 'WEDNESDAY',
    'thu' => 'THURSDAY',
    'fri' => 'FRIDAY',
    'sat' => 'SATURDAY',
    _ => 'SUNDAY',
  };

  String? _apiTime(String value) => switch (value.toLowerCase()) {
    'morning' => '08:00',
    'afternoon' => '14:00',
    'evening' => '19:00',
    'night' => '21:00',
    'flexible' || 'anytime' => null,
    _ => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value) ? value : null,
  };

  String _progressStyle(String value) => switch (value.toLowerCase()) {
    'detailed' || 'simple numbers' => 'DETAILED',
    'balanced' || 'milestone focused' => 'BALANCED',
    _ => 'GENTLE',
  };

  String _friendlyProgressStyle(String value) => switch (value.toUpperCase()) {
    'DETAILED' => 'Detailed',
    'BALANCED' => 'Balanced',
    'GENTLE' => 'Gentle',
    'SIMPLE NUMBERS' => 'Detailed',
    'MILESTONE FOCUSED' => 'Balanced',
    'WEEKLY OVERVIEW' => 'Gentle',
    _ => value,
  };

  String _friendlyTime(Object? value) => switch (value?.toString()) {
    '08:00' => 'Morning',
    '14:00' => 'Afternoon',
    '19:00' => 'Evening',
    '21:00' => 'Night',
    null => 'Flexible',
    final other => other,
  };

  String _friendlyDay(Object? value) => switch (value?.toString()) {
    'MONDAY' => 'Mon',
    'TUESDAY' => 'Tue',
    'WEDNESDAY' => 'Wed',
    'THURSDAY' => 'Thu',
    'FRIDAY' => 'Fri',
    'SATURDAY' => 'Sat',
    'SUNDAY' => 'Sun',
    final other => other ?? '',
  };

  String _apiFrequency(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('most') || lower.contains('daily')) return 'DAILY';
    if (lower.contains('month')) return 'MONTHLY';
    if (lower == 'once') return 'ONCE';
    return 'WEEKLY';
  }

  void _applyPreferences(Object? raw) {
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final days = map['preferredDays'];
    if (days is List) {
      preferredDays = days.map<String>((value) => _friendlyDay(value)).toList();
    }
    preferredTime = _friendlyTime(map['preferredTime']);
    workingFrequency =
        (map['workingFrequency'] as num?)?.toInt() ?? workingFrequency;
    progressStyle = _friendlyProgressStyle(
      map['progressStyle']?.toString() ?? progressStyle,
    );
    personalConstraints = map['personalConstraints']?.toString() ?? '';
  }

  Future<bool> deleteGoal(String id) async {
    final index = goals.indexWhere((goal) => goal.id == id);
    if (index < 0) return false;
    final removed = goals.removeAt(index);
    final removedActions = actions
        .where((action) => action.goalId == id)
        .toList();
    actions.removeWhere((action) => action.goalId == id);
    notifyListeners();
    try {
      if (!demo) await api.delete('/goals/$id');
      await _saveCache();
      return true;
    } on ApiException catch (error) {
      if (error.offline && !demo) {
        await _queueMutation('DELETE', '/goals/$id', null);
        await _savedOffline();
        return true;
      }
      goals.insert(index, removed);
      actions.addAll(removedActions);
      _fail(error.message);
      return false;
    }
  }
}
