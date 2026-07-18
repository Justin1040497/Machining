import 'dart:async';

import 'package:framelean/application/services/execution/media_work_scheduler.dart';

class ExecutionSlotCoordinator {
  ExecutionSlotCoordinator({
    required MediaWorkScheduler? scheduler,
    required this.canRefill,
    required this.refill,
  }) {
    _capacitySubscription = scheduler?.capacityChanges.listen((_) {
      requestRefill();
    });
  }

  final bool Function() canRefill;
  final Future<void> Function() refill;
  StreamSubscription<void>? _capacitySubscription;
  bool _pumpScheduledOrRunning = false;
  bool _refillRequested = false;
  bool _disposed = false;

  void requestRefill() {
    if (_disposed || !canRefill()) {
      return;
    }
    _refillRequested = true;
    if (_pumpScheduledOrRunning) {
      return;
    }
    _pumpScheduledOrRunning = true;
    scheduleMicrotask(() {
      unawaited(_pump());
    });
  }

  Future<void> _pump() async {
    try {
      while (!_disposed && _refillRequested && canRefill()) {
        _refillRequested = false;
        await refill();
      }
    } finally {
      _pumpScheduledOrRunning = false;
      if (!_disposed && _refillRequested && canRefill()) {
        requestRefill();
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _refillRequested = false;
    await _capacitySubscription?.cancel();
  }
}
