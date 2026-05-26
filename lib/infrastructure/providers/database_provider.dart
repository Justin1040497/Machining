import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/infrastructure/database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  /// 全局唯一数据库实例
  final database = AppDatabase();

  /// 这不是即时执行 这是监听事件
  ref.onDispose(database.close);
  return database;
});
