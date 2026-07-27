use std::io::{self, Read, Write};
use std::path::PathBuf;

use framelean_core::{AnalysisId, EngineErrorCode};
use framelean_runtime::{
    AnalysisRevision, AnalysisSnapshotView, AnalyzeMediaResponse, ExecutionLaneSnapshot,
    ExecutionOutputRequest, ExecutionPauseReason, ExecutionProgress, ExecutionSubmissionResult,
    ExecutionTaskState, RecalculateSelection, TaskMode,
};
use serde::{Deserialize, Serialize};

use crate::work_queue::WorkPriority;

pub const PROTOCOL_VERSION: u32 = 1;
pub const MAX_FRAME_BYTES: usize = 16 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RequestEnvelope {
    pub protocol_version: u32,
    pub session_id: Option<String>,
    pub request_id: String,
    pub command: WorkerCommand,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload", rename_all = "snake_case")]
pub enum WorkerCommand {
    Hello(HelloCommand),
    AnalyzeMedia(AnalyzeMediaCommand),
    GeneratePreviewFrames(GeneratePreviewFramesCommand),
    GenerateVideoThumbnail(GenerateVideoThumbnailCommand),
    SubmitAnalysisBatch(SubmitAnalysisBatchCommand),
    GetAnalysisSnapshot(GetAnalysisSnapshotCommand),
    SubmitExecution(SubmitExecutionCommand),
    SubmitExecutionBatch(SubmitExecutionBatchCommand),
    ApplyQueueOrder(ApplyQueueOrderCommand),
    GetEngineSnapshot,
    PreemptAndStart(PreemptAndStartCommand),
    ControlExecution(ControlExecutionCommand),
    Ping,
    Shutdown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HelloCommand {
    pub minimum_protocol_version: u32,
    pub maximum_protocol_version: u32,
    pub client_name: String,
    pub client_version: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClientSourceFacts {
    pub path: PathBuf,
    pub file_size_bytes: u64,
    pub modified_time_unix_nanos: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnalyzeMediaCommand {
    pub client_task_id: String,
    pub client_file_id: String,
    pub source: ClientSourceFacts,
    pub task_mode: TaskMode,
    #[serde(default)]
    pub priority: WorkPriority,
    #[serde(default)]
    pub force_reanalysis: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GeneratePreviewFramesCommand {
    pub client_task_id: String,
    pub source: ClientSourceFacts,
    pub output_directory: PathBuf,
    pub timestamps_us: Vec<u64>,
    pub max_width: Option<u32>,
    #[serde(default)]
    pub priority: WorkPriority,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GenerateVideoThumbnailCommand {
    pub client_task_id: String,
    pub source: ClientSourceFacts,
    pub output_path: PathBuf,
    pub duration_us: Option<u64>,
    pub max_width: u32,
    #[serde(default)]
    pub priority: WorkPriority,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreviewFrameArtifactDocument {
    pub index: usize,
    pub requested_timestamp_us: u64,
    pub decoded_timestamp_us: u64,
    pub width: u32,
    pub height: u32,
    pub output_path: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreviewFramesDocument {
    pub output_directory: PathBuf,
    pub frames: Vec<PreviewFrameArtifactDocument>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VideoThumbnailDocument {
    pub output_path: PathBuf,
    pub requested_timestamp_us: u64,
    pub decoded_timestamp_us: u64,
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubmitAnalysisBatchCommand {
    pub items: Vec<AnalyzeMediaCommand>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GetAnalysisSnapshotCommand {
    pub analysis_id: AnalysisId,
    #[serde(default)]
    pub priority: WorkPriority,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubmitExecutionCommand {
    pub client_task_id: String,
    pub analysis_id: AnalysisId,
    pub expected_revision: AnalysisRevision,
    pub selection: RecalculateSelection,
    pub output: ExecutionOutputRequest,
    #[serde(default)]
    pub priority: WorkPriority,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubmitExecutionBatchCommand {
    pub items: Vec<SubmitExecutionCommand>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BatchSubmissionItem {
    pub client_task_id: String,
    pub child_request_id: String,
    pub work_id: String,
    pub queue_kind: QueueKind,
    pub queue_position: usize,
    pub queue_revision: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreemptAndStartCommand {
    pub execution_id: framelean_core::TaskId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApplyQueueOrderCommand {
    pub order_revision: u64,
    pub expected_analysis_queue_revision: u64,
    pub expected_execution_queue_revision: u64,
    pub ordered_task_ids: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnalysisQueuePosition {
    pub work_id: String,
    pub client_task_id: String,
    pub queue_position: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionQueuePosition {
    pub execution_id: framelean_core::TaskId,
    pub client_task_id: String,
    pub queue_position: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct QueueOrderResult {
    pub order_revision: u64,
    pub analysis_queue_revision: u64,
    pub execution_queue_revision: u64,
    pub analysis_positions: Vec<AnalysisQueuePosition>,
    pub execution_positions: Vec<ExecutionQueuePosition>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExecutionControlAction {
    Pause,
    Resume,
    Cancel,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ControlExecutionCommand {
    pub execution_id: framelean_core::TaskId,
    pub action: ExecutionControlAction,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnalysisQueueEntrySnapshot {
    pub work_id: String,
    pub client_task_id: String,
    pub queue_position: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TerminalExecutionSnapshot {
    pub execution_id: framelean_core::TaskId,
    pub client_task_id: String,
    pub state: ExecutionTaskState,
    pub output_path: Option<PathBuf>,
    pub engine_code: Option<EngineErrorCode>,
    pub message: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TerminalAnalysisSnapshot {
    pub work_id: String,
    pub client_task_id: String,
    pub client_file_id: String,
    pub analysis_id: AnalysisId,
    pub analysis_revision: AnalysisRevision,
    pub succeeded: bool,
    pub engine_code: Option<EngineErrorCode>,
    pub message: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EngineStateSnapshot {
    pub analysis_queue_revision: u64,
    pub active_analysis: Option<AnalysisQueueEntrySnapshot>,
    pub analysis_queue: Vec<AnalysisQueueEntrySnapshot>,
    pub terminal_analyses: Vec<TerminalAnalysisSnapshot>,
    pub execution_lane: ExecutionLaneSnapshot,
    pub terminal_executions: Vec<TerminalExecutionSnapshot>,
    pub last_sequence: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OutputEnvelope {
    pub protocol_version: u32,
    pub session_id: String,
    pub sequence: u64,
    pub request_id: String,
    pub output: WorkerOutput,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "payload", rename_all = "snake_case")]
pub enum WorkerOutput {
    Response(WorkerResponse),
    Event(WorkerEvent),
    Error(WorkerError),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload", rename_all = "snake_case")]
pub enum WorkerResponse {
    Hello {
        negotiated_protocol_version: u32,
        engine_version: String,
        heartbeat_timeout_ms: u64,
        resumed: bool,
    },
    Accepted {
        work_id: String,
        queue_kind: QueueKind,
        queue_position: usize,
        queue_revision: u64,
        state: WorkState,
        analysis_id: Option<AnalysisId>,
        deduplicated: bool,
    },
    BatchAccepted {
        items: Vec<BatchSubmissionItem>,
    },
    Pong,
    ShutdownAccepted,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkState {
    Queued,
    Running,
    Completed,
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum QueueKind {
    Analysis,
    Execution,
    Control,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload", rename_all = "snake_case")]
pub enum WorkerEvent {
    WorkQueued {
        work_id: String,
        client_task_id: Option<String>,
        queue_kind: QueueKind,
        queue_position: usize,
        queue_revision: u64,
    },
    WorkStarted {
        work_id: String,
        client_task_id: Option<String>,
        queue_kind: QueueKind,
        queue_remaining: usize,
        queue_revision: u64,
    },
    AnalysisCompleted {
        work_id: String,
        client_task_id: String,
        client_file_id: String,
        analysis: Box<AnalyzeMediaResponse>,
        snapshot: Option<Box<AnalysisSnapshotView>>,
    },
    AnalysisSnapshotReady {
        work_id: String,
        snapshot: Box<AnalysisSnapshotView>,
    },
    PreviewFramesReady {
        work_id: String,
        client_task_id: String,
        result: Box<PreviewFramesDocument>,
    },
    VideoThumbnailReady {
        work_id: String,
        client_task_id: String,
        result: Box<VideoThumbnailDocument>,
    },
    ExecutionSubmitted {
        work_id: String,
        client_task_id: String,
        submission: Box<ExecutionSubmissionResult>,
    },
    EngineSnapshotReady {
        work_id: String,
        snapshot: Box<EngineStateSnapshot>,
    },
    ExecutionControlAccepted {
        work_id: String,
        execution_id: framelean_core::TaskId,
        state: ExecutionTaskState,
    },
    QueueOrderApplied {
        work_id: String,
        result: Box<QueueOrderResult>,
    },
    QueueOrderConflict {
        work_id: String,
        order_revision: u64,
        snapshot: Box<EngineStateSnapshot>,
    },
    ExecutionStarted {
        execution_id: framelean_core::TaskId,
        client_task_id: String,
        state: ExecutionTaskState,
        resume_depth: usize,
    },
    ExecutionProgress {
        execution_id: framelean_core::TaskId,
        client_task_id: String,
        progress: ExecutionProgress,
        resume_depth: usize,
    },
    ExecutionPaused {
        execution_id: framelean_core::TaskId,
        client_task_id: String,
        pause_reason: Option<ExecutionPauseReason>,
        preempted_by_execution_id: Option<framelean_core::TaskId>,
        resume_depth: usize,
    },
    ExecutionResumed {
        execution_id: framelean_core::TaskId,
        client_task_id: String,
        resume_depth: usize,
    },
    ExecutionStateChanged {
        execution_id: framelean_core::TaskId,
        client_task_id: String,
        state: ExecutionTaskState,
        pause_reason: Option<ExecutionPauseReason>,
        preempted_by_execution_id: Option<framelean_core::TaskId>,
        resume_depth: usize,
    },
    Warning {
        client_task_id: Option<String>,
        execution_id: Option<framelean_core::TaskId>,
        engine_code: Option<EngineErrorCode>,
        message: String,
    },
    ExecutionCompleted {
        execution_id: framelean_core::TaskId,
        client_task_id: String,
        output_path: PathBuf,
    },
    ExecutionFailed {
        execution_id: framelean_core::TaskId,
        client_task_id: String,
        engine_code: Option<EngineErrorCode>,
        message: String,
        resume_depth: usize,
    },
    ExecutionCancelled {
        execution_id: framelean_core::TaskId,
        client_task_id: String,
        resume_depth: usize,
    },
    WorkFailed {
        work_id: String,
        error: WorkerError,
    },
    ShutdownComplete,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum WorkerErrorCode {
    InvalidFrame,
    ProtocolVersionUnsupported,
    HandshakeRequired,
    SessionMismatch,
    InvalidRequest,
    IdempotencyKeyReused,
    WorkerBusy,
    WorkerDraining,
    HeartbeatTimedOut,
    ResponseTooLarge,
    RuntimeFailure,
    SnapshotStoreFailure,
    InternalWorkerFailure,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkerError {
    pub code: WorkerErrorCode,
    pub engine_code: Option<EngineErrorCode>,
    pub message: String,
    pub retryable: bool,
}

pub fn read_request_frame(reader: &mut impl Read) -> io::Result<Option<RequestEnvelope>> {
    let Some(payload) = read_payload(reader)? else {
        return Ok(None);
    };
    serde_json::from_slice(&payload)
        .map(Some)
        .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))
}

pub fn write_output_frame(writer: &mut impl Write, output: &OutputEnvelope) -> io::Result<()> {
    let payload = serialize_output(output)?;
    write_payload(writer, &payload)
}

pub fn write_output_frame_resilient(
    writer: &mut impl Write,
    output: &OutputEnvelope,
) -> io::Result<()> {
    match serialize_output(output) {
        Ok(payload) => write_payload(writer, &payload),
        Err(error) if error.kind() == io::ErrorKind::InvalidData => {
            let fallback = OutputEnvelope {
                protocol_version: output.protocol_version,
                session_id: output.session_id.clone(),
                sequence: output.sequence,
                request_id: output.request_id.clone(),
                output: WorkerOutput::Error(WorkerError {
                    code: WorkerErrorCode::ResponseTooLarge,
                    engine_code: None,
                    message: "worker response exceeds the protocol frame limit".to_owned(),
                    retryable: false,
                }),
            };
            let payload = serialize_output(&fallback)?;
            write_payload(writer, &payload)
        }
        Err(error) => Err(error),
    }
}

fn serialize_output(output: &OutputEnvelope) -> io::Result<Vec<u8>> {
    let mut payload = LimitedBuffer::new(MAX_FRAME_BYTES);
    serde_json::to_writer(&mut payload, output)
        .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
    Ok(payload.into_inner())
}

struct LimitedBuffer {
    bytes: Vec<u8>,
    maximum_bytes: usize,
}

impl LimitedBuffer {
    fn new(maximum_bytes: usize) -> Self {
        Self {
            bytes: Vec::with_capacity(4096),
            maximum_bytes,
        }
    }

    fn into_inner(self) -> Vec<u8> {
        self.bytes
    }
}

impl Write for LimitedBuffer {
    fn write(&mut self, buffer: &[u8]) -> io::Result<usize> {
        let next_length = self
            .bytes
            .len()
            .checked_add(buffer.len())
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "frame size overflow"))?;
        if next_length > self.maximum_bytes {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "worker response exceeds the protocol frame limit",
            ));
        }
        self.bytes.extend_from_slice(buffer);
        Ok(buffer.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

fn read_payload(reader: &mut impl Read) -> io::Result<Option<Vec<u8>>> {
    let mut length = [0_u8; 4];
    loop {
        match reader.read(&mut length[..1]) {
            Ok(0) => return Ok(None),
            Ok(1) => break,
            Ok(_) => unreachable!("single-byte read buffer cannot return more than one byte"),
            Err(error) if error.kind() == io::ErrorKind::Interrupted => {}
            Err(error) => return Err(error),
        }
    }
    reader.read_exact(&mut length[1..])?;
    let length = u32::from_be_bytes(length) as usize;
    if length == 0 || length > MAX_FRAME_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "invalid protocol frame length",
        ));
    }
    let mut payload = vec![0; length];
    reader.read_exact(&mut payload)?;
    Ok(Some(payload))
}

fn write_payload(writer: &mut impl Write, payload: &[u8]) -> io::Result<()> {
    if payload.is_empty() || payload.len() > MAX_FRAME_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "invalid protocol frame length",
        ));
    }
    let length = u32::try_from(payload.len())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "protocol frame is too large"))?;
    writer.write_all(&length.to_be_bytes())?;
    writer.write_all(payload)?;
    writer.flush()
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use super::*;

    #[test]
    fn length_framed_request_round_trips_without_newline_delimiters() {
        let request = RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: None,
            request_id: "hello-1".to_owned(),
            command: WorkerCommand::Hello(HelloCommand {
                minimum_protocol_version: 1,
                maximum_protocol_version: 1,
                client_name: "test".to_owned(),
                client_version: "1".to_owned(),
            }),
        };
        let payload = serde_json::to_vec(&request).unwrap();
        let mut bytes = Vec::new();
        write_payload(&mut bytes, &payload).unwrap();

        let decoded = read_request_frame(&mut Cursor::new(bytes))
            .unwrap()
            .unwrap();
        assert_eq!(decoded, request);
    }

    #[test]
    fn invalid_frame_length_is_rejected_before_allocation() {
        let mut bytes = Cursor::new(((MAX_FRAME_BYTES as u32) + 1).to_be_bytes());
        let error = read_request_frame(&mut bytes).unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
    }

    #[test]
    fn truncated_length_prefix_is_not_treated_as_clean_eof() {
        let mut bytes = Cursor::new(vec![0, 0]);
        let error = read_request_frame(&mut bytes).unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::UnexpectedEof);
    }

    #[test]
    fn interrupted_prefix_read_is_retried() {
        struct InterruptedOnce {
            interrupted: bool,
            bytes: Cursor<Vec<u8>>,
        }

        impl Read for InterruptedOnce {
            fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
                if !self.interrupted {
                    self.interrupted = true;
                    return Err(io::Error::from(io::ErrorKind::Interrupted));
                }
                self.bytes.read(buffer)
            }
        }

        let request = RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: None,
            request_id: "hello-1".to_owned(),
            command: WorkerCommand::Hello(HelloCommand {
                minimum_protocol_version: 1,
                maximum_protocol_version: 1,
                client_name: "test".to_owned(),
                client_version: "1".to_owned(),
            }),
        };
        let payload = serde_json::to_vec(&request).unwrap();
        let mut bytes = Vec::new();
        write_payload(&mut bytes, &payload).unwrap();
        let mut reader = InterruptedOnce {
            interrupted: false,
            bytes: Cursor::new(bytes),
        };

        assert_eq!(read_request_frame(&mut reader).unwrap(), Some(request));
    }

    #[test]
    fn oversized_output_is_replaced_with_a_correlated_protocol_error() {
        let output = OutputEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: "session-test".to_owned(),
            sequence: 9,
            request_id: "analysis-1".to_owned(),
            output: WorkerOutput::Error(WorkerError {
                code: WorkerErrorCode::InternalWorkerFailure,
                engine_code: None,
                message: "x".repeat(MAX_FRAME_BYTES),
                retryable: false,
            }),
        };
        let mut bytes = Vec::new();

        write_output_frame_resilient(&mut bytes, &output).unwrap();

        let payload_length = u32::from_be_bytes(bytes[..4].try_into().unwrap()) as usize;
        assert!(payload_length <= MAX_FRAME_BYTES);
        let decoded: OutputEnvelope = serde_json::from_slice(&bytes[4..]).unwrap();
        assert_eq!(decoded.request_id, "analysis-1");
        assert_eq!(decoded.sequence, 9);
        assert!(matches!(
            decoded.output,
            WorkerOutput::Error(WorkerError {
                code: WorkerErrorCode::ResponseTooLarge,
                ..
            })
        ));
    }

    #[test]
    fn execution_submission_wire_shape_uses_fll_payloads_without_client_identity_leakage() {
        let request: RequestEnvelope = serde_json::from_value(serde_json::json!({
            "protocol_version": PROTOCOL_VERSION,
            "session_id": "session-test",
            "request_id": "submit-1",
            "command": {
                "type": "submit_execution",
                "payload": {
                    "client_task_id": "client-task-1",
                    "analysis_id": "analysis-1",
                    "expected_revision": 1,
                    "selection": {
                        "mode": "manual",
                        "selection": {
                            "candidate_id": "chain-1",
                            "overrides": {
                                "container": null,
                                "video_codec": null,
                                "audio_codec": null,
                                "output_pixel_format": null,
                                "preserves_hdr": null
                            }
                        }
                    },
                    "output": {
                        "requested_path": "/tmp/output.mp4",
                        "collision_policy": "fail_if_exists"
                    },
                    "priority": "foreground"
                }
            }
        }))
        .unwrap();
        let WorkerCommand::SubmitExecution(command) = request.command else {
            panic!("submit_execution must deserialize to its command variant");
        };
        assert_eq!(command.client_task_id, "client-task-1");
        assert_eq!(command.analysis_id.as_str(), "analysis-1");

        let event = WorkerEvent::ExecutionSubmitted {
            work_id: "work-1".to_owned(),
            client_task_id: command.client_task_id,
            submission: Box::new(ExecutionSubmissionResult {
                execution_id: framelean_core::TaskId::new("task-1").unwrap(),
                state: framelean_runtime::ExecutionTaskState::Queued,
                queue_position: 1,
                queue_revision: 7,
            }),
        };
        let encoded = serde_json::to_value(event).unwrap();
        assert_eq!(encoded["type"], "execution_submitted");
        assert_eq!(encoded["payload"]["client_task_id"], "client-task-1");
        assert_eq!(encoded["payload"]["submission"]["execution_id"], "task-1");
        assert_eq!(encoded["payload"]["submission"]["state"], "queued");
        assert_eq!(encoded["payload"]["submission"]["queue_position"], 1);
        assert_eq!(encoded["payload"]["submission"]["queue_revision"], 7);
        assert!(
            encoded["payload"]["submission"]
                .get("client_task_id")
                .is_none()
        );
    }
}
