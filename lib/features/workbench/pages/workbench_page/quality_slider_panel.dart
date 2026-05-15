import 'package:flutter/material.dart';
import 'package:machining/features/workbench/pages/workbench_page/models.dart';

class WorkbenchQualitySliderPanel extends StatelessWidget {
  const WorkbenchQualitySliderPanel({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.title = '视频质量',
    this.trailingText,
    this.showTrailingText = true,
    this.badgeText,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
    this.headerGap = 8,
    this.sliderHeight = 30,
    this.showStops = true,
    this.thumbSize = 28,
    this.trackHeight = 16,
    this.titleFontSize = 13,
    this.trailingFontSize = 13,
  });

  final List<QualityOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final String title;
  final String? trailingText;
  final bool showTrailingText;
  final String? badgeText;
  final EdgeInsetsGeometry padding;
  final double headerGap;
  final double sliderHeight;
  final bool showStops;
  final double thumbSize;
  final double trackHeight;
  final double titleFontSize;
  final double trailingFontSize;

  @override
  Widget build(BuildContext context) {
    final option = options[selectedIndex];
    final resolvedTrailingText =
        trailingText ?? '${option.label} / CRF ${option.crf}';

    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showTrailingText)
                badgeText == null
                    ? Text(
                        resolvedTrailingText,
                        style: TextStyle(
                          fontSize: trailingFontSize,
                          color: const Color(0xFF111111),
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : _QualityBadge(text: badgeText!),
            ],
          ),
          SizedBox(height: headerGap),
          SizedBox(
            height: sliderHeight,
            child: _WorkbenchQualitySlider(
              options: options,
              selectedIndex: selectedIndex,
              onChanged: onChanged,
              showStops: showStops,
              thumbSize: thumbSize,
              trackHeight: trackHeight,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchQualitySlider extends StatelessWidget {
  const _WorkbenchQualitySlider({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    required this.showStops,
    required this.thumbSize,
    required this.trackHeight,
  });

  final List<QualityOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool showStops;
  final double thumbSize;
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final stepCount = options.length <= 1 ? 1 : options.length - 1;
        final normalizedIndex = selectedIndex.clamp(0, stepCount).toDouble();
        final qualityValue = normalizedIndex / stepCount;
        final thumbCenter = qualityValue * trackWidth;
        final maxThumbLeft = trackWidth > thumbSize
            ? trackWidth - thumbSize
            : 0.0;
        final thumbLeft = (thumbCenter - thumbSize / 2)
            .clamp(0.0, maxThumbLeft)
            .toDouble();
        final trackTop = (constraints.maxHeight - trackHeight) / 2;
        final thumbTop = trackTop + trackHeight / 2 - thumbSize / 2;

        void updateValue(Offset localPosition) {
          if (trackWidth <= 0) {
            return;
          }
          final ratio = (localPosition.dx / trackWidth).clamp(0.0, 1.0);
          final index = (ratio * stepCount).round().clamp(0, stepCount);
          onChanged(index);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => updateValue(details.localPosition),
          onHorizontalDragUpdate: (details) {
            updateValue(details.localPosition);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: trackTop,
                child: Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEDED),
                    borderRadius: BorderRadius.circular(trackHeight / 2),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: trackTop,
                child: Container(
                  width: thumbCenter,
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6290FF),
                    borderRadius: BorderRadius.circular(trackHeight / 2),
                  ),
                ),
              ),
              if (showStops)
                Positioned(
                  left: 0,
                  right: 0,
                  top: trackTop + trackHeight / 2 - 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(options.length, (index) {
                      final active = index <= selectedIndex;
                      return Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : const Color(0xFFCFCFCF),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
              Positioned(
                left: thumbLeft,
                top: thumbTop,
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6290FF),
                      width: thumbSize >= 26 ? 4 : 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
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

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFF7900),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
