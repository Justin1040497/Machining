use std::sync::Arc;

use framelean_core::{AnalysisId, Result, TaskId};
use framelean_environment::SystemEnvironment;
use framelean_ffmpeg::FfmpegAdapter;
use framelean_runtime::{
    AnalysisServices, AnalysisSnapshotPolicy, AnalysisSnapshotRecord, AnalysisSnapshotView,
    AnalyzeMediaResponse, AnalyzeTaskRequest, DefaultCapabilityResolver,
    DefaultRecommendationEngine, DeterministicSizeEstimator, EngineRuntime, EstimatorPolicy,
    EvictionStrategy, ExecutionBackend, ExecutionBackendControl, ExecutionBackendObserver,
    ExecutionBackendOutcome, ExecutionBackendRequest, ExecutionLaneSnapshot, ExecutionProgress,
    ExecutionRuntimeEvent, ExecutionServices, ExecutionSubmissionRequest,
    ExecutionSubmissionResult, RecalculateConfigurationRequest, RecalculateConfigurationResponse,
};

pub trait RuntimeHost: Send {
    fn analyze_media(&mut self, request: AnalyzeTaskRequest) -> Result<AnalyzeMediaResponse>;

    fn analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<AnalysisSnapshotView>;

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

impl RuntimeHost for EngineRuntime {
    fn analyze_media(&mut self, request: AnalyzeTaskRequest) -> Result<AnalyzeMediaResponse> {
        EngineRuntime::analyze_media(self, request)
    }

    fn analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<AnalysisSnapshotView> {
        EngineRuntime::analysis_snapshot(self, analysis_id)
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
        ExecutionServices {
            backend: Arc::new(FfmpegRuntimeExecutionBackend { adapter }),
        },
    ))
}

struct FfmpegRuntimeExecutionBackend {
    adapter: Arc<FfmpegAdapter>,
}

impl ExecutionBackend for FfmpegRuntimeExecutionBackend {
    fn execute(
        &self,
        request: &ExecutionBackendRequest,
        observer: &mut dyn ExecutionBackendObserver,
    ) -> Result<ExecutionBackendOutcome> {
        let configuration = &request.configuration;
        if !configuration.video_decoders.is_empty()
            || !configuration.audio_decoders.is_empty()
            || configuration.video_encoder_backend.is_some()
            || configuration.audio_encoder_backend.is_some()
            || !configuration.processors.is_empty()
        {
            return Err(framelean_core::EngineError::with_code(
                framelean_core::ErrorKind::Pipeline,
                framelean_core::EngineErrorCode::EngineExecutionChainNotReady,
                "the selected execution chain requires an unimplemented transform stage",
            ));
        }
        let outcome = self.adapter.remux(
            &request.source_path,
            &request.working_output_path,
            |progress| match observer.on_progress(ExecutionProgress {
                media_time_us: progress.media_time_us,
                processed_bytes: progress.processed_bytes,
            }) {
                ExecutionBackendControl::Continue => framelean_ffmpeg::RemuxControl::Continue,
                ExecutionBackendControl::Cancel => framelean_ffmpeg::RemuxControl::Cancel,
            },
        )?;
        Ok(match outcome {
            framelean_ffmpeg::RemuxOutcome::Completed(progress) => {
                ExecutionBackendOutcome::Completed(ExecutionProgress {
                    media_time_us: progress.media_time_us,
                    processed_bytes: progress.processed_bytes,
                })
            }
            framelean_ffmpeg::RemuxOutcome::Cancelled(progress) => {
                ExecutionBackendOutcome::Cancelled(ExecutionProgress {
                    media_time_us: progress.media_time_us,
                    processed_bytes: progress.processed_bytes,
                })
            }
        })
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::thread;
    use std::time::{Duration, Instant};

    use framelean_analysis::{MediaAnalyzeRequest, MediaSource};
    use framelean_runtime::{
        AnalyzeTaskRequest, ExecutionOutputRequest, ExecutionSubmissionRequest, ExecutionTaskState,
        ManualConfigurationSelection, ManualSelection, OutputCollisionPolicy, RecalculateSelection,
        RequestContext, TaskMode,
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
        fs::write(&input_path, pcm_wav_fixture()).unwrap();
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
        assert_eq!(submission.state, ExecutionTaskState::Queued);

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

    fn pcm_wav_fixture() -> Vec<u8> {
        const SAMPLE_RATE: u32 = 8_000;
        const SAMPLE_COUNT: u32 = 800;
        const CHANNELS: u16 = 1;
        const BITS_PER_SAMPLE: u16 = 16;
        let data_size = SAMPLE_COUNT * u32::from(CHANNELS) * u32::from(BITS_PER_SAMPLE / 8);
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
        for index in 0..SAMPLE_COUNT {
            let sample = if index % 16 < 8 {
                4_000_i16
            } else {
                -4_000_i16
            };
            bytes.extend_from_slice(&sample.to_le_bytes());
        }
        bytes
    }
}
