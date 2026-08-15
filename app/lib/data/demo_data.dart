import '../domain/models.dart';

({List<Goal> goals, List<GoalAction> actions}) createDemoData() {
  final now = DateTime.now();
  const movementId = 'goal-movement';
  const spanishId = 'goal-spanish';
  const readingId = 'goal-reading';
  final goals = [
    Goal(
      id: movementId,
      title: 'Feel strong in my body',
      why: 'I want more energy for the people and work I care about.',
      description:
          'Build a sustainable strength and mobility practice without overdoing it.',
      category: 'Health',
      priority: 'high',
      startDate: now.subtract(const Duration(days: 34)),
      targetDate: now.add(const Duration(days: 86)),
      frequency: '4 times a week',
      preferredDays: const ['Mon', 'Wed', 'Fri', 'Sun'],
      preferredTime: 'Evening',
      progress: .42,
      colorValue: 0xFF315D4C,
      milestones: [
        Milestone(
          id: 'milestone-foundation',
          goalId: movementId,
          title: 'Build the foundation',
          description: 'Complete 12 comfortable sessions.',
          targetDate: now.add(const Duration(days: 14)),
        ),
        Milestone(
          id: 'milestone-routine',
          goalId: movementId,
          title: 'Make it feel automatic',
          targetDate: now.add(const Duration(days: 55)),
        ),
      ],
    ),
    Goal(
      id: spanishId,
      title: 'Speak Spanish with confidence',
      why: 'So I can have real conversations when I travel.',
      category: 'Learning',
      startDate: now.subtract(const Duration(days: 62)),
      targetDate: now.add(const Duration(days: 119)),
      frequency: '5 times a week',
      preferredDays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Sat'],
      preferredTime: 'Morning',
      progress: .61,
      colorValue: 0xFFA94F36,
      milestones: [
        Milestone(
          id: 'milestone-vocabulary',
          goalId: spanishId,
          title: 'Everyday vocabulary',
          targetDate: now.add(const Duration(days: 21)),
          isCompleted: true,
        ),
        Milestone(
          id: 'milestone-conversation',
          goalId: spanishId,
          title: 'Ten-minute conversations',
          targetDate: now.add(const Duration(days: 70)),
        ),
      ],
    ),
    Goal(
      id: readingId,
      title: 'Read with intention',
      why: 'Make space for ideas beyond the daily rush.',
      category: 'Personal',
      startDate: now.subtract(const Duration(days: 15)),
      targetDate: now.add(const Duration(days: 75)),
      frequency: '3 times a week',
      preferredDays: const ['Tue', 'Thu', 'Sun'],
      preferredTime: 'Night',
      progress: .28,
      colorValue: 0xFF7D6B47,
    ),
  ];
  final actions = [
    GoalAction(
      id: 'action-mobility',
      goalId: movementId,
      milestoneId: 'milestone-foundation',
      title: '20-minute mobility flow',
      description: 'Hips, shoulders, and a slow cool-down.',
      dueDate: now,
      preferredTime: '6:30 PM',
      estimatedDuration: 20,
    ),
    GoalAction(
      id: 'action-spanish',
      goalId: spanishId,
      milestoneId: 'milestone-conversation',
      title: 'Practice a café conversation',
      description: 'Listen once, shadow twice, then speak without notes.',
      dueDate: now,
      preferredTime: '8:00 AM',
      estimatedDuration: 15,
    ),
    GoalAction(
      id: 'action-words',
      goalId: spanishId,
      title: 'Review 20 travel words',
      dueDate: now,
      preferredTime: '8:20 AM',
      estimatedDuration: 10,
      status: ActionStatus.completed,
      completedAt: now,
    ),
    GoalAction(
      id: 'action-reading',
      goalId: readingId,
      title: 'Read one chapter',
      dueDate: now.add(const Duration(days: 1)),
      preferredTime: '9:30 PM',
      estimatedDuration: 30,
    ),
    for (var i = 1; i <= 8; i++)
      GoalAction(
        id: 'history-$i',
        goalId: i.isEven ? spanishId : movementId,
        title: i.isEven ? 'Language practice' : 'Movement session',
        dueDate: now.subtract(Duration(days: i)),
        status: i == 3 ? ActionStatus.skipped : ActionStatus.completed,
        completedAt: i == 3 ? null : now.subtract(Duration(days: i)),
      ),
  ];
  return (goals: goals, actions: actions);
}
