import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:machining/features/workbench/pages/workbench_page.dart';

final appRouter = GoRouter(
  initialLocation: "/",
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) {
        return WorkbenchPage();
      },
    ),
    GoRoute(
      path: "/settings",
      builder: (context, state) {
        return const Scaffold(
          body: Center(child: Text("Settings placeholder")),
        );
      },
    ),
  ],
);
