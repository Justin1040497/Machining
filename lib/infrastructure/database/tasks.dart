import 'package:drift/drift.dart';

class TaskRows extends Table {
  /// 这里id用String类型 因为实体类media_task里面用的是uuid
  TextColumn get id => text()();
  TextColumn get inputPath => text().named('input_path')();
  TextColumn get fileName => text().named('file_name')();
  TextColumn get mediaKind =>
      text().named('media_kind').withDefault(const Constant('video'))();
  TextColumn get purpose => text()();
  TextColumn get status => text()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().named('sort_order')();
  TextColumn get outputPath => text().named('output_path').nullable()();
  TextColumn get errorMessage => text().named('error_message').nullable()();
  IntColumn get sourceFileSize =>
      integer().named('source_file_size').nullable()();
  IntColumn get sourceLastModifiedAt =>
      integer().named('source_last_modified_at').nullable()();
  IntColumn get analysisDurationMs =>
      integer().named('analysis_duration_ms').nullable()();
  IntColumn get analysisVideoWidth =>
      integer().named('analysis_video_width').nullable()();
  IntColumn get analysisVideoHeight =>
      integer().named('analysis_video_height').nullable()();
  TextColumn get analysisVideoCodec =>
      text().named('analysis_video_codec').nullable()();
  TextColumn get analysisAudioCodec =>
      text().named('analysis_audio_codec').nullable()();
  TextColumn get analysisVideoPixelFormat =>
      text().named('analysis_video_pixel_format').nullable()();
  IntColumn get analysisVideoBitDepth =>
      integer().named('analysis_video_bit_depth').nullable()();
  TextColumn get analysisColorRange =>
      text().named('analysis_color_range').nullable()();
  TextColumn get analysisColorSpace =>
      text().named('analysis_color_space').nullable()();
  TextColumn get analysisColorTransfer =>
      text().named('analysis_color_transfer').nullable()();
  TextColumn get analysisColorPrimaries =>
      text().named('analysis_color_primaries').nullable()();
  TextColumn get analysisAverageFrameRate =>
      text().named('analysis_average_frame_rate').nullable()();
  TextColumn get analysisRealFrameRate =>
      text().named('analysis_real_frame_rate').nullable()();
  TextColumn get analysisSampleAspectRatio =>
      text().named('analysis_sample_aspect_ratio').nullable()();
  TextColumn get analysisDisplayAspectRatio =>
      text().named('analysis_display_aspect_ratio').nullable()();
  IntColumn get analysisVideoRotationDegrees =>
      integer().named('analysis_video_rotation_degrees').nullable()();
  TextColumn get analysisFieldOrder =>
      text().named('analysis_field_order').nullable()();
  IntColumn get analysisVideoBitrate =>
      integer().named('analysis_video_bitrate').nullable()();
  IntColumn get analysisAudioBitrate =>
      integer().named('analysis_audio_bitrate').nullable()();
  IntColumn get analysisContainerBitrate =>
      integer().named('analysis_container_bitrate').nullable()();
  IntColumn get analysisEstimatedBitrate =>
      integer().named('analysis_estimated_bitrate').nullable()();
  TextColumn get analysisContainerFormat =>
      text().named('analysis_container_format').nullable()();
  IntColumn get analysisAudioChannels =>
      integer().named('analysis_audio_channels').nullable()();
  IntColumn get analysisAudioSampleRate =>
      integer().named('analysis_audio_sample_rate').nullable()();
  TextColumn get analysisAudioChannelLayout =>
      text().named('analysis_audio_channel_layout').nullable()();
  IntColumn get analysisAudioStreamIndex =>
      integer().named('analysis_audio_stream_index').nullable()();
  IntColumn get analysisUpdatedAt =>
      integer().named('analysis_updated_at').nullable()();
  TextColumn get analysisErrorMessage =>
      text().named('analysis_error_message').nullable()();
  TextColumn get outputFormat => text().named('output_format')();
  TextColumn get videoCodec => text().named('video_codec')();
  TextColumn get encoderBackend => text().named('encoder_backend')();
  TextColumn get resolutionPreset => text().named('resolution_preset')();
  TextColumn get outputDirectory => text().named('output_directory')();
  IntColumn get compressionCrf =>
      integer().named('compression_crf').withDefault(const Constant(28))();
  TextColumn get compressionMode =>
      text().named('compression_mode').withDefault(const Constant('preset'))();
  TextColumn get smartPreset => text().named('smart_preset').nullable()();
  IntColumn get targetSizeBytes =>
      integer().named('target_size_bytes').nullable()();
  RealColumn get targetSizeRatio =>
      real().named('target_size_ratio').nullable()();
  TextColumn get outputFileName =>
      text().named('output_file_name').withDefault(const Constant(''))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get startedAt => integer().named('started_at').nullable()();
  IntColumn get completedAt => integer().named('completed_at').nullable()();
  IntColumn get failedAt => integer().named('failed_at').nullable()();

  @override
  String get tableName => 'tasks';

  @override
  Set<Column> get primaryKey => {id};
}
