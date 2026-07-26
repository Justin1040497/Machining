import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/providers/engine_provider.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';

typedef EngineTaskProjectionWidgetBuilder =
    Widget Function(BuildContext context, EngineAnalysisProjection? projection);

/// Reads the live FEngine projection when the widget is mounted by the app.
///
/// Leaf widget tests also exercise workbench components without a
/// [ProviderScope]. In that environment the task tile remains usable and only
/// omits the optional Engine queue annotation.
final class EngineTaskProjectionConsumer extends StatelessWidget {
  const EngineTaskProjectionConsumer({
    super.key,
    required this.taskId,
    required this.builder,
  });

  final String taskId;
  final EngineTaskProjectionWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return builder(context, null);
    }
    return Consumer(
      builder: (context, ref, _) {
        final projection = ref
            .watch(engineTaskProjectionProvider(taskId))
            .asData
            ?.value;
        return builder(context, projection);
      },
    );
  }
}
