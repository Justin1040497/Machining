import 'dart:io';

import 'package:flutter/material.dart';
import 'package:machining/application/services/preview_frame_generator.dart';
import 'package:machining/domain/entities/media_task.dart';

class WorkbenchPreviewPanel extends StatelessWidget {
  const WorkbenchPreviewPanel({
    super.key,
    required this.result,
    required this.selectedTask,
    required this.previewGenerating,
    required this.selectedFrameIndex,
    required this.compareRatio,
    required this.onCompareRatioChanged,
  });

  final PreviewFrameResult? result;
  final MediaTask? selectedTask;
  final bool previewGenerating;
  final int selectedFrameIndex;
  final double compareRatio;
  final ValueChanged<double> onCompareRatioChanged;

  @override
  Widget build(BuildContext context) {
    final frameResult = result;
    final hasFrames =
        frameResult != null &&
        frameResult.taskId == selectedTask?.id &&
        frameResult.frames.isNotEmpty;

    if (!hasFrames) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Text(
              '点击生成预览',
              style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 13),
            ),
          ),
          if (previewGenerating) const _PreviewLoadingOverlay(),
        ],
      );
    }

    final frame = frameResult
        .frames[selectedFrameIndex.clamp(0, frameResult.frames.length - 1)];

    return Stack(
      fit: StackFit.expand,
      children: [
        _PreviewComparison(
          frame: frame,
          compareRatio: compareRatio,
          onCompareRatioChanged: onCompareRatioChanged,
        ),
        const Positioned(left: 22, top: 18, child: _PreviewBadge('原始')),
        const Positioned(right: 22, top: 18, child: _PreviewBadge('压缩预览帧')),
        if (previewGenerating) const _PreviewLoadingOverlay(),
      ],
    );
  }
}

class _PreviewComparison extends StatelessWidget {
  const _PreviewComparison({
    required this.frame,
    required this.compareRatio,
    required this.onCompareRatioChanged,
  });

  final PreviewFramePair frame;
  final double compareRatio;
  final ValueChanged<double> onCompareRatioChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final splitX = (compareRatio * width).clamp(0.0, width);

        void updateSplit(Offset localPosition) {
          final nextRatio = (localPosition.dx / width).clamp(0.02, 0.98);
          onCompareRatioChanged(nextRatio);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => updateSplit(details.localPosition),
          onHorizontalDragUpdate: (details) {
            updateSplit(details.localPosition);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ClipRect(
                  clipper: PreviewComparisonClipper(left: 0, right: splitX),
                  child: Image.file(
                    File(frame.originalFramePath),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRect(
                  clipper: PreviewComparisonClipper(left: splitX, right: width),
                  child: Image.file(
                    File(frame.previewFramePath),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Positioned(
                left: splitX - 2,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: Colors.white),
              ),
              Positioned(
                left: splitX - 18,
                top: (height / 2) - 18,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.compare_arrows_rounded,
                      size: 22,
                      color: Color(0xFF6290FF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xDDEAF2F7),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PreviewLoadingOverlay extends StatelessWidget {
  const _PreviewLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x66FFFFFF),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class PreviewComparisonClipper extends CustomClipper<Rect> {
  const PreviewComparisonClipper({required this.left, required this.right});

  final double left;
  final double right;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      left.clamp(0.0, size.width),
      0,
      right.clamp(0.0, size.width),
      size.height,
    );
  }

  @override
  bool shouldReclip(PreviewComparisonClipper oldClipper) {
    return oldClipper.left != left || oldClipper.right != right;
  }
}
