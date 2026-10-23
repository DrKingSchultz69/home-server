import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import '../widgets/badges.dart';
import '../widgets/cards.dart';
import '../widgets/charts.dart';
import '../widgets/controls.dart';
import '../widgets/feedback.dart';
import '../widgets/lists.dart';
import 'other_screens.dart';
import 'shared.dart';

/// Admin Overview. Phone layout follows the kit's Android example; on wide
/// windows the same blocks spread into two columns.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, required this.wide});
  final bool wide;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  String _range = '24h';

  Future<void> _restart(String name) async {
    final ok = await showWConfirm(
      context,
      title: 'Restart $name?',
      message: 'People using $name will be disconnected for a few seconds.',
      confirmLabel: 'Restart',
      destructive: false,
    );
    if (!ok || !mounted) return;
    showWToast(context, WToast(message: 'Restarting $name…', loading: true));
  }

  void _serviceSheet(DemoService s) {
    showWActionSheet(
      context,
      WActionSheet(
        header: Row(children: [
          IconTile(text: s.name[0], size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: WText.title),
              Text(s.meta, style: WText.mono.copyWith(fontSize: 12)),
            ]),
          ),
          StatusBadge(s.status, s.statusLabel),
        ]),
        actions: [
          SheetAction('Restart service', onTap: () {
            Navigator.pop(context);
            _restart(s.name);
          }),
          SheetAction('View logs', onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = const ServerStatusCard(
      status: WStatus.warn,
      statusLabel: '1 service down',
      bigValue: '6/7',
      bigUnit: 'services online',
      footer: 'Up 41d 6h · checked 12 s ago',
      monoFooter: true,
    );
    final range = WSegmented(options: const ['24h', '7d', '30d'], selected: _range, mono: true, onChanged: (r) => setState(() => _range = r));
    final banner = WBanner(
      color: WColors.down,
      title: 'Home Assistant is down',
      body: 'No response on :8123 for 4 min.',
      action: 'Restart',
      onAction: () => _restart('Home Assistant'),
    );
    final services = WGroup(header: 'Services', children: [
      for (final s in demoServices)
        WListRow(
          title: s.name,
          subtitle: s.meta,
          titleWeight: FontWeight.w500,
          minHeight: 56,
          leading: IconTile(text: s.name[0], size: 32),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusDot(s.status.color, size: 7),
            const SizedBox(width: 6),
            Text(s.statusLabel, style: WText.caption.copyWith(color: s.status.color)),
          ]),
          onTap: () => _serviceSheet(s),
        ),
    ]);
    final users = WGroup(header: 'Users', children: [
      for (final u in demoUsers)
        WListRow(
          title: u.name,
          leading: IconTile(text: u.initials, size: 30, circle: true),
          trailing: RoleBadge(u.role),
        ),
    ]);

    if (!widget.wide) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: gap(16, [
          PageHeader(
            title: 'Overview',
            host: 'homeserver',
            role: WRole.admin,
            mark: true,
            // Phone has 4 tabs; Settings opens from the mark.
            onMarkTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const Scaffold(body: SafeArea(child: SettingsScreen(wide: false))),
            )),
          ),
          status,
          range,
          for (final pair in [demoStats.sublist(0, 2), demoStats.sublist(2)])
            Row(children: [
              Expanded(child: StatTile(stat: pair[0], range: _range, valueSize: 22, showDelta: false)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(stat: pair[1], range: _range, valueSize: 22, showDelta: false)),
            ]),
          banner,
          services,
          users,
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: gap(16, [
        Row(children: [
          const Expanded(child: PageHeader(title: 'Overview', host: 'homeserver', role: WRole.admin)),
          SizedBox(width: 220, child: range),
        ]),
        status,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < demoStats.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: StatTile(stat: demoStats[i], range: _range)),
          ],
        ]),
        banner,
        LineChartCard(title: 'CPU load', range: _range, points: demoCpu[_range]!, xTicks: demoXTicks[_range]!),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: services),
          const SizedBox(width: 16),
          Expanded(
            child: Column(children: [
              users,
              const SizedBox(height: 16),
              const StorageCard(),
            ]),
          ),
        ]),
      ]),
    );
  }
}
