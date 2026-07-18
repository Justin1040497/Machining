import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';

const Object _previewStateValueNotProvided = Object();

final workbenchPreviewProvider =
    NotifierProvider<WorkbenchPreviewNotifier, WorkbenchPreviewState>(
      WorkbenchPreviewNotifier.new,
    );

@immutable
class WorkbenchPreviewState {
  const WorkbenchPreviewState({
    this.generating = false,
    this.compareRatio = 0.5,
    this.selectedFrameIndex = 0,
    this.result,
    this.errorMessage,
  });

  final bool generating;
  final double compareRatio;
  final int selectedFrameIndex;
  final PreviewFrameResult? result;
  final String? errorMessage;

  WorkbenchPreviewState copyWith({
    bool? generating,
    double? compareRatio,
    int? selectedFrameIndex,
    Object? result = _previewStateValueNotProvided,
    Object? errorMessage = _previewStateValueNotProvided,
  }) {
    return WorkbenchPreviewState(
      generating: generating ?? this.generating,
      compareRatio: compareRatio ?? this.compareRatio,
      selectedFrameIndex: selectedFrameIndex ?? this.selectedFrameIndex,
      result: result == _previewStateValueNotProvided
          ? this.result
          : result as PreviewFrameResult?,
      errorMessage: errorMessage == _previewStateValueNotProvided
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class WorkbenchPreviewNotifier extends Notifier<WorkbenchPreviewState> {
  int generationId = 0;

  @override
  WorkbenchPreviewState build() {
    return const WorkbenchPreviewState();
  }

  void reset() {
    generationId += 1;
    state = const WorkbenchPreviewState();
  }

  void setCompareRatio(double value) {
    state = state.copyWith(compareRatio: value.clamp(0.02, 0.98).toDouble());
  }

  void selectFrame(int index) {
    state = state.copyWith(selectedFrameIndex: index < 0 ? 0 : index);
  }

  Future<void> generate({
    required MediaTask task,
    required bool allowExtremeCompression,
  }) async {
    state = state.copyWith(errorMessage: null);
    generationId += 1;
    final activeGenerationId = generationId;
    state = state.copyWith(generating: true, errorMessage: null);

    try {
      final result = await GeneratePreviewFramesUseCase(
        readRuntime: () => ref.read(ffmpegRuntimeProvider.future),
        previewFrameGenerator: ref.read(previewFrameGeneratorProvider),
      ).call(task: task, allowExtremeCompression: allowExtremeCompression);
      if (!_isActiveGeneration(activeGenerationId)) {
        return;
      }

      state = WorkbenchPreviewState(result: result);
    } on Object catch (error) {
      if (!_isActiveGeneration(activeGenerationId)) {
        return;
      }

      state = state.copyWith(generating: false, errorMessage: error.toString());
    }
  }

  bool _isActiveGeneration(int activeGenerationId) {
    return activeGenerationId == generationId;
  }
}
