import 'package:flutter/material.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog_widgets.dart';
import 'package:framelean/features/workbench/presentation_mappers/domain_labels.dart';
import 'package:framelean/features/workbench/widgets/form_controls/config_dropdown.dart';

class WorkbenchImageConfigPanel extends StatelessWidget {
  const WorkbenchImageConfigPanel({
    super.key,
    required this.config,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 18),
    this.itemSpacing = 14,
    this.dropdownHeight,
    this.showTrailingText = true,
    this.labelFontSize = 13,
    this.valueFontSize = 13,
  });

  final ImageProcessingConfig config;
  final ValueChanged<ImageProcessingConfig> onChanged;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final double? dropdownHeight;
  final bool showTrailingText;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final imageFormats = MediaOutputFormat.formatsFor(MediaKind.image);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _ImageQualitySelector(
            quality: config.imageQuality,
            onChanged: (value) {
              onChanged(config.copyWith(imageQuality: value));
            },
          ),
          SizedBox(height: itemSpacing),
          ConfigDropdown<MediaOutputFormat>(
            label: '图片格式',
            trailingText: config.outputFormat.label,
            value: config.outputFormat,
            values: imageFormats,
            itemLabel: (value) => value.label,
            height: dropdownHeight,
            showTrailingText: showTrailingText,
            labelFontSize: labelFontSize,
            valueFontSize: valueFontSize,
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(outputFormat: value));
              }
            },
          ),
          SizedBox(height: itemSpacing),
          ConfigDropdown<ImageResizePreset>(
            label: '分辨率',
            trailingText: config.resizePreset.label,
            value: config.resizePreset,
            values: ImageResizePreset.values,
            itemLabel: (value) => value.label,
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
          _PreserveMetadataSwitch(
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
}

class _ImageQualitySelector extends StatelessWidget {
  const _ImageQualitySelector({required this.quality, required this.onChanged});

  final int quality;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedQualityRatio = quality.clamp(1, 100) / 100;

    return WorkbenchPercentageSliderPanel(
      title: '质量',
      summaryBuilder: (ratio) => '保留${(ratio * 100).round()}%的质量',
      values: WorkbenchConstants.imageQualityRatios,
      selectedValue: selectedQualityRatio,
      onChanged: (value) => onChanged((value * 100).round()),
    );
  }
}

class _PreserveMetadataSwitch extends StatelessWidget {
  const _PreserveMetadataSwitch({
    required this.value,
    required this.height,
    required this.labelFontSize,
    required this.valueFontSize,
    required this.onChanged,
  });

  final bool value;
  final double? height;
  final double labelFontSize;
  final double valueFontSize;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
              '保留元数据',
              style: TextStyle(
                fontSize: labelFontSize,
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value ? '开启' : '关闭',
            style: TextStyle(
              fontSize: valueFontSize,
              color: const Color(0xFF111111),
            ),
          ),
        ],
      ),
    );
  }
}
