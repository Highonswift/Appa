import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Two series on one y-axis (same unit), e.g. BP top/bottom in mmHg, or
/// sugar fasting/after food in mg/dL. Validated palette: blue #2a78d6 and
/// orange #eb6834 pass lightness, chroma, CVD (ΔE 24.7) and 3:1 contrast on
/// white. Identity is never colour alone: legend + direct end labels.
/// Tap anywhere to read the nearest point.
class ChartSeries {
  const ChartSeries(this.label, this.points, this.color);
  final String label;
  final List<(DateTime, num)> points;
  final Color color;
}

const seriesBlue = Color(0xFF2A78D6);

/// Whole numbers as they are; fractions (sleep hours) to one decimal.
String chartValue(num v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
const seriesOrange = Color(0xFFEB6834);

class HealthChart extends StatefulWidget {
  const HealthChart({
    super.key,
    required this.series,
    required this.unit,
    required this.from,
    required this.to,
  });
  final List<ChartSeries> series;
  final String unit;
  final DateTime from;
  final DateTime to;

  @override
  State<HealthChart> createState() => _HealthChartState();
}

class _HealthChartState extends State<HealthChart> {
  (ChartSeries, (DateTime, num))? selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nonEmpty = widget.series.where((s) => s.points.isNotEmpty).toList();
    if (nonEmpty.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: Text(
          'இன்னும் அளவுகள் இல்லை',
          style: t.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      );
    }

    String fmt(DateTime d) => '${d.day}/${d.month}';
    final summary = nonEmpty
        .map((s) => '${s.label}: கடைசி ${s.points.last.$2} ${widget.unit}')
        .join('. ');

    return Semantics(
      label: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.series.length > 1)
            Wrap(
              spacing: 18,
              children: [
                for (final s in widget.series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 18, height: 3, color: s.color),
                      const SizedBox(width: 6),
                      Text(s.label, style: t.bodyMedium),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, 220);
              final painter = _ChartPainter(
                series: widget.series,
                from: widget.from,
                to: widget.to,
                selected: selected,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                ),
                valueStyle: const TextStyle(
                  fontSize: 16,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => setState(
                  () => selected = painter.nearest(d.localPosition, size),
                ),
                child: CustomPaint(size: size, painter: painter),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fmt(widget.from),
                style: t.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              Text(
                widget.unit,
                style: t.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              Text(
                fmt(widget.to),
                style: t.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${selected!.$1.label} · ${fmt(selected!.$2.$1)}: ${chartValue(selected!.$2.$2)} ${widget.unit}',
                style: t.titleMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.from,
    required this.to,
    required this.selected,
    required this.labelStyle,
    required this.valueStyle,
  });

  final List<ChartSeries> series;
  final DateTime from;
  final DateTime to;
  final (ChartSeries, (DateTime, num))? selected;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  static const _left = 40.0, _right = 44.0, _top = 12.0, _bottom = 12.0;

  (double, double) _yRange() {
    final all = [
      for (final s in series)
        for (final p in s.points) p.$2,
    ];
    var lo = all.reduce(math.min).toDouble(),
        hi = all.reduce(math.max).toDouble();
    // Small values (sleep hours) round to 1; larger ones (BP, sugar) to 10.
    final unit = hi < 30 ? 1.0 : 10.0;
    final pad = math.max(unit / 2, (hi - lo) * 0.15);
    lo = math.max(0, ((lo - pad) / unit).floor() * unit).toDouble();
    hi = (((hi + pad) / unit).ceil() * unit).toDouble();
    if (hi <= lo) hi = lo + unit;
    return (lo, hi);
  }

  Offset _pos((DateTime, num) p, Size size, (double, double) yr) {
    final span = to.difference(from).inMinutes.clamp(1, 1 << 31);
    final x =
        _left +
        (size.width - _left - _right) *
            (p.$1.difference(from).inMinutes / span).clamp(0.0, 1.0);
    final y =
        _top +
        (size.height - _top - _bottom) * (1 - (p.$2 - yr.$1) / (yr.$2 - yr.$1));
    return Offset(x, y);
  }

  (ChartSeries, (DateTime, num))? nearest(Offset tap, Size size) {
    final yr = _yRange();
    (ChartSeries, (DateTime, num))? best;
    var bestD = double.infinity;
    for (final s in series) {
      for (final p in s.points) {
        final d = (_pos(p, size, yr) - tap).distance;
        if (d < bestD) {
          bestD = d;
          best = (s, p);
        }
      }
    }
    return bestD < 60 ? best : null;
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    TextStyle style, {
    bool right = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(right ? at.dx - tp.width : at.dx, at.dy - tp.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final yr = _yRange();
    final grid = Paint()
      ..color = const Color(0xFFE4E2DC)
      ..strokeWidth = 1;

    // Recessive grid: 3 lines with values.
    for (var i = 0; i <= 2; i++) {
      final v = yr.$1 + (yr.$2 - yr.$1) * i / 2;
      final y = _top + (size.height - _top - _bottom) * (1 - i / 2);
      canvas.drawLine(Offset(_left, y), Offset(size.width - _right, y), grid);
      _text(
        canvas,
        v.round().toString(),
        Offset(_left - 6, y),
        labelStyle,
        right: true,
      );
    }

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final line = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final o = _pos(s.points[i], size, yr);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, line);
      final ring = Paint()..color = Colors.white;
      final dot = Paint()..color = s.color;
      for (final p in s.points) {
        final o = _pos(p, size, yr);
        canvas.drawCircle(o, 6, ring); // 2px surface ring
        canvas.drawCircle(o, 4, dot); // 8px marker
      }
      // Direct label on the latest point only.
      final last = _pos(s.points.last, size, yr);
      _text(
        canvas,
        chartValue(s.points.last.$2),
        Offset(last.dx + 8, last.dy),
        valueStyle,
      );
    }

    final sel = selected;
    if (sel != null) {
      final o = _pos(sel.$2, size, yr);
      canvas.drawLine(
        Offset(o.dx, _top),
        Offset(o.dx, size.height - _bottom),
        Paint()
          ..color = AppColors.muted
          ..strokeWidth = 1,
      );
      canvas.drawCircle(o, 8, Paint()..color = Colors.white);
      canvas.drawCircle(o, 6, Paint()..color = sel.$1.color);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.series != series ||
      old.selected != selected ||
      old.from != from ||
      old.to != to;
}
