import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/app/providers/app_update_provider.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/widgets/simple_markdown_view.dart';
import 'package:framelean/domain/value_objects/app_release_notes.dart';

class ReleaseNotesPage extends ConsumerStatefulWidget {
  const ReleaseNotesPage({super.key, this.initialVersion});

  final String? initialVersion;

  @override
  ConsumerState<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends ConsumerState<ReleaseNotesPage> {
  String? selectedVersion;

  @override
  void initState() {
    super.initState();
    selectedVersion = widget.initialVersion;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final notesValue = ref.watch(appReleaseNotesProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: notesValue.when(
          data: (notes) => _buildContent(context, notes),
          loading: () => Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          error: (error, _) => _ReleaseNotesEmptyState(
            message: '版本日志读取失败\n$error',
            onBack: () => _goBack(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<AppReleaseNotes> notes) {
    final colors = context.frameLeanColors;
    if (notes.isEmpty) {
      return _ReleaseNotesEmptyState(
        message: '暂无版本日志',
        onBack: () => _goBack(context),
      );
    }

    final selected = _resolveSelectedNotes(notes);
    return Row(
      children: [
        SizedBox(
          width: 168,
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.surface),
            child: Column(
              children: [
                SizedBox(
                  height: 54,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: IconButton(
                        tooltip: '返回设置',
                        onPressed: () => _goBack(context),
                        icon: const Icon(Icons.keyboard_arrow_left_rounded),
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final item = notes[index];
                      final selectedItem = item.version == selected.version;
                      return _ReleaseNotesVersionButton(
                        version: item.version,
                        selected: selectedItem,
                        onPressed: () {
                          setState(() => selectedVersion = item.version);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: colors.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(44, 42, 44, 42),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.version,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: SimpleMarkdownView(markdown: selected.markdown),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  AppReleaseNotes _resolveSelectedNotes(List<AppReleaseNotes> notes) {
    final version = selectedVersion;
    if (version != null) {
      for (final item in notes) {
        if (item.version == version) {
          return item;
        }
      }
    }
    return notes.first;
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/settings');
  }
}

class _ReleaseNotesVersionButton extends StatelessWidget {
  const _ReleaseNotesVersionButton({
    required this.version,
    required this.selected,
    required this.onPressed,
  });

  final String version;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: selected ? colors.primarySoft : Colors.transparent,
          foregroundColor: selected ? colors.primary : colors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Text(version),
      ),
    );
  }
}

class _ReleaseNotesEmptyState extends StatelessWidget {
  const _ReleaseNotesEmptyState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onBack, child: const Text('返回设置')),
        ],
      ),
    );
  }
}
