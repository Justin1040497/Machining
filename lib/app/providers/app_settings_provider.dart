import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/providers/repository_provider.dart';

final appSettingsProvider = FutureProvider<AppSettings>((ref) {
  return LoadAppSettingsUseCase(
    repository: ref.watch(appSettingsRepositoryProvider),
  ).call();
});
