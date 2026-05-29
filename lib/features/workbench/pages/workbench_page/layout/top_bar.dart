import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';

class WorkbenchTopBar extends StatelessWidget {
  const WorkbenchTopBar({
    super.key,
    required this.onOpenAbout,
    this.showBottomBorder = false,
  });

  final VoidCallback onOpenAbout;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: WorkbenchConstants.appTopBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: showBottomBorder
              ? const Border(bottom: BorderSide(color: Color(0xFFE6E6E6)))
              : null,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 22),
            child: SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                tooltip: '关于 FrameLean',
                onPressed: onOpenAbout,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF666666),
                  hoverColor: const Color(0xFFF0F0F0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.info_outline_rounded, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
