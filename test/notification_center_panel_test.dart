import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/theme/framelean_colors.dart';
import 'package:framelean/app/theme/framelean_theme.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/value_objects/task_notification_payload.dart';
import 'package:framelean/features/notifications/services/notification_center_action_resolver.dart';
import 'package:framelean/features/notifications/widgets/notification_center_panel.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';

void main() {
  test('only successful task notifications expose an output action', () {
    final failedNotification = AppNotificationEntry(
      id: 'task-failed',
      kind: AppNotificationKind.task,
      level: AppNotificationLevel.error,
      title: '任务失败',
      message: '编码失败',
      source: 'task',
      createdAt: DateTime(2026, 6, 11),
      payloadJson: const TaskNotificationPayload(
        taskId: 'task-1',
        fileName: 'demo.mp4',
        outputPath: '/output/demo.mp4',
      ).toJson(),
    );

    expect(
      NotificationCenterActionResolver.resolve(failedNotification),
      isNull,
    );
  });

  testWidgets(
    'slides in, marks notifications read, reveals output, and clears history',
    (tester) async {
      final repository = FakeNotificationCenterRepository([
        AppNotificationEntry(
          id: 'task-completed',
          kind: AppNotificationKind.task,
          level: AppNotificationLevel.success,
          title: '任务成功',
          message: 'demo.mp4 已处理完成，输出配置已保存，非运行状态的任务已更新；正在处理的任务将在下次处理时使用新配置',
          source: 'task',
          createdAt: DateTime(2026, 6, 11, 10, 30),
          payloadJson: const TaskNotificationPayload(
            taskId: 'task-1',
            fileName: 'demo.mp4',
            outputPath: '/output/demo.mp4',
          ).toJson(),
        ),
      ]);
      addTearDown(repository.dispose);
      var visible = false;
      var closeCount = 0;
      String? revealedPath;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appNotificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: frameLeanLightTheme(),
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: TextButton(
                          key: const Key('open-notification-center'),
                          onPressed: () => setState(() => visible = true),
                          child: const Text('打开'),
                        ),
                      ),
                      NotificationCenterPanel(
                        visible: visible,
                        onClose: () {
                          closeCount += 1;
                          setState(() => visible = false);
                        },
                        onRevealOutput: (path) async {
                          revealedPath = path;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      final panelFinder = find.byKey(const Key('notification-center-panel'));
      final hiddenLeft = tester.getTopLeft(panelFinder).dx;

      await tester.tap(find.byKey(const Key('open-notification-center')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(tester.getTopLeft(panelFinder).dx, lessThan(hiddenLeft));
      await tester.pumpAndSettle();
      expect(find.text('通知中心'), findsOneWidget);
      expect(find.text('任务成功'), findsOneWidget);
      final subtitleFinder = find.textContaining('demo.mp4 已处理完成');
      expect(subtitleFinder, findsOneWidget);
      final subtitle = tester.widget<Text>(subtitleFinder);
      expect(subtitle.maxLines, isNull);
      expect(subtitle.overflow, isNull);
      expect(find.textContaining('10:30'), findsOneWidget);
      expect(tester.getSize(panelFinder).width, 380);
      expect(repository.markAllAsReadCalls, greaterThan(0));

      final notificationItem = tester.widget<Container>(
        find.byKey(const Key('notification-center-item')),
      );
      final itemDecoration = notificationItem.decoration! as BoxDecoration;
      expect(itemDecoration.color, frameLeanLightColors.surface);
      expect(itemDecoration.borderRadius, BorderRadius.circular(4));
      expect(itemDecoration.border, isNotNull);
      expect(
        tester.getSize(find.byKey(const Key('notification-center-accent'))),
        const Size(2, 14),
      );

      await tester.tap(find.byKey(const Key('notification-reveal-output')));
      await tester.pump();
      expect(revealedPath, '/output/demo.mp4');

      await tester.tap(find.byKey(const Key('notification-center-clear')));
      await tester.pumpAndSettle();
      expect(find.text('暂无通知'), findsOneWidget);
      expect(repository.dismissAllCalls, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(closeCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class FakeNotificationCenterRepository implements AppNotificationRepository {
  FakeNotificationCenterRepository(List<AppNotificationEntry> notifications)
    : _notifications = notifications {
    _emit();
  }

  final StreamController<List<AppNotificationEntry>> _controller =
      StreamController<List<AppNotificationEntry>>.broadcast();
  List<AppNotificationEntry> _notifications;
  int markAllAsReadCalls = 0;
  int dismissAllCalls = 0;

  void dispose() {
    unawaited(_controller.close());
  }

  void _emit() {
    scheduleMicrotask(() {
      if (!_controller.isClosed) {
        _controller.add(List.unmodifiable(_notifications));
      }
    });
  }

  @override
  Future<void> dismiss(String id, DateTime dismissedAt) async {
    _notifications = _notifications.where((item) => item.id != id).toList();
    _emit();
  }

  @override
  Future<void> dismissAll(DateTime dismissedAt) async {
    dismissAllCalls += 1;
    _notifications = [];
    _emit();
  }

  @override
  Future<List<AppNotificationEntry>> loadRecentNotifications({
    int? limit,
  }) async {
    return _notifications.take(limit ?? _notifications.length).toList();
  }

  @override
  Future<void> markAsRead(String id, DateTime readAt) async {}

  @override
  Future<void> markAllAsRead(DateTime readAt) async {
    markAllAsReadCalls += 1;
    _notifications = [
      for (final notification in _notifications)
        AppNotificationEntry(
          id: notification.id,
          kind: notification.kind,
          level: notification.level,
          title: notification.title,
          message: notification.message,
          source: notification.source,
          createdAt: notification.createdAt,
          readAt: readAt,
          dismissedAt: notification.dismissedAt,
          payloadJson: notification.payloadJson,
        ),
    ];
    _emit();
  }

  @override
  Future<void> saveNotification(AppNotificationEntry notification) async {
    _notifications = [notification, ..._notifications];
    _emit();
  }

  @override
  Stream<List<AppNotificationEntry>> watchRecentNotifications({int? limit}) {
    return _controller.stream.map(
      (items) => items.take(limit ?? items.length).toList(),
    );
  }
}
