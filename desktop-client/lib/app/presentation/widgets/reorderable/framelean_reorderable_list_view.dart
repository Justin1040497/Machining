import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ItemExtentBuilder;

import 'package:framelean/app/presentation/widgets/reorderable/src/framelean_reorderable_list_core.dart';
import 'package:framelean/app/constants.dart';

export 'src/framelean_reorderable_list_core.dart'
    show
        FrameLeanReorderCallback,
        FrameLeanReorderDragBoundaryProvider,
        FrameLeanReorderDragUpdateCallback,
        FrameLeanReorderDropDetails,
        FrameLeanReorderDropCompletedCallback,
        FrameLeanReorderDropDisposition,
        FrameLeanReorderDropHandler,
        FrameLeanReorderGapBehavior,
        FrameLeanReorderGapDetails,
        FrameLeanReorderGapResolver,
        FrameLeanReorderItemProxyDecorator,
        FrameLeanReorderableDelayedDragStartListener,
        FrameLeanReorderableDragStartListener;

/// A reorderable material list with controllable gap and external-drop
/// behavior.
///
/// Its constructor and scroll parameters mirror [ReorderableListView]. Items
/// must have stable keys. Callers using custom handles should set
/// [buildDefaultDragHandles] to false and use
/// [FrameLeanReorderableDragStartListener].
class FrameLeanReorderableListView extends StatefulWidget {
  FrameLeanReorderableListView({
    super.key,
    required List<Widget> children,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
    this.gapBehavior,
    this.onDrop,
    this.onDropCompleted,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.acceptedDropProxyDecorator,
    this.proxyAnimationDuration = reorderAnimation,
    this.dropAnimationDuration = reorderAnimation,
    this.allowCrossAxisDrag = false,
    this.buildDefaultDragHandles = true,
    this.padding,
    this.header,
    this.footer,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.scrollController,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.anchor = 0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.autoScrollerVelocityScalar,
    this.dragBoundaryProvider,
    this.mouseCursor,
  }) : assert(children.every((child) => child.key != null)),
       itemBuilder = ((context, index) => children[index]),
       itemCount = children.length;

  const FrameLeanReorderableListView.builder({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
    this.gapBehavior,
    this.onDrop,
    this.onDropCompleted,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.acceptedDropProxyDecorator,
    this.proxyAnimationDuration = reorderAnimation,
    this.dropAnimationDuration = reorderAnimation,
    this.allowCrossAxisDrag = false,
    this.buildDefaultDragHandles = true,
    this.padding,
    this.header,
    this.footer,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.scrollController,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.anchor = 0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.autoScrollerVelocityScalar,
    this.dragBoundaryProvider,
    this.mouseCursor,
  }) : assert(itemCount >= 0),
       assert(
         (itemExtent == null && prototypeItem == null) ||
             (itemExtent == null && itemExtentBuilder == null) ||
             (prototypeItem == null && itemExtentBuilder == null),
       );

  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final FrameLeanReorderCallback onReorder;
  final void Function(int index)? onReorderStart;
  final FrameLeanReorderDragUpdateCallback? onReorderUpdate;
  final void Function(int index)? onReorderEnd;
  final void Function(int index)? onReorderCancel;
  final FrameLeanReorderGapResolver? gapBehavior;
  final FrameLeanReorderDropHandler? onDrop;
  final FrameLeanReorderDropCompletedCallback? onDropCompleted;
  final double? itemExtent;
  final ItemExtentBuilder? itemExtentBuilder;
  final Widget? prototypeItem;
  final FrameLeanReorderItemProxyDecorator? proxyDecorator;
  final FrameLeanReorderItemProxyDecorator? acceptedDropProxyDecorator;
  final Duration proxyAnimationDuration;
  final Duration dropAnimationDuration;
  final bool allowCrossAxisDrag;
  final bool buildDefaultDragHandles;
  final EdgeInsets? padding;
  final Widget? header;
  final Widget? footer;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? scrollController;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double anchor;
  final double? cacheExtent;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final double? autoScrollerVelocityScalar;
  final FrameLeanReorderDragBoundaryProvider? dragBoundaryProvider;
  final MouseCursor? mouseCursor;

  @override
  State<FrameLeanReorderableListView> createState() =>
      _FrameLeanReorderableListViewState();
}

class _FrameLeanReorderableListViewState
    extends State<FrameLeanReorderableListView> {
  final ValueNotifier<bool> _dragging = ValueNotifier(false);

  @override
  void dispose() {
    _dragging.dispose();
    super.dispose();
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = widget.itemBuilder(context, index);
    assert(item.key != null, 'Every reorderable item must have a key.');
    if (!widget.buildDefaultDragHandles) {
      return item;
    }
    final itemKey = _FrameLeanReorderableChildGlobalKey(item.key!, this);

    switch (Theme.of(context).platform) {
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        final handle = ListenableBuilder(
          listenable: _dragging,
          builder: (context, child) {
            final cursor = WidgetStateProperty.resolveAs<MouseCursor>(
              widget.mouseCursor ??
                  const WidgetStateMouseCursor.fromMap({
                    WidgetState.dragged: SystemMouseCursors.grabbing,
                    WidgetState.any: SystemMouseCursors.grab,
                  }),
              {if (_dragging.value) WidgetState.dragged},
            );
            return MouseRegion(cursor: cursor, child: child);
          },
          child: const Icon(Icons.drag_handle),
        );
        return Stack(
          key: itemKey,
          children: [
            item,
            if (widget.scrollDirection == Axis.vertical)
              PositionedDirectional(
                top: 0,
                bottom: 0,
                end: 8,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FrameLeanReorderableDragStartListener(
                    index: index,
                    child: handle,
                  ),
                ),
              )
            else
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 8,
                child: Align(
                  alignment: AlignmentDirectional.bottomCenter,
                  child: FrameLeanReorderableDragStartListener(
                    index: index,
                    child: handle,
                  ),
                ),
              ),
          ],
        );
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return FrameLeanReorderableDelayedDragStartListener(
          key: itemKey,
          index: index,
          child: item,
        );
    }
  }

  Widget _defaultProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(animation.value);
        return Material(elevation: lerpDouble(0, 6, value)!, child: child);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasOverlay(context));

    final padding = widget.padding ?? EdgeInsets.zero;
    double? start = widget.header == null ? null : 0;
    double? end = widget.footer == null ? null : 0;
    if (widget.reverse) {
      (start, end) = (end, start);
    }
    final (
      startPadding,
      endPadding,
      listPadding,
    ) = switch (widget.scrollDirection) {
      Axis.horizontal || Axis.vertical when (start ?? end) == null => (
        EdgeInsets.zero,
        EdgeInsets.zero,
        padding,
      ),
      Axis.horizontal => (
        padding.copyWith(left: 0),
        padding.copyWith(right: 0),
        padding.copyWith(left: start, right: end),
      ),
      Axis.vertical => (
        padding.copyWith(top: 0),
        padding.copyWith(bottom: 0),
        padding.copyWith(top: start, bottom: end),
      ),
    };
    final (headerPadding, footerPadding) = widget.reverse
        ? (startPadding, endPadding)
        : (endPadding, startPadding);

    return CustomScrollView(
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      controller: widget.scrollController,
      primary: widget.primary,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      anchor: widget.anchor,
      cacheExtent: widget.cacheExtent,
      dragStartBehavior: widget.dragStartBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      slivers: [
        if (widget.header != null)
          SliverPadding(
            padding: headerPadding,
            sliver: SliverToBoxAdapter(child: widget.header),
          ),
        SliverPadding(
          padding: listPadding,
          sliver: FrameLeanSliverReorderableList(
            itemBuilder: _buildItem,
            itemExtent: widget.itemExtent,
            itemExtentBuilder: widget.itemExtentBuilder,
            prototypeItem: widget.prototypeItem,
            itemCount: widget.itemCount,
            onReorder: widget.onReorder,
            onReorderStart: (index) {
              _dragging.value = true;
              widget.onReorderStart?.call(index);
            },
            onReorderUpdate: widget.onReorderUpdate,
            onReorderEnd: (index) {
              _dragging.value = false;
              widget.onReorderEnd?.call(index);
            },
            onReorderCancel: (index) {
              _dragging.value = false;
              widget.onReorderCancel?.call(index);
            },
            gapBehavior: widget.gapBehavior,
            onDrop: widget.onDrop,
            onDropCompleted: widget.onDropCompleted,
            proxyDecorator: widget.proxyDecorator ?? _defaultProxyDecorator,
            acceptedDropProxyDecorator: widget.acceptedDropProxyDecorator,
            proxyAnimationDuration: widget.proxyAnimationDuration,
            dropAnimationDuration: widget.dropAnimationDuration,
            allowCrossAxisDrag: widget.allowCrossAxisDrag,
            autoScrollerVelocityScalar: widget.autoScrollerVelocityScalar,
            dragBoundaryProvider: widget.dragBoundaryProvider,
          ),
        ),
        if (widget.footer != null)
          SliverPadding(
            padding: footerPadding,
            sliver: SliverToBoxAdapter(child: widget.footer),
          ),
      ],
    );
  }
}

@optionalTypeArgs
class _FrameLeanReorderableChildGlobalKey extends GlobalObjectKey {
  const _FrameLeanReorderableChildGlobalKey(this.subKey, this.state)
    : super(subKey);

  final Key subKey;
  final State state;

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType &&
        other is _FrameLeanReorderableChildGlobalKey &&
        other.subKey == subKey &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(subKey, state);
}
