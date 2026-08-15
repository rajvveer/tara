import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'theme.dart';

const pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 32);

String shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String fullDate(DateTime date) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
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
  return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 680});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Flat authenticated-app card used by the Anova-derived layouts.
///
/// The legacy entry flow keeps its own neumorphic surface below; signed-in
/// screens use this deliberately simple white-card language instead.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.pressed = false,
    this.color,
    this.radius = 20,
    this.depth = 1,
    this.shape = BoxShape.rectangle,
    this.padding,
    this.margin,
    this.constraints,
  });

  final Widget child;
  final bool pressed;
  final Color? color;
  final double radius;
  final double depth;
  final BoxShape shape;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    constraints: constraints,
    decoration: pressed
        ? AppSurfaceStyle.pressed(
            context,
            color: color,
            radius: radius,
            depth: depth,
            shape: shape,
          )
        : AppSurfaceStyle.raised(
            context,
            color: color,
            radius: radius,
            depth: depth,
            shape: shape,
          ),
    child: child,
  );
}

class AppDropdownButtonFormField<T> extends StatelessWidget {
  const AppDropdownButtonFormField({
    super.key,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: onChanged,
      decoration: decoration,
      isExpanded: true,
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      dropdownColor: theme.colorScheme.surface,
      focusColor: Colors.transparent,
      menuMaxHeight: math.min(MediaQuery.sizeOf(context).height * .48, 360),
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
    );
  }
}

class AppPopupMenuButton<T> extends StatelessWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.initialValue,
    this.onOpened,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.padding = const EdgeInsets.all(8),
    this.child,
    this.icon,
    this.iconSize,
    this.offset = const Offset(0, 6),
    this.enabled = true,
  }) : assert(child == null || icon == null);

  final PopupMenuItemBuilder<T> itemBuilder;
  final T? initialValue;
  final VoidCallback? onOpened;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final String? tooltip;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final Widget? icon;
  final double? iconSize;
  final Offset offset;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuTheme(
      data: PopupMenuTheme.of(context).copyWith(
        color: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 5,
        shadowColor: theme.shadowColor.withValues(alpha: .28),
        menuPadding: const EdgeInsets.symmetric(vertical: 7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => theme.textTheme.labelLarge?.copyWith(
            color: states.contains(WidgetState.disabled)
                ? onwardMuted(context).withValues(alpha: .5)
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
      child: PopupMenuButton<T>(
        initialValue: initialValue,
        onOpened: onOpened,
        onSelected: onSelected,
        onCanceled: onCanceled,
        tooltip: tooltip,
        padding: padding,
        icon: icon,
        iconSize: iconSize,
        offset: offset,
        enabled: enabled,
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(minWidth: 152, maxWidth: 300),
        clipBehavior: Clip.antiAlias,
        popUpAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 180),
          reverseDuration: Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        itemBuilder: itemBuilder,
        child: child,
      ),
    );
  }
}

abstract final class AppSurfaceStyle {
  static BoxDecoration raised(
    BuildContext context, {
    Color? color,
    double radius = 20,
    double depth = 1,
    BoxShape shape = BoxShape.rectangle,
  }) => _decoration(
    context,
    color: color,
    radius: radius,
    depth: depth,
    shape: shape,
    selected: color == Theme.of(context).colorScheme.primary,
  );

  static BoxDecoration pressed(
    BuildContext context, {
    Color? color,
    double radius = 20,
    double depth = 1,
    BoxShape shape = BoxShape.rectangle,
  }) => _decoration(
    context,
    color: color,
    radius: radius,
    depth: depth,
    shape: shape,
    selected: false,
    tonal: true,
  );

  static BoxDecoration _decoration(
    BuildContext context, {
    required Color? color,
    required double radius,
    required double depth,
    required BoxShape shape,
    required bool selected,
    bool tonal = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? scheme.surface;
    return BoxDecoration(
      color: tonal
          ? Color.alphaBlend(scheme.primary.withValues(alpha: .065), base)
          : base,
      shape: shape,
      borderRadius: shape == BoxShape.circle
          ? null
          : BorderRadius.circular(radius),
      border: Border.all(
        color: selected
            ? scheme.primary.withValues(alpha: .18)
            : scheme.outline.withValues(alpha: dark ? .72 : .9),
      ),
      boxShadow: dark || depth <= .45
          ? null
          : [
              BoxShadow(
                color: const Color(
                  0xFF506C98,
                ).withValues(alpha: selected ? .12 : .07),
                blurRadius: depth >= 1.2 ? 22 : 14,
                offset: const Offset(0, 5),
              ),
            ],
    );
  }
}

class AppCircleButton extends StatelessWidget {
  const AppCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      shape: BoxShape.circle,
      color: filled ? scheme.primary : scheme.surface,
      depth: .7,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        color: filled ? scheme.onPrimary : scheme.onSurface,
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    required this.child,
    this.size = 96,
    this.strokeWidth = 8,
    this.color,
  });

  final double value;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: strokeWidth,
            color: scheme.outline.withValues(alpha: .45),
          ),
          CircularProgressIndicator(
            value: value.clamp(0, 1),
            strokeWidth: strokeWidth,
            strokeCap: StrokeCap.round,
            color: color ?? scheme.primary,
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

class OnwardNeumorphicSurface extends StatelessWidget {
  const OnwardNeumorphicSurface({
    super.key,
    required this.child,
    this.pressed = false,
    this.color,
    this.radius = OnwardNeumorphism.surfaceRadius,
    this.depth = 1,
    this.shape = BoxShape.rectangle,
    this.padding,
    this.margin,
    this.constraints,
  });

  final Widget child;
  final bool pressed;
  final Color? color;
  final double radius;
  final double depth;
  final BoxShape shape;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    constraints: constraints,
    decoration: pressed
        ? OnwardNeumorphism.pressed(
            context,
            color: color,
            radius: radius,
            depth: depth,
            shape: shape,
          )
        : OnwardNeumorphism.raised(
            context,
            color: color,
            radius: radius,
            depth: depth,
            shape: shape,
          ),
    child: child,
  );
}

class OnwardWordmark extends StatelessWidget {
  const OnwardWordmark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'GoalSpring',
      header: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 7 : 8,
              height: compact ? 7 : 8,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'GoalSpring',
              style:
                  (compact
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.caption, this.trailing});

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (caption != null) ...[
          const SizedBox(height: 3),
          Text(
            caption!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
          ),
        ],
      ],
    );
    if (trailing != null && MediaQuery.textScalerOf(context).scale(1) >= 1.6) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, const SizedBox(height: 6), trailing!],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        ?trailing,
      ],
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: .12),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Offline — showing your last saved plan',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = lower.contains('behind') || lower.contains('attention')
        ? dark
              ? const Color(0xFFFFB86B)
              : const Color(0xFFA84D00)
        : lower.contains('completed')
        ? dark
              ? const Color(0xFF60D5A3)
              : const Color(0xFF0D7A4F)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: .62);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.color,
    this.height = 7,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${(value * 100).round()} percent complete',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: color ?? Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.outline.withValues(alpha: .38),
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .62),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({
    super.key,
    required this.message,
    this.onDismiss,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
        ],
      ),
    ),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Bringing your plan together…'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
          ),
        ],
      ),
    ),
  );
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.action,
    required this.goal,
    required this.onComplete,
    this.onSkip,
    this.onStart,
    this.onReopen,
    this.onMiss,
    this.onEdit,
    this.onDelete,
    this.icon,
    this.floating = false,
  });

  final GoalAction action;
  final Goal? goal;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final VoidCallback? onStart;
  final VoidCallback? onReopen;
  final VoidCallback? onMiss;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final IconData? icon;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final complete = action.status == ActionStatus.completed;
    final category = goal?.category ?? 'Personal';
    final reflow = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    if (!floating) {
      return _StandardActionRow(
        action: action,
        goal: goal,
        onComplete: onComplete,
        onSkip: onSkip,
        onStart: onStart,
        onReopen: onReopen,
        onMiss: onMiss,
        onEdit: onEdit,
        onDelete: onDelete,
        complete: complete,
        category: category,
        reflow: reflow,
      );
    }
    return Semantics(
      button: !complete,
      enabled: !complete,
      label: complete
          ? '${action.title}, completed'
          : '${action.title}, ${action.estimatedDuration} minutes',
      onTap: complete ? null : onComplete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: ExcludeSemantics(
                child: IconButton(
                  tooltip: complete ? 'Completed' : 'Mark complete',
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 48,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: complete ? null : onComplete,
                  icon: Icon(
                    complete
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: complete
                        ? Theme.of(context).colorScheme.primary
                        : onwardCategoryColor(category),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AppSurface(
                key: ValueKey('floating-action-card-${action.id}'),
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                radius: 22,
                depth: .65,
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: onwardCategoryColor(category),
                      foregroundColor: Colors.white,
                      child: Icon(icon ?? Icons.flag_outlined, size: 16),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            action.title,
                            maxLines: reflow ? null : 1,
                            overflow: reflow ? null : TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: complete
                                      ? onwardMuted(context)
                                      : Theme.of(context).colorScheme.onSurface,
                                  decoration: complete
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            goal?.title ?? 'Finish',
                            maxLines: reflow ? null : 1,
                            overflow: reflow ? null : TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: onwardMuted(context)),
                          ),
                        ],
                      ),
                    ),
                    if (!reflow) ...[
                      const SizedBox(width: 8),
                      Text(
                        action.preferredTime.isNotEmpty
                            ? action.preferredTime
                            : '${action.estimatedDuration} min',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: onwardCategoryColor(category),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_hasMenu) ...[
              const SizedBox(width: 7),
              AppSurface(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                radius: 11,
                depth: .45,
                child: AppPopupMenuButton<String>(
                  tooltip: 'Action options',
                  padding: EdgeInsets.zero,
                  onSelected: _onMenu,
                  itemBuilder: (_) => _menuItems,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: onwardMuted(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasMenu =>
      onSkip != null ||
      onStart != null ||
      onReopen != null ||
      onMiss != null ||
      onEdit != null ||
      onDelete != null;

  List<PopupMenuEntry<String>> get _menuItems => [
    if (action.status == ActionStatus.upcoming && onStart != null)
      const PopupMenuItem(value: 'start', child: Text('Start action')),
    if (action.status != ActionStatus.upcoming && onReopen != null)
      const PopupMenuItem(value: 'reopen', child: Text('Reopen action')),
    if (action.status != ActionStatus.completed && onMiss != null)
      const PopupMenuItem(value: 'miss', child: Text('Mark missed')),
    if (action.status != ActionStatus.completed && onSkip != null)
      const PopupMenuItem(value: 'skip', child: Text('Skip for now')),
    if (onEdit != null)
      const PopupMenuItem(value: 'edit', child: Text('Edit action')),
    if (onDelete != null) ...[
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'delete', child: Text('Delete action')),
    ],
  ];

  void _onMenu(String value) => switch (value) {
    'start' => onStart?.call(),
    'reopen' => onReopen?.call(),
    'miss' => onMiss?.call(),
    'skip' => onSkip?.call(),
    'edit' => onEdit?.call(),
    'delete' => onDelete?.call(),
    _ => null,
  };
}

class _StandardActionRow extends StatelessWidget {
  const _StandardActionRow({
    required this.action,
    required this.goal,
    required this.onComplete,
    required this.onSkip,
    required this.onStart,
    required this.onReopen,
    required this.onMiss,
    required this.onEdit,
    required this.onDelete,
    required this.complete,
    required this.category,
    required this.reflow,
  });

  final GoalAction action;
  final Goal? goal;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final VoidCallback? onStart;
  final VoidCallback? onReopen;
  final VoidCallback? onMiss;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool complete;
  final String category;
  final bool reflow;

  @override
  Widget build(BuildContext context) => Semantics(
    button: !complete,
    label: complete
        ? '${action.title}, completed'
        : '${action.title}, ${action.estimatedDuration} minutes',
    child: AppSurface(
      constraints: const BoxConstraints(minHeight: 70),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      pressed: complete,
      radius: 18,
      depth: .65,
      color: complete
          ? Theme.of(context).colorScheme.surface
          : onwardCategorySurface(context, category),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 48,
            child: IconButton(
              tooltip: complete ? 'Completed' : 'Mark complete',
              onPressed: complete ? null : onComplete,
              icon: Icon(
                complete
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: complete
                    ? Theme.of(context).colorScheme.primary
                    : onwardCategoryColor(category),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action.title,
                  maxLines: reflow ? null : 3,
                  overflow: reflow ? null : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    letterSpacing: 0,
                    decoration: complete ? TextDecoration.lineThrough : null,
                    color: complete ? onwardMuted(context) : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (goal != null) goal!.title,
                    if (action.preferredTime.isNotEmpty) action.preferredTime,
                    '${action.estimatedDuration} min',
                  ].join(' · '),
                  maxLines: reflow ? null : 1,
                  overflow: reflow ? null : TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: onwardMuted(context)),
                ),
              ],
            ),
          ),
          if (_hasMenu)
            AppPopupMenuButton<String>(
              tooltip: 'Action options',
              padding: EdgeInsets.zero,
              onSelected: _onMenu,
              itemBuilder: (_) => _menuItems,
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
            ),
        ],
      ),
    ),
  );

  bool get _hasMenu =>
      onSkip != null ||
      onStart != null ||
      onReopen != null ||
      onMiss != null ||
      onEdit != null ||
      onDelete != null;

  List<PopupMenuEntry<String>> get _menuItems => [
    if (action.status == ActionStatus.upcoming && onStart != null)
      const PopupMenuItem(value: 'start', child: Text('Start action')),
    if (action.status != ActionStatus.upcoming && onReopen != null)
      const PopupMenuItem(value: 'reopen', child: Text('Reopen action')),
    if (action.status != ActionStatus.completed && onMiss != null)
      const PopupMenuItem(value: 'miss', child: Text('Mark missed')),
    if (action.status != ActionStatus.completed && onSkip != null)
      const PopupMenuItem(value: 'skip', child: Text('Skip for now')),
    if (onEdit != null)
      const PopupMenuItem(value: 'edit', child: Text('Edit action')),
    if (onDelete != null) ...[
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'delete', child: Text('Delete action')),
    ],
  ];

  void _onMenu(String value) => switch (value) {
    'start' => onStart?.call(),
    'reopen' => onReopen?.call(),
    'miss' => onMiss?.call(),
    'skip' => onSkip?.call(),
    'edit' => onEdit?.call(),
    'delete' => onDelete?.call(),
    _ => null,
  };
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.actions});

  final List<GoalAction> actions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final strip = SizedBox(
      height: 70,
      child: Row(
        children: List.generate(7, (index) {
          final date = monday.add(Duration(days: index));
          final isToday =
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
          final planned = actions.where((action) {
            final activityDate = action.status == ActionStatus.completed
                ? action.completedAt ?? action.dueDate
                : action.dueDate;
            return activityDate.year == date.year &&
                activityDate.month == date.month &&
                activityDate.day == date.day;
          }).toList();
          final completed = planned
              .where((action) => action.status == ActionStatus.completed)
              .toList();
          final actionProgress = planned.isEmpty
              ? 0.0
              : (completed.length / planned.length).clamp(0.0, 1.0);
          return Expanded(
            child: Semantics(
              label:
                  '${labels[index]} ${date.day}, ${(actionProgress * 100).round()} percent action completion',
              excludeSemantics: true,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      labels[index],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : onwardMuted(context),
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  CustomPaint(
                    key: ValueKey(
                      'week-action-ring-${date.year}-${date.month}-${date.day}',
                    ),
                    painter: _DayProgressPainter(
                      progress: actionProgress,
                      color: OnwardColors.aqua,
                    ),
                    child: SizedBox.square(
                      dimension: 38,
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : onwardMuted(context),
                                fontSize: 10,
                                height: 1,
                                fontWeight: isToday
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
    return MediaQuery.withClampedTextScaling(maxScaleFactor: 1.1, child: strip);
  }
}

class _DayProgressPainter extends CustomPainter {
  const _DayProgressPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ringBounds = (Offset.zero & size).deflate(1.4);
    final trackPaint = Paint()
      ..color = color.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(ringBounds, trackPaint);
    canvas.drawArc(
      ringBounds,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_DayProgressPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
