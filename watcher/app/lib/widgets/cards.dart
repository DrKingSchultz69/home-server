import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import 'badges.dart';
import 'lists.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});
  final DemoServiceCard service;

  @override
  Widget build(BuildContext context) {
    final s = service;
    Widget metric(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: WText.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: WText.mono.copyWith(fontSize: 15, color: WColors.text)),
        ]);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: WColors.surface, borderRadius: BorderRadius.circular(WRadius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconTile(text: s.name[0], size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: WText.title, overflow: TextOverflow.ellipsis),
              Text(s.host, style: WText.mono.copyWith(fontSize: 12)),
            ]),
          ),
          StatusBadge(s.status, s.statusLabel),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 20, children: [metric('Uptime', s.uptime), metric('Response', s.resp), metric('CPU', s.cpu)]),
        const SizedBox(height: 14),
        Text(s.note, style: WText.caption.copyWith(color: s.noteColor)),
      ]),
    );
  }
}

/// Big status number card, e.g. "6/7 services online" or "41d 6h uptime".
class ServerStatusCard extends StatelessWidget {
  const ServerStatusCard({
    super.key,
    required this.status,
    required this.statusLabel,
    required this.bigValue,
    required this.bigUnit,
    required this.footer,
    this.host,
    this.monoFooter = false,
  });

  final WStatus status;
  final String statusLabel;
  final String bigValue;
  final String bigUnit;
  final String footer;
  final String? host;
  final bool monoFooter;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(host == null ? 16 : 20),
        decoration: BoxDecoration(color: WColors.surface, borderRadius: BorderRadius.circular(WRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StatusBadge(status, statusLabel),
            const Spacer(),
            if (host != null) Text(host!, style: WText.mono.copyWith(fontSize: 12)),
          ]),
          SizedBox(height: host == null ? 10 : 14),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(bigValue, style: WText.status),
            const SizedBox(width: 8),
            Text(bigUnit, style: WText.body.copyWith(color: WColors.secondary)),
          ]),
          SizedBox(height: host == null ? 10 : 14),
          Text(footer, style: monoFooter ? WText.mono.copyWith(fontSize: 12) : WText.caption),
        ]),
      );
}

class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.poster, this.focused = false});
  final DemoPoster poster;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final p = poster;
    return Opacity(
      opacity: p.watched ? .5 : 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
              boxShadow: focused ? const [BoxShadow(color: WColors.primary, spreadRadius: 2)] : null,
            ),
            child: Stack(children: [
              Center(child: Text('poster', style: WText.monoSmall.copyWith(color: WColors.disabled))),
              if (p.isNew)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: WColors.primary, borderRadius: BorderRadius.circular(6)),
                    child: const Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: WColors.text)),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(6)),
                  child: Text(p.quality, style: WText.monoSmall.copyWith(fontSize: 10, color: WColors.text)),
                ),
              ),
              if (p.progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: .15),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(widthFactor: p.progress, child: Container(color: WColors.primary)),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: WText.body.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            Text(p.meta, style: WText.caption),
          ]),
        ),
      ]),
    );
  }
}
