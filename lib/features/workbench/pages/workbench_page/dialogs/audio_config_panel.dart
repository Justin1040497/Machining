import 'package:flutter/material.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/app/presentation/domain_labels.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/widgets/form_controls/config_dropdown.dart';

class WorkbenchAudioConfigPanel extends StatelessWidget {
  const WorkbenchAudioConfigPanel({
    super.key,
    required this.config,
    required this.onChanged,
    this.sourceOutputFormat,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 18),
    this.itemSpacing = 14,
    this.dropdownHeight,
    this.showTrailingText = true,
    this.labelFontSize = 13,
    this.valueFontSize = 13,
  });

  final AudioProcessingConfig config;
  final ValueChanged<AudioProcessingConfig> onChanged;
  final MediaOutputFormat? sourceOutputFormat;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final double? dropdownHeight;
  final bool showTrailingText;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final audioFormats = MediaOutputFormat.formatsFor(MediaKind.audio);
    final selectedOutputFormat = audioFormats.contains(config.outputFormat)
        ? config.outputFormat
        : MediaOutputFormat.m4a;

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ConfigDropdown<MediaOutputFormat>(
            label: '音频格式',
            trailingText: _formatLabel(selectedOutputFormat),
            value: selectedOutputFormat,
            values: audioFormats,
            itemLabel: _formatLabel,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onChanged(
                  config.copyWith(
                    outputFormat: value,
                    keepOriginalOutputFormat: value == sourceOutputFormat,
                  ),
                );
              }
            },
          ),
          SizedBox(height: itemSpacing),
          ConfigDropdown<AudioBitratePreset>(
            label: '码率',
            trailingText: config.bitratePreset.label,
            value: config.bitratePreset,
            values: AudioBitratePreset.values,
            itemLabel: (value) => value.label,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(bitratePreset: value));
              }
            },
          ),
          SizedBox(height: itemSpacing),
          ConfigDropdown<AudioSampleRatePreset>(
            label: '采样率',
            trailingText: config.sampleRate.label,
            value: config.sampleRate,
            values: AudioSampleRatePreset.values,
            itemLabel: (value) => value.label,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(sampleRate: value));
              }
            },
          ),
          SizedBox(height: itemSpacing),
          ConfigDropdown<AudioChannelsPreset>(
            label: '声道',
            trailingText: config.channels.label,
            value: config.channels,
            values: AudioChannelsPreset.values,
            itemLabel: (value) => value.label,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(channels: value));
              }
            },
          ),
          SizedBox(height: itemSpacing),
          _AudioConfigSwitch(
            label: '保留元数据',
            value: config.preserveMetadata,
            height: dropdownHeight,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              onChanged(config.copyWith(preserveMetadata: value));
            },
          ),
        ],
      ),
    );
  }

  String _formatLabel(MediaOutputFormat value) {
    if (value == sourceOutputFormat ||
        (config.keepOriginalOutputFormat && value == config.outputFormat)) {
      return '${value.label}（保持原始）';
    }

    return value.label;
  }
}

class _AudioConfigSwitch extends StatelessWidget {
  const _AudioConfigSwitch({
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
