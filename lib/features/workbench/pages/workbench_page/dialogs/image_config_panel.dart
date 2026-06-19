import 'package:flutter/material.dart';
import 'package:framelean/app/presentation/media_configuration_ui_constants.dart';
import 'package:framelean/app/widgets/percentage_slider_panel.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/app/presentation/domain_labels.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/widgets/form_controls/config_dropdown.dart';

class WorkbenchImageConfigPanel extends StatelessWidget {
  const WorkbenchImageConfigPanel({
    super.key,
    required this.config,
    required this.onChanged,
    this.showLosslessCompression = true,
    this.sourceOutputFormat,
    this.sourceWidth,
    this.sourceHeight,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 18),
    this.itemSpacing = 14,
    this.dropdownHeight,
    this.showTrailingText = true,
    this.labelFontSize = 13,
    this.valueFontSize = 13,
  });

  final ImageProcessingConfig config;
  final ValueChanged<ImageProcessingConfig> onChanged;
  final bool showLosslessCompression;
  final MediaOutputFormat? sourceOutputFormat;
  final int? sourceWidth;
  final int? sourceHeight;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final double? dropdownHeight;
  final bool showTrailingText;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final allImageFormats = MediaOutputFormat.formatsFor(MediaKind.image);
    final imageFormats = config.losslessCompression && showLosslessCompression
        ? allImageFormats
              .where(supportsLosslessImageCompression)
              .toList(growable: false)
        : allImageFormats;
    final selectedOutputFormat = imageFormats.contains(config.outputFormat)
        ? config.outputFormat
        : imageFormats.first;
    final resizeValues = _resizeValues();
    final selectedResizePreset = resizeValues.contains(config.resizePreset)
        ? config.resizePreset
        : ImageResizePreset.original;

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (showLosslessCompression) ...[
            _ImageSettingSwitch(
              label: '无损压缩',
              value: config.losslessCompression,
              height: dropdownHeight,
              labelFontSize: labelFontSize,
              valueFontSize: valueFontSize,
              onChanged: _setLosslessCompression,
            ),
            SizedBox(height: itemSpacing),
          ],
          if (!showLosslessCompression || !config.losslessCompression) ...[
            _ImageQualitySelector(
              quality: config.imageQuality,
              onChanged: (value) {
                onChanged(config.copyWith(imageQuality: value));
              },
            ),
            SizedBox(height: itemSpacing),
          ],
          ConfigDropdown<MediaOutputFormat>(
            label: '图片格式',
            trailingText: _formatLabel(selectedOutputFormat),
            value: selectedOutputFormat,
            values: imageFormats,
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
          ConfigDropdown<ImageResizePreset>(
            label: '分辨率',
            trailingText: _resizeLabel(selectedResizePreset),
            value: selectedResizePreset,
            values: resizeValues,
            itemLabel: _resizeLabel,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(resizePreset: value));
              }
            },
          ),

          SizedBox(height: itemSpacing),
          _ImageSettingSwitch(
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

  void _setLosslessCompression(bool value) {
    if (!value) {
      onChanged(config.copyWith(losslessCompression: false));
      return;
    }

    final outputFormat = supportsLosslessImageCompression(config.outputFormat)
        ? config.outputFormat
        : MediaOutputFormat.webp;
    onChanged(
      config.copyWith(
        outputFormat: outputFormat,
        keepOriginalOutputFormat:
            config.keepOriginalOutputFormat &&
            outputFormat == sourceOutputFormat,
        losslessCompression: true,
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

  String _resizeLabel(ImageResizePreset value) {
    if (value == ImageResizePreset.original &&
        sourceWidth != null &&
        sourceHeight != null) {
      return '$sourceWidth × $sourceHeight（保持原始）';
    }

    return value.label;
  }

  List<ImageResizePreset> _resizeValues() {
    final sourceSize = (width: sourceWidth, height: sourceHeight);
    return ImageResizePreset.values.where((preset) {
      if (preset == ImageResizePreset.original) {
        return true;
      }

      final presetSize = _resizePresetSize(preset);
      if (presetSize == null ||
          sourceSize.width == null ||
          sourceSize.height == null) {
        return true;
      }

      return sourceSize.width != presetSize.width ||
          sourceSize.height != presetSize.height;
    }).toList();
  }

  ({int width, int height})? _resizePresetSize(ImageResizePreset preset) {
    return switch (preset) {
      ImageResizePreset.original => null,
      ImageResizePreset.longEdge3840 => (width: 3840, height: 2160),
      ImageResizePreset.longEdge2560 => (width: 2560, height: 1440),
      ImageResizePreset.longEdge1920 => (width: 1920, height: 1080),
      ImageResizePreset.longEdge1280 => (width: 1280, height: 720),
      ImageResizePreset.longEdge720 => (width: 720, height: 720),
    };
  }
}

class _ImageQualitySelector extends StatelessWidget {
  const _ImageQualitySelector({required this.quality, required this.onChanged});

  final int quality;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedQualityRatio = quality.clamp(1, 100) / 100;

    return PercentageSliderPanel(
      title: '质量',
      summaryBuilder: (ratio) => '保留${(ratio * 100).round()}%的质量',
      values: MediaConfigurationUiConstants.imageQualityRatios,
      selectedValue: selectedQualityRatio,
      onChanged: (value) => onChanged((value * 100).round()),
    );
  }
}

class _ImageSettingSwitch extends StatelessWidget {
  const _ImageSettingSwitch({
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
