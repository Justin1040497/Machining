import 'package:go_router/go_router.dart';
import 'package:framelean/features/workbench/pages/workbench_page.dart';

final appRouter = GoRouter(
  initialLocation: "/",
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) {
        return WorkbenchPage();
      },
    ),
  ],
);
