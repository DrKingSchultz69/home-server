import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import '../widgets/badges.dart';
import '../widgets/cards.dart';
import '../widgets/controls.dart';
import '../widgets/feedback.dart';
import '../widgets/lists.dart';
import 'shared.dart';
import 'ui_kit_screen.dart';

EdgeInsets _pad(bool wide) => wide ? const EdgeInsets.fromLTRB(24, 16, 24, 32) : const EdgeInsets.fromLTRB(16, 8, 16, 20);

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key, required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) => ListView(
        padding: _pad(wide),
        children: gap(16, [
          const PageHeader(title: 'Media'),
          GridView.count(
            crossAxisCount: wide ? 5 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: .52,
            children: [for (final p in demoPosters) PosterCard(poster: p)],
          ),
        ]),
      );
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) => ListView(
        padding: _pad(wide),
        children: gap(12, [
          const PageHeader(title: 'Alerts'),
          for (final b in demoBanners.reversed) WBanner(color: b.color, title: b.title, body: b.body, action: b.action),
        ]),
      );
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key, required this.wide});
  final bool wide;

  Future<void> _remove(BuildContext context, DemoUser u) async {
    final ok = await showWConfirm(
      context,
      title: 'Remove ${u.name}?',
      message: 'They lose access to ${u.role.label} services. Their files stay on the server.',
      confirmLabel: 'Remove',
    );
    if (ok && context.mounted) showWToast(context, WToast(message: '${u.name} removed', dot: WColors.ok));
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: _pad(wide),
        children: gap(16, [
          const PageHeader(title: 'Users'),
          WGroup(children: [
            for (final u in demoUsers)
              WListRow(
                title: u.name,
                subtitle: u.lastSeen,
                leading: IconTile(text: u.initials, size: 30, circle: true),
                trailing: RoleBadge(u.role),
                onTap: u.role == WRole.admin ? null : () => _remove(context, u),
              ),
          ]),
        ]),
      );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.wide});
  final bool wide;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _push = true;

  @override
  Widget build(BuildContext context) => ListView(
        padding: _pad(widget.wide),
        children: gap(16, [
          const PageHeader(title: 'Settings'),
          WGroup(children: [
            WListRow(
              title: 'Users & roles',
              value: '${demoUsers.length}',
              chevron: true,
              leading: const IconTile(icon: Icons.person_outline_rounded, color: WColors.primary),
              onTap: () {},
            ),
            WListRow(
              title: 'Push alerts',
              leading: const IconTile(icon: Icons.notifications_none_rounded, color: WColors.warning, fg: WColors.base),
              trailing: WToggle(value: _push, onChanged: (v) => setState(() => _push = v)),
            ),
            WListRow(
              title: 'UI kit',
              subtitle: 'All components and states',
              chevron: true,
              leading: const IconTile(icon: Icons.grid_view_rounded, color: WColors.raised),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UiKitScreen())),
            ),
          ]),
          WGroup(children: [WListRow(title: 'Sign out', destructive: true, onTap: () {})]),
          Center(child: Text('Signing out keeps this device on your network.', style: WText.caption)),
          const Center(child: MetaChip('Watcher 0.1.0')),
        ]),
      );
}
