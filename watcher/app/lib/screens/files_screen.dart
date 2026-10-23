import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import '../widgets/badges.dart';
import '../widgets/controls.dart';
import '../widgets/feedback.dart';
import '../widgets/lists.dart';
import 'shared.dart';

/// Files. Wide: list/grid plus a details panel (the kit's Windows example).
/// Narrow: grouped list with selection checks.
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.wide});
  final bool wide;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _view = 'List';
  int _sel = 2;

  Future<void> _delete(DemoFile f) async {
    final ok = await showWConfirm(
      context,
      title: 'Delete ${f.name}?',
      message: 'It will be removed from the server for everyone who can see this folder.',
      confirmLabel: 'Delete',
    );
    if (ok && mounted) showWToast(context, WToast(message: '${f.name} deleted', dot: WColors.ok));
  }

  void _upload() => showWToast(context, const WToast(message: 'Uploading 3 files…', loading: true, trailingText: '62%'));

  @override
  Widget build(BuildContext context) => widget.wide ? _desktop() : _phone();

  Widget _phone() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: gap(16, [
          const PageHeader(title: 'Files', host: 'Family'),
          const WTextField(hint: 'Search files and media', leading: Icons.search_rounded, height: 40),
          WGroup(children: [
            for (var i = 0; i < demoFiles.length; i++)
              FileRow(file: demoFiles[i], selected: i == _sel, onTap: () => setState(() => _sel = i)),
          ]),
          Row(children: [
            Expanded(child: WButton('Upload', onPressed: _upload)),
            const SizedBox(width: 10),
            Expanded(child: WButton('Download', kind: WButtonKind.secondary, onPressed: () {})),
          ]),
        ]),
      );

  Widget _desktop() {
    final sel = demoFiles[_sel];
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Files  /  Family', style: WText.caption),
                  const SizedBox(height: 2),
                  const Text('Photos 2026', style: WText.pageTitle),
                ]),
              ),
              const SizedBox(width: 240, child: WTextField(hint: 'Search', leading: Icons.search_rounded, height: 36)),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: WSegmented(options: const ['List', 'Grid'], selected: _view, compact: true, onChanged: (v) => setState(() => _view = v)),
              ),
              const SizedBox(width: 12),
              WButton('Upload', small: true, onPressed: _upload),
            ]),
          ),
          Expanded(child: _view == 'List' ? _list() : _grid()),
        ]),
      ),
      Container(
        width: 300,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: WColors.surface, borderRadius: BorderRadius.circular(WRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: WColors.raised, borderRadius: BorderRadius.circular(WRadius.control)),
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: sel.type.bg, borderRadius: BorderRadius.circular(14)),
                child: Text(sel.type.ext, style: WText.mono.copyWith(color: sel.type.fg)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(sel.name, style: WText.title),
          const SizedBox(height: 4),
          Text(sel.type.kind, style: WText.caption),
          const SizedBox(height: 16),
          WGroup(color: WColors.raised, separator: WColors.separatorOnRaised, radius: WRadius.control, children: [
            _detail('Size', Text(sel.size, style: WText.mono.copyWith(color: WColors.text))),
            _detail('Modified', Text(sel.date, style: WText.mono.copyWith(color: WColors.text))),
            _detail('Access', RoleBadge(sel.role, small: true)),
          ]),
          const Spacer(),
          WButton('Download', small: true, expand: true, onPressed: () {}),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: WButton('Share', kind: WButtonKind.secondary, small: true, expand: true, onPressed: () {})),
            const SizedBox(width: 8),
            Expanded(child: WButton('Delete', kind: WButtonKind.destructive, small: true, expand: true, onPressed: () => _delete(sel))),
          ]),
        ]),
      ),
    ]);
  }

  Widget _detail(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(child: Text(label, style: WText.caption)),
          value,
        ]),
      );

  static const _cols = [110.0, 150.0, 110.0];

  Widget _list() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WColors.separator))),
            child: Row(children: [
              Expanded(child: Text('Name', style: WText.caption.copyWith(fontSize: 12))),
              _cell(Text('Size', textAlign: TextAlign.right, style: WText.caption.copyWith(fontSize: 12)), 0),
              _cell(Text('Modified', style: WText.caption.copyWith(fontSize: 12)), 1),
              _cell(Text('Shared with', style: WText.caption.copyWith(fontSize: 12)), 2),
            ]),
          ),
          for (var i = 0; i < demoFiles.length; i++)
            Pressable(
              onTap: () => setState(() => _sel = i),
              builder: (context, hover, _) {
                final f = demoFiles[i];
                return Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: i == _sel ? WColors.tint(WColors.primary, .18) : hover ? WColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Row(children: [
                        IconTile(text: f.type.ext, color: f.type.bg, fg: f.type.fg, size: 28, mono: true),
                        const SizedBox(width: 10),
                        Expanded(child: Text(f.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                    _cell(Text(f.size, textAlign: TextAlign.right, style: WText.mono), 0),
                    _cell(Text(f.date, style: WText.mono), 1),
                    _cell(Align(alignment: Alignment.centerLeft, child: RoleBadge(f.role)), 2),
                  ]),
                );
              },
            ),
        ],
      );

  Widget _cell(Widget child, int col) => Padding(
        padding: const EdgeInsets.only(left: 12),
        child: SizedBox(width: _cols[col], child: child),
      );

  Widget _grid() => GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 190,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: .95,
        ),
        itemCount: demoFiles.length,
        itemBuilder: (context, i) => FileTile(
          file: demoFiles[i],
          selected: i == _sel,
          aspect: 4 / 3,
          iconSize: 48,
          onTap: () => setState(() => _sel = i),
        ),
      );
}
