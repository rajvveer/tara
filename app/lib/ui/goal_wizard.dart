import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../domain/models.dart';
import 'theme.dart';
import 'widgets.dart';

class GoalWizardScreen extends StatefulWidget {
  const GoalWizardScreen({super.key});

  @override
  State<GoalWizardScreen> createState() => _GoalWizardScreenState();
}

class _GoalWizardScreenState extends State<GoalWizardScreen> {
  final _title = TextEditingController();
  final _doneMeans = TextEditingController();
  final _why = TextEditingController();
  final _customCategory = TextEditingController();
  final List<TextEditingController> _milestones = [TextEditingController()];
  final List<TextEditingController> _actions = [TextEditingController()];
  final List<int?> _actionMilestoneIndexes = [null];
  int _step = 0;
  String _category = 'Health';
  String _priority = 'medium';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));
  bool _ongoing = false;
  late Set<String> _days;
  late String _frequency;
  late String _time;
  int _duration = 30;
  late String _constraints;

  static const _steps = ['Goal', 'Outcome', 'Rhythm', 'First steps'];

  @override
  void initState() {
    super.initState();
    final defaults = context.appRead;
    _days = defaults.preferredDays.toSet();
    if (_days.isEmpty) _days.addAll(const ['Mon', 'Wed', 'Fri']);
    _time = defaults.preferredTime;
    _frequency = switch (defaults.workingFrequency) {
      1 => 'Once a week',
      2 => '2 times a week',
      4 => '4 times a week',
      >= 5 => 'Most days',
      _ => '3 times a week',
    };
    _constraints = defaults.personalConstraints;
  }

  @override
  void dispose() {
    _title.dispose();
    _doneMeans.dispose();
    _why.dispose();
    _customCategory.dispose();
    for (final controller in [..._milestones, ..._actions]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (_step == 0 && _title.text.trim().length < 3) {
      showToast(context, 'Describe the direction in a few words.');
      return;
    }
    if (_step == 0 &&
        _category == 'Custom' &&
        _customCategory.text.trim().length < 2) {
      showToast(context, 'Name the part of life this goal belongs to.');
      return;
    }
    if (_step == 2 && _days.isEmpty) {
      showToast(context, 'Choose at least one workable day.');
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    final milestoneEntries = [
      for (var index = 0; index < _milestones.length; index++)
        if (_milestones[index].text.trim().isNotEmpty)
          (index: index, title: _milestones[index].text.trim()),
    ];
    final milestoneIndexes = {
      for (var index = 0; index < milestoneEntries.length; index++)
        milestoneEntries[index].index: index,
    };
    final actionEntries = [
      for (var index = 0; index < _actions.length; index++)
        if (_actions[index].text.trim().isNotEmpty)
          (
            title: _actions[index].text.trim(),
            milestoneIndex: _actionMilestoneIndexes[index],
          ),
    ];
    final goal = Goal(
      id: newClientId(),
      title: _title.text.trim(),
      why: _why.text.trim(),
      description: _doneMeans.text.trim(),
      category: _category,
      priority: _priority,
      startDate: DateTime.now(),
      targetDate: _targetDate,
      ongoing: _ongoing,
      frequency: _frequency,
      preferredDays: _days.toList(),
      preferredTime: _time,
      colorValue: _categoryColor(_category).toARGB32(),
      weeklyTarget: _weeklyTarget,
      customCategory: _category == 'Custom'
          ? _customCategory.text.trim()
          : null,
    );
    final created = await context.appRead.createGoal(
      goal,
      milestoneTitles: milestoneEntries.map((entry) => entry.title).toList(),
      actionTitles: actionEntries.map((entry) => entry.title).toList(),
      actionMilestoneIndexes: actionEntries
          .map((entry) => milestoneIndexes[entry.milestoneIndex])
          .toList(),
      actionDuration: _duration,
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    } else if (mounted) {
      showToast(
        context,
        context.appRead.message ?? 'We could not save that goal.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final theme = Theme.of(context);
    final wizardTheme = theme.copyWith(
      chipTheme: theme.chipTheme.copyWith(
        selectedColor: theme.colorScheme.primary.withValues(alpha: .14),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 720,
          child: Column(
            children: [
              _WizardHeader(
                step: _step,
                steps: _steps,
                onBack: _step == 0
                    ? () => Navigator.of(context).pop()
                    : () => setState(() => _step--),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                    child: Theme(data: wizardTheme, child: _content(context)),
                  ),
                ),
              ),
              _WizardFooter(
                busy: state.busy,
                finalStep: _step == 3,
                onContinue: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) => switch (_step) {
    0 => _DirectionStep(
      title: _title,
      category: _category,
      customCategory: _customCategory,
      onCategory: (value) => setState(() => _category = value),
      onTitleChanged: (_) => setState(() {}),
      onTemplate: _applyTemplate,
    ),
    1 => _OutcomeStep(
      outcome: _doneMeans,
      why: _why,
      goalTitle: _title.text,
      targetDate: _targetDate,
      ongoing: _ongoing,
      onOngoing: (value) => setState(() => _ongoing = value),
      onPickDate: _pickDate,
    ),
    2 => _RhythmStep(
      days: _days,
      frequency: _frequency,
      time: _time,
      duration: _duration,
      priority: _priority,
      constraints: _constraints,
      onDay: (day) => setState(
        () => _days.contains(day) ? _days.remove(day) : _days.add(day),
      ),
      onFrequency: (value) => setState(() => _frequency = value),
      onTime: (value) => setState(() => _time = value),
      onDuration: (value) => setState(() => _duration = value),
      onPriority: (value) => setState(() => _priority = value),
    ),
    _ => _RoadmapStep(
      goalTitle: _title.text,
      milestones: _milestones,
      actions: _actions,
      actionMilestoneIndexes: _actionMilestoneIndexes,
      onAddMilestone: () =>
          setState(() => _milestones.add(TextEditingController())),
      onRemoveMilestone: (index) => setState(() {
        _milestones.removeAt(index).dispose();
        for (
          var action = 0;
          action < _actionMilestoneIndexes.length;
          action++
        ) {
          final selected = _actionMilestoneIndexes[action];
          if (selected == index) _actionMilestoneIndexes[action] = null;
          if (selected != null && selected > index) {
            _actionMilestoneIndexes[action] = selected - 1;
          }
        }
      }),
      onAddAction: () => setState(() {
        _actions.add(TextEditingController());
        _actionMilestoneIndexes.add(null);
      }),
      onRemoveAction: (index) => setState(() {
        _actions.removeAt(index).dispose();
        _actionMilestoneIndexes.removeAt(index);
      }),
      onActionMilestone: (index, value) =>
          setState(() => _actionMilestoneIndexes[index] = value),
    ),
  };

  void _applyTemplate(_GoalTemplate template) => setState(() {
    _title.text = template.title;
    _doneMeans.text = template.outcome;
    _why.text = template.why;
    _actions.first.text = template.firstAction;
    _category = template.category;
  });

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'WHEN WOULD THIS FEEL COMPLETE?',
    );
    if (value != null) setState(() => _targetDate = value);
  }

  Color _categoryColor(String category) => onwardCategoryColor(category);

  int get _weeklyTarget => switch (_frequency) {
    'Once a week' => 1,
    '2 times a week' => 2,
    '4 times a week' => 4,
    'Most days' => 7,
    _ => 3,
  };
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.steps,
    required this.onBack,
  });

  final int step;
  final List<String> steps;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            Row(
              children: [
                AppCircleButton(
                  icon: step == 0
                      ? Icons.close_rounded
                      : Icons.arrow_back_rounded,
                  tooltip: step == 0 ? 'Close' : 'Previous step',
                  onPressed: onBack,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create a goal',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        steps[step],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onwardMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${step + 1} of ${steps.length}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                steps.length,
                (index) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 4,
                    margin: EdgeInsets.only(
                      right: index == steps.length - 1 ? 0 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: index <= step
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
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

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.busy,
    required this.finalStep,
    required this.onContinue,
  });

  final bool busy;
  final bool finalStep;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('goal-wizard-primary'),
            onPressed: busy ? null : onContinue,
            icon: busy
                ? SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : Icon(
                    finalStep
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(
              busy && finalStep
                  ? 'Building your plan...'
                  : finalStep
                  ? 'Build my plan'
                  : 'Continue',
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 7),
      Text(subtitle, style: _supporting(context)),
    ],
  );
}

class _GoalTemplate {
  const _GoalTemplate({
    required this.title,
    required this.icon,
    required this.category,
    required this.outcome,
    required this.why,
    required this.firstAction,
  });

  final String title;
  final IconData icon;
  final String category;
  final String outcome;
  final String why;
  final String firstAction;
}

const _goalTemplates = [
  _GoalTemplate(
    title: 'Build a fitness habit',
    icon: Icons.directions_run_rounded,
    category: 'Health',
    outcome: 'Move consistently and feel stronger and more energetic.',
    why: 'I want more energy for the people and work I care about.',
    firstAction: 'Do one comfortable 20-minute workout',
  ),
  _GoalTemplate(
    title: 'Learn something new',
    icon: Icons.menu_book_rounded,
    category: 'Learning',
    outcome: 'Finish one practical course and use what I learn.',
    why: 'I want to grow a skill that opens new possibilities.',
    firstAction: 'Choose a course and complete the first lesson',
  ),
  _GoalTemplate(
    title: 'Finish a project',
    icon: Icons.rocket_launch_outlined,
    category: 'Career',
    outcome: 'Ship a complete first version I can share with others.',
    why: 'Finishing this will create momentum for what comes next.',
    firstAction: 'Define the smallest version I can finish',
  ),
];

class _DirectionStep extends StatelessWidget {
  const _DirectionStep({
    required this.title,
    required this.category,
    required this.customCategory,
    required this.onCategory,
    required this.onTitleChanged,
    required this.onTemplate,
  });

  final TextEditingController title;
  final String category;
  final TextEditingController customCategory;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<_GoalTemplate> onTemplate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'What do you want to make progress on?',
          subtitle: 'Pick a starter to fill the plan, or name your own goal.',
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _goalTemplates
              .map(
                (template) => _GoalTemplateCard(
                  title: template.title,
                  icon: template.icon,
                  selected: title.text == template.title,
                  onTap: () => onTemplate(template),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: title,
          autofocus: false,
          onChanged: onTitleChanged,
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: 2,
          style: Theme.of(context).textTheme.titleLarge,
          decoration: const InputDecoration(
            labelText: 'Goal name',
            hintText: 'e.g. Feel strong in my body',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 22),
        Text('Category', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
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
                    (value) => ChoiceChip(
                      avatar: Icon(
                        _wizardCategoryIcon(value),
                        size: 17,
                        color: category == value
                            ? Theme.of(context).colorScheme.primary
                            : onwardMuted(context),
                      ),
                      label: Text(value),
                      selected: category == value,
                      showCheckmark: false,
                      onSelected: (_) => onCategory(value),
                    ),
                  )
                  .toList(),
        ),
        if (category == 'Custom') ...[
          const SizedBox(height: 14),
          TextField(
            controller: customCategory,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Custom category',
              hintText: 'Creative practice',
            ),
          ),
        ],
      ],
    );
  }
}

class _OutcomeStep extends StatelessWidget {
  const _OutcomeStep({
    required this.outcome,
    required this.why,
    required this.goalTitle,
    required this.targetDate,
    required this.ongoing,
    required this.onOngoing,
    required this.onPickDate,
  });

  final TextEditingController outcome;
  final TextEditingController why;
  final String goalTitle;
  final DateTime targetDate;
  final bool ongoing;
  final ValueChanged<bool> onOngoing;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'What will progress look like?',
          subtitle: 'A rough finish line is enough. You can refine it later.',
        ),
        const SizedBox(height: 22),
        if (goalTitle.isNotEmpty) ...[
          AppSurface(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            pressed: true,
            radius: 16,
            depth: .45,
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    goalTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: outcome,
          autofocus: false,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'A good outcome (optional)',
            hintText: 'e.g. Complete 30 workouts and feel more energetic',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        AppSurface(
          padding: const EdgeInsets.all(6),
          radius: 18,
          depth: .55,
          child: Column(
            children: [
              SwitchListTile(
                value: ongoing,
                onChanged: onOngoing,
                contentPadding: const EdgeInsets.only(left: 10, right: 4),
                title: const Text('Ongoing practice'),
                subtitle: const Text('Keep going without a deadline'),
              ),
              if (!ongoing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onPickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('Target date  ·  ${shortDate(targetDate)}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('Why it matters', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Optional, but useful on difficult days.',
          style: _supporting(context),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: why,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'This matters because…',
            hintText: 'I want more energy for the people I care about.',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _RhythmStep extends StatelessWidget {
  const _RhythmStep({
    required this.days,
    required this.frequency,
    required this.time,
    required this.duration,
    required this.priority,
    required this.constraints,
    required this.onDay,
    required this.onFrequency,
    required this.onTime,
    required this.onDuration,
    required this.onPriority,
  });

  final Set<String> days;
  final String frequency;
  final String time;
  final int duration;
  final String priority;
  final String constraints;
  final ValueChanged<String> onDay;
  final ValueChanged<String> onFrequency;
  final ValueChanged<String> onTime;
  final ValueChanged<int> onDuration;
  final ValueChanged<String> onPriority;

  @override
  Widget build(BuildContext context) {
    final times = ['Morning', 'Afternoon', 'Evening', 'Night', 'Flexible'];
    if (!times.contains(time)) times.add(time);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'Make it fit your real week.',
          subtitle:
              'Your onboarding choices are already selected. Adjust only what changed.',
        ),
        if (constraints.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppSurface(
            pressed: true,
            padding: const EdgeInsets.all(14),
            radius: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Keep in mind: $constraints')),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        AppSurface(
          padding: const EdgeInsets.all(16),
          radius: 20,
          depth: .7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How often?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    const [
                          'Once a week',
                          '2 times a week',
                          '3 times a week',
                          '4 times a week',
                          'Most days',
                        ]
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value),
                            selected: frequency == value,
                            showCheckmark: false,
                            onSelected: (_) => onFrequency(value),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 22),
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
                            selected: days.contains(day),
                            showCheckmark: false,
                            onSelected: (_) => onDay(day),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 22),
              Text('Best time', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: times
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: time == value,
                        showCheckmark: false,
                        onSelected: (_) => onTime(value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              Text(
                'Session length',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [15, 30, 45, 60]
                    .map(
                      (minutes) => ChoiceChip(
                        label: Text('$minutes min'),
                        selected: duration == minutes,
                        showCheckmark: false,
                        onSelected: (_) => onDuration(minutes),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              Text('Priority', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const ['Low', 'Medium', 'High']
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: priority == value.toLowerCase(),
                        showCheckmark: false,
                        onSelected: (_) => onPriority(value.toLowerCase()),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoadmapStep extends StatelessWidget {
  const _RoadmapStep({
    required this.goalTitle,
    required this.milestones,
    required this.actions,
    required this.actionMilestoneIndexes,
    required this.onAddMilestone,
    required this.onRemoveMilestone,
    required this.onAddAction,
    required this.onRemoveAction,
    required this.onActionMilestone,
  });

  final String goalTitle;
  final List<TextEditingController> milestones;
  final List<TextEditingController> actions;
  final List<int?> actionMilestoneIndexes;
  final VoidCallback onAddMilestone;
  final ValueChanged<int> onRemoveMilestone;
  final VoidCallback onAddAction;
  final ValueChanged<int> onRemoveAction;
  final void Function(int index, int? milestoneIndex) onActionMilestone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _StepIntro(
        title: 'Give Tara a useful starting point.',
        subtitle:
            'Actions and milestones are optional. Tara will turn your goal and rhythm into a different task for each scheduled day.',
      ),
      const SizedBox(height: 18),
      AppSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        pressed: true,
        radius: 16,
        depth: .45,
        child: Row(
          children: [
            Icon(
              Icons.track_changes_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                goalTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text(
        'Starting actions (optional)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      for (var index = 0; index < actions.length; index++) ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: actions[index],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Action ${index + 1}',
                  hintText: index == 0
                      ? 'Do one 20-minute session'
                      : 'Prepare what I need',
                ),
              ),
            ),
            if (actions.length > 1)
              IconButton(
                onPressed: () => onRemoveAction(index),
                tooltip: 'Remove action',
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        if (milestones.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppDropdownButtonFormField<int?>(
            initialValue: actionMilestoneIndexes[index],
            decoration: const InputDecoration(labelText: 'Belongs to'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('No milestone'),
              ),
              for (
                var milestone = 0;
                milestone < milestones.length;
                milestone++
              )
                DropdownMenuItem<int?>(
                  value: milestone,
                  child: Text('Milestone ${milestone + 1}'),
                ),
            ],
            onChanged: (value) => onActionMilestone(index, value),
          ),
        ],
        const SizedBox(height: 10),
      ],
      TextButton.icon(
        onPressed: onAddAction,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add another action'),
      ),
      const SizedBox(height: 22),
      Text(
        'Milestones (optional)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      for (var index = 0; index < milestones.length; index++) ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: milestones[index],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Milestone ${index + 1}',
                  hintText: index == 0
                      ? 'Build a comfortable foundation'
                      : 'Reach the next checkpoint',
                ),
              ),
            ),
            if (milestones.length > 1)
              IconButton(
                onPressed: () => onRemoveMilestone(index),
                tooltip: 'Remove milestone',
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
      TextButton.icon(
        onPressed: onAddMilestone,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add another milestone'),
      ),
    ],
  );
}

TextStyle? _supporting(BuildContext context) => Theme.of(
  context,
).textTheme.bodyLarge?.copyWith(color: onwardMuted(context));

class _GoalTemplateCard extends StatelessWidget {
  const _GoalTemplateCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Use template: $title',
    child: AppSurface(
      radius: 18,
      depth: .75,
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 154,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

IconData _wizardCategoryIcon(String category) =>
    switch (category.toLowerCase()) {
      'health' => Icons.directions_run_rounded,
      'learning' => Icons.menu_book_rounded,
      'career' => Icons.work_outline_rounded,
      'finance' => Icons.savings_outlined,
      'relationships' => Icons.favorite_outline_rounded,
      'productivity' => Icons.bolt_rounded,
      'custom' => Icons.add_rounded,
      _ => Icons.person_outline_rounded,
    };
