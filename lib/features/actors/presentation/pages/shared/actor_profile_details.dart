import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';

class ActorProfileDetails extends StatefulWidget {
  const ActorProfileDetails({
    super.key,
    required this.actor,
    required this.compact,
  });

  final ActorDetailDto actor;
  final bool compact;

  @override
  State<ActorProfileDetails> createState() => _ActorProfileDetailsState();
}

class _ActorProfileDetailsState extends State<ActorProfileDetails> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ActorProfileDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor.summary.id != widget.actor.summary.id) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = widget.actor;
    final birthday = actor.birthday;
    final age = actor.age == null ? null : '${actor.age}岁';
    final fields = <(String, String)>[
      if (birthday != null)
        (
          '生日',
          '${birthday.year}年${birthday.month}月${birthday.day}日${age == null ? '' : ' · $age'}',
        )
      else if (age != null)
        ('年龄', age),
      if (actor.birthplace != null) ('出生地', actor.birthplace!),
      if (actor.bloodType != null) ('血型', actor.bloodType!),
      if (actor.heightCm != null) ('身高', '${actor.heightCm} cm'),
      if (actor.cup != null) ('罩杯', actor.cup!),
      if (actor.bustCm != null) ('胸围', '${actor.bustCm} cm'),
      if (actor.waistCm != null) ('腰围', '${actor.waistCm} cm'),
      if (actor.hipsCm != null) ('臀围', '${actor.hipsCm} cm'),
    ];
    if (fields.isEmpty) return const SizedBox.shrink();

    final summary = <(String, String)>[
      if (age != null) ('年龄', age),
      if (actor.heightCm != null) ('身高', '${actor.heightCm} cm'),
      if (actor.cup != null) ('罩杯', actor.cup!),
    ];
    // 只有出生地等少量资料时直接显示，避免空摘要和无意义的展开操作。
    if (summary.isEmpty) summary.addAll(fields.take(3));
    final hasMore = fields.any((field) => !summary.contains(field));
    final visible = widget.compact && !_expanded ? summary : fields;
    final spacing = context.appSpacing;
    final details = SelectionArea(
      child: Wrap(
        spacing: spacing.lg,
        runSpacing: spacing.xs,
        children: [
          for (final (label, value) in visible)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      tone: AppTextTone.muted,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s10,
                tone: AppTextTone.secondary,
              ),
            ),
        ],
      ),
    );
    return Padding(
      key: const Key('actor-profile-details'),
      padding: EdgeInsets.only(top: widget.compact ? spacing.sm : spacing.xs),
      child: widget.compact && hasMore
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.xs),
                    child: details,
                  ),
                ),
                SizedBox(width: spacing.sm),
                AppIconButton(
                  key: const Key('actor-profile-toggle'),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  size: AppIconButtonSize.mini,
                  tooltip: _expanded ? '收起资料' : '展开资料',
                  semanticLabel: _expanded ? '收起资料' : '展开资料',
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            )
          : details,
    );
  }
}
