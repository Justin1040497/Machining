import 'package:flutter/material.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/app/presentation/domain_labels.dart';
import 'package:framelean/app/widgets/form_controls/config_checkbox.dart';
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

    return Padding(
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
          ConfigCheckbox(
            label: '保留元数据',
            value: config.preserveMetadata,
            height: dropdownHeight ?? 34,
            fontSize: labelFontSize,
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
