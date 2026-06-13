import 'package:flutter/material.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/app/presentation/domain_labels.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/widgets/form_controls/config_dropdown.dart';

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
    this.sourceOutputFormat,
    this.keepOriginalOutputFormat = false,
    this.showPreserveHdrOption = false,
    this.preserveHdr = false,
    this.onPreserveHdrChanged,
    this.preserveMetadata = true,
    this.onPreserveMetadataChanged,
    this.videoCodecValues = const [VideoCodec.h264, VideoCodec.hevc],
    this.videoCodecEnabled = true,
    this.showEncoderBackend = true,
    this.resolutionValues = const [
      ResolutionPreset.original,
      ResolutionPreset.p2160,
      ResolutionPreset.p1080,
      ResolutionPreset.p720,
      ResolutionPreset.p480,
    ],
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
  final OutputFormat? sourceOutputFormat;
  final bool keepOriginalOutputFormat;
  final bool showPreserveHdrOption;
  final bool preserveHdr;
  final ValueChanged<bool>? onPreserveHdrChanged;
  final bool preserveMetadata;
  final ValueChanged<bool>? onPreserveMetadataChanged;
  final List<VideoCodec> videoCodecValues;
  final bool videoCodecEnabled;
  final bool showEncoderBackend;
  final List<ResolutionPreset> resolutionValues;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final double? dropdownHeight;
  final bool showTrailingText;
  final String Function(ResolutionPreset value)? resolutionLabelBuilder;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final selectedResolutionValue =
        resolutionValues.contains(selectedResolutionPreset)
        ? selectedResolutionPreset
        : ResolutionPreset.original;

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ConfigDropdown<OutputFormat>(
            label: '视频格式',
            trailingText: _outputFormatLabel(selectedOutputFormat),
            value: selectedOutputFormat,
            values: OutputFormat.values,
            itemLabel: _outputFormatLabel,
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
          if (showPreserveHdrOption && onPreserveHdrChanged != null) ...[
            SizedBox(height: itemSpacing),
            _VideoConfigSwitch(
              label: '保持 HDR',
              value: preserveHdr,
              height: dropdownHeight,
              labelFontSize: labelFontSize,
              valueFontSize: valueFontSize,
              onChanged: onPreserveHdrChanged!,
            ),
          ],
          SizedBox(height: itemSpacing),
          ConfigDropdown<VideoCodec>(
            label: '视频编码',
            trailingText: selectedVideoCodec == VideoCodec.hevc
                ? 'HEVC'
                : selectedVideoCodec.label,
            value: selectedVideoCodec,
            values: videoCodecValues,
            itemLabel: (value) => value.label,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            enabled: videoCodecEnabled,
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
              enabled: !preserveHdr,
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
            trailingText: (resolutionLabelBuilder ?? (value) => value.label)(
              selectedResolutionValue,
            ),
            value: selectedResolutionValue,
            values: resolutionValues,
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
          if (onPreserveMetadataChanged != null) ...[
            SizedBox(height: itemSpacing),
            _VideoConfigSwitch(
              label: '保留元数据',
              value: preserveMetadata,
              height: dropdownHeight,
              labelFontSize: labelFontSize,
              valueFontSize: valueFontSize,
              onChanged: onPreserveMetadataChanged!,
            ),
          ],
        ],
      ),
    );
  }

  String _outputFormatLabel(OutputFormat value) {
    if (value == sourceOutputFormat ||
        (keepOriginalOutputFormat && value == selectedOutputFormat)) {
      return '${value.label}（保持原始）';
    }

    return value.label;
  }
}

class _VideoConfigSwitch extends StatelessWidget {
  const _VideoConfigSwitch({
    required this.label,
    required this.value,
    required this.height,
    required this.labelFontSize,
    required this.valueFontSize,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final double? height;
  final double labelFontSize;
  final double valueFontSize;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return SizedBox(
      height: height ?? 34,
      child: Row(
        children: [
          Transform.scale(
            scale: 0.78,
            child: Switch(
              padding: EdgeInsets.zero,
              value: value,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: labelFontSize.flSp,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value ? '开启' : '关闭',
            style: TextStyle(
              fontSize: valueFontSize.flSp,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
