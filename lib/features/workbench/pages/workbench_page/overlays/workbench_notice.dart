import 'package:flutter/material.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';

class WorkbenchNotice extends StatelessWidget {
  const WorkbenchNotice({
    super.key,
    required this.message,
    required this.onDismissed,
    this.actionLabel,
    this.onActionPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final noticeWidth = screenWidth < 460 ? screenWidth - 32 : 380.0;

    return Positioned(
      top: WorkbenchConstants.appTopBarHeight + 14,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: noticeWidth,
              minWidth: screenWidth < 460 ? 0 : 320,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFF6290FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E2430),
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (actionLabel != null && onActionPressed != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onActionPressed,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4D7DFF),
                          minimumSize: const Size(44, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ],
                    Tooltip(
                      message: '关闭',
                      child: IconButton(
                        onPressed: onDismissed,
                        icon: const Icon(Icons.close_rounded, size: 17),
                        color: const Color(0xFF8A9099),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
