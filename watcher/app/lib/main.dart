import 'package:flutter/material.dart';

import 'screens/files_screen.dart';
import 'screens/other_screens.dart';
import 'screens/overview_screen.dart';
import 'screens/shared.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';
import 'widgets/charts.dart';
import 'widgets/badges.dart';
import 'widgets/nav.dart';

void main() => runApp(const WatcherApp());

class WatcherApp extends StatelessWidget {
  const WatcherApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Watcher',
        debugShowCheckedModeBanner: false,
        theme: buildWatcherTheme(),
        home: const Shell(),
      );
}

/// Phone (< 600 wide): bottom tab bar with 4 destinations.
/// Desktop: 240px sidebar; Users and Settings are admin-only extras.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _dests = [
    NavDest('Overview', Icons.space_dashboard_outlined),
    NavDest('Media', Icons.play_circle_outline_rounded),
    NavDest('Files', Icons.folder_outlined),
    NavDest('Alerts', Icons.notifications_none_rounded, count: 3, alert: true),
    NavDest('Users', Icons.people_outline_rounded, count: 5),
    NavDest('Settings', Icons.settings_outlined),
  ];

  Widget _page(int i, bool wide) => switch (i) {
        0 => OverviewScreen(wide: wide),
        1 => MediaScreen(wide: wide),
        2 => FilesScreen(wide: wide),
        3 => AlertsScreen(wide: wide),
        4 => UsersScreen(wide: wide),
        _ => SettingsScreen(wide: wide),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    if (!wide) {
      final tabIndex = _index > 3 ? 0 : _index;
      return Scaffold(
        body: SafeArea(bottom: false, child: _page(tabIndex, false)),
        bottomNavigationBar: WTabBar(items: _dests.sublist(0, 4), index: tabIndex, onTap: (i) => setState(() => _index = i)),
      );
    }
    return Scaffold(
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          width: 240,
          color: WColors.surface,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 6, 10, 16),
              child: Row(children: [
                WatcherMark(size: 26),
                SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('homeserver', style: WText.bodyStrong),
                  Row(children: [
                    StatusDot(WColors.ok),
                    SizedBox(width: 5),
                    Text('Online', style: TextStyle(fontSize: 12, color: WColors.ok)),
                  ]),
                ]),
              ]),
            ),
            for (var i = 0; i < _dests.length; i++) ...[
              SidebarItem(dest: _dests[i], active: i == _index, onTap: () => setState(() => _index = i)),
              const SizedBox(height: 2),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text('Storage', style: WText.caption.copyWith(fontSize: 12))),
                  Text('3.1 / 8 TB', style: WText.mono.copyWith(fontSize: 12, color: WColors.text)),
                ]),
                const SizedBox(height: 8),
                const UsageBar(fraction: .39, height: 6),
              ]),
            ),
          ]),
        ),
        Expanded(child: _page(_index, true)),
      ]),
    );
  }
}
