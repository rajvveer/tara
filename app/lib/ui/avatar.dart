import 'package:flutter/material.dart';

import 'theme.dart';

const onwardAvatarHeads = [
  'woman',
  'man',
  'neutral',
  'amara',
  'arjun',
  'mei',
  'leo',
  'zoya',
  'noor',
  'sam',
];
const onwardAvatarTops = [
  'violet',
  'blue',
  'rose',
  'coral',
  'mustard',
  'mint',
  'tangerine',
  'crimson',
  'turquoise',
  'cream',
];
const onwardAvatarBottoms = [
  'navy',
  'teal',
  'plum',
  'forest',
  'denim',
  'charcoal',
  'indigo',
  'sand',
  'burgundy',
  'cobalt',
];
const onwardAvatarHeadLabels = {
  'woman': 'Woman',
  'man': 'Man',
  'neutral': 'Neutral',
  'amara': 'Amara',
  'arjun': 'Arjun',
  'mei': 'Mei',
  'leo': 'Leo',
  'zoya': 'Zoya',
  'noor': 'Noor',
  'sam': 'Sam',
};
const onwardAvatarTopColors = {
  'violet': Color(0xFF9372EA),
  'blue': Color(0xFF70AFE8),
  'rose': Color(0xFFE97098),
  'coral': Color(0xFFFB7560),
  'mustard': Color(0xFFFDB426),
  'mint': Color(0xFF96E9D5),
  'tangerine': Color(0xFFFD8C14),
  'crimson': Color(0xFFC31523),
  'turquoise': Color(0xFF14D1D1),
  'cream': Color(0xFFFDF1E1),
};
const onwardAvatarBottomColors = {
  'navy': Color(0xFF233255),
  'teal': Color(0xFF205048),
  'plum': Color(0xFF482050),
  'forest': Color(0xFF224F28),
  'denim': Color(0xFF20407C),
  'charcoal': Color(0xFF4B504B),
  'indigo': Color(0xFF1A2B55),
  'sand': Color(0xFFEFCBA7),
  'burgundy': Color(0xFF69121A),
  'cobalt': Color(0xFF194AD2),
};

// The source illustrations have slightly different transparent bounds. Scale
// each one to the neutral character's visible 341 x 580 frame so switching
// heads never makes the whole character look shorter or larger.
const _onwardCharacterScale = <String, Size>{
  'woman': Size(1.0302, 1.0052),
  'man': Size(.9971, 1),
  'neutral': Size(1, 1),
  'amara': Size(1.0089, .9764),
  'arjun': Size(.9855, .9881),
  'mei': Size(.9971, 1.0193),
  'leo': Size(.9715, .9781),
  'zoya': Size(.9827, .9915),
  'noor': Size(1, .9898),
  'sam': Size(.9799, .9847),
};
const defaultOnwardAvatar = 'neutral-violet-navy';

String normalizeOnwardAvatar(String? value) {
  final parts = value?.split('-') ?? const <String>[];
  if (parts.length != 3 ||
      !onwardAvatarHeads.contains(parts[0]) ||
      !onwardAvatarTops.contains(parts[1]) ||
      !onwardAvatarBottoms.contains(parts[2])) {
    return defaultOnwardAvatar;
  }
  return value!;
}

String onwardAvatarHead(String value) =>
    normalizeOnwardAvatar(value).split('-')[0];
String onwardAvatarTop(String value) =>
    normalizeOnwardAvatar(value).split('-')[1];
String onwardAvatarBottom(String value) =>
    normalizeOnwardAvatar(value).split('-')[2];

String onwardAvatarKey({
  required String head,
  required String top,
  required String bottom,
}) => '$head-$top-$bottom';

String onwardAvatarPortraitAsset(String avatarKey) =>
    'assets/avatars/avatar-${onwardAvatarHead(avatarKey)}.png';

String onwardCharacterLayerAsset(String avatarKey, String layer) =>
    'assets/avatars/character-layer-${onwardAvatarHead(avatarKey)}-$layer.png';

class OnwardCharacter extends StatelessWidget {
  const OnwardCharacter({super.key, required this.avatarKey});

  final String avatarKey;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeOnwardAvatar(avatarKey);
    final characterScale =
        _onwardCharacterScale[onwardAvatarHead(normalized)] ?? const Size(1, 1);
    Widget layer(String name, {Color? tint}) {
      final selection = switch (name) {
        'top' => onwardAvatarTop(normalized),
        'bottom' => onwardAvatarBottom(normalized),
        _ => onwardAvatarHead(normalized),
      };
      final image = Image.asset(
        onwardCharacterLayerAsset(normalized, name),
        key: ValueKey('character-$name-image'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        excludeFromSemantics: name != 'base',
        semanticLabel: name == 'base' ? 'Selected GoalSpring character' : null,
        filterQuality: FilterQuality.high,
      );
      return tint == null
          ? image
          : ColorFiltered(
              key: ValueKey('character-$name-$selection'),
              colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
              child: image,
            );
    }

    return Transform.scale(
      scaleX: characterScale.width,
      scaleY: characterScale.height,
      alignment: Alignment.bottomCenter,
      child: Stack(
        fit: StackFit.expand,
        children: [
          layer('base'),
          layer(
            'bottom',
            tint: onwardAvatarBottomColors[onwardAvatarBottom(normalized)],
          ),
          layer(
            'top',
            tint: onwardAvatarTopColors[onwardAvatarTop(normalized)],
          ),
        ],
      ),
    );
  }
}

class OnwardAvatar extends StatelessWidget {
  const OnwardAvatar({
    super.key,
    required this.name,
    required this.avatarKey,
    this.radius = 28,
    this.profileImageUrl,
  });

  final String name;
  final String? avatarKey;
  final double radius;
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '$name avatar',
    child: CircleAvatar(
      radius: radius,
      backgroundColor: OnwardColors.lilac,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: profileImageUrl?.trim().isNotEmpty == true
              ? Image.network(
                  profileImageUrl!.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Image.asset(
                    onwardAvatarPortraitAsset(normalizeOnwardAvatar(avatarKey)),
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  onwardAvatarPortraitAsset(normalizeOnwardAvatar(avatarKey)),
                  fit: BoxFit.cover,
                ),
        ),
      ),
    ),
  );
}

class OnwardAvatarHeadPicker extends StatelessWidget {
  const OnwardAvatarHeadPicker({
    super.key,
    required this.avatarKey,
    required this.onChanged,
  });

  final String avatarKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedHead = onwardAvatarHead(avatarKey);
    String avatarFor(String head) {
      return onwardAvatarKey(
        head: head,
        top: onwardAvatarTop(avatarKey),
        bottom: onwardAvatarBottom(avatarKey),
      );
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: onwardAvatarHeads.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final head = onwardAvatarHeads[index];
          final label = onwardAvatarHeadLabels[head]!;
          final selected = selectedHead == head;
          final option = avatarFor(head);
          return SizedBox(
            width: 88,
            child: Semantics(
              button: true,
              selected: selected,
              label: '$label avatar',
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .10)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      OnwardAvatar(name: label, avatarKey: option, radius: 28),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
