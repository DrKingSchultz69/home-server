import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';

/// Teal line + 14% area fill. Points are y-values in a [0, boxHeight] box
/// where 0 is the top, matching the SVG paths in the design.
class Sparkline extends StatelessWidget {
  const Sparkline(this.points, {super.key, this.height = 28, this.boxHeight = 32, this.strokeWidth = 1.75, this.crosshairAt});
  final List<double> points;
  final double height;
  final double boxHeight;
  final double strokeWidth;
  final double? crosshairAt; // 0..1 across the width

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _LinePainter(points, boxHeight, strokeWidth, crosshairAt)),
      );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.points, this.boxHeight, this.strokeWidth, this.crosshairAt);
  final List<double> points;
  final double boxHeight;
  final double strokeWidth;
  final double? crosshairAt;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final dx = size.width / (points.length - 1);
    final sy = size.height / boxHeight;
    final line = Path()..moveTo(0, points[0] * sy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(i * dx, points[i] * sy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = WColors.tint(WColors.data, .14));
    canvas.drawPath(
      line,
      Paint()
        ..color = WColors.data
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    if (crosshairAt != null) {
      final x = size.width * crosshairAt!;
      final p = Paint()
        ..color = WColors.text.withValues(alpha: .4)
        ..strokeWidth = 1;
      for (double y = 0; y < size.height; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + 3).clamp(0, size.height)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.points != points || old.crosshairAt != crosshairAt;
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.stat, required this.range, this.valueSize = 24, this.showDelta = true});
  final DemoStat stat;
  final String range;
  final double valueSize;
  final bool showDelta;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: WColors.surface, borderRadius: BorderRadius.circular(WRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(stat.label, style: WText.caption),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(stat.value, style: WText.monoValue.copyWith(fontSize: valueSize)),
            const SizedBox(width: 4),
            Text(stat.unit, style: WText.mono.copyWith(fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Sparkline(stat.series[range]!, height: valueSize > 22 ? 28 : 26),
          if (showDelta) ...[
            const SizedBox(height: 6),
            Text(stat.delta, style: WText.monoSmall.copyWith(color: stat.deltaColor)),
          ],
        ]),
      );
}

/// Card with the CPU line chart, y-axis labels, grid lines and a tooltip.
class LineChartCard extends StatelessWidget {
  const LineChartCard({super.key, required this.title, required this.range, required this.points, required this.xTicks, this.summary = 'avg 21%'});
  final String title;
  final String range;
  final List<double> points;
  final List<String> xTicks;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: WColors.surface, borderRadius: BorderRadius.circular(WRadius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: WText.title)),
          Text('$range · $summary', style: WText.mono),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (final t in ['100', '50', '0']) Text(t, style: WText.monoSmall)],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                return Stack(clipBehavior: Clip.none, children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (_) => Container(height: 1, color: WColors.separator)),
                  ),
                  Positioned.fill(child: Sparkline(points, height: 160, boxHeight: 160, strokeWidth: 2, crosshairAt: .7)),
                  Positioned(
                    left: c.maxWidth * .7 + 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: WColors.raised, borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('16:40', style: WText.mono.copyWith(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('34%', style: WText.mono.copyWith(fontSize: 12, color: WColors.text)),
                      ]),
                    ),
                  ),
                ]);
              }),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final x in xTicks) Text(x, style: WText.monoSmall)],
          ),
        ),
      ]),
    );
  }
}

class BarChartCard extends StatelessWidget {
  const BarChartCard({super.key, required this.title, required this.bars, this.highlight = 4});
  final String title;
  final List<(String, double)> bars;
  final int highlight;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: WColors.surface, borderRadius: BorderRadius.circular(WRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: WText.bodyStrong),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Expanded(
                      child: FractionallySizedBox(
                        heightFactor: bars[i].$2,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == highlight ? WColors.data : WColors.tint(WColors.data, .35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(bars[i].$1, style: WText.monoSmall.copyWith(fontSize: 10)),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      );
}

class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.fraction, this.color = WColors.data, this.height = 8});
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: WColors.raised,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2))),
          ),
        ),
      );
}

class StorageCard extends StatelessWidget {
  const StorageCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget disk(String name, String used, double pct, Color color, Color textColor) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(name, style: WText.caption.copyWith(color: WColors.text))),
              Text(used, style: WText.mono.copyWith(color: textColor)),
            ]),
            const SizedBox(height: 6),
            UsageBar(fraction: pct, color: color),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: WColors.surface, borderRadius: BorderRadius.circular(WRadius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Storage', style: WText.bodyStrong),
        const SizedBox(height: 12),
        disk('Disk 1 · System', '212 / 500 GB', .42, WColors.data, WColors.secondary),
        const SizedBox(height: 12),
        disk('Disk 2 · Media', '7.3 / 8 TB', .91, WColors.warning, WColors.warning),
      ]),
    );
  }
}

class LogView extends StatelessWidget {
  const LogView({super.key, required this.logs});
  final List<DemoLog> logs;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: WColors.logBg, borderRadius: BorderRadius.circular(WRadius.control)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final l in logs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.time, style: WText.mono.copyWith(fontSize: 12, color: WColors.disabled)),
                const SizedBox(width: 12),
                SizedBox(width: 40, child: Text(l.level, style: WText.mono.copyWith(fontSize: 12, color: l.color))),
                const SizedBox(width: 12),
                Expanded(child: Text(l.message, style: WText.mono.copyWith(fontSize: 12, color: WColors.text))),
              ]),
            ),
        ]),
      );
}
