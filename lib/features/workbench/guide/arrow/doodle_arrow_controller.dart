import 'dart:math' as math;

import 'package:flutter/material.dart';

class DoodleArrowController extends ChangeNotifier {
  DoodleArrowController({
    required TickerProvider vsync,
    required Offset startPoint,
    required Offset targetPoint,
    Duration drawDuration = const Duration(milliseconds: 700),
    Duration moveDuration = const Duration(milliseconds: 700),
    int? seed,
  }) : curveSeed = seed ?? math.Random().nextInt(1 << 31),
       _startPoint = startPoint,
       _targetPoint = targetPoint,
       _startTween = Tween(begin: startPoint, end: startPoint),
       _targetTween = Tween(begin: targetPoint, end: targetPoint),
       drawAnimation = AnimationController(
         vsync: vsync,
         duration: drawDuration,
       ),
       moveAnimation = AnimationController(
         vsync: vsync,
         duration: moveDuration,
       ) {
    final random = math.Random(curveSeed);
    arrowHeadScale = 0.8 + random.nextDouble() * 0.4;
    strokeOffset = Offset(
      -1.2 + random.nextDouble() * 2.4,
      -1.2 + random.nextDouble() * 2.4,
    );
    drawAnimation.addListener(notifyListeners);
    moveAnimation.addListener(notifyListeners);
  }

  final int curveSeed;
  final AnimationController drawAnimation;
  final AnimationController moveAnimation;
  late final double arrowHeadScale;
  late final Offset strokeOffset;
  Offset _startPoint;
  Offset _targetPoint;
  Tween<Offset> _startTween;
  Tween<Offset> _targetTween;

  double get drawProgress => drawAnimation.value;

  Offset get startPoint =>
      _startTween.transform(Curves.easeOutCubic.transform(moveAnimation.value));

  Offset get targetPoint => _targetTween.transform(
    Curves.easeOutCubic.transform(moveAnimation.value),
  );

  void draw() {
    if (drawAnimation.status == AnimationStatus.dismissed) {
      drawAnimation.forward();
    }
  }

  void updatePoints({required Offset startPoint, required Offset targetPoint}) {
    if (_startPoint == startPoint && _targetPoint == targetPoint) {
      return;
    }
    final currentStart = this.startPoint;
    final currentTarget = this.targetPoint;
    _startPoint = startPoint;
    _targetPoint = targetPoint;
    _startTween = Tween(begin: currentStart, end: startPoint);
    _targetTween = Tween(begin: currentTarget, end: targetPoint);
    moveAnimation.forward(from: 0);
  }

  @override
  void dispose() {
    drawAnimation
      ..removeListener(notifyListeners)
      ..dispose();
    moveAnimation
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
