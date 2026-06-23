/// domain 层导出门面。
///
/// 跨层调用必须经此 barrel 导入，禁止直达具体文件。
/// 同层内部互引用可直达文件（属于内部实现细节）。
///
/// 导出原则：仅导出跨层需要的公共类型。本层所有文件目前均被外部引用，
/// 故全部导出。新增仅同层内部使用的辅助类时不进此清单。
library;

// entities
export 'entities/app_notification_entry.dart';
export 'entities/app_settings.dart';
export 'entities/media_task.dart';
export 'entities/task_folder.dart';

// enums
export 'enums/app_close_behavior.dart';
export 'enums/app_notification_kind.dart';
export 'enums/app_notification_level.dart';
export 'enums/app_shortcut_action.dart';
export 'enums/app_theme_mode.dart';
export 'enums/app_update_status.dart';
export 'enums/compression_mode.dart';
export 'enums/encoder_backend.dart';
export 'enums/hdr_output_mode.dart';
export 'enums/media_kind.dart';
export 'enums/media_output_format.dart';
export 'enums/media_processing_preset.dart';
export 'enums/media_task_policy_tag.dart';
export 'enums/notification_delivery_mode.dart';
export 'enums/notification_event_type.dart';
export 'enums/output_format.dart';
export 'enums/output_location_mode.dart';
export 'enums/proprietary_audio_format.dart';
export 'enums/resolution_preset.dart';
export 'enums/smart_compression_preset.dart';
export 'enums/task_completion_sound.dart';
export 'enums/task_purpose.dart';
export 'enums/task_status.dart';
export 'enums/two_pass_mode.dart';
export 'enums/video_codec.dart';

// services
export 'services/source_compression_assessor.dart';

// value_objects
export 'value_objects/app_compression_settings.dart';
export 'value_objects/app_release_info.dart';
export 'value_objects/app_release_notes.dart';
export 'value_objects/app_shortcut_binding.dart';
export 'value_objects/app_update_package_info.dart';
export 'value_objects/app_update_state.dart';
export 'value_objects/audio_processing_config.dart';
export 'value_objects/enterprise_update_config.dart';
export 'value_objects/image_processing_config.dart';
export 'value_objects/media_analysis_result.dart';
export 'value_objects/media_audio_stream_info.dart';
export 'value_objects/media_task_config.dart';
export 'value_objects/proprietary_audio_decode_result.dart';
export 'value_objects/source_file_fingerprint.dart';
export 'value_objects/task_notification_payload.dart';
export 'value_objects/update_notification_payload.dart';
export 'value_objects/video_output_compatibility.dart';
export 'value_objects/video_processing_config.dart';
export 'value_objects/video_task_config.dart';
