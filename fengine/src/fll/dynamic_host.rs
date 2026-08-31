use std::path::{Path, PathBuf};

use framelean_core::{AnalysisId, EngineError, EngineErrorCode, ErrorKind, Result, TaskId};
use framelean_ffmpeg::{
    PreviewFrameArtifact, PreviewFramesRequest, PreviewFramesResult, VideoThumbnailRequest,
    VideoThumbnailResult,
};
use framelean_runtime::{
    AnalysisSnapshotRecord, AnalysisSnapshotView, AnalyzeMediaResponse, AnalyzeTaskRequest,
    ExecutionLaneSnapshot, ExecutionRuntimeEvent, ExecutionSubmissionRequest,
    ExecutionSubmissionResult, RecalculateConfigurationRequest, RecalculateConfigurationResponse,
};
use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::{Value, json};

use super::documents::{
    ExecutionEventDocument, RequestDocument, decode_response, decode_response_value,
};
use super::loader::{FllLoader, resolve_default_library_path};
use crate::runtime_api::{
    AnalysisDocument, AnalysisId as LocalAnalysisId, AnalysisSnapshotDocument,
    AnalysisSnapshotRecordDocument, AnalyzeRequest, ExecutionEvent,
    ExecutionId as LocalExecutionId, ExecutionLaneSnapshot as LocalExecutionLaneSnapshot,
    ExecutionSubmissionRequest as LocalExecutionSubmissionRequest,
    ExecutionSubmissionResult as LocalExecutionSubmissionResult, FllErrorCode, ModelError,
    PreviewFramesRequest as LocalPreviewFramesRequest,
    PreviewFramesResult as LocalPreviewFramesResult, RecalculateConfigurationDocument,
    RecalculateConfigurationRequest as LocalRecalculateConfigurationRequest,
    ReorderExecutionsRequest, VideoThumbnailRequest as LocalVideoThumbnailRequest,
    VideoThumbnailResult as LocalVideoThumbnailResult,
};
use crate::runtime_host::{RuntimeApiHost, RuntimeHost};

pub struct DynamicRuntimeHost {
    loader: FllLoader,
}

impl DynamicRuntimeHost {
    pub fn load(path: impl AsRef<Path>) -> Result<Self> {
        Ok(Self {
            loader: FllLoader::load(path)?,
        })
    }

    pub fn from_default_location() -> Result<Self> {
        Self::load(resolve_default_library_path()?)
    }

    pub fn library_path_from_environment() -> Option<PathBuf> {
        std::env::var_os("FRAMELEAN_FLL_LIBRARY").map(PathBuf::from)
    }

    fn invoke_value<P: Serialize>(&self, operation: &str, payload: P) -> Result<Value> {
        let request =
            serde_json::to_vec(&RequestDocument::new(operation, payload)).map_err(|error| {
                EngineError::with_source_code(
                    ErrorKind::NativeLibrary,
                    EngineErrorCode::InternalNativeLibraryError,
                    format!("cannot serialize FLL {operation} request"),
                    error,
                )
            })?;
        let response = self.loader.invoke(&request)?;
        decode_response_value(&response)
    }

    fn invoke<T: DeserializeOwned, P: Serialize>(&self, operation: &str, payload: P) -> Result<T> {
        Self::decode_legacy_value(self.invoke_value(operation, payload)?, operation)
    }

    fn decode_legacy_value<T: DeserializeOwned>(value: Value, operation: &str) -> Result<T> {
        serde_json::from_value(value).map_err(|error| {
            EngineError::with_source_code(
                ErrorKind::NativeLibrary,
                EngineErrorCode::InternalNativeLibraryError,
                format!("FLL {operation} result has an unexpected shape"),
                error,
            )
        })
    }

    fn map_model_error(operation: &str, error: ModelError) -> EngineError {
        EngineError::with_source_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::InternalNativeLibraryError,
            format!("FLL {operation} result is not a valid runtime document"),
            error,
        )
    }

    fn decode_analysis_document(
        &self,
        operation: &str,
        payload: impl Serialize,
    ) -> Result<AnalysisDocument> {
        let document = AnalysisDocument::from_value(self.invoke_value(operation, payload)?)
            .map_err(|error| Self::map_model_error(operation, error))?;
        Ok(document)
    }

    fn decode_snapshot_document(
        &self,
        operation: &str,
        payload: impl Serialize,
    ) -> Result<AnalysisSnapshotDocument> {
        let document = AnalysisSnapshotDocument::from_value(self.invoke_value(operation, payload)?)
            .map_err(|error| Self::map_model_error(operation, error))?;
        Ok(document)
    }

    fn decode_snapshot_record_document(
        &self,
        operation: &str,
        payload: impl Serialize,
    ) -> Result<AnalysisSnapshotRecordDocument> {
        let document =
            AnalysisSnapshotRecordDocument::from_value(self.invoke_value(operation, payload)?)
                .map_err(|error| Self::map_model_error(operation, error))?;
        Ok(document)
    }

    fn decode_recalculate_document(
        &self,
        operation: &str,
        payload: impl Serialize,
    ) -> Result<RecalculateConfigurationDocument> {
        let document =
            RecalculateConfigurationDocument::from_value(self.invoke_value(operation, payload)?)
                .map_err(|error| Self::map_model_error(operation, error))?;
        Ok(document)
    }

    fn decode_legacy_projection<T: DeserializeOwned, S: Serialize>(
        value: S,
        field: &str,
    ) -> Result<T> {
        let value = serde_json::to_value(value).map_err(|error| {
            EngineError::with_source_code(
                ErrorKind::NativeLibrary,
                EngineErrorCode::InternalNativeLibraryError,
                format!("cannot serialize FLL {field} projection"),
                error,
            )
        })?;
        Self::decode_legacy_value(value, field)
    }

    fn convert_event(document: ExecutionEvent) -> Result<ExecutionRuntimeEvent> {
        let execution_id = TaskId::new(document.execution_id.into_string())?;
        let resource_pool =
            Self::decode_legacy_projection(document.resource_pool, "resource_pool")?;
        let state = Self::decode_legacy_projection(document.state, "execution state")?;
        let pause_reason = document
            .pause_reason
            .map(|value| Self::decode_legacy_projection(value, "pause reason"))
            .transpose()?;
        let preempted_by_execution_id = document
            .preempted_by_execution_id
            .map(|value| TaskId::new(value.into_string()))
            .transpose()?;
        let progress = document
            .progress
            .map(|value| Self::decode_legacy_projection(value, "execution progress"))
            .transpose()?;
        let error_code = document
            .error_code
            .map(|value: FllErrorCode| Self::decode_legacy_projection(value, "error code"))
            .transpose()?;
        Ok(ExecutionRuntimeEvent {
            execution_id,
            resource_pool,
            sequence: document.sequence,
            state,
            pause_reason,
            preempted_by_execution_id,
            resume_depth: document.resume_depth,
            progress,
            output_path: document.output_path,
            error_code,
            message: document.message,
        })
    }

    fn convert_execution_snapshot(
        snapshot: LocalExecutionLaneSnapshot,
    ) -> Result<ExecutionLaneSnapshot> {
        fn convert_entry(
            entry: crate::runtime_api::ScheduledExecutionProjection,
        ) -> Result<framelean_runtime::ScheduledExecution> {
            Ok(framelean_runtime::ScheduledExecution {
                execution_id: TaskId::new(entry.execution_id.into_string())?,
                resource_pool: DynamicRuntimeHost::decode_legacy_projection(
                    entry.resource_pool,
                    "resource_pool",
                )?,
                state: DynamicRuntimeHost::decode_legacy_projection(
                    entry.state,
                    "execution state",
                )?,
                pause_reason: entry
                    .pause_reason
                    .map(|value| {
                        DynamicRuntimeHost::decode_legacy_projection(value, "pause reason")
                    })
                    .transpose()?,
                preempted_by_execution_id: entry
                    .preempted_by_execution_id
                    .map(|value| TaskId::new(value.into_string()))
                    .transpose()?,
                checkpoint: entry
                    .checkpoint
                    .map(|value| {
                        DynamicRuntimeHost::decode_legacy_projection(value, "execution checkpoint")
                    })
                    .transpose()?,
            })
        }

        Ok(ExecutionLaneSnapshot {
            queue_revision: snapshot.queue_revision,
            active_executions: snapshot
                .active_executions
                .into_iter()
                .map(convert_entry)
                .collect::<Result<_>>()?,
            normal_waiting: snapshot
                .normal_waiting
                .into_iter()
                .map(convert_entry)
                .collect::<Result<_>>()?,
            video_resume_stack: snapshot
                .video_resume_stack
                .into_iter()
                .map(convert_entry)
                .collect::<Result<_>>()?,
            auxiliary_resume_stack: snapshot
                .auxiliary_resume_stack
                .into_iter()
                .map(convert_entry)
                .collect::<Result<_>>()?,
            user_paused: snapshot
                .user_paused
                .into_iter()
                .map(convert_entry)
                .collect::<Result<_>>()?,
        })
    }

    fn invoke_local_id<T: serde::de::DeserializeOwned>(
        &self,
        operation: &str,
        id: &LocalExecutionId,
    ) -> Result<T> {
        self.invoke(operation, json!({ "execution_id": id.as_str() }))
    }

    fn invoke_local_analysis_id<T: serde::de::DeserializeOwned>(
        &self,
        operation: &str,
        id: &LocalAnalysisId,
    ) -> Result<T> {
        self.invoke(operation, json!({ "analysis_id": id.as_str() }))
    }

    fn decode_local_event(bytes: &[u8]) -> Result<ExecutionEvent> {
        let document: ExecutionEventDocument = decode_response(bytes)?;
        Ok(document)
    }

    #[cfg(test)]
    fn decode_event(bytes: &[u8]) -> Result<ExecutionRuntimeEvent> {
        Self::convert_event(Self::decode_local_event(bytes)?)
    }
}

impl RuntimeApiHost for DynamicRuntimeHost {
    fn analyze_media(&mut self, request: AnalyzeRequest) -> Result<AnalysisDocument> {
        self.decode_analysis_document("analyze_media", request)
    }

    fn analysis_snapshot(
        &mut self,
        analysis_id: &LocalAnalysisId,
    ) -> Result<AnalysisSnapshotDocument> {
        self.decode_snapshot_document(
            "analysis_snapshot",
            json!({ "analysis_id": analysis_id.as_str() }),
        )
    }

    fn generate_preview_frames(
        &mut self,
        request: &LocalPreviewFramesRequest,
    ) -> Result<LocalPreviewFramesResult> {
        self.invoke("generate_preview_frames", request)
    }

    fn generate_video_thumbnail(
        &mut self,
        request: &LocalVideoThumbnailRequest,
    ) -> Result<LocalVideoThumbnailResult> {
        self.invoke("generate_video_thumbnail", request)
    }

    fn analysis_snapshot_record(
        &mut self,
        analysis_id: &LocalAnalysisId,
    ) -> Result<AnalysisSnapshotRecordDocument> {
        self.decode_snapshot_record_document(
            "export_analysis_snapshot",
            json!({ "analysis_id": analysis_id.as_str() }),
        )
    }

    fn discard_analysis_snapshot(&mut self, analysis_id: &LocalAnalysisId) -> Result<bool> {
        self.invoke_local_analysis_id("discard_analysis_snapshot", analysis_id)
    }

    fn restore_analysis_snapshot(&mut self, record: AnalysisSnapshotRecordDocument) -> Result<()> {
        self.invoke("restore_analysis_snapshot", record.into_value())
    }

    fn recalculate_configuration(
        &mut self,
        request: LocalRecalculateConfigurationRequest,
    ) -> Result<RecalculateConfigurationDocument> {
        self.decode_recalculate_document("recalculate_configuration", request)
    }

    fn submit_execution(
        &mut self,
        request: LocalExecutionSubmissionRequest,
    ) -> Result<LocalExecutionSubmissionResult> {
        self.invoke("submit_execution", request)
    }

    fn drain_execution_events(&mut self) -> Result<Vec<ExecutionEvent>> {
        let mut events = Vec::new();
        loop {
            match self.loader.poll_event() {
                Ok(Some(bytes)) => events.push(Self::decode_local_event(&bytes)?),
                Ok(None) => break,
                Err(error) => return Err(error),
            }
        }
        Ok(events)
    }

    fn execution_snapshot(&self) -> Result<LocalExecutionLaneSnapshot> {
        self.invoke("execution_snapshot", json!({}))
    }

    fn reorder_waiting_executions(&mut self, request: ReorderExecutionsRequest) -> Result<u64> {
        self.invoke("reorder_waiting_executions", request)
    }

    fn preempt_and_start_execution(&mut self, execution_id: &LocalExecutionId) -> Result<()> {
        self.invoke_local_id("preempt_and_start_execution", execution_id)
    }

    fn pause_execution(&mut self, execution_id: &LocalExecutionId) -> Result<()> {
        self.invoke_local_id("pause_execution", execution_id)
    }

    fn resume_execution(&mut self, execution_id: &LocalExecutionId) -> Result<()> {
        self.invoke_local_id("resume_execution", execution_id)
    }

    fn cancel_execution(&mut self, execution_id: &LocalExecutionId) -> Result<()> {
        self.invoke_local_id("cancel_execution", execution_id)
    }
}

impl RuntimeHost for DynamicRuntimeHost {
    fn analyze_media(&mut self, request: AnalyzeTaskRequest) -> Result<AnalyzeMediaResponse> {
        let local_request = AnalyzeRequest {
            task_mode: Self::decode_legacy_projection(request.task_mode, "task mode")?,
            media_request: Self::decode_legacy_projection(
                request.media_request,
                "media analyze request",
            )?,
            context: Self::decode_legacy_projection(request.context, "request context")?,
        };
        let document = RuntimeApiHost::analyze_media(self, local_request)?;
        Self::decode_legacy_value(document.into_value(), "analyze_media")
    }

    fn analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<AnalysisSnapshotView> {
        let local_id = LocalAnalysisId::new(analysis_id.as_str());
        let document = RuntimeApiHost::analysis_snapshot(self, &local_id)?;
        Self::decode_legacy_value(document.into_value(), "analysis_snapshot")
    }

    fn generate_preview_frames(
        &mut self,
        request: &PreviewFramesRequest,
    ) -> Result<PreviewFramesResult> {
        let local_request = LocalPreviewFramesRequest {
            input_path: request.input_path.clone(),
            output_directory: request.output_directory.clone(),
            timestamps_us: request.timestamps_us.clone(),
            max_width: request.max_width,
        };
        let result = RuntimeApiHost::generate_preview_frames(self, &local_request)?;
        Ok(PreviewFramesResult {
            output_directory: result.output_directory,
            frames: result
                .frames
                .into_iter()
                .map(|frame| PreviewFrameArtifact {
                    index: frame.index,
                    requested_timestamp_us: frame.requested_timestamp_us,
                    decoded_timestamp_us: frame.decoded_timestamp_us,
                    width: frame.width,
                    height: frame.height,
                    output_path: frame.output_path,
                })
                .collect(),
        })
    }

    fn generate_video_thumbnail(
        &mut self,
        request: &VideoThumbnailRequest,
    ) -> Result<VideoThumbnailResult> {
        let local_request = LocalVideoThumbnailRequest {
            input_path: request.input_path.clone(),
            output_path: request.output_path.clone(),
            duration_us: request.duration_us,
            max_width: request.max_width,
        };
        let result = RuntimeApiHost::generate_video_thumbnail(self, &local_request)?;
        Ok(VideoThumbnailResult {
            output_path: result.output_path,
            requested_timestamp_us: result.requested_timestamp_us,
            decoded_timestamp_us: result.decoded_timestamp_us,
            width: result.width,
            height: result.height,
        })
    }

    fn analysis_snapshot_record(
        &mut self,
        analysis_id: &AnalysisId,
    ) -> Result<AnalysisSnapshotRecord> {
        let local_id = LocalAnalysisId::new(analysis_id.as_str());
        let document = RuntimeApiHost::analysis_snapshot_record(self, &local_id)?;
        Self::decode_legacy_value(document.into_value(), "export_analysis_snapshot")
    }

    fn discard_analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<bool> {
        let local_id = LocalAnalysisId::new(analysis_id.as_str());
        RuntimeApiHost::discard_analysis_snapshot(self, &local_id)
    }

    fn restore_analysis_snapshot(&mut self, record: AnalysisSnapshotRecord) -> Result<()> {
        let value = serde_json::to_value(record).map_err(|error| {
            EngineError::with_source_code(
                ErrorKind::NativeLibrary,
                EngineErrorCode::InternalNativeLibraryError,
                "cannot serialize analysis snapshot record",
                error,
            )
        })?;
        let document = AnalysisSnapshotRecordDocument::from_value(value)
            .map_err(|error| Self::map_model_error("restore_analysis_snapshot", error))?;
        RuntimeApiHost::restore_analysis_snapshot(self, document)
    }

    fn recalculate_configuration(
        &mut self,
        request: RecalculateConfigurationRequest,
    ) -> Result<RecalculateConfigurationResponse> {
        let local_request: LocalRecalculateConfigurationRequest =
            Self::decode_legacy_projection(request, "recalculate configuration request")?;
        let document = RuntimeApiHost::recalculate_configuration(self, local_request)?;
        Self::decode_legacy_value(document.into_value(), "recalculate_configuration")
    }

    fn submit_execution(
        &mut self,
        request: ExecutionSubmissionRequest,
    ) -> Result<ExecutionSubmissionResult> {
        let local_request: LocalExecutionSubmissionRequest =
            Self::decode_legacy_projection(request, "execution submission request")?;
        let result = RuntimeApiHost::submit_execution(self, local_request)?;
        Ok(ExecutionSubmissionResult {
            execution_id: TaskId::new(result.execution_id.into_string())?,
            state: Self::decode_legacy_projection(result.state, "execution state")?,
            queue_position: result.queue_position,
            queue_revision: result.queue_revision,
        })
    }

    fn drain_execution_events(&mut self) -> Result<Vec<ExecutionRuntimeEvent>> {
        RuntimeApiHost::drain_execution_events(self)?
            .into_iter()
            .map(Self::convert_event)
            .collect()
    }

    fn execution_snapshot(&self) -> Result<ExecutionLaneSnapshot> {
        Self::convert_execution_snapshot(RuntimeApiHost::execution_snapshot(self)?)
    }

    fn reorder_waiting_executions(
        &mut self,
        expected_revision: u64,
        ordered_execution_ids: &[TaskId],
    ) -> Result<u64> {
        let request = ReorderExecutionsRequest {
            expected_revision,
            ordered_execution_ids: ordered_execution_ids
                .iter()
                .map(|id| LocalExecutionId::new(id.as_str()))
                .collect(),
        };
        RuntimeApiHost::reorder_waiting_executions(self, request)
    }

    fn preempt_and_start_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        let local_id = LocalExecutionId::new(execution_id.as_str());
        RuntimeApiHost::preempt_and_start_execution(self, &local_id)
    }

    fn pause_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        let local_id = LocalExecutionId::new(execution_id.as_str());
        RuntimeApiHost::pause_execution(self, &local_id)
    }

    fn resume_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        let local_id = LocalExecutionId::new(execution_id.as_str());
        RuntimeApiHost::resume_execution(self, &local_id)
    }

    fn cancel_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        let local_id = LocalExecutionId::new(execution_id.as_str());
        RuntimeApiHost::cancel_execution(self, &local_id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use framelean_core::TaskId;

    #[test]
    fn operation_payload_uses_string_ids() {
        let id = TaskId::new("execution-1").unwrap();
        let value = json!({ "execution_id": id.as_str() });
        assert_eq!(value["execution_id"], "execution-1");
    }

    #[test]
    fn legacy_execution_request_matches_local_transport() {
        let legacy = framelean_runtime::ExecutionSubmissionRequest {
            analysis_id: framelean_core::AnalysisId::new("analysis-1").unwrap(),
            expected_revision: framelean_runtime::AnalysisRevision::initial()
                .next()
                .unwrap(),
            selection: framelean_runtime::RecalculateSelection::Manual(
                framelean_runtime::ManualConfigurationSelection {
                    candidate_id: framelean_runtime::ExecutionChainId::new("candidate-1").unwrap(),
                    overrides: framelean_runtime::ManualSelection::empty(),
                },
            ),
            output: framelean_runtime::ExecutionOutputRequest {
                requested_path: "/tmp/output.mkv".into(),
                collision_policy: framelean_runtime::OutputCollisionPolicy::FailIfExists,
            },
            context: framelean_runtime::RequestContext {
                request_id: Some("request-1".to_owned()),
                client_file_id: Some("file-1".to_owned()),
                correlation_id: Some("correlation-1".to_owned()),
            },
        };
        let value = serde_json::to_value(&legacy).unwrap();
        let local: LocalExecutionSubmissionRequest =
            DynamicRuntimeHost::decode_legacy_projection(legacy, "execution submission request")
                .unwrap();
        assert_eq!(serde_json::to_value(local).unwrap(), value);
    }

    #[test]
    fn execution_result_matches_local_and_legacy_wire_shapes() {
        let value = json!({
            "execution_id": "execution-1",
            "state": "queued",
            "queue_position": 2,
            "queue_revision": 9
        });
        let legacy: framelean_runtime::ExecutionSubmissionResult =
            serde_json::from_value(value.clone()).unwrap();
        let local: LocalExecutionSubmissionResult = serde_json::from_value(value.clone()).unwrap();
        assert_eq!(serde_json::to_value(legacy).unwrap(), value);
        assert_eq!(serde_json::to_value(local).unwrap(), value);
    }

    #[test]
    fn local_lane_projection_converts_to_legacy_wire_shape() {
        let value = json!({
            "queue_revision": 11,
            "active_executions": [{
                "execution_id": "execution-1",
                "resource_pool": "video",
                "state": "paused",
                "pause_reason": "preemption",
                "preempted_by_execution_id": "execution-2",
                "checkpoint": {
                    "media_time_us": 17,
                    "processed_bytes": 23,
                    "opaque_token": "future-token"
                }
            }],
            "normal_waiting": [],
            "video_resume_stack": [],
            "auxiliary_resume_stack": [],
            "user_paused": []
        });
        let local: LocalExecutionLaneSnapshot = serde_json::from_value(value.clone()).unwrap();
        let legacy = DynamicRuntimeHost::convert_execution_snapshot(local).unwrap();
        assert_eq!(serde_json::to_value(legacy).unwrap(), value);
    }

    #[test]
    fn local_event_converts_to_legacy_runtime_event_fields() {
        let value = json!({
            "execution_id": "execution-1",
            "resource_pool": "auxiliary",
            "sequence": 4,
            "state": "failed",
            "pause_reason": null,
            "preempted_by_execution_id": null,
            "resume_depth": 0,
            "progress": {"media_time_us": 12, "processed_bytes": 34},
            "output_path": "/tmp/output.mkv",
            "error_code": "INTERNAL_RUNTIME_ERROR",
            "message": "failure"
        });
        let local: ExecutionEvent = serde_json::from_value(value).unwrap();
        let legacy = DynamicRuntimeHost::convert_event(local).unwrap();
        assert_eq!(legacy.execution_id.as_str(), "execution-1");
        assert_eq!(
            legacy.resource_pool,
            framelean_runtime::ExecutionResourcePool::Auxiliary
        );
        assert_eq!(legacy.sequence, 4);
        assert_eq!(legacy.state, framelean_runtime::ExecutionTaskState::Failed);
        assert_eq!(legacy.progress.unwrap().media_time_us, 12);
        assert_eq!(
            legacy.output_path.unwrap(),
            PathBuf::from("/tmp/output.mkv")
        );
        assert_eq!(
            legacy.error_code,
            Some(framelean_core::EngineErrorCode::InternalRuntimeError)
        );
        assert_eq!(legacy.message.as_deref(), Some("failure"));
    }

    #[test]
    fn event_conversion_rejects_empty_execution_ids() {
        let bytes = serde_json::to_vec(&json!({
            "document_version": 1,
            "ok": true,
            "result": {
                "execution_id": "",
                "resource_pool": "auxiliary",
                "sequence": 1,
                "state": "queued",
                "pause_reason": null,
                "preempted_by_execution_id": null,
                "resume_depth": 0,
                "progress": null,
                "output_path": null,
                "error_code": null,
                "message": null
            }
        }))
        .unwrap();
        assert!(DynamicRuntimeHost::decode_event(&bytes).is_err());
    }
}
