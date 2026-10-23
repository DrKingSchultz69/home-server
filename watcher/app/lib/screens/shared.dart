import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/badges.dart';

/// Inserts fixed vertical gaps between children.
List<Widget> gap(double size, List<Widget> children) => [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: size), children[i]],
    ];

/// The app mark. Uses the owner's icon asset.
class WatcherMark extends StatelessWidget {
  const WatcherMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: Image.asset('assets/watcher_icon.png', width: size, height: size, filterQuality: FilterQuality.medium),
      );
}

/// Large title with the host and role above it.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.host, this.role, this.mark = false, this.onMarkTap});
  final String title;
  final String? host;
  final WRole? role;
  final bool mark;
  final VoidCallback? onMarkTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (host != null || role != null)
                Row(children: [
                  if (host != null) Text(host!, style: WText.caption),
                  if (role != null) ...[const SizedBox(width: 8), RoleBadge(role!, small: true)],
                ]),
              const SizedBox(height: 2),
              Text(title, style: WText.large),
            ]),
          ),
          if (mark) GestureDetector(onTap: onMarkTap, child: const WatcherMark()),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: WColors.secondary),
            const SizedBox(height: 12),
            Text(title, style: WText.title),
            const SizedBox(height: 4),
            Text(body, style: WText.caption, textAlign: TextAlign.center),
          ]),
        ),
      );
}
