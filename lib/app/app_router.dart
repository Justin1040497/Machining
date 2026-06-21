import 'package:flutter/material.dart';
import 'package:framelean/app/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/features/settings/pages/app_settings_page.dart';
import 'package:framelean/features/settings/pages/release_notes_page.dart';
import 'package:framelean/features/workbench/pages/workbench_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: homeRoute,
  routes: [
    GoRoute(
      path: homeRoute,
      builder: (context, state) {
        return const WorkbenchPage();
      },
    ),
    GoRoute(
      path: settingsRoute,
      builder: (context, state) {
        return const AppSettingsPage();
      },
    ),
    GoRoute(
      path: releaseNotesRoute,
      builder: (context, state) {
        return ReleaseNotesPage(
          initialVersion: state.uri.queryParameters['version'],
          from: state.uri.queryParameters['from'],
        );
      },
    ),
  ],
);
