import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'badges.dart';
import 'controls.dart';

class NavDest {
  const NavDest(this.label, this.icon, {this.count, this.alert = false});
  final String label;
  final IconData icon;
  final int? count;
  final bool alert; // count shown in red (unread alerts)
}

/// Android bottom tab bar: 72 high, active = blue, red badge for unread.
class WTabBar extends StatelessWidget {
  const WTabBar({super.key, required this.items, required this.index, required this.onTap});
  final List<NavDest> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        color: WColors.surface,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Pressable(
                    onTap: () => onTap(i),
                    builder: (context, _, __) {
                      final active = i == index;
                      final c = active ? WColors.primary : WColors.secondary;
                      final d = items[i];
                      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Stack(clipBehavior: Clip.none, children: [
                          Icon(d.icon, size: 24, color: c),
                          if (d.alert && (d.count ?? 0) > 0)
                            Positioned(top: -6, right: -10, child: CountBadge(d.count!, size: 16)),
                        ]),
                        const SizedBox(height: 5),
                        Text(d.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c)),
                      ]);
                    },
                  ),
                ),
            ]),
          ),
        ),
      );
}

/// Windows sidebar row: 40 high, active row #2C2C2E with blue icon.
class SidebarItem extends StatelessWidget {
  const SidebarItem({super.key, required this.dest, required this.active, required this.onTap});
  final NavDest dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        builder: (context, hover, _) => Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active || hover ? WColors.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(dest.icon, size: 18, color: active ? WColors.primary : WColors.secondary),
            const SizedBox(width: 10),
            Expanded(child: Text(dest.label, style: const TextStyle(fontSize: 14, color: WColors.text))),
            if (dest.count != null)
              Text('${dest.count}', style: WText.mono.copyWith(fontSize: 12, color: dest.alert ? WColors.down : WColors.secondary)),
          ]),
        ),
      );
}
