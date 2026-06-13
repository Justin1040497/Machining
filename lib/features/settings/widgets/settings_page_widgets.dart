part of '../pages/app_settings_page.dart';

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
      ),
    );
  }
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '设置加载失败',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
                  const SizedBox(width: 12),
                  TextButton(onPressed: onBack, child: const Text('返回工作台')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: Container(
        padding: EdgeInsets.only(top: 34),
        alignment: AlignmentDirectional.topStart,
        child: child,
      ),
    );
  }
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.title,
    required this.children,
    this.maxWidth = 520,
  });

  final String title;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(31, 21, 31, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 34),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.selectedSection,
    required this.saving,
    required this.onClose,
    required this.onSectionSelected,
  });

  final _SettingsSection selectedSection;
  final bool saving;
  final VoidCallback onClose;
  final ValueChanged<_SettingsSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          21,
          AppLayoutConstants.topBarHeight,
          20,
          18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackToWorkbenchButton(saving: saving, onPressed: onClose),
            const SizedBox(height: 34),
            _SidebarGroup(
              label: '常规配置',
              sections: const [_SettingsSection.app, _SettingsSection.about],
              selectedSection: selectedSection,
              onSectionSelected: onSectionSelected,
            ),
            const SizedBox(height: 30),
            _SidebarGroup(
              label: '任务设置',
              sections: const [
                _SettingsSection.video,
                _SettingsSection.image,
                _SettingsSection.audio,
              ],
              selectedSection: selectedSection,
              onSectionSelected: onSectionSelected,
            ),
            const SizedBox(height: 30),
            _SidebarGroup(
              label: '输入和输出',
              sections: const [
                _SettingsSection.output,
                _SettingsSection.encoder,
              ],
              selectedSection: selectedSection,
              onSectionSelected: onSectionSelected,
            ),
            const Spacer(),
            if (saving)
              Text(
                '正在保存...',
                style: TextStyle(color: colors.textTertiary, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackToWorkbenchButton extends StatelessWidget {
  const _BackToWorkbenchButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: saving ? null : onPressed,
      child: SizedBox(
        height: 26,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              Icons.chevron_left_rounded,
              color: colors.textPrimary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '返回工作台',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarGroup extends StatelessWidget {
  const _SidebarGroup({
    required this.label,
    required this.sections,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final String label;
  final List<_SettingsSection> sections;
  final _SettingsSection selectedSection;
  final ValueChanged<_SettingsSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 9),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final section in sections) ...[
          _SidebarItem(
            section: section,
            selected: section == selectedSection,
            onTap: () => onSectionSelected(section),
          ),
          if (section != sections.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Material(
      color: selected ? colors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: SizedBox(
          height: 29,
          child: Row(
            children: [
              const SizedBox(width: 9),
              Icon(section.icon, color: colors.textPrimary, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
