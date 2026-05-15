import 'package:flutter/material.dart';
import 'package:machining/features/workbench/pages/workbench_page/constants.dart';

class WorkbenchTopBar extends StatelessWidget {
  const WorkbenchTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: WorkbenchConstants.appTopBarHeight,
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Colors.white),
        child: SizedBox.expand(),
      ),
    );
  }
}
