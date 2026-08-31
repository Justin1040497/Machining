use std::sync::Arc;

use crate::runtime_api::{
    AnalysisDocument as LocalAnalysisDocument, AnalysisId as LocalAnalysisId,
    AnalysisSnapshotDocument as LocalAnalysisSnapshotDocument,
    AnalysisSnapshotRecordDocument as LocalAnalysisSnapshotRecordDocument,
    AnalyzeRequest as LocalAnalyzeRequest, ExecutionEvent as LocalExecutionEvent,
    ExecutionId as LocalExecutionId, ExecutionLaneSnapshot as LocalExecutionLaneSnapshot,
    ExecutionSubmissionRequest as LocalExecutionSubmissionRequest,
    ExecutionSubmissionResult as LocalExecutionSubmissionResult,
    PreviewFramesRequest as LocalPreviewFramesRequest,
    PreviewFramesResult as LocalPreviewFramesResult,
    RecalculateConfigurationDocument as LocalRecalculateConfigurationDocument,
    RecalculateConfigurationRequest as LocalRecalculateConfigurationRequest,
    ReorderExecutionsRequest as LocalReorderExecutionsRequest,
    VideoThumbnailRequest as LocalVideoThumbnailRequest,
    VideoThumbnailResult as LocalVideoThumbnailResult,
};
use framelean_core::{AnalysisId, Result, TaskId};
use framelean_environment::SystemEnvironment;
use framelean_ffmpeg::{
    FfmpegAdapter, PreviewFramesRequest, PreviewFramesResult, VideoThumbnailRequest,
    VideoThumbnailResult,
};
use framelean_runtime::{
    AnalysisServices, AnalysisSnapshotPolicy, AnalysisSnapshotRecord, AnalysisSnapshotView,
    AnalyzeMediaResponse, AnalyzeTaskRequest, DefaultCapabilityResolver,
    DefaultRecommendationEngine, DeterministicSizeEstimator, EngineRuntime, EstimatorPolicy,
    EvictionStrategy, ExecutionLaneSnapshot, ExecutionRuntimeEvent, ExecutionServices,
    ExecutionSubmissionRequest, ExecutionSubmissionResult, RecalculateConfigurationRequest,
    RecalculateConfigurationResponse,
};

pub trait RuntimeHost: Send {
    fn analyze_media(&mut self, request: AnalyzeTaskRequest) -> Result<AnalyzeMediaResponse>;

    fn analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<AnalysisSnapshotView>;

    fn generate_preview_frames(
        &mut self,
        request: &PreviewFramesRequest,
    ) -> Result<PreviewFramesResult>;

    fn generate_video_thumbnail(
        &mut self,
        request: &VideoThumbnailRequest,
    ) -> Result<VideoThumbnailResult>;

    fn analysis_snapshot_record(
        &mut self,
        analysis_id: &AnalysisId,
    ) -> Result<AnalysisSnapshotRecord>;

    fn discard_analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<bool>;

    fn restore_analysis_snapshot(&mut self, record: AnalysisSnapshotRecord) -> Result<()>;

    fn recalculate_configuration(
        &mut self,
        request: RecalculateConfigurationRequest,
    ) -> Result<RecalculateConfigurationResponse>;

    fn submit_execution(
        &mut self,
        request: ExecutionSubmissionRequest,
    ) -> Result<ExecutionSubmissionResult>;

    fn drain_execution_events(&mut self) -> Vec<ExecutionRuntimeEvent>;

    fn execution_snapshot(&self) -> Result<ExecutionLaneSnapshot>;

    fn reorder_waiting_executions(
        &mut self,
        expected_revision: u64,
        ordered_execution_ids: &[TaskId],
    ) -> Result<u64>;

    fn preempt_and_start_execution(&mut self, execution_id: &TaskId) -> Result<()>;

    fn pause_execution(&mut self, execution_id: &TaskId) -> Result<()>;

    fn resume_execution(&mut self, execution_id: &TaskId) -> Result<()>;

    fn cancel_execution(&mut self, execution_id: &TaskId) -> Result<()>;
}

pub(crate) trait RuntimeApiHost: Send {
    fn analyze_media(&mut self, request: LocalAnalyzeRequest) -> Result<LocalAnalysisDocument>;

    fn analysis_snapshot(
        &mut self,
        analysis_id: &LocalAnalysisId,
    ) -> Result<LocalAnalysisSnapshotDocument>;

    fn generate_preview_frames(
        &mut self,
        request: &LocalPreviewFramesRequest,
    ) -> Result<LocalPreviewFramesResult>;

    fn generate_video_thumbnail(
        &mut self,
        request: &LocalVideoThumbnailRequest,
    ) -> Result<LocalVideoThumbnailResult>;

    fn analysis_snapshot_record(
        &mut self,
        analysis_id: &LocalAnalysisId,
    ) -> Result<LocalAnalysisSnapshotRecordDocument>;

    fn discard_analysis_snapshot(&mut self, analysis_id: &LocalAnalysisId) -> Result<bool>;

    fn restore_analysis_snapshot(
        &mut self,
        record: LocalAnalysisSnapshotRecordDocument,
    ) -> Result<()>;

    fn recalculate_configuration(
        &mut self,
        request: LocalRecalculateConfigurationRequest,
    ) -> Result<LocalRecalculateConfigurationDocument>;

    fn submit_execution(
        &mut self,
        request: LocalExecutionSubmissionRequest,
    ) -> Result<LocalExecutionSubmissionResult>;

    fn drain_execution_events(&mut self) -> Result<Vec<LocalExecutionEvent>>;

    fn execution_snapshot(&self) -> Result<LocalExecutionLaneSnapshot>;

    fn reorder_waiting_executions(&mut self, request: LocalReorderExecutionsRequest)
    -> Result<u64>;

    fn preempt_and_start_execution(&mut self, execution_id: &LocalExecutionId) -> Result<()>;

    fn pause_execution(&mut self, execution_id: &LocalExecutionId) -> Result<()>;

    fn resume_execution(&mut self, execution_id: &LocalExecutionId) -> Result<()>;

    fn cancel_execution(&mut self, execution_id: &LocalExecutionId) -> Result<()>;
}

impl RuntimeHost for EngineRuntime {
    fn analyze_media(&mut self, request: AnalyzeTaskRequest) -> Result<AnalyzeMediaResponse> {
        EngineRuntime::analyze_media(self, request)
    }

    fn analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<AnalysisSnapshotView> {
        EngineRuntime::analysis_snapshot(self, analysis_id)
    }

    fn generate_preview_frames(
        &mut self,
        request: &PreviewFramesRequest,
    ) -> Result<PreviewFramesResult> {
        FfmpegAdapter::new()?.generate_preview_frames(request)
    }

    fn generate_video_thumbnail(
        &mut self,
        request: &VideoThumbnailRequest,
    ) -> Result<VideoThumbnailResult> {
        FfmpegAdapter::new()?.generate_video_thumbnail(request)
    }

    fn analysis_snapshot_record(
        &mut self,
        analysis_id: &AnalysisId,
    ) -> Result<AnalysisSnapshotRecord> {
        EngineRuntime::analysis_snapshot_record(self, analysis_id)
    }

    fn discard_analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<bool> {
        EngineRuntime::discard_analysis_snapshot(self, analysis_id)
    }

    fn restore_analysis_snapshot(&mut self, record: AnalysisSnapshotRecord) -> Result<()> {
        EngineRuntime::restore_analysis_snapshot(self, record)
    }

    fn recalculate_configuration(
        &mut self,
        request: RecalculateConfigurationRequest,
    ) -> Result<RecalculateConfigurationResponse> {
        EngineRuntime::recalculate_configuration(self, request)
    }

    fn submit_execution(
        &mut self,
        request: ExecutionSubmissionRequest,
    ) -> Result<ExecutionSubmissionResult> {
        EngineRuntime::submit_execution(self, request)
    }

    fn drain_execution_events(&mut self) -> Vec<ExecutionRuntimeEvent> {
        EngineRuntime::drain_execution_events(self)
    }

    fn execution_snapshot(&self) -> Result<ExecutionLaneSnapshot> {
        EngineRuntime::execution_snapshot(self)
    }

    fn reorder_waiting_executions(
        &mut self,
        expected_revision: u64,
        ordered_execution_ids: &[TaskId],
    ) -> Result<u64> {
        EngineRuntime::reorder_waiting_executions(self, expected_revision, ordered_execution_ids)
    }

    fn preempt_and_start_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        EngineRuntime::preempt_and_start_execution(self, execution_id)
    }

    fn pause_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        EngineRuntime::pause_execution(self, execution_id)
    }

    fn resume_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        EngineRuntime::resume_execution(self, execution_id)
    }

    fn cancel_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        EngineRuntime::cancel_execution(self, execution_id)
    }
}

pub fn build_default_runtime() -> Result<EngineRuntime> {
    let adapter = Arc::new(FfmpegAdapter::new()?);
    let execution_services = ExecutionServices::ffmpeg(adapter.clone());
    build_runtime(adapter, execution_services)
}

fn build_runtime(
    adapter: Arc<FfmpegAdapter>,
    execution_services: ExecutionServices,
) -> Result<EngineRuntime> {
    let system = Arc::new(SystemEnvironment::new());
    let services = AnalysisServices {
        analyzer: adapter.clone(),
        environment: system.clone(),
        resource_monitor: system,
        native_backend_providers: vec![adapter.clone()],
        capability_resolver: Arc::new(DefaultCapabilityResolver),
        recommendation_engine: Arc::new(DefaultRecommendationEngine),
        size_estimator: Arc::new(DeterministicSizeEstimator),
        estimator_policy: EstimatorPolicy::baseline(),
    };
    let policy = AnalysisSnapshotPolicy::new(None, None, EvictionStrategy::LeastRecentlyUsed)?;
    Ok(EngineRuntime::with_analysis_and_execution_services(
        services,
        policy,
        execution_services,
    ))
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::thread;
    use std::time::{Duration, Instant};

    use framelean_analysis::{MediaAnalyzeRequest, MediaSource};
    use framelean_runtime::{
        AnalyzeTaskRequest, AudioStreamSelection, ExecutionOutputRequest,
        ExecutionSubmissionRequest, ExecutionTaskState, FfmpegExecutionBackend,
        ManualConfigurationSelection, ManualSelection, OutputCollisionPolicy, PresetSelection,
        RecalculateSelection, RequestContext, TaskMode,
    };

    use super::*;

    #[test]
    fn default_runtime_analyzes_and_executes_a_real_stream_copy_task() {
        static TEST_SEQUENCE: AtomicU64 = AtomicU64::new(1);
        let sequence = TEST_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let root = std::env::temp_dir().join(format!(
            "framelean-runtime-execution-test-{}-{sequence}",
            std::process::id()
        ));
        fs::create_dir_all(&root).unwrap();
        let input_path = root.join("input.wav");
        let output_path = root.join("output.wav");
        fs::write(&input_path, pcm_wav_fixture(800)).unwrap();
        let mut runtime = build_default_runtime().unwrap();

        let analysis = runtime
            .analyze_media(AnalyzeTaskRequest {
                task_mode: TaskMode::AudioConvert,
                media_request: MediaAnalyzeRequest {
                    source: MediaSource::local_file(&input_path).unwrap(),
                    request_id: Some("analysis-request".to_owned()),
                    expected_source: None,
                },
                context: RequestContext::default(),
            })
            .unwrap();
        assert!(analysis.error.is_none(), "{:?}", analysis.error);
        let candidate = analysis
            .capabilities
            .as_ref()
            .and_then(|capabilities| capabilities.execution_chains.first())
            .unwrap_or_else(|| {
                panic!(
                    "real remux backend must expose an audio conversion chain; requirements: {:#?}; exclusions: {:#?}",
                    analysis.requirements,
                    analysis.capabilities.as_ref().map(|value| &value.exclusions)
                )
            });

        let submission = runtime
            .submit_execution(ExecutionSubmissionRequest {
                analysis_id: analysis.analysis_id,
                expected_revision: analysis.analysis_revision,
                selection: RecalculateSelection::Manual(ManualConfigurationSelection {
                    candidate_id: candidate.id.clone(),
                    overrides: ManualSelection::empty(),
                }),
                output: ExecutionOutputRequest {
                    requested_path: output_path.clone(),
                    collision_policy: OutputCollisionPolicy::FailIfExists,
                },
                context: RequestContext::default(),
            })
            .unwrap();
        assert_eq!(submission.state, ExecutionTaskState::Running);

        let deadline = Instant::now() + Duration::from_secs(5);
        let mut terminal = None;
        while Instant::now() < deadline {
            for event in runtime.drain_execution_events() {
                if event.execution_id == submission.execution_id
                    && matches!(
                        event.state,
                        ExecutionTaskState::Completed
                            | ExecutionTaskState::Failed
                            | ExecutionTaskState::Cancelled
                    )
                {
                    terminal = Some(event);
                }
            }
            if terminal.is_some() {
                break;
            }
            thread::sleep(Duration::from_millis(10));
        }
        let terminal = terminal.expect("execution must reach a terminal state");
        assert_eq!(terminal.state, ExecutionTaskState::Completed);
        assert!(terminal.error_code.is_none(), "{:?}", terminal.message);
        assert_eq!(terminal.output_path.as_deref(), Some(output_path.as_path()));
        assert!(fs::metadata(&output_path).unwrap().len() > 44);

        let output_analysis = runtime
            .analyze_media(AnalyzeTaskRequest {
                task_mode: TaskMode::AudioConvert,
                media_request: MediaAnalyzeRequest {
                    source: MediaSource::local_file(&output_path).unwrap(),
                    request_id: Some("output-analysis-request".to_owned()),
                    expected_source: None,
                },
                context: RequestContext::default(),
            })
            .unwrap();
        assert!(
            output_analysis.error.is_none(),
            "{:?}",
            output_analysis.error
        );
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn default_runtime_executes_a_real_audio_video_transcode_chain() {
        static TEST_SEQUENCE: AtomicU64 = AtomicU64::new(1);
        let sequence = TEST_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let root = std::env::temp_dir().join(format!(
            "framelean-runtime-video-transcode-test-{}-{sequence}",
            std::process::id()
        ));
        fs::create_dir_all(&root).unwrap();
        let input_path = root.join("input.avi");
        let output_path = root.join("output.mp4");
        fs::write(&input_path, raw_audiovisual_avi_fixture()).unwrap();
        let mut runtime = build_default_runtime().unwrap();

        let analysis = runtime
            .analyze_media(AnalyzeTaskRequest {
                task_mode: TaskMode::VideoCompress,
                media_request: MediaAnalyzeRequest {
                    source: MediaSource::local_file(&input_path).unwrap(),
                    request_id: Some("video-analysis-request".to_owned()),
                    expected_source: None,
                },
                context: RequestContext::default(),
            })
            .unwrap();
        assert!(analysis.error.is_none(), "{:?}", analysis.error);
        let candidate = analysis
            .capabilities
            .as_ref()
            .and_then(|capabilities| {
                capabilities
                    .execution_chains
                    .iter()
                    .find(|candidate| {
                        candidate.video_encoder.is_some() && candidate.audio_encoder.is_some()
                    })
            })
            .unwrap_or_else(|| {
                panic!(
                    "real video transcode chain must be available; requirements: {:#?}; exclusions: {:#?}",
                    analysis.requirements,
                    analysis.capabilities.as_ref().map(|value| &value.exclusions)
                )
            });
        assert!(
            candidate
                .processors
                .iter()
                .any(|processor| processor.operation == "pixel_format_conversion")
        );
        assert!(
            candidate
                .processors
                .iter()
                .any(|processor| processor.operation == "sample_format_conversion")
        );
        assert_eq!(candidate.audio_decoders.len(), 2);

        let submission = runtime
            .submit_execution(ExecutionSubmissionRequest {
                analysis_id: analysis.analysis_id,
                expected_revision: analysis.analysis_revision,
                selection: RecalculateSelection::Manual(ManualConfigurationSelection {
                    candidate_id: candidate.id.clone(),
                    overrides: ManualSelection {
                        audio_streams: Some(vec![
                            AudioStreamSelection {
                                stream_index: candidate.audio_decoders[0].stream_index,
                                bitrate_bps: Some(64_000),
                                sample_rate_hz: Some(32_000),
                                channel_count: Some(1),
                            },
                            AudioStreamSelection {
                                stream_index: candidate.audio_decoders[1].stream_index,
                                bitrate_bps: Some(96_000),
                                sample_rate_hz: Some(48_000),
                                channel_count: Some(2),
                            },
                        ]),
                        ..ManualSelection::empty()
                    },
                }),
                output: ExecutionOutputRequest {
                    requested_path: output_path.clone(),
                    collision_policy: OutputCollisionPolicy::FailIfExists,
                },
                context: RequestContext::default(),
            })
            .unwrap();

        let deadline = Instant::now() + Duration::from_secs(5);
        let mut terminal = None;
        while Instant::now() < deadline {
            for event in runtime.drain_execution_events() {
                if event.execution_id == submission.execution_id
                    && matches!(
                        event.state,
                        ExecutionTaskState::Completed
                            | ExecutionTaskState::Failed
                            | ExecutionTaskState::Cancelled
                    )
                {
                    terminal = Some(event);
                }
            }
            if terminal.is_some() {
                break;
            }
            thread::sleep(Duration::from_millis(10));
        }
        let terminal = terminal.expect("video execution must reach a terminal state");
        assert_eq!(terminal.state, ExecutionTaskState::Completed);
        assert!(terminal.error_code.is_none(), "{:?}", terminal.message);
        assert_eq!(terminal.output_path.as_deref(), Some(output_path.as_path()));
        assert!(fs::metadata(&output_path).unwrap().len() > 64);

        let output_analysis = runtime
            .analyze_media(AnalyzeTaskRequest {
                task_mode: TaskMode::VideoCompress,
                media_request: MediaAnalyzeRequest {
                    source: MediaSource::local_file(&output_path).unwrap(),
                    request_id: Some("video-output-analysis-request".to_owned()),
                    expected_source: None,
                },
                context: RequestContext::default(),
            })
            .unwrap();
        assert!(
            output_analysis.error.is_none(),
            "transcoded output must be readable: {:?}",
            output_analysis.error
        );
        let output_requirements = output_analysis.requirements.as_ref().unwrap();
        assert_eq!(output_requirements.video_streams.len(), 1);
        assert_eq!(output_requirements.audio_streams.len(), 2);
        assert_eq!(output_requirements.video_streams[0].codec, "h264");
        assert_eq!(output_requirements.audio_streams[0].codec, "aac");
        assert_eq!(
            output_requirements.audio_streams[0].sample_rate_hz,
            Some(32_000)
        );
        assert_eq!(output_requirements.audio_streams[0].channel_count, Some(1));
        assert_eq!(output_requirements.audio_streams[1].codec, "aac");
        assert_eq!(
            output_requirements.audio_streams[1].sample_rate_hz,
            Some(48_000)
        );
        assert_eq!(output_requirements.audio_streams[1].channel_count, Some(2));
        assert!(
            output_analysis
                .capabilities
                .as_ref()
                .is_some_and(|capabilities| capabilities
                    .execution_chains
                    .iter()
                    .any(|candidate| candidate.video_encoder.is_some()
                        && candidate.audio_encoder.is_some())),
            "transcoded H.264/AAC MP4 must remain eligible for compression"
        );
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn default_runtime_executes_a_real_audio_compression_chain() {
        static TEST_SEQUENCE: AtomicU64 = AtomicU64::new(1);
        let sequence = TEST_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let root = std::env::temp_dir().join(format!(
            "framelean-runtime-audio-transcode-test-{}-{sequence}",
            std::process::id()
        ));
        fs::create_dir_all(&root).unwrap();
        let input_path = root.join("input.wav");
        let output_path = root.join("output.m4a");
        fs::write(&input_path, pcm_wav_fixture(4_000)).unwrap();
        let mut runtime = build_default_runtime().unwrap();

        let analysis = runtime
            .analyze_media(AnalyzeTaskRequest {
                task_mode: TaskMode::AudioCompress,
                media_request: MediaAnalyzeRequest {
                    source: MediaSource::local_file(&input_path).unwrap(),
                    request_id: Some("audio-compression-analysis".to_owned()),
                    expected_source: None,
                },
                context: RequestContext::default(),
            })
            .unwrap();
        assert!(analysis.error.is_none(), "{:?}", analysis.error);
        let preset = analysis
            .presets
            .iter()
            .find(|preset| preset.id.as_str() == "balanced" && preset.applicable)
            .unwrap_or_else(|| {
                panic!(
                    "balanced audio preset must be available; requirements: {:#?}; capabilities: {:#?}",
                    analysis.requirements, analysis.capabilities
                )
            });
        let preset_id = preset.id.clone();
        let candidate = preset.candidate.as_ref().unwrap().clone();
        assert_eq!(candidate.output_container, "m4a");
        assert!(candidate.video_encoder.is_none());
        assert!(candidate.audio_encoder.is_some());
        assert_eq!(candidate.output_audio_codec.as_deref(), Some("aac"));
        assert!(candidate.audio_bitrate_options_bps.contains(&192_000));
        assert!(candidate.audio_sample_rate_options_hz.contains(&32_000));
        assert!(candidate.audio_channel_count_options.contains(&2));

        let rejected_output_path = root.join("rejected.m4a");
        let rejected = runtime
            .submit_execution(ExecutionSubmissionRequest {
                analysis_id: analysis.analysis_id.clone(),
                expected_revision: analysis.analysis_revision,
                selection: RecalculateSelection::Preset(PresetSelection {
                    preset_id: preset_id.clone(),
                    candidate_id: candidate.id.clone(),
                    overrides: ManualSelection {
                        container: None,
                        video_codec: None,
                        audio_codec: None,
                        audio_streams: Some(vec![AudioStreamSelection {
                            stream_index: candidate.audio_decoders[0].stream_index,
                            bitrate_bps: Some(192_000),
                            sample_rate_hz: Some(12_345),
                            channel_count: Some(2),
                        }]),
                        output_pixel_format: None,
                        preserves_hdr: None,
                    },
                }),
                output: ExecutionOutputRequest {
                    requested_path: rejected_output_path.clone(),
                    collision_policy: OutputCollisionPolicy::FailIfExists,
                },
                context: RequestContext::default(),
            })
            .unwrap_err();
        assert_eq!(
            rejected.code(),
            framelean_core::EngineErrorCode::MediaCapabilityIncompatible
        );
        assert!(!rejected_output_path.exists());

        let submission = runtime
            .submit_execution(ExecutionSubmissionRequest {
                analysis_id: analysis.analysis_id,
                expected_revision: analysis.analysis_revision,
                selection: RecalculateSelection::Preset(PresetSelection {
                    preset_id,
                    candidate_id: candidate.id.clone(),
                    overrides: ManualSelection {
                        container: None,
                        video_codec: None,
                        audio_codec: None,
                        audio_streams: Some(vec![AudioStreamSelection {
                            stream_index: candidate.audio_decoders[0].stream_index,
                            bitrate_bps: Some(192_000),
                            sample_rate_hz: Some(32_000),
                            channel_count: Some(2),
                        }]),
                        output_pixel_format: None,
                        preserves_hdr: None,
                    },
                }),
                output: ExecutionOutputRequest {
                    requested_path: output_path.clone(),
                    collision_policy: OutputCollisionPolicy::FailIfExists,
                },
                context: RequestContext::default(),
            })
            .unwrap();

        let deadline = Instant::now() + Duration::from_secs(5);
        let mut terminal = None;
        while Instant::now() < deadline {
            for event in runtime.drain_execution_events() {
                if event.execution_id == submission.execution_id
                    && matches!(
                        event.state,
                        ExecutionTaskState::Completed
                            | ExecutionTaskState::Failed
                            | ExecutionTaskState::Cancelled
                    )
                {
                    terminal = Some(event);
                }
            }
            if terminal.is_some() {
                break;
            }
            thread::sleep(Duration::from_millis(10));
        }
        let terminal = terminal.expect("audio execution must reach a terminal state");
        assert_eq!(terminal.state, ExecutionTaskState::Completed);
        assert!(terminal.error_code.is_none(), "{:?}", terminal.message);
        assert_eq!(terminal.output_path.as_deref(), Some(output_path.as_path()));
        assert!(fs::metadata(&output_path).unwrap().len() > 64);

        let output_analysis = runtime
            .analyze_media(AnalyzeTaskRequest {
                task_mode: TaskMode::AudioCompress,
                media_request: MediaAnalyzeRequest {
                    source: MediaSource::local_file(&output_path).unwrap(),
                    request_id: Some("audio-compression-output-analysis".to_owned()),
                    expected_source: None,
                },
                context: RequestContext::default(),
            })
            .unwrap();
        assert!(
            output_analysis.error.is_none(),
            "compressed output must be readable: {:?}",
            output_analysis.error
        );
        let requirements = output_analysis.requirements.as_ref().unwrap();
        assert!(requirements.video_streams.is_empty());
        assert_eq!(requirements.audio_streams.len(), 1);
        assert_eq!(requirements.audio_streams[0].codec, "aac");
        assert_eq!(requirements.audio_streams[0].sample_rate_hz, Some(32_000));
        assert_eq!(requirements.audio_streams[0].channel_count, Some(2));
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn real_auxiliary_remux_executions_resume_in_per_pool_lifo_order() {
        static TEST_SEQUENCE: AtomicU64 = AtomicU64::new(1);
        let sequence = TEST_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let root = std::env::temp_dir().join(format!(
            "framelean-runtime-lifo-test-{}-{sequence}",
            std::process::id()
        ));
        fs::create_dir_all(&root).unwrap();
        let input_path = root.join("input.wav");
        fs::write(&input_path, pcm_wav_fixture(400_000)).unwrap();

        let adapter = Arc::new(FfmpegAdapter::new().unwrap());
        let backend = Arc::new(FfmpegExecutionBackend::with_progress_delay(
            adapter.clone(),
            Duration::from_millis(2),
        ));
        let mut runtime = build_runtime(adapter, ExecutionServices { backend }).unwrap();
        let analysis = runtime
            .analyze_media(AnalyzeTaskRequest {
                task_mode: TaskMode::AudioConvert,
                media_request: MediaAnalyzeRequest {
                    source: MediaSource::local_file(&input_path).unwrap(),
                    request_id: Some("lifo-analysis-request".to_owned()),
                    expected_source: None,
                },
                context: RequestContext::default(),
            })
            .unwrap();
        assert!(analysis.error.is_none(), "{:?}", analysis.error);
        let candidate_id = analysis
            .capabilities
            .as_ref()
            .and_then(|capabilities| capabilities.execution_chains.first())
            .map(|candidate| candidate.id.clone())
            .unwrap_or_else(|| {
                panic!(
                    "real remux backend must expose an audio conversion chain; requirements: {:#?}; exclusions: {:#?}",
                    analysis.requirements,
                    analysis.capabilities.as_ref().map(|value| &value.exclusions)
                )
            });

        let output_paths = [
            root.join("a1.wav"),
            root.join("a2.wav"),
            root.join("a3.wav"),
            root.join("a4.wav"),
        ];
        let mut submissions = Vec::new();
        for output_path in &output_paths {
            submissions.push(
                runtime
                    .submit_execution(ExecutionSubmissionRequest {
                        analysis_id: analysis.analysis_id.clone(),
                        expected_revision: analysis.analysis_revision,
                        selection: RecalculateSelection::Manual(ManualConfigurationSelection {
                            candidate_id: candidate_id.clone(),
                            overrides: ManualSelection::empty(),
                        }),
                        output: ExecutionOutputRequest {
                            requested_path: output_path.clone(),
                            collision_policy: OutputCollisionPolicy::FailIfExists,
                        },
                        context: RequestContext::default(),
                    })
                    .unwrap(),
            );
        }
        let a1 = submissions[0].execution_id.clone();
        let a2 = submissions[1].execution_id.clone();
        let a3 = submissions[2].execution_id.clone();
        let a4 = submissions[3].execution_id.clone();

        runtime.preempt_and_start_execution(&a3).unwrap();
        runtime.preempt_and_start_execution(&a4).unwrap();

        let nested_snapshot = runtime.execution_snapshot().unwrap();
        assert!(
            nested_snapshot
                .active_executions
                .iter()
                .any(|entry| entry.execution_id == a1)
        );
        assert!(
            nested_snapshot
                .active_executions
                .iter()
                .any(|entry| entry.execution_id == a4)
        );
        assert!(nested_snapshot.normal_waiting.is_empty());
        assert_eq!(
            nested_snapshot
                .auxiliary_resume_stack
                .iter()
                .map(|entry| entry.execution_id.clone())
                .collect::<Vec<_>>(),
            [a2.clone(), a3.clone()]
        );
        assert!(
            nested_snapshot
                .auxiliary_resume_stack
                .iter()
                .all(|entry| entry.checkpoint.is_some())
        );

        let deadline = Instant::now() + Duration::from_secs(15);
        let mut terminal_order = Vec::new();
        let mut resume_order = Vec::new();
        while Instant::now() < deadline && terminal_order.len() < submissions.len() {
            for event in runtime.drain_execution_events() {
                if event.state == ExecutionTaskState::Resuming {
                    resume_order.push(event.execution_id.clone());
                }
                if matches!(
                    event.state,
                    ExecutionTaskState::Completed
                        | ExecutionTaskState::Failed
                        | ExecutionTaskState::Cancelled
                ) {
                    assert_eq!(
                        event.state,
                        ExecutionTaskState::Completed,
                        "execution {} failed: {:?} {:?}",
                        event.execution_id,
                        event.error_code,
                        event.message
                    );
                    terminal_order.push(event.execution_id);
                }
            }
            thread::sleep(Duration::from_millis(5));
        }
        assert_eq!(resume_order, [a3, a2]);
        assert_eq!(terminal_order.len(), submissions.len());
        let final_snapshot = runtime.execution_snapshot().unwrap();
        assert!(final_snapshot.active_executions.is_empty());
        assert!(final_snapshot.normal_waiting.is_empty());
        assert!(final_snapshot.video_resume_stack.is_empty());
        assert!(final_snapshot.auxiliary_resume_stack.is_empty());

        for (index, output_path) in output_paths.iter().enumerate() {
            assert!(fs::metadata(output_path).unwrap().len() > 44);
            let output_analysis = runtime
                .analyze_media(AnalyzeTaskRequest {
                    task_mode: TaskMode::AudioConvert,
                    media_request: MediaAnalyzeRequest {
                        source: MediaSource::local_file(output_path).unwrap(),
                        request_id: Some(format!("lifo-output-analysis-{index}")),
                        expected_source: None,
                    },
                    context: RequestContext::default(),
                })
                .unwrap();
            assert!(
                output_analysis.error.is_none(),
                "output {} is not readable: {:?}",
                output_path.display(),
                output_analysis.error
            );
        }
        fs::remove_dir_all(root).unwrap();
    }

    fn pcm_wav_fixture(sample_count: u32) -> Vec<u8> {
        const SAMPLE_RATE: u32 = 8_000;
        const CHANNELS: u16 = 1;
        const BITS_PER_SAMPLE: u16 = 16;
        let data_size = sample_count * u32::from(CHANNELS) * u32::from(BITS_PER_SAMPLE / 8);
        let mut bytes = Vec::with_capacity((44 + data_size) as usize);
        bytes.extend_from_slice(b"RIFF");
        bytes.extend_from_slice(&(36 + data_size).to_le_bytes());
        bytes.extend_from_slice(b"WAVEfmt ");
        bytes.extend_from_slice(&16_u32.to_le_bytes());
        bytes.extend_from_slice(&1_u16.to_le_bytes());
        bytes.extend_from_slice(&CHANNELS.to_le_bytes());
        bytes.extend_from_slice(&SAMPLE_RATE.to_le_bytes());
        let byte_rate = SAMPLE_RATE * u32::from(CHANNELS) * u32::from(BITS_PER_SAMPLE / 8);
        bytes.extend_from_slice(&byte_rate.to_le_bytes());
        bytes.extend_from_slice(&(CHANNELS * (BITS_PER_SAMPLE / 8)).to_le_bytes());
        bytes.extend_from_slice(&BITS_PER_SAMPLE.to_le_bytes());
        bytes.extend_from_slice(b"data");
        bytes.extend_from_slice(&data_size.to_le_bytes());
        for index in 0..sample_count {
            let sample = if index % 16 < 8 {
                4_000_i16
            } else {
                -4_000_i16
            };
            bytes.extend_from_slice(&sample.to_le_bytes());
        }
        bytes
    }

    fn raw_audiovisual_avi_fixture() -> Vec<u8> {
        const WIDTH: u32 = 2;
        const HEIGHT: u32 = 2;
        const FRAME_BYTES: u32 = 16;
        const SAMPLE_RATE: u32 = 8_000;
        const SAMPLE_COUNT: u32 = 4_000;
        const AUDIO_BYTES: u32 = SAMPLE_COUNT * 2;

        let mut main_header = Vec::with_capacity(56);
        push_u32(&mut main_header, 500_000);
        push_u32(&mut main_header, SAMPLE_RATE * 2 + FRAME_BYTES * 2);
        push_u32(&mut main_header, 0);
        push_u32(&mut main_header, 0x10);
        push_u32(&mut main_header, 1);
        push_u32(&mut main_header, 0);
        push_u32(&mut main_header, 3);
        push_u32(&mut main_header, AUDIO_BYTES);
        push_u32(&mut main_header, WIDTH);
        push_u32(&mut main_header, HEIGHT);
        main_header.extend_from_slice(&[0; 16]);

        let mut video_header = Vec::with_capacity(56);
        video_header.extend_from_slice(b"vids");
        video_header.extend_from_slice(b"DIB ");
        push_u32(&mut video_header, 0);
        push_u16(&mut video_header, 0);
        push_u16(&mut video_header, 0);
        push_u32(&mut video_header, 0);
        push_u32(&mut video_header, 1);
        push_u32(&mut video_header, 2);
        push_u32(&mut video_header, 0);
        push_u32(&mut video_header, 1);
        push_u32(&mut video_header, FRAME_BYTES);
        push_u32(&mut video_header, u32::MAX);
        push_u32(&mut video_header, 0);
        push_i16(&mut video_header, 0);
        push_i16(&mut video_header, 0);
        push_i16(&mut video_header, WIDTH as i16);
        push_i16(&mut video_header, HEIGHT as i16);

        let mut bitmap_info = Vec::with_capacity(40);
        push_u32(&mut bitmap_info, 40);
        push_i32(&mut bitmap_info, WIDTH as i32);
        push_i32(&mut bitmap_info, HEIGHT as i32);
        push_u16(&mut bitmap_info, 1);
        push_u16(&mut bitmap_info, 24);
        push_u32(&mut bitmap_info, 0);
        push_u32(&mut bitmap_info, FRAME_BYTES);
        push_i32(&mut bitmap_info, 0);
        push_i32(&mut bitmap_info, 0);
        push_u32(&mut bitmap_info, 0);
        push_u32(&mut bitmap_info, 0);

        let mut audio_header = Vec::with_capacity(56);
        audio_header.extend_from_slice(b"auds");
        audio_header.extend_from_slice(&[0; 4]);
        push_u32(&mut audio_header, 0);
        push_u16(&mut audio_header, 0);
        push_u16(&mut audio_header, 0);
        push_u32(&mut audio_header, 0);
        push_u32(&mut audio_header, 2);
        push_u32(&mut audio_header, SAMPLE_RATE * 2);
        push_u32(&mut audio_header, 0);
        push_u32(&mut audio_header, SAMPLE_COUNT);
        push_u32(&mut audio_header, AUDIO_BYTES);
        push_u32(&mut audio_header, u32::MAX);
        push_u32(&mut audio_header, 2);
        audio_header.extend_from_slice(&[0; 8]);

        let mut wave_format = Vec::with_capacity(16);
        push_u16(&mut wave_format, 1);
        push_u16(&mut wave_format, 1);
        push_u32(&mut wave_format, SAMPLE_RATE);
        push_u32(&mut wave_format, SAMPLE_RATE * 2);
        push_u16(&mut wave_format, 2);
        push_u16(&mut wave_format, 16);

        let video_stream = list_chunk(
            b"strl",
            [
                riff_chunk(b"strh", video_header),
                riff_chunk(b"strf", bitmap_info),
            ]
            .concat(),
        );
        let audio_stream = list_chunk(
            b"strl",
            [
                riff_chunk(b"strh", audio_header),
                riff_chunk(b"strf", wave_format),
            ]
            .concat(),
        );
        let header_list = list_chunk(
            b"hdrl",
            [
                riff_chunk(b"avih", main_header),
                video_stream,
                audio_stream.clone(),
                audio_stream,
            ]
            .concat(),
        );
        let frame = vec![0, 255, 0, 0, 255, 0, 0, 0, 0, 0, 255, 0, 0, 255, 0, 0];
        let mut audio = Vec::with_capacity(AUDIO_BYTES as usize);
        for index in 0..SAMPLE_COUNT {
            let sample = if index % 32 < 16 {
                4_000_i16
            } else {
                -4_000_i16
            };
            audio.extend_from_slice(&sample.to_le_bytes());
        }
        let mut second_audio = Vec::with_capacity(AUDIO_BYTES as usize);
        for index in 0..SAMPLE_COUNT {
            let sample = if index % 20 < 10 {
                2_000_i16
            } else {
                -2_000_i16
            };
            second_audio.extend_from_slice(&sample.to_le_bytes());
        }
        let video_chunk = riff_chunk(b"00db", frame);
        let audio_chunk = riff_chunk(b"01wb", audio);
        let second_audio_chunk = riff_chunk(b"02wb", second_audio);
        let movie_data = [video_chunk, audio_chunk, second_audio_chunk].concat();
        let mut index_data = Vec::new();
        index_data.extend_from_slice(b"00db");
        push_u32(&mut index_data, 0x10);
        push_u32(&mut index_data, 4);
        push_u32(&mut index_data, FRAME_BYTES);
        index_data.extend_from_slice(b"01wb");
        push_u32(&mut index_data, 0);
        push_u32(&mut index_data, 4 + 8 + FRAME_BYTES);
        push_u32(&mut index_data, AUDIO_BYTES);
        index_data.extend_from_slice(b"02wb");
        push_u32(&mut index_data, 0);
        push_u32(&mut index_data, 4 + 8 + FRAME_BYTES + 8 + AUDIO_BYTES);
        push_u32(&mut index_data, AUDIO_BYTES);
        riff_file(
            b"AVI ",
            [
                header_list,
                list_chunk(b"movi", movie_data),
                riff_chunk(b"idx1", index_data),
            ]
            .concat(),
        )
    }

    fn riff_file(kind: &[u8; 4], contents: Vec<u8>) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(12 + contents.len());
        bytes.extend_from_slice(b"RIFF");
        push_u32(&mut bytes, (4 + contents.len()) as u32);
        bytes.extend_from_slice(kind);
        bytes.extend_from_slice(&contents);
        bytes
    }

    fn list_chunk(kind: &[u8; 4], contents: Vec<u8>) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(4 + contents.len());
        bytes.extend_from_slice(kind);
        bytes.extend_from_slice(&contents);
        riff_chunk(b"LIST", bytes)
    }

    fn riff_chunk(tag: &[u8; 4], mut data: Vec<u8>) -> Vec<u8> {
        let data_len = data.len();
        let mut bytes = Vec::with_capacity(8 + data_len + (data_len & 1));
        bytes.extend_from_slice(tag);
        push_u32(&mut bytes, data_len as u32);
        bytes.append(&mut data);
        if data_len & 1 != 0 {
            bytes.push(0);
        }
        bytes
    }

    fn push_u16(bytes: &mut Vec<u8>, value: u16) {
        bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn push_i16(bytes: &mut Vec<u8>, value: i16) {
        bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn push_u32(bytes: &mut Vec<u8>, value: u32) {
        bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn push_i32(bytes: &mut Vec<u8>, value: i32) {
        bytes.extend_from_slice(&value.to_le_bytes());
    }
}
