import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow_controller.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow_painter.dart';

class DoodleArrow extends StatefulWidget {
  const DoodleArrow({
    super.key,
    required this.startPoint,
    required this.targetPoint,
    required this.color,
    this.seed,
    this.drawDuration = const Duration(milliseconds: 700),
    this.moveDuration = const Duration(milliseconds: 700),
  });

  final Offset startPoint;
  final Offset targetPoint;
  final Color color;
  final int? seed;
  final Duration drawDuration;
  final Duration moveDuration;

  @override
  State<DoodleArrow> createState() => _DoodleArrowState();
}

class _DoodleArrowState extends State<DoodleArrow>
    with TickerProviderStateMixin {
  late final DoodleArrowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DoodleArrowController(
      vsync: this,
      startPoint: widget.startPoint,
      targetPoint: widget.targetPoint,
      drawDuration: widget.drawDuration,
      moveDuration: widget.moveDuration,
      seed: widget.seed,
    );
    _controller.draw();
  }

  @override
  void didUpdateWidget(covariant DoodleArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.updatePoints(
      startPoint: widget.startPoint,
      targetPoint: widget.targetPoint,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: DoodleArrowPainter(
            startPoint: _controller.startPoint,
            targetPoint: _controller.targetPoint,
            progress: _controller.drawProgress,
            curveSeed: _controller.curveSeed,
            arrowHeadScale: _controller.arrowHeadScale,
            strokeOffset: _controller.strokeOffset,
            color: widget.color,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
