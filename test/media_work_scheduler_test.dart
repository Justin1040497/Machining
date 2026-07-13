import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/execution/media_resource_monitor.dart';
import 'package:framelean/application/services/execution/media_work_scheduler.dart';

void main() {
  group('MediaWorkScheduler capacityChanges', () {
    test('emits when a lease releases capacity', () async {
      final scheduler = MediaWorkScheduler(maxTotalConcurrentWorks: 1);
      addTearDown(scheduler.stop);
      final changes = <void>[];
      final subscription = scheduler.capacityChanges.listen(changes.add);
      addTearDown(subscription.cancel);
      final lease = scheduler.tryAcquire(_request('analysis'))!;

      await lease.release();
      await Future<void>.delayed(Duration.zero);

      expect(changes, hasLength(1));
    });

    test(
      'emits only when resource pressure becomes less restrictive',
      () async {
        final monitor = _FakeResourceMonitor(
          MediaResourcePressure.severePressure,
        );
        final scheduler = MediaWorkScheduler(resourceMonitor: monitor);
        addTearDown(scheduler.stop);
        var changeCount = 0;
        final subscription = scheduler.capacityChanges.listen((_) {
          changeCount += 1;
        });
        addTearDown(subscription.cancel);

        monitor.setPressure(MediaResourcePressure.underPressure);
        monitor.setPressure(MediaResourcePressure.normal);
        monitor.setPressure(MediaResourcePressure.underPressure);
        await Future<void>.delayed(Duration.zero);

        expect(changeCount, 2);
      },
    );
  });
}

MediaWorkRequest _request(String id) {
  return MediaWorkRequest(
    id: id,
    kind: MediaWorkKind.analyze,
    priority: MediaWorkPriority.normal,
  );
}

class _FakeResourceMonitor extends MediaResourceMonitor {
  _FakeResourceMonitor(this._pressure);

  final StreamController<MediaResourcePressure> _controller =
      StreamController<MediaResourcePressure>.broadcast();
  MediaResourcePressure _pressure;

  @override
  MediaResourcePressure get currentPressure => _pressure;

  @override
  Stream<MediaResourcePressure> get pressureChanges => _controller.stream;

  void setPressure(MediaResourcePressure pressure) {
    _pressure = pressure;
    _controller.add(pressure);
  }

  @override
  Future<void> stop() => _controller.close();
}
