import 'package:flutter/material.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/features/workbench/presentation_mappers/domain_labels.dart';
import 'package:framelean/features/workbench/widgets/form_controls/config_dropdown.dart';

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
          ConfigDropdown<OutputFormat>(
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
          ConfigDropdown<VideoCodec>(
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
            ConfigDropdown<EncoderBackend>(
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
          ConfigDropdown<ResolutionPreset>(
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
