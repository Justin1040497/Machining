import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:framelean/app/notifications/app_notification_host.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';
import 'package:framelean/app/theme/framelean_theme.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/infrastructure/providers/app_notification_provider.dart';

void main() {
  testWidgets('presents notification without missing overlay errors', (
    tester,
  ) async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appNotificationManagerProvider.overrideWithValue(manager)],
        child: ScreenUtilInit(
          designSize: frameLeanScreenDesignSize,
          fontSizeResolver: frameLeanFontSizeResolver,
          builder: (context, child) {
            return MaterialApp(
              theme: frameLeanLightTheme(),
              builder: (context, child) {
                return AppNotificationHost(
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const Scaffold(body: Text('home')),
            );
          },
        ),
      ),
    );

    await manager.notify(
      level: AppNotificationLevel.success,
      title: '设置修改并保存成功',
      source: 'settings',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('设置修改并保存成功'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class FakeAppNotificationRepository implements AppNotificationRepository {
  final savedNotifications = <AppNotificationEntry>[];

  @override
  Future<void> dismiss(String id, DateTime dismissedAt) async {}

  @override
  Future<List<AppNotificationEntry>> loadRecentNotifications({
    int limit = 50,
  }) async {
    return savedNotifications.take(limit).toList();
  }

  @override
  Future<void> markAsRead(String id, DateTime readAt) async {}

  @override
  Future<void> saveNotification(AppNotificationEntry notification) async {
    savedNotifications.add(notification);
  }

  @override
  Stream<List<AppNotificationEntry>> watchRecentNotifications({
    int limit = 50,
  }) async* {
    yield savedNotifications.take(limit).toList();
  }
}
