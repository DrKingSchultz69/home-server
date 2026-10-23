import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'controls.dart';

class StatusDot extends StatelessWidget {
  const StatusDot(this.color, {super.key, this.size = 6, this.hollow = false});
  final Color color;
  final double size;
  final bool hollow;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hollow ? null : color,
          border: hollow ? Border.all(color: color, width: 1.5) : null,
        ),
      );
}

/// Tinted pill with a dot: Online / Degraded / Down / Unknown / Restarting.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, this.label, {super.key, this.small = false});
  final WStatus status;
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final lead = switch (status) {
      WStatus.busy => const Spinner(color: WColors.primary, size: 10),
      WStatus.unknown => const StatusDot(WColors.secondary, hollow: true),
      _ => StatusDot(status.color),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: small ? 2 : 5),
      decoration: BoxDecoration(color: status.tint, borderRadius: BorderRadius.circular(small ? 6 : WRadius.badge)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        lead,
        const SizedBox(width: 6),
        Text(label, style: WText.label.copyWith(color: status.color, fontSize: small ? 11 : 12)),
      ]),
    );
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key, this.small = false});
  final WRole role;
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: small ? 2 : 5),
        decoration: BoxDecoration(color: role.bg, borderRadius: BorderRadius.circular(small ? 6 : WRadius.badge)),
        child: Text(role.label, style: WText.label.copyWith(color: role.fg, fontSize: small ? 11 : 12)),
      );
}

class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.size = 20});
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(minWidth: size),
        height: size,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: WColors.down, borderRadius: BorderRadius.circular(size / 2)),
        child: Text('$count',
            style: WText.mono.copyWith(fontSize: size > 16 ? 12 : 10, fontWeight: FontWeight.w500, color: WColors.text)),
      );
}

/// Grey mono chip, e.g. "4K · HDR".
class MetaChip extends StatelessWidget {
  const MetaChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: WColors.raised, borderRadius: BorderRadius.circular(WRadius.badge)),
        child: Text(text, style: WText.monoSmall),
      );
}
