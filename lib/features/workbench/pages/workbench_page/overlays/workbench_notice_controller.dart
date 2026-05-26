import 'dart:async';

import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/overlays/workbench_notice.dart';

class WorkbenchNoticeController {
  static const _animationDuration = Duration(milliseconds: 220);

  OverlayEntry? _entry;
  Timer? _timer;
  Timer? _removeTimer;
  ValueNotifier<bool>? _visible;

  void dispose() {
    hide(immediate: true);
  }

  void show(BuildContext context, String message, {SnackBarAction? action}) {
    hide(immediate: true);

    final overlay = Overlay.of(context);
    final visible = ValueNotifier(false);
    _visible = visible;
    _entry = OverlayEntry(
      builder: (context) {
        return WorkbenchNotice(
          message: message,
          visibleListenable: visible,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_visible == visible) {
        visible.value = true;
      }
    });
    _timer = Timer(const Duration(seconds: 4), hide);
  }

  void hide({bool immediate = false}) {
    _timer?.cancel();
    _timer = null;
    _removeTimer?.cancel();
    _removeTimer = null;

    final entry = _entry;
    final visible = _visible;
    if (entry == null) {
      visible?.dispose();
      _visible = null;
      return;
    }

    void removeEntry() {
      if (_entry == entry) {
        entry.remove();
        _entry = null;
      }
      if (_visible == visible) {
        _visible = null;
      }
      visible?.dispose();
    }

    if (immediate) {
      removeEntry();
      return;
    }

    visible?.value = false;
    _removeTimer = Timer(_animationDuration, () {
      _removeTimer = null;
      removeEntry();
    });
  }
}
