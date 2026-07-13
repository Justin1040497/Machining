import 'dart:async';

import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/content/composite_guide_groups.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';
import 'package:framelean/features/workbench/guide/models/guide_state.dart';
import 'package:framelean/features/workbench/guide/scheduler/guide_scheduler.dart';

class WorkbenchGuideAnchors {
  WorkbenchGuideAnchors()
    : listViewportKey = GlobalKey(debugLabel: 'guide-list-viewport'),
      lastTaskKey = GlobalKey(debugLabel: 'guide-last-task'),
      addButtonKey = GlobalKey(debugLabel: 'guide-add-button'),
      startButtonKey = GlobalKey(debugLabel: 'guide-start-button');

  final GlobalKey listViewportKey;
  final GlobalKey lastTaskKey;
  final GlobalKey addButtonKey;
  final GlobalKey startButtonKey;
}

typedef WorkbenchGuideHostBuilder =
    Widget Function(
      BuildContext context,
      WorkbenchGuideAnchors anchors,
      ValueChanged<GuideListMetrics> onListMetricsChanged,
      Widget guideLayer,
    );

class WorkbenchGuideAnchorHost extends StatefulWidget {
  const WorkbenchGuideAnchorHost({
    super.key,
    required this.taskCount,
    required this.builder,
  });

  final int? taskCount;
  final WorkbenchGuideHostBuilder builder;

  @override
  State<WorkbenchGuideAnchorHost> createState() =>
      _WorkbenchGuideAnchorHostState();
}

class _WorkbenchGuideAnchorHostState extends State<WorkbenchGuideAnchorHost> {
  final WorkbenchGuideAnchors _anchors = WorkbenchGuideAnchors();
  GuideListMetrics _listMetrics = const GuideListMetrics(
    hasScrollableContent: false,
  );
  var _layoutRevision = 0;

  @override
  Widget build(BuildContext context) {
    final guideLayer = WorkbenchBackgroundGuideSystem(
      taskCount: widget.taskCount,
      anchors: _anchors,
      listMetrics: _listMetrics,
      layoutRevision: _layoutRevision,
    );
    return widget.builder(
      context,
      _anchors,
      _handleListMetricsChanged,
      guideLayer,
    );
  }

  void _handleListMetricsChanged(GuideListMetrics metrics) {
    if (!mounted || _listMetrics == metrics) {
      return;
    }
    setState(() {
      _listMetrics = metrics;
      _layoutRevision += 1;
    });
  }
}

class WorkbenchBackgroundGuideSystem extends StatefulWidget {
  const WorkbenchBackgroundGuideSystem({
    super.key,
    required this.taskCount,
    required this.anchors,
    required this.listMetrics,
    required this.layoutRevision,
  });

  final int? taskCount;
  final WorkbenchGuideAnchors anchors;
  final GuideListMetrics listMetrics;
  final int layoutRevision;

  @override
  State<WorkbenchBackgroundGuideSystem> createState() =>
      _WorkbenchBackgroundGuideSystemState();
}

class _WorkbenchBackgroundGuideSystemState
    extends State<WorkbenchBackgroundGuideSystem>
    with WidgetsBindingObserver {
  final GlobalKey _rootKey = GlobalKey(debugLabel: 'guide-root');
  final GuideScheduler _scheduler = GuideScheduler();
  GuideGeometry? _geometry;
  GuideScene _visibleScene = GuideScene.hidden;
  double _opacity = 0;
  Duration _fadeDuration = const Duration(milliseconds: 600);
  var _transitionGeneration = 0;
  var _measurementScheduled = false;
  var _hasScheduledInput = false;
  int? _scheduledTaskCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(covariant WorkbenchBackgroundGuideSystem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskCount != widget.taskCount ||
        oldWidget.layoutRevision != widget.layoutRevision ||
        oldWidget.listMetrics != widget.listMetrics) {
      _scheduleMeasurement();
    }
  }

  @override
  void didChangeMetrics() {
    _scheduleMeasurement();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transitionGeneration += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();
    return SizedBox.expand(
      key: _rootKey,
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: const ValueKey('workbench-background-guide-layer'),
          opacity: _opacity,
          duration: _fadeDuration,
          curve: Curves.easeOutCubic,
          child: _buildScene(),
        ),
      ),
    );
  }

  Widget _buildScene() {
    final geometry = _geometry;
    if (geometry == null) {
      return const SizedBox.shrink();
    }
    return switch (_visibleScene) {
      GuideScene.emptyQueue => EmptyQueueGuideGroup(
        key: const ValueKey('empty-queue-guide-group'),
        geometry: geometry,
      ),
      GuideScene.taskWorkspace => TaskWorkspaceGuideGroup(
        key: const ValueKey('task-workspace-guide-group'),
        geometry: geometry,
      ),
      GuideScene.hidden || GuideScene.transitioning => const SizedBox.shrink(),
    };
  }

  void _scheduleMeasurement() {
    if (_measurementScheduled) {
      return;
    }
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) {
        return;
      }
      _measureAndSchedule();
    });
  }

  void _measureAndSchedule() {
    final rootBox = _renderBoxFor(_rootKey);
    final viewportRect = _rectFor(widget.anchors.listViewportKey, rootBox);
    final addButtonRect = _rectFor(widget.anchors.addButtonKey, rootBox);
    final startButtonRect = _rectFor(widget.anchors.startButtonKey, rootBox);
    if (rootBox == null ||
        viewportRect == null ||
        addButtonRect == null ||
        startButtonRect == null) {
      _applyGeometry(null);
      return;
    }
    final geometry = GuideGeometry(
      workbenchSize: rootBox.size,
      listViewportRect: viewportRect,
      lastTaskRect: _rectFor(widget.anchors.lastTaskKey, rootBox),
      addButtonRect: addButtonRect,
      startButtonRect: startButtonRect,
      hasScrollableContent: widget.listMetrics.hasScrollableContent,
    );
    _applyGeometry(geometry);
  }

  void _applyGeometry(GuideGeometry? geometry) {
    if (_hasScheduledInput &&
        _geometry == geometry &&
        _scheduledTaskCount == widget.taskCount) {
      return;
    }
    _hasScheduledInput = true;
    _scheduledTaskCount = widget.taskCount;
    final decision = _scheduler.update(
      GuideSchedulerInput(taskCount: widget.taskCount, geometry: geometry),
    );
    if (mounted) {
      setState(() => _geometry = geometry);
    }
    switch (decision.transition) {
      case GuideTransitionKind.none:
      case GuideTransitionKind.positionOnly:
        return;
      case GuideTransitionKind.fadeIn:
        _fadeIn(decision.scene);
        return;
      case GuideTransitionKind.fadeOut:
        _fadeOut();
        return;
      case GuideTransitionKind.sceneSwap:
        _swapScene(decision.scene);
        return;
    }
  }

  void _fadeIn(GuideScene scene) {
    final generation = ++_transitionGeneration;
    setState(() {
      _visibleScene = scene;
      _fadeDuration = const Duration(milliseconds: 600);
      _opacity = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _transitionGeneration) {
        return;
      }
      setState(() => _opacity = 1);
    });
  }

  void _fadeOut() {
    final generation = ++_transitionGeneration;
    setState(() {
      _fadeDuration = const Duration(milliseconds: 350);
      _opacity = 0;
    });
    unawaited(_hideAfterFade(generation));
  }

  Future<void> _hideAfterFade(int generation) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || generation != _transitionGeneration) {
      return;
    }
    setState(() => _visibleScene = GuideScene.hidden);
  }

  void _swapScene(GuideScene nextScene) {
    final generation = ++_transitionGeneration;
    setState(() {
      _fadeDuration = const Duration(milliseconds: 350);
      _opacity = 0;
    });
    unawaited(_completeSceneSwap(generation, nextScene));
  }

  Future<void> _completeSceneSwap(int generation, GuideScene nextScene) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || generation != _transitionGeneration) {
      return;
    }
    setState(() {
      _visibleScene = nextScene;
      _fadeDuration = const Duration(milliseconds: 600);
      _opacity = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _transitionGeneration) {
        return;
      }
      setState(() => _opacity = 1);
    });
  }

  RenderBox? _renderBoxFor(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject;
  }

  Rect? _rectFor(GlobalKey key, RenderBox? rootBox) {
    if (rootBox == null) {
      return null;
    }
    final box = _renderBoxFor(key);
    if (box == null) {
      return null;
    }
    final globalTopLeft = box.localToGlobal(Offset.zero);
    final localTopLeft = rootBox.globalToLocal(globalTopLeft);
    return localTopLeft & box.size;
  }
}
