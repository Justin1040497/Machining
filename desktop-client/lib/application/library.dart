/// application 层导出门面。
///
/// 跨层调用必须经此 barrel 导入，禁止直达具体文件。
/// 同层内部互引用可直达文件（属于内部实现细节）。
///
/// 不导出的内部实现：
/// - services/execution/task_execution_notification_summary.dart（仅 application 内部用）
/// - use_cases/media_tasks/reorder_media_tasks_use_case.dart（当前无引用，疑似废弃）
library;

export 'constants.dart';

// models
export 'models/engine_analysis_documents.dart';
export 'models/engine_analysis_projection.dart';

// repositories（端口定义，infrastructure 实现）
export 'repositories/app_notification_repository.dart';
export 'repositories/app_settings_repository.dart';
export 'repositories/engine_analysis_projection_repository.dart';
export 'repositories/imported_media_batch_persistence.dart';
export 'repositories/media_task_repository.dart';
export 'repositories/task_folder_repository.dart';
export 'repositories/workbench_order_revision_store.dart';

// services
export 'services/analysis/media_analysis_queue.dart';
export 'services/app_maintenance/app_cache_cleaner.dart';
export 'services/app_notifications/app_notification_manager.dart';
export 'services/app_notifications/task_completion_sound_player.dart';
export 'services/app_settings/app_settings_save_coordinator.dart';
export 'services/app_settings/app_settings_save_target.dart';
export 'services/app_update/app_update_client.dart';
export 'services/app_update/app_update_download_state_store.dart';
export 'services/app_update/app_update_install_id_store.dart';
export 'services/app_update/app_update_package_downloader.dart';
export 'services/app_update/app_update_snooze_store.dart';
export 'services/app_update/enterprise_update_config_store.dart';
export 'services/app_update/release_signature_verifier.dart';
export 'services/app_update/sparkle_update_controller.dart';
export 'services/app_update/updater_helper_launcher.dart';
export 'services/execution/execution_log_store.dart';
export 'services/execution/execution_queue_result.dart';
export 'services/execution/media_task_execution_coordinator.dart';
export 'services/execution/output_failure.dart';
export 'services/execution/preview_frame_generator.dart';
export 'services/engine/engine_gateway.dart';
export 'services/engine/engine_lifecycle_coordinator.dart';
export 'services/engine/task_folder_queue_projection.dart';
export 'services/engine/engine_execution_output_planner.dart';
export 'services/engine/engine_media_display_projection_mapper.dart';
export 'services/engine/engine_task_mode_mapper.dart';
export 'services/framelean_build_info.dart';
export 'services/input_runtime/media_folder_scanner.dart';
export 'services/input_runtime/media_input_preparer.dart';
export 'services/input_runtime/media_kind_resolver.dart';
export 'services/input_runtime/proprietary_audio_adapter_registry.dart';
export 'services/input_runtime/proprietary_audio_decoder.dart';
export 'services/input_runtime/proprietary_audio_format_resolver.dart';
export 'services/input_runtime/source_file_checker.dart';
export 'services/input_runtime/source_file_fingerprint_reader.dart';
export 'services/platform/external_link_opener.dart';
export 'services/platform/file_revealer.dart';
export 'services/platform/file_selection_service.dart';
export 'services/platform/theme_preferences_cache.dart';

// use_cases
export 'use_cases/app_maintenance/clear_app_cache_use_case.dart';
export 'use_cases/app_maintenance/preview_app_cache_cleanup_use_case.dart';
export 'use_cases/app_settings/apply_output_settings_to_existing_tasks_use_case.dart';
export 'use_cases/app_settings/load_app_settings_use_case.dart';
export 'use_cases/app_settings/save_app_settings_use_case.dart';
export 'use_cases/media_tasks/analyze_media_task_use_case.dart';
export 'use_cases/media_tasks/apply_engine_queue_order_use_case.dart';
export 'use_cases/media_tasks/clear_media_tasks_use_case.dart';
export 'use_cases/media_tasks/delete_media_task_use_case.dart';
export 'use_cases/media_tasks/generate_preview_frames_use_case.dart';
export 'use_cases/media_tasks/import_media_folder_use_case.dart';
export 'use_cases/media_tasks/import_media_task_use_case.dart';
export 'use_cases/media_tasks/import_media_tasks_use_case.dart';
export 'use_cases/media_tasks/load_engine_analysis_snapshot_use_case.dart';
export 'use_cases/media_tasks/organize_imported_media_batch_atomically_use_case.dart';
export 'use_cases/media_tasks/media_task_use_case_helpers.dart';
export 'use_cases/media_tasks/pause_all_media_task_executions_use_case.dart';
export 'use_cases/media_tasks/pause_media_task_execution_use_case.dart';
export 'use_cases/media_tasks/place_workbench_top_level_item_use_case.dart';
export 'use_cases/media_tasks/reconcile_media_tasks_use_case.dart';
export 'use_cases/media_tasks/reorder_workbench_items_use_case.dart';
export 'use_cases/media_tasks/replace_missing_source_use_case.dart';
export 'use_cases/media_tasks/save_engine_task_configuration_use_case.dart';
export 'use_cases/media_tasks/submit_engine_execution_use_case.dart';
export 'use_cases/media_tasks/submit_engine_analysis_batch_use_case.dart';
export 'use_cases/media_tasks/retry_media_task_use_case.dart';
export 'use_cases/media_tasks/start_execution_queue_use_case.dart';
export 'use_cases/media_tasks/start_or_resume_media_task_use_case.dart';
export 'use_cases/media_tasks/task_folder_use_cases.dart';
