import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import 'controls.dart';

/// Rounded inset group; draws a 1px separator between children.
class WGroup extends StatelessWidget {
  const WGroup({super.key, required this.children, this.header, this.color = WColors.surface, this.separator = WColors.separator, this.radius = WRadius.card});
  final List<Widget> children;
  final String? header;
  final Color color;
  final Color separator;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: color,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(height: 1, color: separator),
            children[i],
          ],
        ]),
      ),
    );
    if (header == null) return box;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(header!.toUpperCase(), style: WText.caption)),
      const SizedBox(height: 6),
      box,
    ]);
  }
}

class IconTile extends StatelessWidget {
  const IconTile({super.key, this.icon, this.text, this.color = WColors.raised, this.fg = WColors.text, this.size = 30, this.circle = false, this.mono = false});
  final IconData? icon;
  final String? text;
  final Color color;
  final Color fg;
  final double size;
  final bool circle;
  final bool mono;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(size >= 48 ? 12 : size >= 40 ? 10 : 8),
        ),
        child: icon != null
            ? Icon(icon, size: size * .53, color: fg)
            : Text(text ?? '',
                style: TextStyle(
                  fontFamily: mono ? 'GeistMono' : 'Geist',
                  fontSize: mono ? (size >= 48 ? 12 : size >= 32 ? 10 : 9) : (size >= 40 ? 17 : 13),
                  fontWeight: mono ? FontWeight.w500 : FontWeight.w600,
                  color: fg,
                )),
      );
}

class WListRow extends StatelessWidget {
  const WListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.chevron = false,
    this.destructive = false,
    this.onTap,
    this.minHeight = 52,
    this.titleWeight = FontWeight.w400,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? value;
  final bool chevron;
  final bool destructive;
  final VoidCallback? onTap;
  final double minHeight;
  final FontWeight titleWeight;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      builder: (context, hover, down) {
        final bg = down ? WColors.raised : hover ? WColors.surfaceHover : Colors.transparent;
        if (destructive) {
          return Container(
            color: bg,
            constraints: BoxConstraints(minHeight: minHeight),
            alignment: Alignment.center,
            child: Text(title, style: WText.body.copyWith(color: WColors.down)),
          );
        }
        return Container(
          color: bg,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: WText.body.copyWith(fontWeight: titleWeight)),
                if (subtitle != null) ...[const SizedBox(height: 1), Text(subtitle!, style: WText.caption)],
              ]),
            ),
            if (value != null) Text(value!, style: WText.body.copyWith(color: WColors.secondary)),
            if (trailing != null) trailing!,
            if (chevron) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 20, color: WColors.disabled),
            ],
          ]),
        );
      },
    );
  }
}

class SelectCheck extends StatelessWidget {
  const SelectCheck(this.selected, {super.key});
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? WColors.primary : null,
          border: selected ? null : Border.all(color: WColors.checkBorder, width: 1.5),
        ),
        child: selected ? const Icon(Icons.check_rounded, size: 14, color: WColors.text) : null,
      );
}

/// Phone file row: type tile, name + meta, size, selection check.
class FileRow extends StatelessWidget {
  const FileRow({super.key, required this.file, this.selected = false, this.onTap});
  final DemoFile file;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = file.type;
    return Pressable(
      onTap: onTap,
      builder: (context, hover, _) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        color: selected ? WColors.tint(WColors.primary, .18) : hover ? WColors.surfaceHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          IconTile(text: t.ext, color: t.bg, fg: t.fg, size: 32, mono: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(file.name, style: WText.body, overflow: TextOverflow.ellipsis),
              Text(file.isDir ? '24 items · ${file.date}' : file.date, style: WText.caption),
            ]),
          ),
          Text(file.size, style: WText.mono),
          const SizedBox(width: 12),
          SelectCheck(selected),
        ]),
      ),
    );
  }
}

/// Square or 4:3 file tile with a 2px blue ring when selected.
class FileTile extends StatelessWidget {
  const FileTile({super.key, required this.file, this.selected = false, this.onTap, this.aspect = 1, this.iconSize = 52});
  final DemoFile file;
  final bool selected;
  final VoidCallback? onTap;
  final double aspect;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = file.type;
    return Pressable(
      onTap: onTap,
      builder: (context, _, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: aspect,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected ? const [BoxShadow(color: WColors.primary, spreadRadius: 2)] : null,
            ),
            child: Container(
              width: iconSize,
              height: iconSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
              child: Text(t.ext, style: WText.mono.copyWith(fontSize: iconSize > 50 ? 12 : 11, color: t.fg)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(file.name, style: WText.caption.copyWith(color: WColors.text, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            Text(file.isDir ? '24 items' : file.size, style: WText.monoSmall),
          ]),
        ),
      ]),
    );
  }
}
