/// infrastructure 层导出门面。
///
/// 跨层调用必须经此 barrel 导入，禁止直达具体文件。
/// 同层内部互引用可直达文件（属于内部实现细节）。
///
/// 不导出的内部实现（21 个）：
/// - database/{app_notifications,engine_analysis_projections,settings,task_folders,tasks,
///   persistence_compatibility}.dart
///   （drift 表定义与兼容性辅助，仅 infrastructure 内部用）
/// - repositories/mappers/{compression_mode_mapper,media_task_config_json_mapper}.dart
///   （DTO 映射，仅仓储实现内部用）
/// - services/app_update/{http_app_update_client,noop_app_update_client}.dart
///   （具体实现变体，由 enterprise_aware_app_update_client 调度）
/// - services/input_runtime/standard_cli_proprietary_audio_decoder.dart
///   （由 proprietary_audio_decoder_dispatcher 调度）
/// - services/proprietary_audio/ncm/*.dart（NCM 格式内部实现）
library;

// database
export 'database/app_database.dart';

// repositories（drift 实现）
export 'repositories/drift_app_notification_repository.dart';
export 'repositories/drift_app_settings_repository.dart';
export 'repositories/drift_engine_analysis_projection_repository.dart';
export 'repositories/drift_media_task_repository.dart';
export 'repositories/drift_imported_media_batch_persistence.dart';
export 'repositories/drift_workbench_order_revision_store.dart';

// services - app_maintenance
export 'services/app_maintenance/local_app_cache_cleaner.dart';

// services - app_notifications
export 'services/app_notifications/local_task_completion_sound_player.dart';

// services - app_update
export 'services/app_update/cryptography_release_signature_verifier.dart';
export 'services/app_update/enterprise_aware_app_update_client.dart';
export 'services/app_update/local_app_update_download_state_store.dart';
export 'services/app_update/local_app_update_install_id_store.dart';
export 'services/app_update/local_app_update_package_downloader.dart';
export 'services/app_update/local_app_update_snooze_store.dart';
export 'services/app_update/local_enterprise_update_config_store.dart';
export 'services/app_update/local_updater_helper_launcher.dart';
export 'services/app_update/method_channel_sparkle_update_controller.dart';

// services - execution
export 'services/execution/local_execution_resource_guard.dart';
export 'services/execution/local_interrupted_output_cleaner.dart';

// services - engine
export 'services/engine/fengine_frame_codec.dart';
export 'services/engine/fengine_protocol_client.dart';
export 'services/engine/local_fengine_executable_locator.dart';
export 'services/engine/local_fengine_gateway.dart';

// services - input_runtime
export 'services/input_runtime/bundled_proprietary_audio_adapter_registry.dart';
export 'services/input_runtime/default_media_input_preparer.dart';
export 'services/input_runtime/file_extension_media_kind_resolver.dart';
export 'services/input_runtime/file_extension_proprietary_audio_format_resolver.dart';
export 'services/input_runtime/local_media_folder_scanner.dart';
export 'services/input_runtime/local_source_file_checker.dart';
export 'services/input_runtime/local_source_file_fingerprint_reader.dart';

// services - platform
export 'services/platform/desktop_file_selection_service.dart';
export 'services/platform/local_external_link_opener.dart';
export 'services/platform/local_file_revealer.dart';
export 'services/platform/local_theme_preferences_cache.dart';

// services - proprietary_audio
export 'services/proprietary_audio/proprietary_audio_decoder_dispatcher.dart';
