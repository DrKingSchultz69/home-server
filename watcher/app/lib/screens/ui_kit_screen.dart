import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import '../widgets/badges.dart';
import '../widgets/cards.dart';
import '../widgets/charts.dart';
import '../widgets/controls.dart';
import '../widgets/feedback.dart';
import '../widgets/lists.dart';
import 'shared.dart';

/// Every component from the kit in its states, for checking against the design.
class UiKitScreen extends StatefulWidget {
  const UiKitScreen({super.key});

  @override
  State<UiKitScreen> createState() => _UiKitScreenState();
}

class _UiKitScreenState extends State<UiKitScreen> {
  bool _on = true;
  String _range = '24h';
  String _view = 'List';
  int _fileSel = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.canvas,
      appBar: AppBar(
        backgroundColor: WColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: const Row(children: [WatcherMark(size: 28), SizedBox(width: 10), Text('Watcher UI Kit', style: WText.title)]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(spacing: 24, runSpacing: 24, children: [
            _panel('01 · COLOUR', _colours()),
            _panel('02 · TYPE · RADII', _type()),
            _panel('03 · BUTTONS', _buttons(), wide: true),
            _panel('04 · INPUTS', _inputs()),
            _panel('05 · TOGGLES · SEGMENTED', _toggles()),
            _panel('06 · BADGES', _badges()),
            _panel('07 · LIST ROWS', _rows()),
            _panel('08 · SERVICE CARDS', _serviceCards(), wide: true),
            _panel('09 · SERVER STATUS · STAT TILES', _status(), wide: true),
            _panel('10 · CHARTS', _charts(), wide: true),
            _panel('11 · BANNERS · TOASTS', _banners()),
            _panel('12 · SHEET · CONFIRM DIALOG', _sheets(), wide: true),
            _panel('14 · FILE ITEMS', _files(), wide: true),
            _panel('15 · VIDEO POSTER CARDS', _posters(), wide: true),
          ]),
        ],
      ),
    );
  }

  Widget _panel(String label, Widget child, {bool wide = false}) => LayoutBuilder(builder: (context, c) {
        final w = (wide ? 760.0 : 560.0).clamp(0.0, MediaQuery.sizeOf(context).width - 48);
        return Container(
          width: w,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: WColors.base, borderRadius: BorderRadius.circular(WRadius.panel)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: WText.sectionLabel),
            const SizedBox(height: 18),
            child,
          ]),
        );
      });

  Widget _colours() {
    const swatches = [
      ('Base', WColors.base, '#101011'), ('Surface', WColors.surface, '#1C1C1E'), ('Raised', WColors.raised, '#2C2C2E'),
      ('Text', WColors.text, '#F5F5F7'), ('Secondary', WColors.secondary, '#8E8E93'), ('Primary', WColors.primary, '#0A84FF'),
      ('Data', WColors.data, '#30D5C8'), ('OK', WColors.ok, '#30D158'), ('Warning', WColors.warning, '#FF9F0A'), ('Down', WColors.down, '#FF453A'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          for (final (name, c, hex) in swatches)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(WRadius.control),
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                ),
              ),
              const SizedBox(height: 6),
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(hex, style: WText.monoSmall),
            ]),
        ],
      ),
      const SizedBox(height: 20),
      Text('Tints for badges and banners: status colour at 15% on #1C1C1E. Blue is the only interactive colour. Teal is reserved for data.',
          style: WText.caption.copyWith(height: 1.5)),
    ]);
  }

  Widget _type() {
    Widget row(String spec, Widget sample) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            SizedBox(width: 84, child: Text(spec, style: WText.monoSmall)),
            const SizedBox(width: 16),
            Flexible(child: sample),
          ]),
        );
    Widget radius(double r, String label) => Column(children: [
          Container(width: 56, height: 40, decoration: BoxDecoration(color: WColors.raised, borderRadius: BorderRadius.circular(r))),
          const SizedBox(height: 6),
          Text(label, style: WText.monoSmall),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row('Status 56/700', const Text('41d', style: WText.status)),
      row('Large 30/700', const Text('Overview', style: WText.large)),
      row('Title 17/600', const Text('Jellyfin', style: WText.title)),
      row('Body 15/400', const Text('Streaming to 3 devices', style: WText.body)),
      row('Caption 13', Text('Last checked 12 s ago', style: WText.caption)),
      row('Data mono', Text('11.4 GB · 84 Mb/s', style: WText.monoValue.copyWith(fontSize: 22, fontWeight: FontWeight.w400))),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        radius(8, '8 badge'),
        const SizedBox(width: 12),
        radius(12, '12 control'),
        const SizedBox(width: 12),
        radius(16, '16 card'),
        const SizedBox(width: 20),
        Expanded(child: Text('Spacing 4 · 8 · 12 · 16 · 24 · 32. Min hit target 48dp.', style: WText.caption.copyWith(height: 1.5))),
      ]),
    ]);
  }

  Widget _buttons() {
    Widget line(String label, WButtonKind k, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(width: 100, child: Text(label, style: WText.caption)),
            Expanded(child: WButton(text, kind: k, expand: true, onPressed: () {})),
            const SizedBox(width: 10),
            Expanded(child: WButton(text, kind: k, expand: true, loading: true, onPressed: () {})),
            const SizedBox(width: 10),
            Expanded(child: WButton(text, kind: k, expand: true)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SizedBox(width: 100),
        for (final h in ['DEFAULT (hover / press me)', 'LOADING', 'DISABLED']) Expanded(child: Text(h, style: WText.monoSmall)),
      ]),
      const SizedBox(height: 10),
      line('Primary', WButtonKind.primary, 'Restart'),
      line('Secondary', WButtonKind.secondary, 'View logs'),
      line('Destructive', WButtonKind.destructive, 'Remove'),
      line('Plain', WButtonKind.plain, 'Cancel'),
      Row(children: [
        WButton('Small', small: true, onPressed: () {}),
        const SizedBox(width: 10),
        WButton('Small', small: true, kind: WButtonKind.secondary, onPressed: () {}),
        const SizedBox(width: 10),
        WIconButton(icon: Icons.refresh_rounded, onPressed: () {}),
        const SizedBox(width: 10),
        Text('Icon button 48 · small 36 (desktop only)', style: WText.caption),
      ]),
    ]);
  }

  Widget _inputs() => Column(children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.6,
          children: [
            _labelled('Default', const WTextField(hint: 'Search')),
            _labelled('Filled', WTextField(controller: TextEditingController(text: 'homeserver'))),
            _labelled('Error', WTextField(controller: TextEditingController(text: '192.168.1.999'), error: 'Not a valid IP address')),
            _labelled('Disabled', const WTextField(hint: 'Port 8096', enabled: false)),
            _labelled('Password', WTextField(controller: TextEditingController(text: 'password'), obscure: true)),
          ],
        ),
        const SizedBox(height: 16),
        const WTextField(hint: 'Search files and media', leading: Icons.search_rounded, height: 40),
      ]);

  Widget _labelled(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: WText.caption),
        const SizedBox(height: 6),
        child,
      ]);

  Widget _toggles() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (final (label, w) in [
            ('LIVE', WToggle(value: _on, onChanged: (v) => setState(() => _on = v))),
            ('ON', WToggle(value: true, onChanged: (_) {})),
            ('OFF', WToggle(value: false, onChanged: (_) {})),
            ('DISABLED', const WToggle(value: true)),
          ]) ...[
            Column(children: [w, const SizedBox(height: 6), Text(label, style: WText.monoSmall)]),
            const SizedBox(width: 28),
          ],
        ]),
        const SizedBox(height: 18),
        WSegmented(options: const ['24h', '7d', '30d'], selected: _range, mono: true, onChanged: (r) => setState(() => _range = r)),
        const SizedBox(height: 10),
        FractionallySizedBox(
          widthFactor: .6,
          child: WSegmented(options: const ['List', 'Grid'], selected: _view, onChanged: (v) => setState(() => _view = v)),
        ),
      ]);

  Widget _badges() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Wrap(spacing: 8, runSpacing: 8, children: [
          StatusBadge(WStatus.ok, 'Online'),
          StatusBadge(WStatus.warn, 'Degraded'),
          StatusBadge(WStatus.down, 'Down'),
          StatusBadge(WStatus.unknown, 'Unknown'),
          StatusBadge(WStatus.busy, 'Restarting'),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final r in WRole.values) RoleBadge(r),
          const CountBadge(3),
          const MetaChip('4K · HDR'),
        ]),
      ]);

  Widget _rows() => WGroup(children: [
        WListRow(title: 'Users & roles', value: '5', chevron: true, leading: const IconTile(icon: Icons.person_outline_rounded, color: WColors.primary), onTap: () {}),
        WListRow(
          title: 'Push alerts',
          leading: const IconTile(icon: Icons.notifications_none_rounded, color: WColors.warning, fg: WColors.base),
          trailing: WToggle(value: _on, onChanged: (v) => setState(() => _on = v)),
        ),
        const WListRow(title: 'Mira K.', subtitle: 'Last seen 2 h ago', leading: IconTile(text: 'MK', circle: true), trailing: RoleBadge(WRole.family)),
        WListRow(title: 'Press and hold me', chevron: true, onTap: () {}),
        WListRow(title: 'Sign out', destructive: true, onTap: () {}),
      ]);

  Widget _serviceCards() => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.9,
        children: [for (final s in demoServiceCards) ServiceCard(service: s)],
      );

  Widget _status() => Column(children: [
        const ServerStatusCard(
          status: WStatus.ok,
          statusLabel: 'All systems normal',
          host: 'homeserver',
          bigValue: '41d 6h',
          bigUnit: 'uptime',
          footer: '6 of 7 services online · last check 12 s ago',
        ),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < demoStats.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: StatTile(stat: demoStats[i], range: _range)),
          ],
        ]),
      ]);

  Widget _charts() => Column(children: [
        LineChartCard(title: 'CPU load', range: _range, points: demoCpu[_range]!, xTicks: demoXTicks[_range]!),
        const SizedBox(height: 12),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: BarChartCard(title: 'Bandwidth · 7d', bars: demoBandwidth)),
          SizedBox(width: 12),
          Expanded(child: StorageCard()),
        ]),
        const SizedBox(height: 12),
        const LogView(logs: demoLogs),
      ]);

  Widget _banners() => Column(children: [
        for (final b in demoBanners) ...[
          WBanner(color: b.color, title: b.title, body: b.body, action: b.action),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 8),
        const WToast(message: 'Jellyfin restarted', dot: WColors.ok, action: 'Undo'),
        const SizedBox(height: 10),
        const WToast(message: "Couldn't reach server", dot: WColors.down, action: 'Retry'),
        const SizedBox(height: 10),
        const WToast(message: 'Uploading 3 files…', loading: true, trailingText: '62%'),
      ]);

  Widget _sheets() => Wrap(spacing: 12, runSpacing: 12, children: [
        WButton('Open action sheet', kind: WButtonKind.secondary, onPressed: () {
          showWActionSheet(
            context,
            WActionSheet(
              header: Row(children: [
                const IconTile(text: 'J', size: 40),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Jellyfin', style: WText.title),
                  Text(':8096 · 200 OK', style: WText.mono.copyWith(fontSize: 12)),
                ]),
              ]),
              actions: [
                SheetAction('Restart service', onTap: () => Navigator.pop(context)),
                SheetAction('View logs', onTap: () => Navigator.pop(context)),
              ],
            ),
          );
        }),
        WButton('Open confirm dialog', kind: WButtonKind.destructive, onPressed: () {
          showWConfirm(
            context,
            title: 'Remove Mira K.?',
            message: "She'll lose access to Family libraries and shared folders. Her files stay on the server.",
            confirmLabel: 'Remove',
          );
        }),
        WButton('Show toast', kind: WButtonKind.plain, onPressed: () {
          showWToast(context, const WToast(message: 'Jellyfin restarted', dot: WColors.ok, action: 'Undo'));
        }),
      ]);

  Widget _files() => Column(children: [
        WGroup(children: [
          for (var i = 0; i < 5; i++) FileRow(file: demoFiles[i], selected: i == _fileSel, onTap: () => setState(() => _fileSel = i)),
        ]),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (i, f) in [(0, demoFiles[0]), (1, demoFiles[2]), (2, demoFiles[4]), (3, demoFiles[5])]) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: FileTile(file: f, selected: i == 1)),
          ],
        ]),
      ]);

  Widget _posters() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < demoPosters.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: PosterCard(poster: demoPosters[i], focused: i == 2)),
          ],
        ]),
        const SizedBox(height: 18),
        Text('States: new · in progress (blue bar) · watched (dimmed 50%) · focused on desktop (2px blue ring).', style: WText.caption),
      ]);
}
