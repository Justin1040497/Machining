import 'package:flutter/material.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

class WorkbenchDropOverlay extends StatelessWidget {
  const WorkbenchDropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.textPrimary.withAlpha(122)),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    WorkbenchIcons.fileUpload,
                    color: colors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '移动到窗口松手即添加',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18.flSp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
