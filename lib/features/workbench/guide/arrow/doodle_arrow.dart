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
    this.maxLength = 280,
    this.curveBias = Offset.zero,
    this.targetDirection,
    this.clipRect,
  });

  final Offset startPoint;
  final Offset targetPoint;
  final Color color;
  final int? seed;
  final Duration drawDuration;
  final Duration moveDuration;
  final double maxLength;

  /// 屏幕坐标方向上的曲线偏移。
  ///
  /// 例如：
  /// Offset(0, 24) 表示曲线向下鼓起；
  /// Offset(0, -20) 表示曲线向上鼓起。
  final Offset curveBias;

  /// 箭头进入目标点时的屏幕坐标方向；为空时沿起点到终点方向自然收束。
  final Offset? targetDirection;

  /// 和 Workbench Stack 使用同一坐标系的安全绘制区域。
  final Rect? clipRect;

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
            maxLength: widget.maxLength,
            curveBias: widget.curveBias,
            targetDirection: widget.targetDirection,
            clipRect: widget.clipRect,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
