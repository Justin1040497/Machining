import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/infrastructure/services/update/self_hosted_update_checker.dart';
import 'package:http/http.dart' as http;

final appUpdateCheckerProvider = Provider<AppUpdateChecker>((ref) {
  final httpClient = http.Client();
  ref.onDispose(httpClient.close);
  return SelfHostedUpdateChecker.frameLean(httpClient: httpClient);
});
