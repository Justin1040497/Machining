import 'package:flutter/material.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';

class WorkbenchVideoConfigPanel extends StatelessWidget {
  const WorkbenchVideoConfigPanel({
    super.key,
    required this.selectedOutputFormat,
    required this.selectedVideoCodec,
    required this.selectedEncoderBackend,
    required this.selectedResolutionPreset,
    required this.availableEncoderBackends,
    required this.onOutputFormatChanged,
    required this.onVideoCodecChanged,
    required this.onEncoderBackendChanged,
    required this.onResolutionPresetChanged,
    this.showEncoderBackend = true,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 18),
    this.itemSpacing = 14,
    this.dropdownHeight,
    this.showTrailingText = true,
    this.resolutionLabelBuilder,
    this.labelFontSize = 13,
    this.valueFontSize = 13,
  });

  final OutputFormat selectedOutputFormat;
  final VideoCodec selectedVideoCodec;
  final EncoderBackend selectedEncoderBackend;
  final ResolutionPreset selectedResolutionPreset;
  final List<EncoderBackend> availableEncoderBackends;
  final ValueChanged<OutputFormat> onOutputFormatChanged;
  final ValueChanged<VideoCodec> onVideoCodecChanged;
  final ValueChanged<EncoderBackend> onEncoderBackendChanged;
  final ValueChanged<ResolutionPreset> onResolutionPresetChanged;
  final bool showEncoderBackend;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final double? dropdownHeight;
  final bool showTrailingText;
  final String Function(ResolutionPreset value)? resolutionLabelBuilder;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _ConfigDropdown<OutputFormat>(
            label: '视频格式',
            trailingText: selectedOutputFormat.label,
            value: selectedOutputFormat,
            values: OutputFormat.values,
            itemLabel: (value) => value.label,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onOutputFormatChanged(value);
              }
            },
          ),
          SizedBox(height: itemSpacing),
          _ConfigDropdown<VideoCodec>(
            label: '视频编码',
            trailingText: selectedVideoCodec == VideoCodec.hevc
                ? 'HEVC'
                : selectedVideoCodec.label,
            value: selectedVideoCodec,
            values: const [VideoCodec.h264, VideoCodec.hevc],
            itemLabel: (value) => value.label,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onVideoCodecChanged(value);
              }
            },
          ),
          if (showEncoderBackend) ...[
            SizedBox(height: itemSpacing),
            _ConfigDropdown<EncoderBackend>(
              label: '编码器',
              trailingText: selectedEncoderBackend.label,
              value: selectedEncoderBackend,
              values: availableEncoderBackends,
              itemLabel: (value) => value.label,
              height: dropdownHeight,
              showTrailingText: showTrailingText,
              labelFontSize: labelFontSize,
              valueFontSize: valueFontSize,
              onChanged: (value) {
                if (value != null) {
                  onEncoderBackendChanged(value);
                }
              },
            ),
          ],
          SizedBox(height: itemSpacing),
          _ConfigDropdown<ResolutionPreset>(
            label: '分辨率',
            trailingText: selectedResolutionPreset.label,
            value: selectedResolutionPreset,
            values: const [
              ResolutionPreset.original,
              ResolutionPreset.p2160,
              ResolutionPreset.p1080,
              ResolutionPreset.p720,
              ResolutionPreset.p480,
            ],
            itemLabel: resolutionLabelBuilder ?? (value) => value.label,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onResolutionPresetChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ConfigDropdown<T> extends StatelessWidget {
  const _ConfigDropdown({
    required this.label,
    required this.trailingText,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
    this.height,
    this.showTrailingText = true,
    this.labelFontSize = 13,
    this.valueFontSize = 13,
  });

  final String label;
  final String trailingText;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final double? height;
  final bool showTrailingText;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: labelFontSize,
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showTrailingText)
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: valueFontSize,
                  color: const Color(0xFF111111),
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: height,
          child: DropdownButtonFormField<T>(
            key: ValueKey('$label-$value'),
            initialValue: value,
            isDense: true,
            style: TextStyle(fontSize: valueFontSize, color: Colors.black),
            items: values.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel(item),
                  style: TextStyle(
                    fontSize: valueFontSize,
                    color: const Color(0xFF111111),
                    height: 1.2,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF9A9A9A),
              size: 20,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: Color(0xFF6290FF)),
              ),
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}
