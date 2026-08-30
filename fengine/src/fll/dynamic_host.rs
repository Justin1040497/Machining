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
    ExecutionEventDocument, PreviewFramesResultDocument, RequestDocument,
    VideoThumbnailResultDocument, decode_response, decode_response_value,
};
use super::loader::{FllLoader, resolve_default_library_path};
use crate::runtime_api::{
    AnalysisDocument, AnalysisSnapshotDocument, AnalysisSnapshotRecordDocument, AnalyzeRequest,
    ExecutionEvent, ExecutionId as LocalExecutionId,
    ExecutionLaneSnapshot as LocalExecutionLaneSnapshot,
    ExecutionSubmissionRequest as LocalExecutionSubmissionRequest,
    ExecutionSubmissionResult as LocalExecutionSubmissionResult, FllErrorCode, ModelError,
    PreviewFramesRequest as LocalPreviewFramesRequest, RecalculateConfigurationDocument,
    RecalculateConfigurationRequest as LocalRecalculateConfigurationRequest,
    ReorderExecutionsRequest, VideoThumbnailRequest as LocalVideoThumbnailRequest,
};
use crate::runtime_host::RuntimeHost;

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

    fn decode_analysis_document<T: DeserializeOwned>(
        &self,
        operation: &str,
        payload: impl Serialize,
    ) -> Result<T> {
        let document = AnalysisDocument::from_value(self.invoke_value(operation, payload)?)
            .map_err(|error| Self::map_model_error(operation, error))?;
        Self::decode_legacy_value(document.into_value(), operation)
    }

    fn decode_snapshot_document<T: DeserializeOwned>(
        &self,
        operation: &str,
        payload: impl Serialize,
    ) -> Result<T> {
        let document = AnalysisSnapshotDocument::from_value(self.invoke_value(operation, payload)?)
            .map_err(|error| Self::map_model_error(operation, error))?;
        Self::decode_legacy_value(document.into_value(), operation)
    }

    fn decode_snapshot_record_document<T: DeserializeOwned>(
        &self,
        operation: &str,
        payload: impl Serialize,
    ) -> Result<T> {
        let document =
            AnalysisSnapshotRecordDocument::from_value(self.invoke_value(operation, payload)?)
                .map_err(|error| Self::map_model_error(operation, error))?;
        Self::decode_legacy_value(document.into_value(), operation)
    }

    fn decode_recalculate_document<T: DeserializeOwned>(
        &self,
        operation: &str,
        payload: impl Serialize,
    ) -> Result<T> {
        let document =
            RecalculateConfigurationDocument::from_value(self.invoke_value(operation, payload)?)
                .map_err(|error| Self::map_model_error(operation, error))?;
        Self::decode_legacy_value(document.into_value(), operation)
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

    fn invoke_id<T: serde::de::DeserializeOwned>(&self, operation: &str, id: &TaskId) -> Result<T> {
        self.invoke(operation, json!({ "execution_id": id.as_str() }))
    }

    fn invoke_analysis_id<T: serde::de::DeserializeOwned>(
        &self,
        operation: &str,
        id: &AnalysisId,
    ) -> Result<T> {
        self.invoke(operation, json!({ "analysis_id": id.as_str() }))
    }

    fn decode_event(bytes: &[u8]) -> Result<ExecutionRuntimeEvent> {
        let document: ExecutionEventDocument = decode_response(bytes)?;
        Self::convert_event(document)
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
        self.decode_analysis_document("analyze_media", local_request)
    }

    fn analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<AnalysisSnapshotView> {
        self.decode_snapshot_document(
            "analysis_snapshot",
            json!({ "analysis_id": analysis_id.as_str() }),
        )
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
        let result: PreviewFramesResultDocument =
            self.invoke("generate_preview_frames", local_request)?;
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
        let result: VideoThumbnailResultDocument =
            self.invoke("generate_video_thumbnail", local_request)?;
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
        self.decode_snapshot_record_document(
            "export_analysis_snapshot",
            json!({ "analysis_id": analysis_id.as_str() }),
        )
    }

    fn discard_analysis_snapshot(&mut self, analysis_id: &AnalysisId) -> Result<bool> {
        self.invoke_analysis_id("discard_analysis_snapshot", analysis_id)
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
        self.invoke("restore_analysis_snapshot", document.into_value())
    }

    fn recalculate_configuration(
        &mut self,
        request: RecalculateConfigurationRequest,
    ) -> Result<RecalculateConfigurationResponse> {
        let local_request: LocalRecalculateConfigurationRequest =
            Self::decode_legacy_projection(request, "recalculate configuration request")?;
        self.decode_recalculate_document("recalculate_configuration", local_request)
    }

    fn submit_execution(
        &mut self,
        request: ExecutionSubmissionRequest,
    ) -> Result<ExecutionSubmissionResult> {
        let local_request: LocalExecutionSubmissionRequest =
            Self::decode_legacy_projection(request, "execution submission request")?;
        let result: LocalExecutionSubmissionResult =
            self.invoke("submit_execution", local_request)?;
        Ok(ExecutionSubmissionResult {
            execution_id: TaskId::new(result.execution_id.into_string())?,
            state: Self::decode_legacy_projection(result.state, "execution state")?,
            queue_position: result.queue_position,
            queue_revision: result.queue_revision,
        })
    }

    fn drain_execution_events(&mut self) -> Result<Vec<ExecutionRuntimeEvent>> {
        let mut events = Vec::new();
        loop {
            match self.loader.poll_event() {
                Ok(Some(bytes)) => {
                    let event = Self::decode_event(&bytes)?;
                    events.push(event);
                }
                Ok(None) => break,
                Err(error) => return Err(error),
            }
        }
        Ok(events)
    }

    fn execution_snapshot(&self) -> Result<ExecutionLaneSnapshot> {
        let snapshot: LocalExecutionLaneSnapshot = self.invoke("execution_snapshot", json!({}))?;
        Self::convert_execution_snapshot(snapshot)
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
        self.invoke("reorder_waiting_executions", request)
    }

    fn preempt_and_start_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        self.invoke_id("preempt_and_start_execution", execution_id)
    }

    fn pause_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        self.invoke_id("pause_execution", execution_id)
    }

    fn resume_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        self.invoke_id("resume_execution", execution_id)
    }

    fn cancel_execution(&mut self, execution_id: &TaskId) -> Result<()> {
        self.invoke_id("cancel_execution", execution_id)
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
