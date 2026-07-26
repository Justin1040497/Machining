import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_configuration_dialog_widgets.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

const _scrollbarThickness = 4.0;
const _scrollbarGutter = 12.0;

/// 任务配置弹窗的统一模板。
///
/// 提供固定的对话框外壳和布局分区。调用方通过 [primaryContent]、
/// [secondaryContent]、[advancedContent] 注入各媒体类型独有的配置内容。
/// 所有状态由外部 [StatefulBuilder] 管理，本组件为纯展示层。
class TaskConfigDialogTemplate extends StatelessWidget {
  const TaskConfigDialogTemplate({
    super.key,
    required this.task,
    required this.title,
    required this.onClose,
    required this.onSave,
    this.onOpenSource,
    this.thumbnail,
    this.sourceSummary,
    required this.selectedPurpose,
    required this.onPurposeChanged,
    required this.primaryContent,
    this.showPurposeSelector = true,
    this.showSecondaryContent = false,
    this.secondaryContent,
    required this.threadLimit,
    required this.onThreadLimitChanged,
    this.advancedContent,
    this.modified = false,
    this.compressed = false,
    this.saveEnabled = true,
    this.saveLabel = '保存',
    this.scrollController,
  });

  final MediaTask task;
  final String title;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final VoidCallback? onOpenSource;

  final ImageProvider? thumbnail;
  final Widget? sourceSummary;

  final TaskPurpose selectedPurpose;
  final ValueChanged<TaskPurpose> onPurposeChanged;

  /// 主内容区 —— 用途选择下方第一个区域，放压缩选项 + 媒体配置面板。
  final Widget primaryContent;
  final bool showPurposeSelector;

  /// 是否在源文件摘要和用途选择之间插入次要内容区。
  final bool showSecondaryContent;

  /// 次要内容区 —— 一般放输出位置选择。
  final Widget? secondaryContent;

  final int? threadLimit;
  final ValueChanged<int?> onThreadLimitChanged;

  /// 高级设置区额外内容 —— 二压模式 / 音频流 / 保留元数据 / 输出位置(fallback)。
  final Widget? advancedContent;

  final bool modified;
  final bool compressed;
  final bool saveEnabled;
  final String saveLabel;

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final effectiveController = scrollController ?? ScrollController();

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 25, 21),
            child: Stack(
              children: [
                // Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppDialogBackHeader(
                    title: title,
                    onClose: onClose,
                    trailing: onOpenSource == null
                        ? null
                        : SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                              tooltip: '打开源文件所在位置',
                              onPressed: onOpenSource,
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                WorkbenchIcons.openInNew,
                                color: colors.textPrimary,
                                size: 16,
                              ),
                            ),
                          ),
                  ),
                ),

                // Scrollable body
                Positioned.fill(
                  top: 46,
                  bottom: 56,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: Scrollbar(
                      controller: effectiveController,
                      thumbVisibility: false,
                      trackVisibility: false,
                      thickness: _scrollbarThickness,
                      radius: const Radius.circular(4),
                      interactive: true,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(
                          2,
                          0,
                          _scrollbarGutter,
                          0,
                        ),
                        child: SingleChildScrollView(
                          controller: effectiveController,
                          physics: const ClampingScrollPhysics(),
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 源文件摘要
                              sourceSummary ??
                                  WorkbenchSourceSummary(
                                    task: task,
                                    thumbnail: thumbnail,
                                  ),

                              // 次要内容区
                              if (showSecondaryContent &&
                                  secondaryContent != null) ...[
                                const SizedBox(height: 14),
                                secondaryContent!,
                              ],

                              const SizedBox(height: 14),

                              if (showPurposeSelector) ...[
                                // 用途选择
                                _PurposeSelector(
                                  selectedPurpose: selectedPurpose,
                                  onChanged: onPurposeChanged,
                                  colors: colors,
                                ),
                                const SizedBox(height: 14),
                              ],

                              // 主内容区
                              primaryContent,

                              const SizedBox(height: 14),

                              // 高级设置区
                              if (advancedContent != null ||
                                  threadLimit != null)
                                _AdvancedSettingsSection(
                                  threadLimit: threadLimit,
                                  onThreadLimitChanged: onThreadLimitChanged,
                                  child: advancedContent,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AppDialogActions(
                    leading: WorkbenchTaskConfigurationStatusBadges(
                      modified: modified,
                      compressed: compressed,
                    ),
                    onCancel: onClose,
                    onSave: saveEnabled ? onSave : null,
                    saveLabel: saveLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 用途选择
// ---------------------------------------------------------------------------

class _PurposeSelector extends StatelessWidget {
  const _PurposeSelector({
    required this.selectedPurpose,
    required this.onChanged,
    required this.colors,
  });

  final TaskPurpose selectedPurpose;
  final ValueChanged<TaskPurpose> onChanged;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: CupertinoSlidingSegmentedControl<TaskPurpose>(
        groupValue: selectedPurpose,
        backgroundColor: colors.surfaceDisabled,
        thumbColor: colors.surface,
        padding: const EdgeInsets.all(3),
        children: const {
          TaskPurpose.compression: Text('压缩'),
          TaskPurpose.conversion: Text('格式转换'),
        },
        onValueChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 高级设置区外壳
// ---------------------------------------------------------------------------

class _AdvancedSettingsSection extends StatefulWidget {
  const _AdvancedSettingsSection({
    required this.threadLimit,
    required this.onThreadLimitChanged,
    this.child,
  });

  final int? threadLimit;
  final ValueChanged<int?> onThreadLimitChanged;
  final Widget? child;

  @override
  State<_AdvancedSettingsSection> createState() =>
      _AdvancedSettingsSectionState();
}

class _AdvancedSettingsSectionState extends State<_AdvancedSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          maintainState: true,
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          iconColor: colors.textSecondary,
          collapsedIconColor: colors.textSecondary,
          title: Text(
            '高级设置',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.flSp,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            if (widget.child != null) ...[
              widget.child!,
              const SizedBox(height: 12),
            ],
            ConfigDropdown<int>(
              label: '线程限制',
              trailingText: '',
              value: widget.threadLimit ?? 0,
              values: const [0, 1, 2, 3, 4, 6, 8],
              itemLabel: (v) => v == 0 ? '自动' : '$v 线程',
              onChanged: (value) {
                widget.onThreadLimitChanged(value == 0 ? null : value);
              },
              height: 40,
              showTrailingText: false,
              labelFontSize: 12,
              valueFontSize: 12,
            ),
          ],
        ),
      ),
    );
  }
}
