import 'dart:async';

import 'package:flutter/material.dart';
import 'package:machining/features/workbench/pages/workbench_page/overlays/workbench_notice.dart';

class WorkbenchNoticeController {
  OverlayEntry? _entry;
  Timer? _timer;

  void dispose() {
    hide();
  }

  void show(BuildContext context, String message, {SnackBarAction? action}) {
    hide();

    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (context) {
        return WorkbenchNotice(
          message: message,
          actionLabel: action?.label,
          onActionPressed: action == null
              ? null
              : () {
                  hide();
                  action.onPressed();
                },
          onDismissed: hide,
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(const Duration(seconds: 4), hide);
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}
