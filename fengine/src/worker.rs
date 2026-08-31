use std::collections::{HashMap, HashSet, VecDeque};
use std::io::{self, BufReader, BufWriter};
use std::panic::{self, AssertUnwindSafe};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{self, Receiver, Sender, SyncSender, TrySendError};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use framelean_analysis::{
    ExpectedSourceFacts, MediaAnalysisStatus, MediaAnalyzeRequest, MediaSource, SourceFingerprint,
};
use framelean_core::{AnalysisId, EngineError, ErrorKind, Result};
use framelean_ffmpeg::{PreviewFramesRequest, VideoThumbnailRequest};
use framelean_runtime::{
    AnalysisSnapshotView, AnalyzeMediaResponse, AnalyzeTaskRequest, ExecutionSubmissionRequest,
    ExecutionSubmissionResult, RequestContext, TaskMode,
};

use crate::protocol::{
    AnalysisQueueEntrySnapshot, AnalysisQueuePosition, AnalyzeMediaCommand, ApplyQueueOrderCommand,
    BatchSubmissionItem, ClientSourceFacts, EngineStateSnapshot, ExecutionControlAction,
    ExecutionQueuePosition, HelloCommand, OutputEnvelope, PreviewFrameArtifactDocument,
    PreviewFramesDocument, QueueKind, QueueOrderResult, RequestEnvelope, TerminalAnalysisSnapshot,
    TerminalExecutionSnapshot, VideoThumbnailDocument, WorkState, WorkerCommand, WorkerError,
    WorkerErrorCode, WorkerEvent, WorkerOutput, WorkerResponse, read_request_frame,
    write_output_frame_resilient,
};
use crate::runtime_host::{RuntimeHost, build_default_runtime};
use crate::snapshot_store::{DirectorySnapshotStore, SnapshotStore};
use crate::work_queue::{QueuedWork, WorkPriority, WorkQueue};

static SESSION_SEQUENCE: AtomicU64 = AtomicU64::new(1);
const HEARTBEAT_TIMEOUT_MS: u64 = 15_000;
const MAX_REQUEST_ID_BYTES: usize = 256;
const MAX_COMMAND_BYTES: usize = 64 * 1024;
const MAX_CLIENT_ID_BYTES: usize = 256;
const MAX_CLIENT_LABEL_BYTES: usize = 128;
const MAX_ANALYSIS_ID_BYTES: usize = 128;
const MAX_QUEUED_WORK_ITEMS: usize = 128;
const DRAIN_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_REQUEST_CACHE_ENTRIES: usize = 512;
const MAX_REQUEST_CACHE_BYTES: usize = 8 * 1024 * 1024;
const REQUEST_CACHE_TTL: Duration = Duration::from_secs(30 * 60);
const MAX_TERMINAL_CACHE_ENTRIES: usize = 64;
const MAX_TERMINAL_EXECUTION_ENTRIES: usize = 128;
const MAX_TERMINAL_ANALYSIS_ENTRIES: usize = 128;
const MAX_TERMINAL_CACHE_BYTES: usize = 32 * 1024 * 1024;
const TERMINAL_CACHE_TTL: Duration = Duration::from_secs(30 * 60);
const MAX_INGRESS_MESSAGES: usize = 64;
const MAX_OUTPUT_MESSAGES: usize = 32;
const COORDINATOR_POLL_INTERVAL: Duration = Duration::from_millis(100);
const OUTPUT_BACKPRESSURE_TIMEOUT: Duration = Duration::from_secs(1);
const OUTPUT_DRAIN_TIMEOUT: Duration = Duration::from_secs(2);

#[derive(Debug, Clone, PartialEq, Eq)]
enum WorkPayload {
    Analyze(AnalyzeMediaCommand),
    GeneratePreviewFrames(crate::protocol::GeneratePreviewFramesCommand),
    GenerateVideoThumbnail(crate::protocol::GenerateVideoThumbnailCommand),
    GetSnapshot(crate::protocol::GetAnalysisSnapshotCommand),
    SubmitExecution(crate::protocol::SubmitExecutionCommand),
    ApplyQueueOrder(ApplyQueueOrderWork),
    GetEngineSnapshot,
    PreemptAndStart(crate::protocol::PreemptAndStartCommand),
    ControlExecution(crate::protocol::ControlExecutionCommand),
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ApplyQueueOrderWork {
    command: ApplyQueueOrderCommand,
    ordered_analysis_work_ids: Vec<String>,
    ordered_execution_ids: Vec<framelean_core::TaskId>,
    analysis_revision_matches: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct WorkItem {
    work_id: String,
    request_id: String,
    priority: WorkPriority,
    payload: WorkPayload,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct RequestRecord {
    command: WorkerCommand,
    work_id: Option<String>,
    immediate_response: Option<WorkerResponse>,
    cached_bytes: usize,
    recorded_at: Instant,
}

impl RequestRecord {
    fn new(
        command: WorkerCommand,
        work_id: Option<String>,
        immediate_response: Option<WorkerResponse>,
        recorded_at: Instant,
    ) -> Self {
        let cached_bytes = request_record_size(&command);
        Self {
            command,
            work_id,
            immediate_response,
            cached_bytes,
            recorded_at,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct WorkRecord {
    state: WorkState,
    analysis_id: Option<AnalysisId>,
    waiters: Vec<WorkWaiter>,
    terminal: Option<WorkTerminal>,
    terminal_bytes: usize,
    completed_at: Option<Instant>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum WorkTerminal {
    Analysis {
        analysis: Box<AnalyzeMediaResponse>,
        snapshot: Option<Box<AnalysisSnapshotView>>,
    },
    Snapshot(Box<AnalysisSnapshotView>),
    PreviewFrames(Box<PreviewFramesDocument>),
    VideoThumbnail(Box<VideoThumbnailDocument>),
    Execution(Box<ExecutionSubmissionResult>),
    EngineSnapshot(Box<EngineStateSnapshot>),
    QueueOrderApplied(Box<QueueOrderResult>),
    QueueOrderConflict {
        order_revision: u64,
        snapshot: Box<EngineStateSnapshot>,
    },
    ExecutionControl {
        execution_id: framelean_core::TaskId,
        state: framelean_runtime::ExecutionTaskState,
    },
    Failed(WorkerError),
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct WorkWaiter {
    request_id: String,
    client_task_id: Option<String>,
    client_file_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct AnalysisWorkKey {
    client_file_id: String,
    path: PathBuf,
    file_size_bytes: u64,
    modified_time_unix_nanos: Option<String>,
    task_mode: TaskMode,
}

impl From<&AnalyzeMediaCommand> for AnalysisWorkKey {
    fn from(command: &AnalyzeMediaCommand) -> Self {
        Self {
            client_file_id: command.client_file_id.clone(),
            path: command.source.path.clone(),
            file_size_bytes: command.source.file_size_bytes,
            modified_time_unix_nanos: command.source.modified_time_unix_nanos.clone(),
            task_mode: command.task_mode,
        }
    }
}

impl WorkWaiter {
    fn from_payload(request_id: &str, payload: &WorkPayload) -> Self {
        match payload {
            WorkPayload::Analyze(command) => Self {
                request_id: request_id.to_owned(),
                client_task_id: Some(command.client_task_id.clone()),
                client_file_id: Some(command.client_file_id.clone()),
            },
            WorkPayload::GeneratePreviewFrames(command) => Self {
                request_id: request_id.to_owned(),
                client_task_id: Some(command.client_task_id.clone()),
                client_file_id: None,
            },
            WorkPayload::GenerateVideoThumbnail(command) => Self {
                request_id: request_id.to_owned(),
                client_task_id: Some(command.client_task_id.clone()),
                client_file_id: None,
            },
            WorkPayload::GetSnapshot(_)
            | WorkPayload::SubmitExecution(_)
            | WorkPayload::ApplyQueueOrder(_)
            | WorkPayload::GetEngineSnapshot
            | WorkPayload::PreemptAndStart(_)
            | WorkPayload::ControlExecution(_) => Self {
                request_id: request_id.to_owned(),
                client_task_id: None,
                client_file_id: None,
            },
        }
    }
}

enum RuntimeCommand {
    Execute(Box<WorkItem>),
    Stop,
}

enum RuntimeResult {
    Ready,
    Fatal(WorkerError),
    Completed(Box<CompletedWork>),
}

struct CompletedWork {
    item: WorkItem,
    result: std::result::Result<RuntimeCompletion, WorkerError>,
}

enum RuntimeCompletion {
    Analysis {
        analysis: AnalyzeMediaResponse,
        snapshot: Option<Box<AnalysisSnapshotView>>,
    },
    Snapshot(AnalysisSnapshotView),
    PreviewFrames(PreviewFramesDocument),
    VideoThumbnail(VideoThumbnailDocument),
    Execution(ExecutionSubmissionResult),
    EngineSnapshot(framelean_runtime::ExecutionLaneSnapshot),
    QueueOrderApplied {
        order_revision: u64,
        execution_lane: framelean_runtime::ExecutionLaneSnapshot,
    },
    QueueOrderConflict {
        order_revision: u64,
        execution_lane: framelean_runtime::ExecutionLaneSnapshot,
    },
    ExecutionControl {
        execution_id: framelean_core::TaskId,
        state: framelean_runtime::ExecutionTaskState,
    },
}

enum CoordinatorMessage {
    Request {
        request: Box<RequestEnvelope>,
        received_at: Instant,
    },
    Runtime(RuntimeResult),
    RuntimeExecutionEvent(framelean_runtime::ExecutionRuntimeEvent),
    HeartbeatTimedOut,
    DrainTimedOut,
    InputClosed,
    InputFailed(String),
}

pub struct WorkerCoordinator {
    session_id: Option<String>,
    sequence: u64,
    next_work_number: u64,
    handshake_ready: bool,
    runtime_ready: bool,
    draining: bool,
    shutdown_request_id: Option<String>,
    stopping: bool,
    abort_executor: bool,
    last_client_contact: Option<Instant>,
    drain_deadline: Option<Instant>,
    termination_error: Option<String>,
    active_work_id: Option<String>,
    active_analysis: Option<AnalysisQueueEntrySnapshot>,
    analysis_queue: WorkQueue<WorkPayload>,
    control_queue: WorkQueue<WorkPayload>,
    requests: HashMap<(String, String), RequestRecord>,
    request_order: VecDeque<(String, String)>,
    request_cache_bytes: usize,
    works: HashMap<String, WorkRecord>,
    terminal_order: VecDeque<String>,
    terminal_cache_bytes: usize,
    analysis_work: HashMap<AnalysisWorkKey, String>,
    hello_request: Option<(String, HelloCommand)>,
    execution_clients: HashMap<framelean_core::TaskId, String>,
    execution_order: Vec<framelean_core::TaskId>,
    terminal_analyses: VecDeque<TerminalAnalysisSnapshot>,
    terminal_executions: VecDeque<TerminalExecutionSnapshot>,
}

impl WorkerCoordinator {
    pub fn new() -> Self {
        Self {
            session_id: None,
            sequence: 0,
            next_work_number: 1,
            handshake_ready: false,
            runtime_ready: false,
            draining: false,
            shutdown_request_id: None,
            stopping: false,
            abort_executor: false,
            last_client_contact: None,
            drain_deadline: None,
            termination_error: None,
            active_work_id: None,
            active_analysis: None,
            analysis_queue: WorkQueue::new(),
            control_queue: WorkQueue::new(),
            requests: HashMap::new(),
            request_order: VecDeque::new(),
            request_cache_bytes: 0,
            works: HashMap::new(),
            terminal_order: VecDeque::new(),
            terminal_cache_bytes: 0,
            analysis_work: HashMap::new(),
            hello_request: None,
            execution_clients: HashMap::new(),
            execution_order: Vec::new(),
            terminal_analyses: VecDeque::new(),
            terminal_executions: VecDeque::new(),
        }
    }

    #[cfg(test)]
    fn handle_request(
        &mut self,
        request: RequestEnvelope,
        runtime_tx: &Sender<RuntimeCommand>,
    ) -> Vec<OutputEnvelope> {
        self.handle_request_received_at(request, Instant::now(), runtime_tx)
    }

    fn handle_request_received_at(
        &mut self,
        request: RequestEnvelope,
        received_at: Instant,
        runtime_tx: &Sender<RuntimeCommand>,
    ) -> Vec<OutputEnvelope> {
        if request.protocol_version != crate::protocol::PROTOCOL_VERSION {
            return vec![self.error_output(
                request.request_id,
                WorkerError {
                    code: WorkerErrorCode::ProtocolVersionUnsupported,
                    engine_code: None,
                    message: "unsupported protocol version".to_owned(),
                    retryable: false,
                },
            )];
        }
        if request.request_id.trim().is_empty() || request.request_id.len() > MAX_REQUEST_ID_BYTES {
            return vec![self.error_output(
                "invalid-request".to_owned(),
                invalid_request("request_id is empty or exceeds the protocol limit"),
            )];
        }
        if bounded_json_size(&request.command, MAX_COMMAND_BYTES).is_none() {
            return vec![self.error_output(
                request.request_id,
                invalid_request("request command exceeds the protocol limit"),
            )];
        }
        if let Err(error) = validate_command(&request.command) {
            return vec![self.error_output(request.request_id, error)];
        }

        if matches!(request.command, WorkerCommand::Hello(_)) {
            return self.handle_hello(request, received_at);
        }
        let Some(session_id) = &self.session_id else {
            return vec![self.error_output(
                request.request_id,
                WorkerError {
                    code: WorkerErrorCode::HandshakeRequired,
                    engine_code: None,
                    message: "hello must be completed before other requests".to_owned(),
                    retryable: false,
                },
            )];
        };
        if request.session_id.as_deref() != Some(session_id.as_str()) {
            return vec![self.error_output(
                request.request_id,
                WorkerError {
                    code: WorkerErrorCode::SessionMismatch,
                    engine_code: None,
                    message: "request session does not match the active session".to_owned(),
                    retryable: false,
                },
            )];
        }
        self.last_client_contact = Some(received_at);
        let key = (session_id.clone(), request.request_id.clone());
        if let Some(previous) = self.requests.get(&key).cloned() {
            if previous.command != request.command {
                return vec![self.error_output(
                    request.request_id,
                    WorkerError {
                        code: WorkerErrorCode::IdempotencyKeyReused,
                        engine_code: None,
                        message: "request_id was already used for a different command".to_owned(),
                        retryable: false,
                    },
                )];
            }
            return if let Some(response) = previous.immediate_response {
                vec![self.response_output(request.request_id, response)]
            } else {
                self.replay_work(request.request_id, previous.work_id, &request.command, true)
            };
        }
        if self.draining {
            return vec![self.error_output(
                request.request_id,
                WorkerError {
                    code: WorkerErrorCode::WorkerDraining,
                    engine_code: None,
                    message: "worker is draining and no longer accepts requests".to_owned(),
                    retryable: true,
                },
            )];
        }
        let request_record_bytes = request_record_size(&request.command);
        if !self.ensure_request_cache_capacity(request_record_bytes, received_at) {
            return vec![self.error_output(
                request.request_id,
                WorkerError {
                    code: WorkerErrorCode::WorkerBusy,
                    engine_code: None,
                    message: "worker idempotency cache capacity has been reached".to_owned(),
                    retryable: true,
                },
            )];
        }

        match request.command.clone() {
            WorkerCommand::AnalyzeMedia(command) => {
                let analysis_key = AnalysisWorkKey::from(&command);
                if !command.force_reanalysis
                    && let Some(work_id) = self.analysis_work.get(&analysis_key).cloned()
                    && self.analysis_work_is_reusable(&work_id)
                {
                    self.cache_request(
                        key,
                        RequestRecord::new(
                            request.command,
                            Some(work_id.clone()),
                            None,
                            received_at,
                        ),
                    );
                    if let Some(record) = self.works.get_mut(&work_id).filter(|record| {
                        matches!(record.state, WorkState::Queued | WorkState::Running)
                    }) {
                        record.waiters.push(WorkWaiter {
                            request_id: request.request_id.clone(),
                            client_task_id: Some(command.client_task_id.clone()),
                            client_file_id: Some(command.client_file_id.clone()),
                        });
                    }
                    return self.replay_work(
                        request.request_id,
                        Some(work_id),
                        &WorkerCommand::AnalyzeMedia(command),
                        true,
                    );
                }
                self.enqueue_work(
                    request.request_id,
                    request.command,
                    WorkPayload::Analyze(command),
                    runtime_tx,
                )
            }
            WorkerCommand::SubmitAnalysisBatch(command) => {
                let items = command
                    .items
                    .iter()
                    .cloned()
                    .map(|item| {
                        (
                            item.client_task_id.clone(),
                            WorkerCommand::AnalyzeMedia(item.clone()),
                            WorkPayload::Analyze(item),
                        )
                    })
                    .collect();
                self.enqueue_batch(
                    request.request_id,
                    request.command,
                    items,
                    runtime_tx,
                    received_at,
                )
            }
            WorkerCommand::GetAnalysisSnapshot(command) => self.enqueue_work(
                request.request_id,
                request.command,
                WorkPayload::GetSnapshot(command),
                runtime_tx,
            ),
            WorkerCommand::GeneratePreviewFrames(command) => self.enqueue_work(
                request.request_id,
                request.command,
                WorkPayload::GeneratePreviewFrames(command),
                runtime_tx,
            ),
            WorkerCommand::GenerateVideoThumbnail(command) => self.enqueue_work(
                request.request_id,
                request.command,
                WorkPayload::GenerateVideoThumbnail(command),
                runtime_tx,
            ),
            WorkerCommand::SubmitExecution(command) => self.enqueue_work(
                request.request_id,
                request.command,
                WorkPayload::SubmitExecution(command),
                runtime_tx,
            ),
            WorkerCommand::SubmitExecutionBatch(command) => {
                let items = command
                    .items
                    .iter()
                    .cloned()
                    .map(|item| {
                        (
                            item.client_task_id.clone(),
                            WorkerCommand::SubmitExecution(item.clone()),
                            WorkPayload::SubmitExecution(item),
                        )
                    })
                    .collect();
                self.enqueue_batch(
                    request.request_id,
                    request.command,
                    items,
                    runtime_tx,
                    received_at,
                )
            }
            WorkerCommand::ApplyQueueOrder(command) => {
                let ordered_execution_ids = command
                    .ordered_task_ids
                    .iter()
                    .flat_map(|client_task_id| {
                        self.execution_order.iter().filter(|execution_id| {
                            self.execution_clients.get(*execution_id) == Some(client_task_id)
                        })
                    })
                    .cloned()
                    .collect();
                self.enqueue_work(
                    request.request_id,
                    request.command,
                    WorkPayload::ApplyQueueOrder(ApplyQueueOrderWork {
                        command,
                        ordered_analysis_work_ids: Vec::new(),
                        ordered_execution_ids,
                        analysis_revision_matches: false,
                    }),
                    runtime_tx,
                )
            }
            WorkerCommand::GetEngineSnapshot => self.enqueue_work(
                request.request_id,
                request.command,
                WorkPayload::GetEngineSnapshot,
                runtime_tx,
            ),
            WorkerCommand::PreemptAndStart(command) => self.enqueue_work(
                request.request_id,
                request.command,
                WorkPayload::PreemptAndStart(command),
                runtime_tx,
            ),
            WorkerCommand::ControlExecution(command) => self.enqueue_work(
                request.request_id,
                request.command,
                WorkPayload::ControlExecution(command),
                runtime_tx,
            ),
            WorkerCommand::Ping => {
                self.cache_request(
                    key,
                    RequestRecord::new(
                        request.command,
                        None,
                        Some(WorkerResponse::Pong),
                        received_at,
                    ),
                );
                vec![self.response_output(request.request_id, WorkerResponse::Pong)]
            }
            WorkerCommand::Shutdown => {
                self.draining = true;
                self.last_client_contact = None;
                self.drain_deadline = Some(received_at + DRAIN_TIMEOUT);
                self.shutdown_request_id = Some(request.request_id.clone());
                self.cache_request(
                    key,
                    RequestRecord::new(
                        request.command,
                        None,
                        Some(WorkerResponse::ShutdownAccepted),
                        received_at,
                    ),
                );
                let mut output = vec![
                    self.response_output(request.request_id, WorkerResponse::ShutdownAccepted),
                ];
                self.dispatch_next(runtime_tx, &mut output);
                output
            }
            WorkerCommand::Hello(_) => unreachable!("hello was handled above"),
        }
    }

    fn ensure_request_cache_capacity(&mut self, additional_bytes: usize, now: Instant) -> bool {
        self.prune_request_cache(now, 1, additional_bytes);
        self.requests.len() < MAX_REQUEST_CACHE_ENTRIES
            && self
                .request_cache_bytes
                .checked_add(additional_bytes)
                .is_some_and(|bytes| bytes <= MAX_REQUEST_CACHE_BYTES)
    }

    fn cache_request(&mut self, key: (String, String), record: RequestRecord) {
        debug_assert!(!self.requests.contains_key(&key));
        self.request_cache_bytes = self.request_cache_bytes.saturating_add(record.cached_bytes);
        self.request_order.push_back(key.clone());
        self.requests.insert(key, record);
    }

    fn prune_request_cache(
        &mut self,
        now: Instant,
        additional_entries: usize,
        additional_bytes: usize,
    ) {
        loop {
            let over_limit = self.requests.len().saturating_add(additional_entries)
                > MAX_REQUEST_CACHE_ENTRIES
                || self.request_cache_bytes.saturating_add(additional_bytes)
                    > MAX_REQUEST_CACHE_BYTES;
            let candidate = self.request_order.iter().position(|key| {
                self.requests.get(key).is_some_and(|record| {
                    let expired =
                        now.saturating_duration_since(record.recorded_at) >= REQUEST_CACHE_TTL;
                    let evictable = record.immediate_response.is_some()
                        || record.work_id.as_ref().is_none_or(|work_id| {
                            self.works
                                .get(work_id)
                                .is_none_or(|work| work.terminal.is_some())
                        });
                    evictable && (expired || over_limit)
                })
            });
            let Some(position) = candidate else {
                break;
            };
            let key = self
                .request_order
                .remove(position)
                .expect("request cache position is valid");
            if let Some(record) = self.requests.remove(&key) {
                self.request_cache_bytes =
                    self.request_cache_bytes.saturating_sub(record.cached_bytes);
            }
        }
    }

    fn remove_cached_requests_for_work(&mut self, work_id: &str) {
        let keys: Vec<_> = self
            .requests
            .iter()
            .filter(|(_, record)| record.work_id.as_deref() == Some(work_id))
            .map(|(key, _)| key.clone())
            .collect();
        for key in keys {
            if let Some(record) = self.requests.remove(&key) {
                self.request_cache_bytes =
                    self.request_cache_bytes.saturating_sub(record.cached_bytes);
            }
            if let Some(position) = self.request_order.iter().position(|value| value == &key) {
                self.request_order.remove(position);
            }
        }
    }

    fn handle_hello(
        &mut self,
        request: RequestEnvelope,
        received_at: Instant,
    ) -> Vec<OutputEnvelope> {
        let WorkerCommand::Hello(hello) = request.command else {
            unreachable!("hello matcher guarantees command type");
        };
        if request.session_id.is_some() {
            return vec![self.error_output(
                request.request_id,
                invalid_request("hello cannot include a session_id"),
            )];
        }
        if hello.minimum_protocol_version > hello.maximum_protocol_version
            || hello.minimum_protocol_version > crate::protocol::PROTOCOL_VERSION
            || hello.maximum_protocol_version < crate::protocol::PROTOCOL_VERSION
        {
            return vec![self.error_output(
                request.request_id,
                WorkerError {
                    code: WorkerErrorCode::ProtocolVersionUnsupported,
                    engine_code: None,
                    message: "no compatible protocol version was offered".to_owned(),
                    retryable: false,
                },
            )];
        }
        if let Some((previous_request_id, previous_hello)) = &self.hello_request {
            if previous_request_id == &request.request_id && previous_hello == &hello {
                self.last_client_contact = Some(received_at);
                return vec![self.response_output(
                    request.request_id,
                    WorkerResponse::Hello {
                        negotiated_protocol_version: crate::protocol::PROTOCOL_VERSION,
                        engine_version: env!("CARGO_PKG_VERSION").to_owned(),
                        heartbeat_timeout_ms: HEARTBEAT_TIMEOUT_MS,
                        resumed: true,
                    },
                )];
            }
            if previous_request_id == &request.request_id {
                return vec![self.error_output(
                    request.request_id,
                    WorkerError {
                        code: WorkerErrorCode::IdempotencyKeyReused,
                        engine_code: None,
                        message: "hello request_id was reused with different content".to_owned(),
                        retryable: false,
                    },
                )];
            }
            self.hello_request = Some((request.request_id.clone(), hello));
            self.handshake_ready = true;
            self.last_client_contact = Some(received_at);
            return vec![self.response_output(
                request.request_id,
                WorkerResponse::Hello {
                    negotiated_protocol_version: crate::protocol::PROTOCOL_VERSION,
                    engine_version: env!("CARGO_PKG_VERSION").to_owned(),
                    heartbeat_timeout_ms: HEARTBEAT_TIMEOUT_MS,
                    resumed: true,
                },
            )];
        }
        if hello.client_name.trim().is_empty() || hello.client_version.trim().is_empty() {
            return vec![self.error_output(
                request.request_id,
                invalid_request("client_name and client_version are required"),
            )];
        }
        let session_id = new_session_id();
        self.session_id = Some(session_id);
        self.hello_request = Some((request.request_id.clone(), hello));
        self.handshake_ready = true;
        self.last_client_contact = Some(received_at);
        vec![self.response_output(
            request.request_id,
            WorkerResponse::Hello {
                negotiated_protocol_version: crate::protocol::PROTOCOL_VERSION,
                engine_version: env!("CARGO_PKG_VERSION").to_owned(),
                heartbeat_timeout_ms: HEARTBEAT_TIMEOUT_MS,
                resumed: false,
            },
        )]
    }

    fn enqueue_work(
        &mut self,
        request_id: String,
        command: WorkerCommand,
        payload: WorkPayload,
        runtime_tx: &Sender<RuntimeCommand>,
    ) -> Vec<OutputEnvelope> {
        self.enqueue_work_internal(request_id, command, payload, runtime_tx, true)
    }

    fn enqueue_work_internal(
        &mut self,
        request_id: String,
        command: WorkerCommand,
        payload: WorkPayload,
        runtime_tx: &Sender<RuntimeCommand>,
        dispatch: bool,
    ) -> Vec<OutputEnvelope> {
        if self
            .analysis_queue
            .len()
            .saturating_add(self.control_queue.len())
            >= MAX_QUEUED_WORK_ITEMS
            && self.active_work_id.is_some()
        {
            return vec![self.error_output(
                request_id,
                WorkerError {
                    code: WorkerErrorCode::WorkerBusy,
                    engine_code: None,
                    message: "worker queue capacity has been reached".to_owned(),
                    retryable: true,
                },
            )];
        }
        let priority = match &payload {
            WorkPayload::Analyze(value) => value.priority,
            WorkPayload::GeneratePreviewFrames(value) => value.priority,
            WorkPayload::GenerateVideoThumbnail(value) => value.priority,
            WorkPayload::GetSnapshot(value) => value.priority,
            WorkPayload::SubmitExecution(value) => value.priority,
            WorkPayload::ApplyQueueOrder(_) => WorkPriority::Foreground,
            WorkPayload::GetEngineSnapshot | WorkPayload::ControlExecution(_) => {
                WorkPriority::Normal
            }
            WorkPayload::PreemptAndStart(_) => WorkPriority::Foreground,
        };
        let work_id = format!("work-{}", self.next_work_number);
        self.next_work_number = self.next_work_number.saturating_add(1);
        let item = WorkItem {
            work_id: work_id.clone(),
            request_id: request_id.clone(),
            priority,
            payload,
        };
        let queue_kind = work_queue_kind(&item.payload);
        let (queue_position, queue_revision) = {
            let queue = match queue_kind {
                QueueKind::Analysis => &mut self.analysis_queue,
                QueueKind::Control => &mut self.control_queue,
                QueueKind::Execution => unreachable!("media executions are owned by FLL"),
            };
            let position = queue.enqueue(QueuedWork {
                work_id: item.work_id.clone(),
                request_id: item.request_id.clone(),
                priority: item.priority,
                payload: item.payload.clone(),
            });
            (position, queue.revision())
        };
        let session_id = self.session_id.clone().expect("handshake established");
        self.cache_request(
            (session_id, request_id.clone()),
            RequestRecord::new(command, Some(work_id.clone()), None, Instant::now()),
        );
        self.works.insert(
            work_id.clone(),
            WorkRecord {
                state: WorkState::Queued,
                analysis_id: None,
                waiters: vec![WorkWaiter::from_payload(&request_id, &item.payload)],
                terminal: None,
                terminal_bytes: 0,
                completed_at: None,
            },
        );
        if let WorkPayload::Analyze(command) = &item.payload {
            self.analysis_work
                .insert(AnalysisWorkKey::from(command), work_id.clone());
        }
        let mut output = vec![
            self.accepted_output(request_id.clone(), Some(work_id.clone()), false),
            self.event_output(
                request_id,
                WorkerEvent::WorkQueued {
                    work_id,
                    client_task_id: client_task_id_for_payload(&item.payload),
                    queue_kind,
                    queue_position,
                    queue_revision,
                },
            ),
        ];
        if dispatch {
            self.dispatch_next(runtime_tx, &mut output);
        }
        output
    }

    fn enqueue_batch(
        &mut self,
        request_id: String,
        command: WorkerCommand,
        items: Vec<(String, WorkerCommand, WorkPayload)>,
        runtime_tx: &Sender<RuntimeCommand>,
        received_at: Instant,
    ) -> Vec<OutputEnvelope> {
        let queued = self
            .analysis_queue
            .len()
            .saturating_add(self.control_queue.len());
        if queued.saturating_add(items.len()) > MAX_QUEUED_WORK_ITEMS
            || self.requests.len().saturating_add(items.len()) > MAX_REQUEST_CACHE_ENTRIES
        {
            return vec![self.error_output(
                request_id,
                WorkerError {
                    code: WorkerErrorCode::WorkerBusy,
                    engine_code: None,
                    message: "batch cannot be accepted atomically within queue capacity".to_owned(),
                    retryable: true,
                },
            )];
        }

        let mut output = Vec::new();
        let mut accepted_items = Vec::with_capacity(items.len());
        for (client_task_id, child_command, payload) in items {
            // Child request IDs are server-owned and intentionally independent
            // of the caller-provided parent ID. Besides keeping them stable in
            // the cached BatchAccepted response, this guarantees that a valid
            // maximum-length parent ID cannot produce an invalid (>256 byte)
            // child ID when the Client later reattaches to that work.
            let child_request_id = format!("batch-child:work-{}", self.next_work_number);
            let child_outputs = self.enqueue_work_internal(
                child_request_id.clone(),
                child_command,
                payload,
                runtime_tx,
                false,
            );
            let accepted = child_outputs
                .first()
                .and_then(|envelope| match &envelope.output {
                    WorkerOutput::Response(WorkerResponse::Accepted {
                        work_id,
                        queue_kind,
                        queue_position,
                        queue_revision,
                        ..
                    }) => Some(BatchSubmissionItem {
                        client_task_id,
                        child_request_id: child_request_id.clone(),
                        work_id: work_id.clone(),
                        queue_kind: *queue_kind,
                        queue_position: *queue_position,
                        queue_revision: *queue_revision,
                    }),
                    _ => None,
                });
            let Some(accepted) = accepted else {
                return vec![self.error_output(
                    request_id,
                    invalid_worker_failure("batch child did not produce an acceptance record"),
                )];
            };
            accepted_items.push(accepted);
            output.extend(child_outputs);
        }

        let response = WorkerResponse::BatchAccepted {
            items: accepted_items,
        };
        let session_id = self.session_id.clone().expect("handshake established");
        self.cache_request(
            (session_id, request_id.clone()),
            RequestRecord::new(command, None, Some(response.clone()), received_at),
        );
        output.push(self.response_output(request_id, response));
        self.dispatch_next(runtime_tx, &mut output);
        output
    }

    fn dispatch_next(
        &mut self,
        runtime_tx: &Sender<RuntimeCommand>,
        output: &mut Vec<OutputEnvelope>,
    ) {
        if self.active_work_id.is_none()
            && self.analysis_queue.is_empty()
            && self.control_queue.is_empty()
            && self.draining
        {
            self.stopping = true;
            self.drain_deadline = None;
            if let Some(request_id) = self.shutdown_request_id.take() {
                output.push(self.event_output(request_id, WorkerEvent::ShutdownComplete));
            }
            return;
        }
        if !self.handshake_ready
            || !self.runtime_ready
            || self.active_work_id.is_some()
            || self.stopping
        {
            return;
        }
        let (queued, queue_kind, queue_remaining, queue_revision) =
            if let Some(queued) = self.control_queue.dequeue() {
                (
                    queued,
                    QueueKind::Control,
                    self.control_queue.len(),
                    self.control_queue.revision(),
                )
            } else if let Some(queued) = self.analysis_queue.dequeue() {
                (
                    queued,
                    QueueKind::Analysis,
                    self.analysis_queue.len(),
                    self.analysis_queue.revision(),
                )
            } else {
                return;
            };
        let mut item = WorkItem {
            work_id: queued.work_id,
            request_id: queued.request_id,
            priority: queued.priority,
            payload: queued.payload,
        };
        if let WorkPayload::ApplyQueueOrder(work) = &mut item.payload {
            let mut requested = HashSet::new();
            let order_is_unique = work
                .command
                .ordered_task_ids
                .iter()
                .all(|client_task_id| requested.insert(client_task_id.as_str()));
            let ordered_analysis_work_ids: Vec<_> = work
                .command
                .ordered_task_ids
                .iter()
                .flat_map(|client_task_id| {
                    self.analysis_queue.entries().filter_map(|queued| {
                        let WorkPayload::Analyze(command) = &queued.payload else {
                            return None;
                        };
                        (command.client_task_id == *client_task_id).then(|| queued.work_id.clone())
                    })
                })
                .collect();
            work.analysis_revision_matches = order_is_unique
                && work.command.expected_analysis_queue_revision == self.analysis_queue.revision()
                && ordered_analysis_work_ids.len() == self.analysis_queue.len();
            work.ordered_analysis_work_ids = ordered_analysis_work_ids;
        }
        self.active_work_id = Some(item.work_id.clone());
        self.active_analysis = match &item.payload {
            WorkPayload::Analyze(command) => Some(AnalysisQueueEntrySnapshot {
                work_id: item.work_id.clone(),
                client_task_id: command.client_task_id.clone(),
                queue_position: 0,
            }),
            _ => None,
        };
        if let Some(record) = self.works.get_mut(&item.work_id) {
            record.state = WorkState::Running;
        }
        output.push(self.event_output(
            item.request_id.clone(),
            WorkerEvent::WorkStarted {
                work_id: item.work_id.clone(),
                client_task_id: client_task_id_for_payload(&item.payload),
                queue_kind,
                queue_remaining,
                queue_revision,
            },
        ));
        if runtime_tx
            .send(RuntimeCommand::Execute(Box::new(item.clone())))
            .is_err()
        {
            self.active_work_id = None;
            self.fail_work(
                item,
                invalid_worker_failure("runtime executor is unavailable"),
                output,
            );
        }
    }

    fn handle_runtime(
        &mut self,
        result: RuntimeResult,
        runtime_tx: &Sender<RuntimeCommand>,
    ) -> Vec<OutputEnvelope> {
        match result {
            RuntimeResult::Ready => {
                self.runtime_ready = true;
                let mut output = Vec::new();
                self.dispatch_next(runtime_tx, &mut output);
                output
            }
            RuntimeResult::Fatal(error) => {
                self.runtime_ready = false;
                self.stopping = true;
                self.termination_error = Some(error.message.clone());
                let mut output = self.fail_all_work(error.clone());
                output.push(self.error_output("runtime".to_owned(), error));
                output
            }
            RuntimeResult::Completed(completed) => {
                let CompletedWork { item, result } = *completed;
                let mut output = Vec::new();
                if self.active_work_id.as_deref() != Some(item.work_id.as_str()) {
                    output.push(self.error_output(
                        item.request_id,
                        invalid_worker_failure("runtime completed an unknown work item"),
                    ));
                    self.stopping = true;
                    self.termination_error =
                        Some("runtime completed an unknown work item".to_owned());
                    return output;
                }
                self.active_work_id = None;
                self.active_analysis = None;
                match result {
                    Err(error) => self.fail_work(item, error, &mut output),
                    Ok(RuntimeCompletion::Analysis { analysis, snapshot }) => {
                        let WorkPayload::Analyze(command) = &item.payload else {
                            unreachable!("analysis completion must match analysis work");
                        };
                        let failed = analysis.media_analysis_status == MediaAnalysisStatus::Failed;
                        self.terminal_analyses
                            .retain(|entry| entry.client_task_id != command.client_task_id);
                        self.terminal_analyses.push_back(TerminalAnalysisSnapshot {
                            work_id: item.work_id.clone(),
                            client_task_id: command.client_task_id.clone(),
                            client_file_id: command.client_file_id.clone(),
                            analysis_id: analysis.analysis_id.clone(),
                            analysis_revision: analysis.analysis_revision,
                            succeeded: !failed,
                            engine_code: analysis.error.as_ref().map(|error| error.code),
                            message: analysis.error.as_ref().map(|error| error.message.clone()),
                        });
                        while self.terminal_analyses.len() > MAX_TERMINAL_ANALYSIS_ENTRIES {
                            self.terminal_analyses.pop_front();
                        }
                        let analysis_id = (!failed).then(|| analysis.analysis_id.clone());
                        self.complete_work(
                            &item,
                            if failed {
                                WorkState::Failed
                            } else {
                                WorkState::Completed
                            },
                            analysis_id.clone(),
                            WorkTerminal::Analysis {
                                analysis: Box::new(analysis.clone()),
                                snapshot: snapshot.clone(),
                            },
                        );
                        self.remove_analysis_key(&item);
                        let waiters = self.take_waiters(&item.work_id);
                        for waiter in waiters {
                            output.push(self.event_output(
                                waiter.request_id,
                                WorkerEvent::AnalysisCompleted {
                                    work_id: item.work_id.clone(),
                                    client_task_id: waiter.client_task_id.unwrap_or_default(),
                                    client_file_id: waiter.client_file_id.unwrap_or_default(),
                                    analysis: Box::new(analysis.clone()),
                                    snapshot: snapshot.clone(),
                                },
                            ));
                        }
                    }
                    Ok(RuntimeCompletion::Snapshot(snapshot)) => {
                        self.complete_work(
                            &item,
                            WorkState::Completed,
                            Some(snapshot.analysis_id.clone()),
                            WorkTerminal::Snapshot(Box::new(snapshot.clone())),
                        );
                        output.push(self.event_output(
                            item.request_id,
                            WorkerEvent::AnalysisSnapshotReady {
                                work_id: item.work_id,
                                snapshot: Box::new(snapshot),
                            },
                        ));
                    }
                    Ok(RuntimeCompletion::PreviewFrames(result)) => {
                        let WorkPayload::GeneratePreviewFrames(command) = &item.payload else {
                            unreachable!("preview completion must match preview work");
                        };
                        self.complete_work(
                            &item,
                            WorkState::Completed,
                            None,
                            WorkTerminal::PreviewFrames(Box::new(result.clone())),
                        );
                        output.push(self.event_output(
                            item.request_id,
                            WorkerEvent::PreviewFramesReady {
                                work_id: item.work_id,
                                client_task_id: command.client_task_id.clone(),
                                result: Box::new(result),
                            },
                        ));
                    }
                    Ok(RuntimeCompletion::VideoThumbnail(result)) => {
                        let WorkPayload::GenerateVideoThumbnail(command) = &item.payload else {
                            unreachable!("thumbnail completion must match thumbnail work");
                        };
                        self.complete_work(
                            &item,
                            WorkState::Completed,
                            None,
                            WorkTerminal::VideoThumbnail(Box::new(result.clone())),
                        );
                        output.push(self.event_output(
                            item.request_id,
                            WorkerEvent::VideoThumbnailReady {
                                work_id: item.work_id,
                                client_task_id: command.client_task_id.clone(),
                                result: Box::new(result),
                            },
                        ));
                    }
                    Ok(RuntimeCompletion::Execution(submission)) => {
                        let WorkPayload::SubmitExecution(command) = &item.payload else {
                            unreachable!("execution completion must match execution work");
                        };
                        self.complete_work(
                            &item,
                            WorkState::Completed,
                            Some(command.analysis_id.clone()),
                            WorkTerminal::Execution(Box::new(submission.clone())),
                        );
                        self.execution_clients.insert(
                            submission.execution_id.clone(),
                            command.client_task_id.clone(),
                        );
                        self.execution_order.push(submission.execution_id.clone());
                        output.push(self.event_output(
                            item.request_id,
                            WorkerEvent::ExecutionSubmitted {
                                work_id: item.work_id,
                                client_task_id: command.client_task_id.clone(),
                                submission: Box::new(submission),
                            },
                        ));
                    }
                    Ok(RuntimeCompletion::EngineSnapshot(execution_lane)) => {
                        let snapshot = self.engine_state_snapshot(execution_lane);
                        self.complete_work(
                            &item,
                            WorkState::Completed,
                            None,
                            WorkTerminal::EngineSnapshot(Box::new(snapshot.clone())),
                        );
                        output.push(self.event_output(
                            item.request_id,
                            WorkerEvent::EngineSnapshotReady {
                                work_id: item.work_id,
                                snapshot: Box::new(snapshot),
                            },
                        ));
                    }
                    Ok(RuntimeCompletion::QueueOrderApplied {
                        order_revision,
                        execution_lane,
                    }) => {
                        let WorkPayload::ApplyQueueOrder(work) = &item.payload else {
                            unreachable!("queue-order completion must match queue-order work");
                        };
                        self.analysis_queue
                            .reorder(
                                work.command.expected_analysis_queue_revision,
                                &work.ordered_analysis_work_ids,
                            )
                            .expect("analysis order was validated before runtime mutation");
                        let result = self.queue_order_result(order_revision, &execution_lane);
                        self.complete_work(
                            &item,
                            WorkState::Completed,
                            None,
                            WorkTerminal::QueueOrderApplied(Box::new(result.clone())),
                        );
                        output.push(self.event_output(
                            item.request_id,
                            WorkerEvent::QueueOrderApplied {
                                work_id: item.work_id,
                                result: Box::new(result),
                            },
                        ));
                    }
                    Ok(RuntimeCompletion::QueueOrderConflict {
                        order_revision,
                        execution_lane,
                    }) => {
                        let snapshot = self.engine_state_snapshot(execution_lane);
                        self.complete_work(
                            &item,
                            WorkState::Completed,
                            None,
                            WorkTerminal::QueueOrderConflict {
                                order_revision,
                                snapshot: Box::new(snapshot.clone()),
                            },
                        );
                        output.push(self.event_output(
                            item.request_id,
                            WorkerEvent::QueueOrderConflict {
                                work_id: item.work_id,
                                order_revision,
                                snapshot: Box::new(snapshot),
                            },
                        ));
                    }
                    Ok(RuntimeCompletion::ExecutionControl {
                        execution_id,
                        state,
                    }) => {
                        self.complete_work(
                            &item,
                            WorkState::Completed,
                            None,
                            WorkTerminal::ExecutionControl {
                                execution_id: execution_id.clone(),
                                state,
                            },
                        );
                        output.push(self.event_output(
                            item.request_id,
                            WorkerEvent::ExecutionControlAccepted {
                                work_id: item.work_id,
                                execution_id,
                                state,
                            },
                        ));
                    }
                }
                self.dispatch_next(runtime_tx, &mut output);
                self.prune_terminal_cache(Instant::now());
                output
            }
        }
    }

    fn engine_state_snapshot(
        &self,
        execution_lane: framelean_runtime::ExecutionLaneSnapshot,
    ) -> EngineStateSnapshot {
        let analysis_queue = self
            .analysis_queue
            .entries()
            .filter_map(|queued| {
                let WorkPayload::Analyze(command) = &queued.payload else {
                    return None;
                };
                Some(AnalysisQueueEntrySnapshot {
                    work_id: queued.work_id.clone(),
                    client_task_id: command.client_task_id.clone(),
                    queue_position: self.analysis_queue.position(&queued.work_id).unwrap_or(0),
                })
            })
            .collect();
        EngineStateSnapshot {
            analysis_queue_revision: self.analysis_queue.revision(),
            active_analysis: self.active_analysis.clone(),
            analysis_queue,
            terminal_analyses: self.terminal_analyses.iter().cloned().collect(),
            execution_lane,
            terminal_executions: self.terminal_executions.iter().cloned().collect(),
            last_sequence: self.sequence,
        }
    }

    fn queue_order_result(
        &self,
        order_revision: u64,
        execution_lane: &framelean_runtime::ExecutionLaneSnapshot,
    ) -> QueueOrderResult {
        let analysis_positions = self
            .analysis_queue
            .entries()
            .enumerate()
            .filter_map(|(index, queued)| {
                let WorkPayload::Analyze(command) = &queued.payload else {
                    return None;
                };
                Some(AnalysisQueuePosition {
                    work_id: queued.work_id.clone(),
                    client_task_id: command.client_task_id.clone(),
                    queue_position: index + 1,
                })
            })
            .collect();
        let execution_positions = execution_lane
            .normal_waiting
            .iter()
            .enumerate()
            .map(|(index, entry)| ExecutionQueuePosition {
                execution_id: entry.execution_id.clone(),
                client_task_id: self
                    .execution_clients
                    .get(&entry.execution_id)
                    .cloned()
                    .unwrap_or_default(),
                queue_position: index + 1,
            })
            .collect();
        QueueOrderResult {
            order_revision,
            analysis_queue_revision: self.analysis_queue.revision(),
            execution_queue_revision: execution_lane.queue_revision,
            analysis_positions,
            execution_positions,
        }
    }

    fn handle_execution_event(
        &mut self,
        event: framelean_runtime::ExecutionRuntimeEvent,
    ) -> Vec<OutputEnvelope> {
        let client_task_id = self
            .execution_clients
            .get(&event.execution_id)
            .cloned()
            .unwrap_or_default();
        let request_id = format!("execution-event-{}", event.execution_id);
        if matches!(
            event.state,
            framelean_runtime::ExecutionTaskState::Completed
                | framelean_runtime::ExecutionTaskState::Failed
                | framelean_runtime::ExecutionTaskState::Cancelled
        ) {
            self.terminal_executions
                .retain(|entry| entry.execution_id != event.execution_id);
            self.terminal_executions
                .push_back(TerminalExecutionSnapshot {
                    execution_id: event.execution_id.clone(),
                    client_task_id: client_task_id.clone(),
                    resource_pool: event.resource_pool,
                    state: event.state,
                    output_path: event.output_path.clone(),
                    engine_code: event.error_code,
                    message: event.message.clone(),
                });
            while self.terminal_executions.len() > MAX_TERMINAL_EXECUTION_ENTRIES {
                self.terminal_executions.pop_front();
            }
        }
        let protocol_event = match event.state {
            framelean_runtime::ExecutionTaskState::Running if event.progress.is_some() => {
                WorkerEvent::ExecutionProgress {
                    execution_id: event.execution_id,
                    client_task_id,
                    resource_pool: event.resource_pool,
                    progress: event.progress.expect("progress state was checked"),
                    resume_depth: event.resume_depth,
                }
            }
            framelean_runtime::ExecutionTaskState::Running => WorkerEvent::ExecutionStarted {
                execution_id: event.execution_id,
                client_task_id,
                resource_pool: event.resource_pool,
                state: event.state,
                resume_depth: event.resume_depth,
            },
            framelean_runtime::ExecutionTaskState::Paused
            | framelean_runtime::ExecutionTaskState::Preempted => WorkerEvent::ExecutionPaused {
                execution_id: event.execution_id,
                client_task_id,
                resource_pool: event.resource_pool,
                pause_reason: event.pause_reason,
                preempted_by_execution_id: event.preempted_by_execution_id,
                resume_depth: event.resume_depth,
            },
            framelean_runtime::ExecutionTaskState::Resuming => WorkerEvent::ExecutionResumed {
                execution_id: event.execution_id,
                client_task_id,
                resource_pool: event.resource_pool,
                resume_depth: event.resume_depth,
            },
            framelean_runtime::ExecutionTaskState::Completed => WorkerEvent::ExecutionCompleted {
                execution_id: event.execution_id,
                client_task_id,
                resource_pool: event.resource_pool,
                output_path: event.output_path.unwrap_or_default(),
            },
            framelean_runtime::ExecutionTaskState::Failed => WorkerEvent::ExecutionFailed {
                execution_id: event.execution_id,
                client_task_id,
                resource_pool: event.resource_pool,
                engine_code: event.error_code,
                message: event
                    .message
                    .unwrap_or_else(|| "media execution failed".to_owned()),
                resume_depth: event.resume_depth,
            },
            framelean_runtime::ExecutionTaskState::Cancelled => WorkerEvent::ExecutionCancelled {
                execution_id: event.execution_id,
                client_task_id,
                resource_pool: event.resource_pool,
                resume_depth: event.resume_depth,
            },
            _ => WorkerEvent::ExecutionStateChanged {
                execution_id: event.execution_id,
                client_task_id,
                resource_pool: event.resource_pool,
                state: event.state,
                pause_reason: event.pause_reason,
                preempted_by_execution_id: event.preempted_by_execution_id,
                resume_depth: event.resume_depth,
            },
        };
        vec![self.event_output(request_id, protocol_event)]
    }

    fn handle_input_closed(&mut self, runtime_tx: &Sender<RuntimeCommand>) -> Vec<OutputEnvelope> {
        self.handle_input_closed_at(Instant::now(), runtime_tx)
    }

    fn handle_input_closed_at(
        &mut self,
        received_at: Instant,
        runtime_tx: &Sender<RuntimeCommand>,
    ) -> Vec<OutputEnvelope> {
        self.draining = true;
        self.last_client_contact = None;
        self.drain_deadline = Some(received_at + DRAIN_TIMEOUT);
        let mut output = Vec::new();
        self.dispatch_next(runtime_tx, &mut output);
        output
    }

    fn handle_input_failed(
        &mut self,
        message: String,
        runtime_tx: &Sender<RuntimeCommand>,
    ) -> Vec<OutputEnvelope> {
        self.draining = true;
        self.last_client_contact = None;
        self.drain_deadline = Some(Instant::now() + DRAIN_TIMEOUT);
        self.termination_error = Some(format!("protocol input failed: {message}"));
        let mut output = vec![self.error_output(
            "invalid-frame".to_owned(),
            WorkerError {
                code: WorkerErrorCode::InvalidFrame,
                engine_code: None,
                message,
                retryable: false,
            },
        )];
        self.dispatch_next(runtime_tx, &mut output);
        output
    }

    fn heartbeat_wait(&self, now: Instant) -> Option<Duration> {
        let last_contact = self.last_client_contact?;
        let deadline = last_contact + Duration::from_millis(HEARTBEAT_TIMEOUT_MS);
        Some(deadline.saturating_duration_since(now))
    }

    fn drain_wait(&self, now: Instant) -> Option<Duration> {
        self.drain_deadline
            .map(|deadline| deadline.saturating_duration_since(now))
    }

    fn coordinator_wait(&self, now: Instant) -> Option<Duration> {
        [self.heartbeat_wait(now), self.drain_wait(now)]
            .into_iter()
            .flatten()
            .min()
    }

    fn handle_drain_timeout(&mut self, now: Instant) -> Vec<OutputEnvelope> {
        if self
            .drain_wait(now)
            .is_none_or(|remaining| !remaining.is_zero())
        {
            return Vec::new();
        }
        self.drain_deadline = None;
        self.runtime_ready = false;
        self.stopping = true;
        self.abort_executor = true;
        self.termination_error
            .get_or_insert_with(|| "worker drain deadline expired".to_owned());
        let error = WorkerError {
            code: WorkerErrorCode::WorkerDraining,
            engine_code: None,
            message: "worker drain deadline expired".to_owned(),
            retryable: true,
        };
        let mut output = self.fail_all_work(error.clone());
        output.push(self.error_output("drain-timeout".to_owned(), error));
        output
    }

    fn handle_heartbeat_timeout(&mut self, now: Instant) -> Vec<OutputEnvelope> {
        if self
            .heartbeat_wait(now)
            .is_some_and(|remaining| !remaining.is_zero())
        {
            return Vec::new();
        }
        self.last_client_contact = None;
        self.runtime_ready = false;
        self.stopping = true;
        self.abort_executor = true;
        self.termination_error = Some("client heartbeat timed out".to_owned());
        let error = WorkerError {
            code: WorkerErrorCode::HeartbeatTimedOut,
            engine_code: None,
            message: "client heartbeat timed out".to_owned(),
            retryable: false,
        };
        let mut output = self.fail_all_work(error.clone());
        output.push(self.error_output("heartbeat".to_owned(), error));
        output
    }

    fn complete_work(
        &mut self,
        item: &WorkItem,
        state: WorkState,
        analysis_id: Option<AnalysisId>,
        terminal: WorkTerminal,
    ) {
        let terminal_bytes = terminal_size(&terminal);
        if let Some(record) = self.works.get_mut(&item.work_id) {
            if record.terminal.is_some() {
                self.terminal_cache_bytes = self
                    .terminal_cache_bytes
                    .saturating_sub(record.terminal_bytes);
            }
            record.state = state;
            record.analysis_id = analysis_id;
            record.terminal = Some(terminal);
            record.terminal_bytes = terminal_bytes;
            record.completed_at = Some(Instant::now());
            self.terminal_cache_bytes = self.terminal_cache_bytes.saturating_add(terminal_bytes);
            self.terminal_order.push_back(item.work_id.clone());
        }
    }

    fn fail_work(&mut self, item: WorkItem, error: WorkerError, output: &mut Vec<OutputEnvelope>) {
        let preemption_warning = match &item.payload {
            WorkPayload::PreemptAndStart(command) => Some((
                command.execution_id.clone(),
                self.execution_clients.get(&command.execution_id).cloned(),
            )),
            _ => None,
        };
        self.complete_work(
            &item,
            WorkState::Failed,
            None,
            WorkTerminal::Failed(error.clone()),
        );
        self.remove_analysis_key(&item);
        let waiters = self.take_waiters(&item.work_id);
        for waiter in waiters {
            output.push(self.event_output(
                waiter.request_id,
                WorkerEvent::WorkFailed {
                    work_id: item.work_id.clone(),
                    error: error.clone(),
                },
            ));
        }
        if let Some((execution_id, client_task_id)) = preemption_warning {
            output.push(self.event_output(
                format!("execution-warning-{execution_id}"),
                WorkerEvent::Warning {
                    client_task_id,
                    execution_id: Some(execution_id),
                    engine_code: error.engine_code,
                    message: error.message,
                },
            ));
        }
    }

    fn remove_analysis_key(&mut self, item: &WorkItem) {
        if let WorkPayload::Analyze(command) = &item.payload {
            let key = AnalysisWorkKey::from(command);
            if self.analysis_work.get(&key) == Some(&item.work_id) {
                self.analysis_work.remove(&key);
            }
        }
    }

    fn analysis_work_is_reusable(&self, work_id: &str) -> bool {
        let Some(record) = self.works.get(work_id) else {
            return false;
        };
        matches!(record.state, WorkState::Queued | WorkState::Running)
    }

    fn take_waiters(&mut self, work_id: &str) -> Vec<WorkWaiter> {
        self.works
            .get_mut(work_id)
            .map(|record| std::mem::take(&mut record.waiters))
            .unwrap_or_default()
    }

    fn prune_terminal_cache(&mut self, now: Instant) {
        loop {
            let over_limit = self.terminal_order.len() > MAX_TERMINAL_CACHE_ENTRIES
                || self.terminal_cache_bytes > MAX_TERMINAL_CACHE_BYTES;
            let candidate = self.terminal_order.iter().position(|work_id| {
                self.works.get(work_id).is_some_and(|record| {
                    record.terminal.is_some()
                        && (over_limit
                            || record.completed_at.is_some_and(|completed_at| {
                                now.saturating_duration_since(completed_at) >= TERMINAL_CACHE_TTL
                            }))
                })
            });
            let Some(position) = candidate else {
                break;
            };
            let work_id = self
                .terminal_order
                .remove(position)
                .expect("terminal cache position is valid");
            if let Some(record) = self.works.remove(&work_id) {
                self.terminal_cache_bytes = self
                    .terminal_cache_bytes
                    .saturating_sub(record.terminal_bytes);
            }
            self.analysis_work
                .retain(|_, analysis_work_id| analysis_work_id != &work_id);
            self.remove_cached_requests_for_work(&work_id);
        }
    }

    fn fail_all_work(&mut self, error: WorkerError) -> Vec<OutputEnvelope> {
        self.active_work_id = None;
        self.active_analysis = None;
        self.analysis_queue = WorkQueue::new();
        self.control_queue = WorkQueue::new();
        self.analysis_work.clear();
        let pending: Vec<_> = self
            .works
            .iter_mut()
            .filter(|(_, record)| record.terminal.is_none())
            .map(|(work_id, record)| {
                record.state = WorkState::Failed;
                record.analysis_id = None;
                record.terminal = Some(WorkTerminal::Failed(error.clone()));
                (work_id.clone(), record.waiters.clone())
            })
            .collect();
        let mut output = Vec::new();
        for (work_id, waiters) in pending {
            for waiter in waiters {
                output.push(self.event_output(
                    waiter.request_id,
                    WorkerEvent::WorkFailed {
                        work_id: work_id.clone(),
                        error: error.clone(),
                    },
                ));
            }
        }
        output
    }

    fn accepted_output(
        &mut self,
        request_id: String,
        work_id: Option<String>,
        deduplicated: bool,
    ) -> OutputEnvelope {
        let (state, analysis_id) = work_id
            .as_ref()
            .and_then(|value| {
                self.works
                    .get(value)
                    .map(|record| (record.state, record.analysis_id.clone()))
            })
            .unwrap_or((WorkState::Completed, None));
        let (queue_kind, position, queue_revision) = work_id
            .as_deref()
            .and_then(|value| {
                self.analysis_queue
                    .position(value)
                    .map(|position| {
                        (
                            QueueKind::Analysis,
                            position,
                            self.analysis_queue.revision(),
                        )
                    })
                    .or_else(|| {
                        self.control_queue.position(value).map(|position| {
                            (QueueKind::Control, position, self.control_queue.revision())
                        })
                    })
            })
            .unwrap_or((QueueKind::Control, 0, self.control_queue.revision()));
        self.response_output(
            request_id,
            WorkerResponse::Accepted {
                work_id: work_id.unwrap_or_default(),
                queue_kind,
                queue_position: position,
                queue_revision,
                state,
                analysis_id,
                deduplicated,
            },
        )
    }

    fn replay_work(
        &mut self,
        request_id: String,
        work_id: Option<String>,
        command: &WorkerCommand,
        deduplicated: bool,
    ) -> Vec<OutputEnvelope> {
        let mut outputs =
            vec![self.accepted_output(request_id.clone(), work_id.clone(), deduplicated)];
        let Some(work_id) = work_id else {
            return outputs;
        };
        let terminal = self
            .works
            .get(&work_id)
            .and_then(|record| record.terminal.clone());
        let Some(terminal) = terminal else {
            return outputs;
        };
        let event = match (terminal, command) {
            (
                WorkTerminal::Analysis { analysis, snapshot },
                WorkerCommand::AnalyzeMedia(command),
            ) => WorkerEvent::AnalysisCompleted {
                work_id,
                client_task_id: command.client_task_id.clone(),
                client_file_id: command.client_file_id.clone(),
                analysis,
                snapshot,
            },
            (WorkTerminal::Snapshot(snapshot), WorkerCommand::GetAnalysisSnapshot(_)) => {
                WorkerEvent::AnalysisSnapshotReady { work_id, snapshot }
            }
            (
                WorkTerminal::PreviewFrames(result),
                WorkerCommand::GeneratePreviewFrames(command),
            ) => WorkerEvent::PreviewFramesReady {
                work_id,
                client_task_id: command.client_task_id.clone(),
                result,
            },
            (
                WorkTerminal::VideoThumbnail(result),
                WorkerCommand::GenerateVideoThumbnail(command),
            ) => WorkerEvent::VideoThumbnailReady {
                work_id,
                client_task_id: command.client_task_id.clone(),
                result,
            },
            (WorkTerminal::Execution(submission), WorkerCommand::SubmitExecution(command)) => {
                WorkerEvent::ExecutionSubmitted {
                    work_id,
                    client_task_id: command.client_task_id.clone(),
                    submission,
                }
            }
            (WorkTerminal::EngineSnapshot(snapshot), WorkerCommand::GetEngineSnapshot) => {
                WorkerEvent::EngineSnapshotReady { work_id, snapshot }
            }
            (WorkTerminal::QueueOrderApplied(result), WorkerCommand::ApplyQueueOrder(_)) => {
                WorkerEvent::QueueOrderApplied { work_id, result }
            }
            (
                WorkTerminal::QueueOrderConflict {
                    order_revision,
                    snapshot,
                },
                WorkerCommand::ApplyQueueOrder(_),
            ) => WorkerEvent::QueueOrderConflict {
                work_id,
                order_revision,
                snapshot,
            },
            (
                WorkTerminal::ExecutionControl {
                    execution_id,
                    state,
                },
                WorkerCommand::PreemptAndStart(_) | WorkerCommand::ControlExecution(_),
            ) => WorkerEvent::ExecutionControlAccepted {
                work_id,
                execution_id,
                state,
            },
            (WorkTerminal::Failed(error), _) => WorkerEvent::WorkFailed { work_id, error },
            _ => {
                return vec![self.error_output(
                    request_id,
                    invalid_worker_failure("recorded work outcome does not match request"),
                )];
            }
        };
        outputs.push(self.event_output(request_id, event));
        outputs
    }

    fn response_output(&mut self, request_id: String, response: WorkerResponse) -> OutputEnvelope {
        self.output(request_id, WorkerOutput::Response(response))
    }

    fn event_output(&mut self, request_id: String, event: WorkerEvent) -> OutputEnvelope {
        self.output(request_id, WorkerOutput::Event(event))
    }

    fn error_output(&mut self, request_id: String, error: WorkerError) -> OutputEnvelope {
        self.output(request_id, WorkerOutput::Error(error))
    }

    fn output(&mut self, request_id: String, output: WorkerOutput) -> OutputEnvelope {
        self.sequence = self.sequence.saturating_add(1);
        OutputEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: self
                .session_id
                .clone()
                .unwrap_or_else(|| "uninitialized".to_owned()),
            sequence: self.sequence,
            request_id,
            output,
        }
    }
}

impl Default for WorkerCoordinator {
    fn default() -> Self {
        Self::new()
    }
}

fn request_record_size(command: &WorkerCommand) -> usize {
    bounded_json_size(command, MAX_COMMAND_BYTES)
        .unwrap_or(MAX_COMMAND_BYTES)
        .saturating_add(256)
}

fn terminal_size(terminal: &WorkTerminal) -> usize {
    let size = match terminal {
        WorkTerminal::Analysis { analysis, snapshot } => {
            bounded_json_size(&(analysis, snapshot), MAX_TERMINAL_CACHE_BYTES)
        }
        WorkTerminal::Snapshot(value) => bounded_json_size(value, MAX_TERMINAL_CACHE_BYTES),
        WorkTerminal::PreviewFrames(value) => bounded_json_size(value, MAX_TERMINAL_CACHE_BYTES),
        WorkTerminal::VideoThumbnail(value) => bounded_json_size(value, MAX_TERMINAL_CACHE_BYTES),
        WorkTerminal::Execution(value) => bounded_json_size(value, MAX_TERMINAL_CACHE_BYTES),
        WorkTerminal::EngineSnapshot(value) => bounded_json_size(value, MAX_TERMINAL_CACHE_BYTES),
        WorkTerminal::QueueOrderApplied(value) => {
            bounded_json_size(value, MAX_TERMINAL_CACHE_BYTES)
        }
        WorkTerminal::QueueOrderConflict { snapshot, .. } => {
            bounded_json_size(snapshot, MAX_TERMINAL_CACHE_BYTES)
        }
        WorkTerminal::ExecutionControl {
            execution_id,
            state,
        } => bounded_json_size(&(execution_id, state), MAX_TERMINAL_CACHE_BYTES),
        WorkTerminal::Failed(value) => bounded_json_size(value, MAX_TERMINAL_CACHE_BYTES),
    };
    size.unwrap_or(MAX_TERMINAL_CACHE_BYTES.saturating_add(1))
        .saturating_add(256)
}

fn bounded_json_size(value: &impl serde::Serialize, maximum_bytes: usize) -> Option<usize> {
    struct CountingWriter {
        written: usize,
        maximum_bytes: usize,
    }

    impl io::Write for CountingWriter {
        fn write(&mut self, buffer: &[u8]) -> io::Result<usize> {
            let next = self
                .written
                .checked_add(buffer.len())
                .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "JSON size overflow"))?;
            if next > self.maximum_bytes {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    "JSON exceeds its bounded size",
                ));
            }
            self.written = next;
            Ok(buffer.len())
        }

        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }

    let mut writer = CountingWriter {
        written: 0,
        maximum_bytes,
    };
    serde_json::to_writer(&mut writer, value)
        .ok()
        .map(|()| writer.written)
}

pub fn serve_stdio(snapshot_dir: PathBuf) -> Result<()> {
    let runtime = build_default_runtime()?;
    let store: Box<dyn SnapshotStore> = Box::new(DirectorySnapshotStore::new(snapshot_dir)?);
    run_stdio(runtime, store)
}

fn run_stdio<R, S>(runtime: R, store: S) -> Result<()>
where
    R: RuntimeHost + 'static,
    S: SnapshotStore + 'static,
{
    let (input_tx, input_rx) = mpsc::sync_channel(MAX_INGRESS_MESSAGES);
    let (runtime_tx, runtime_rx) = mpsc::channel();
    let reader_tx = input_tx.clone();
    let _reader = thread::spawn(move || {
        let stdin = io::stdin();
        let mut reader = BufReader::new(stdin.lock());
        loop {
            match read_request_frame(&mut reader) {
                Ok(Some(request)) => {
                    if reader_tx
                        .send(CoordinatorMessage::Request {
                            request: Box::new(request),
                            received_at: Instant::now(),
                        })
                        .is_err()
                    {
                        break;
                    }
                }
                Ok(None) => {
                    let _ = reader_tx.send(CoordinatorMessage::InputClosed);
                    break;
                }
                Err(error) => {
                    let _ = reader_tx.send(CoordinatorMessage::InputFailed(error.to_string()));
                    break;
                }
            }
        }
    });

    let executor_result_tx = input_tx.clone();
    let executor = thread::spawn(move || {
        let panic_result_tx = executor_result_tx.clone();
        if panic::catch_unwind(AssertUnwindSafe(|| {
            run_executor(runtime, store, runtime_rx, executor_result_tx);
        }))
        .is_err()
        {
            let _ = panic_result_tx.send(CoordinatorMessage::Runtime(RuntimeResult::Fatal(
                invalid_worker_failure("runtime executor panicked"),
            )));
        }
    });
    let (output_tx, output_rx) = mpsc::sync_channel(MAX_OUTPUT_MESSAGES);
    let (writer_result_tx, writer_result_rx) = mpsc::channel();
    let writer = thread::spawn(move || {
        let stdout = io::stdout();
        let mut writer = BufWriter::new(stdout.lock());
        let result = (|| -> io::Result<()> {
            while let Ok(output) = output_rx.recv() {
                write_output_frame_resilient(&mut writer, &output)?;
            }
            std::io::Write::flush(&mut writer)
        })()
        .map_err(|error| error.to_string());
        let _ = writer_result_tx.send(result);
    });
    let mut coordinator = WorkerCoordinator::new();
    let runtime_command_tx = runtime_tx;
    let mut transport_error = None;

    while !coordinator.stopping {
        match writer_result_rx.try_recv() {
            Ok(Err(message)) => {
                transport_error = Some(format!("worker output writer failed: {message}"));
                coordinator.abort_executor = true;
                break;
            }
            Ok(Ok(())) | Err(mpsc::TryRecvError::Disconnected) => {
                transport_error = Some("worker output writer stopped unexpectedly".to_owned());
                coordinator.abort_executor = true;
                break;
            }
            Err(mpsc::TryRecvError::Empty) => {}
        }
        let now = Instant::now();
        let wait = coordinator
            .coordinator_wait(now)
            .unwrap_or(COORDINATOR_POLL_INTERVAL)
            .min(COORDINATOR_POLL_INTERVAL);
        let message = match input_rx.recv_timeout(wait) {
            Ok(message) => message,
            Err(mpsc::RecvTimeoutError::Timeout) => {
                let now = Instant::now();
                if coordinator
                    .drain_wait(now)
                    .is_some_and(|remaining| remaining.is_zero())
                {
                    CoordinatorMessage::DrainTimedOut
                } else if coordinator
                    .heartbeat_wait(now)
                    .is_some_and(|remaining| remaining.is_zero())
                {
                    CoordinatorMessage::HeartbeatTimedOut
                } else {
                    continue;
                }
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                transport_error = Some("worker coordinator input disconnected".to_owned());
                coordinator.abort_executor = true;
                break;
            }
        };
        let outputs = match message {
            CoordinatorMessage::Request {
                request,
                received_at,
            } => coordinator.handle_request_received_at(*request, received_at, &runtime_command_tx),
            CoordinatorMessage::Runtime(result) => {
                coordinator.handle_runtime(result, &runtime_command_tx)
            }
            CoordinatorMessage::RuntimeExecutionEvent(event) => {
                coordinator.handle_execution_event(event)
            }
            CoordinatorMessage::HeartbeatTimedOut => {
                coordinator.handle_heartbeat_timeout(Instant::now())
            }
            CoordinatorMessage::DrainTimedOut => coordinator.handle_drain_timeout(Instant::now()),
            CoordinatorMessage::InputClosed => coordinator.handle_input_closed(&runtime_command_tx),
            CoordinatorMessage::InputFailed(message) => {
                eprintln!("FEngine protocol input failed: {message}");
                coordinator.handle_input_failed(message, &runtime_command_tx)
            }
        };
        if let Err(error) = send_outputs(&output_tx, outputs) {
            transport_error = Some(error.message().to_owned());
            coordinator.abort_executor = true;
            break;
        }
    }
    let _ = runtime_command_tx.send(RuntimeCommand::Stop);
    if !coordinator.abort_executor {
        let _ = executor.join();
    }
    drop(output_tx);
    let writer_finished = match writer_result_rx.recv_timeout(OUTPUT_DRAIN_TIMEOUT) {
        Ok(Ok(())) => true,
        Ok(Err(message)) => {
            transport_error
                .get_or_insert_with(|| format!("worker output writer failed: {message}"));
            true
        }
        Err(mpsc::RecvTimeoutError::Timeout) => {
            transport_error.get_or_insert_with(|| {
                "worker output writer did not drain before its deadline".to_owned()
            });
            false
        }
        Err(mpsc::RecvTimeoutError::Disconnected) => {
            transport_error.get_or_insert_with(|| "worker output writer disconnected".to_owned());
            true
        }
    };
    if writer_finished {
        let _ = writer.join();
    }
    match transport_error.or(coordinator.termination_error) {
        Some(message) => Err(EngineError::new(ErrorKind::Runtime, message)),
        None => Ok(()),
    }
}

fn send_outputs(sender: &SyncSender<OutputEnvelope>, outputs: Vec<OutputEnvelope>) -> Result<()> {
    let deadline = Instant::now() + OUTPUT_BACKPRESSURE_TIMEOUT;
    for output in outputs {
        let mut pending = output;
        loop {
            match sender.try_send(pending) {
                Ok(()) => break,
                Err(TrySendError::Full(output)) if Instant::now() < deadline => {
                    pending = output;
                    thread::sleep(Duration::from_millis(1));
                }
                Err(TrySendError::Full(_)) => {
                    return Err(EngineError::new(
                        ErrorKind::Runtime,
                        "worker output backpressure deadline expired",
                    ));
                }
                Err(TrySendError::Disconnected(_)) => {
                    return Err(EngineError::new(
                        ErrorKind::Runtime,
                        "worker output writer is unavailable",
                    ));
                }
            }
        }
    }
    Ok(())
}

fn run_executor<R, S>(
    mut runtime: R,
    mut store: S,
    runtime_rx: Receiver<RuntimeCommand>,
    result_tx: SyncSender<CoordinatorMessage>,
) where
    R: RuntimeHost,
    S: SnapshotStore,
{
    match store.load_all() {
        Ok(records) => {
            for record in records {
                if let Err(error) = runtime.restore_analysis_snapshot(record) {
                    let _ = result_tx.send(CoordinatorMessage::Runtime(RuntimeResult::Fatal(
                        runtime_error(error),
                    )));
                    return;
                }
            }
            let _ = result_tx.send(CoordinatorMessage::Runtime(RuntimeResult::Ready));
        }
        Err(error) => {
            let _ = result_tx.send(CoordinatorMessage::Runtime(RuntimeResult::Fatal(
                snapshot_store_error(error),
            )));
            return;
        }
    }

    loop {
        match runtime_rx.recv_timeout(Duration::from_millis(20)) {
            Ok(command) => match command {
                RuntimeCommand::Stop => break,
                RuntimeCommand::Execute(item) => {
                    let item = *item;
                    let result = execute_work(&mut runtime, &mut store, &item);
                    let result = result.map_or_else(
                        |error| {
                            Err(if error.kind() == ErrorKind::Snapshot {
                                snapshot_store_error(error)
                            } else {
                                runtime_error(error)
                            })
                        },
                        Ok,
                    );
                    let _ = result_tx.send(CoordinatorMessage::Runtime(RuntimeResult::Completed(
                        Box::new(CompletedWork { item, result }),
                    )));
                }
            },
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => break,
        }
        match runtime.drain_execution_events() {
            Ok(events) => {
                for event in events {
                    if result_tx
                        .send(CoordinatorMessage::RuntimeExecutionEvent(event))
                        .is_err()
                    {
                        return;
                    }
                }
            }
            Err(error) => {
                let _ = result_tx.send(CoordinatorMessage::Runtime(RuntimeResult::Fatal(
                    runtime_error(error),
                )));
                return;
            }
        }
    }
}

fn execute_work<R, S>(runtime: &mut R, store: &mut S, item: &WorkItem) -> Result<RuntimeCompletion>
where
    R: RuntimeHost,
    S: SnapshotStore,
{
    match &item.payload {
        WorkPayload::Analyze(command) => {
            let response = runtime.analyze_media(AnalyzeTaskRequest {
                task_mode: command.task_mode,
                media_request: MediaAnalyzeRequest {
                    source: MediaSource::local_file(&command.source.path)?,
                    request_id: Some(item.request_id.clone()),
                    expected_source: Some(ExpectedSourceFacts {
                        file_size_bytes: command.source.file_size_bytes,
                        modified_time_unix_nanos: command.source.modified_time_unix_nanos.clone(),
                    }),
                },
                context: RequestContext {
                    request_id: Some(item.request_id.clone()),
                    client_file_id: Some(command.client_file_id.clone()),
                    correlation_id: Some(command.client_task_id.clone()),
                },
            })?;
            if response.media_analysis_status != MediaAnalysisStatus::Failed {
                let record = runtime.analysis_snapshot_record(&response.analysis_id)?;
                if let Err(persistence_error) = store.save(&record) {
                    runtime
                        .discard_analysis_snapshot(&response.analysis_id)
                        .map_err(|rollback_error| {
                            EngineError::new(
                                ErrorKind::Snapshot,
                                format!(
                                    "analysis snapshot persistence failed and rollback failed: {}; {}",
                                    persistence_error.message(),
                                    rollback_error.message()
                                ),
                            )
                        })?;
                    return Err(persistence_error);
                }
            }
            let snapshot = if response.media_analysis_status == MediaAnalysisStatus::Failed {
                None
            } else {
                Some(Box::new(runtime.analysis_snapshot(&response.analysis_id)?))
            };
            Ok(RuntimeCompletion::Analysis {
                analysis: response,
                snapshot,
            })
        }
        WorkPayload::GetSnapshot(command) => Ok(RuntimeCompletion::Snapshot(
            runtime.analysis_snapshot(&command.analysis_id)?,
        )),
        WorkPayload::GeneratePreviewFrames(command) => {
            validate_source_facts(&command.source)?;
            let result = runtime.generate_preview_frames(&PreviewFramesRequest {
                input_path: command.source.path.clone(),
                output_directory: command.output_directory.clone(),
                timestamps_us: command.timestamps_us.clone(),
                max_width: command.max_width,
            })?;
            Ok(RuntimeCompletion::PreviewFrames(PreviewFramesDocument {
                output_directory: result.output_directory,
                frames: result
                    .frames
                    .into_iter()
                    .map(|frame| PreviewFrameArtifactDocument {
                        index: frame.index,
                        requested_timestamp_us: frame.requested_timestamp_us,
                        decoded_timestamp_us: frame.decoded_timestamp_us,
                        width: frame.width,
                        height: frame.height,
                        output_path: frame.output_path,
                    })
                    .collect(),
            }))
        }
        WorkPayload::GenerateVideoThumbnail(command) => {
            validate_source_facts(&command.source)?;
            let result = runtime.generate_video_thumbnail(&VideoThumbnailRequest {
                input_path: command.source.path.clone(),
                output_path: command.output_path.clone(),
                duration_us: command.duration_us,
                max_width: command.max_width,
            })?;
            Ok(RuntimeCompletion::VideoThumbnail(VideoThumbnailDocument {
                output_path: result.output_path,
                requested_timestamp_us: result.requested_timestamp_us,
                decoded_timestamp_us: result.decoded_timestamp_us,
                width: result.width,
                height: result.height,
            }))
        }
        WorkPayload::SubmitExecution(command) => Ok(RuntimeCompletion::Execution(
            runtime.submit_execution(ExecutionSubmissionRequest {
                analysis_id: command.analysis_id.clone(),
                expected_revision: command.expected_revision,
                selection: command.selection.clone(),
                output: command.output.clone(),
                context: RequestContext {
                    request_id: Some(item.request_id.clone()),
                    client_file_id: None,
                    correlation_id: Some(command.client_task_id.clone()),
                },
            })?,
        )),
        WorkPayload::ApplyQueueOrder(work) => {
            let current = runtime.execution_snapshot()?;
            if !work.analysis_revision_matches
                || current.queue_revision != work.command.expected_execution_queue_revision
            {
                return Ok(RuntimeCompletion::QueueOrderConflict {
                    order_revision: work.command.order_revision,
                    execution_lane: current,
                });
            }
            let waiting: HashSet<_> = current
                .normal_waiting
                .iter()
                .map(|entry| entry.execution_id.clone())
                .collect();
            let ordered_waiting: Vec<_> = work
                .ordered_execution_ids
                .iter()
                .filter(|execution_id| waiting.contains(*execution_id))
                .cloned()
                .collect();
            runtime.reorder_waiting_executions(
                work.command.expected_execution_queue_revision,
                &ordered_waiting,
            )?;
            Ok(RuntimeCompletion::QueueOrderApplied {
                order_revision: work.command.order_revision,
                execution_lane: runtime.execution_snapshot()?,
            })
        }
        WorkPayload::GetEngineSnapshot => Ok(RuntimeCompletion::EngineSnapshot(
            runtime.execution_snapshot()?,
        )),
        WorkPayload::PreemptAndStart(command) => {
            runtime.preempt_and_start_execution(&command.execution_id)?;
            Ok(RuntimeCompletion::ExecutionControl {
                execution_id: command.execution_id.clone(),
                state: framelean_runtime::ExecutionTaskState::Running,
            })
        }
        WorkPayload::ControlExecution(command) => {
            let state = match command.action {
                ExecutionControlAction::Pause => {
                    runtime.pause_execution(&command.execution_id)?;
                    framelean_runtime::ExecutionTaskState::Paused
                }
                ExecutionControlAction::Resume => {
                    runtime.resume_execution(&command.execution_id)?;
                    framelean_runtime::ExecutionTaskState::Running
                }
                ExecutionControlAction::Cancel => {
                    runtime.cancel_execution(&command.execution_id)?;
                    framelean_runtime::ExecutionTaskState::CancelRequested
                }
            };
            Ok(RuntimeCompletion::ExecutionControl {
                execution_id: command.execution_id.clone(),
                state,
            })
        }
    }
}

fn runtime_error(error: EngineError) -> WorkerError {
    WorkerError {
        code: WorkerErrorCode::RuntimeFailure,
        engine_code: Some(error.code()),
        message: error.message().to_owned(),
        retryable: error.code().is_retryable(),
    }
}

fn validate_source_facts(source: &ClientSourceFacts) -> Result<()> {
    let fingerprint = SourceFingerprint::from_local_file(&source.path)?;
    ExpectedSourceFacts {
        file_size_bytes: source.file_size_bytes,
        modified_time_unix_nanos: source.modified_time_unix_nanos.clone(),
    }
    .validate(&fingerprint)
}

fn snapshot_store_error(error: EngineError) -> WorkerError {
    WorkerError {
        code: WorkerErrorCode::SnapshotStoreFailure,
        engine_code: Some(error.code()),
        message: error.message().to_owned(),
        retryable: true,
    }
}

fn invalid_request(message: impl Into<String>) -> WorkerError {
    WorkerError {
        code: WorkerErrorCode::InvalidRequest,
        engine_code: None,
        message: message.into(),
        retryable: false,
    }
}

fn invalid_worker_failure(message: impl Into<String>) -> WorkerError {
    WorkerError {
        code: WorkerErrorCode::InternalWorkerFailure,
        engine_code: None,
        message: message.into(),
        retryable: false,
    }
}

fn work_queue_kind(payload: &WorkPayload) -> QueueKind {
    match payload {
        WorkPayload::Analyze(_) => QueueKind::Analysis,
        WorkPayload::GeneratePreviewFrames(_)
        | WorkPayload::GenerateVideoThumbnail(_)
        | WorkPayload::GetSnapshot(_)
        | WorkPayload::SubmitExecution(_)
        | WorkPayload::ApplyQueueOrder(_)
        | WorkPayload::GetEngineSnapshot
        | WorkPayload::PreemptAndStart(_)
        | WorkPayload::ControlExecution(_) => QueueKind::Control,
    }
}

fn client_task_id_for_payload(payload: &WorkPayload) -> Option<String> {
    match payload {
        WorkPayload::Analyze(command) => Some(command.client_task_id.clone()),
        WorkPayload::GeneratePreviewFrames(command) => Some(command.client_task_id.clone()),
        WorkPayload::GenerateVideoThumbnail(command) => Some(command.client_task_id.clone()),
        WorkPayload::SubmitExecution(command) => Some(command.client_task_id.clone()),
        WorkPayload::GetSnapshot(_)
        | WorkPayload::ApplyQueueOrder(_)
        | WorkPayload::GetEngineSnapshot
        | WorkPayload::PreemptAndStart(_)
        | WorkPayload::ControlExecution(_) => None,
    }
}

fn validate_command(command: &WorkerCommand) -> std::result::Result<(), WorkerError> {
    match command {
        WorkerCommand::Hello(command) => {
            if !is_bounded_text(&command.client_name, MAX_CLIENT_LABEL_BYTES)
                || !is_bounded_text(&command.client_version, MAX_CLIENT_LABEL_BYTES)
            {
                return Err(invalid_request(
                    "client_name and client_version are required and bounded",
                ));
            }
        }
        WorkerCommand::AnalyzeMedia(command) => {
            if !is_bounded_text(&command.client_task_id, MAX_CLIENT_ID_BYTES)
                || !is_bounded_text(&command.client_file_id, MAX_CLIENT_ID_BYTES)
                || command.source.path.as_os_str().is_empty()
            {
                return Err(invalid_request(
                    "analysis client ids and source path are required and bounded",
                ));
            }
            if command
                .source
                .modified_time_unix_nanos
                .as_ref()
                .is_some_and(|value| value.parse::<u128>().is_err())
            {
                return Err(invalid_request(
                    "source modified time must be an unsigned integer",
                ));
            }
        }
        WorkerCommand::GeneratePreviewFrames(command) => {
            if !is_bounded_text(&command.client_task_id, MAX_CLIENT_ID_BYTES)
                || command.source.path.as_os_str().is_empty()
                || command.output_directory.as_os_str().is_empty()
                || command.timestamps_us.is_empty()
                || command.timestamps_us.len() > 16
                || command.max_width == Some(0)
            {
                return Err(invalid_request(
                    "preview request requires a task id, paths, one to sixteen timestamps, and a positive optional width",
                ));
            }
        }
        WorkerCommand::GenerateVideoThumbnail(command) => {
            if !is_bounded_text(&command.client_task_id, MAX_CLIENT_ID_BYTES)
                || command.source.path.as_os_str().is_empty()
                || command.output_path.as_os_str().is_empty()
                || command.max_width == 0
            {
                return Err(invalid_request(
                    "thumbnail request requires a task id, paths, and a positive width",
                ));
            }
        }
        WorkerCommand::SubmitAnalysisBatch(command) => {
            if command.items.is_empty() || command.items.len() > MAX_QUEUED_WORK_ITEMS {
                return Err(invalid_request(
                    "analysis batch must contain a bounded number of items",
                ));
            }
            let mut task_ids = HashSet::new();
            for item in &command.items {
                validate_command(&WorkerCommand::AnalyzeMedia(item.clone()))?;
                if !task_ids.insert(item.client_task_id.as_str()) {
                    return Err(invalid_request(
                        "analysis batch contains duplicate client_task_id values",
                    ));
                }
            }
        }
        WorkerCommand::GetAnalysisSnapshot(command) => {
            if !is_bounded_text(command.analysis_id.as_str(), MAX_ANALYSIS_ID_BYTES) {
                return Err(invalid_request("analysis_id exceeds the protocol limit"));
            }
        }
        WorkerCommand::SubmitExecution(command) => {
            if !is_bounded_text(&command.client_task_id, MAX_CLIENT_ID_BYTES) {
                return Err(invalid_request(
                    "execution client_task_id is required and bounded",
                ));
            }
            if !is_bounded_text(command.analysis_id.as_str(), MAX_ANALYSIS_ID_BYTES) {
                return Err(invalid_request("analysis_id exceeds the protocol limit"));
            }
        }
        WorkerCommand::SubmitExecutionBatch(command) => {
            if command.items.is_empty() || command.items.len() > MAX_QUEUED_WORK_ITEMS {
                return Err(invalid_request(
                    "execution batch must contain a bounded number of items",
                ));
            }
            let mut task_ids = HashSet::new();
            for item in &command.items {
                validate_command(&WorkerCommand::SubmitExecution(item.clone()))?;
                if !task_ids.insert(item.client_task_id.as_str()) {
                    return Err(invalid_request(
                        "execution batch contains duplicate client_task_id values",
                    ));
                }
            }
        }
        WorkerCommand::ApplyQueueOrder(command) => {
            if command.ordered_task_ids.len() > MAX_QUEUED_WORK_ITEMS
                || command
                    .ordered_task_ids
                    .iter()
                    .any(|value| !is_bounded_text(value, MAX_CLIENT_ID_BYTES))
            {
                return Err(invalid_request(
                    "queue order task ids are required and bounded",
                ));
            }
            let unique: HashSet<_> = command.ordered_task_ids.iter().collect();
            if unique.len() != command.ordered_task_ids.len() {
                return Err(invalid_request("queue order contains duplicate task ids"));
            }
        }
        WorkerCommand::PreemptAndStart(command) => {
            if !is_bounded_text(command.execution_id.as_str(), MAX_ANALYSIS_ID_BYTES) {
                return Err(invalid_request("execution_id exceeds the protocol limit"));
            }
        }
        WorkerCommand::ControlExecution(command) => {
            if !is_bounded_text(command.execution_id.as_str(), MAX_ANALYSIS_ID_BYTES) {
                return Err(invalid_request("execution_id exceeds the protocol limit"));
            }
        }
        WorkerCommand::GetEngineSnapshot | WorkerCommand::Ping | WorkerCommand::Shutdown => {}
    }
    Ok(())
}

fn is_bounded_text(value: &str, maximum_bytes: usize) -> bool {
    !value.trim().is_empty() && value.len() <= maximum_bytes
}

fn new_session_id() -> String {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |value| value.as_nanos());
    let sequence = SESSION_SEQUENCE.fetch_add(1, Ordering::Relaxed);
    format!("session-{}-{timestamp}-{sequence}", std::process::id())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protocol::{
        ClientSourceFacts, GeneratePreviewFramesCommand, GenerateVideoThumbnailCommand,
        HelloCommand, RequestEnvelope, SubmitAnalysisBatchCommand, SubmitExecutionCommand,
        WorkerCommand, WorkerOutput,
    };
    use crate::snapshot_store::MemorySnapshotStore;

    fn submit_execution_command(client_task_id: &str) -> SubmitExecutionCommand {
        SubmitExecutionCommand {
            client_task_id: client_task_id.to_owned(),
            analysis_id: framelean_core::AnalysisId::new("analysis-test").unwrap(),
            expected_revision: framelean_runtime::AnalysisRevision::initial(),
            selection: framelean_runtime::RecalculateSelection::Manual(
                framelean_runtime::ManualConfigurationSelection {
                    candidate_id: framelean_runtime::ExecutionChainId::new("chain-test").unwrap(),
                    overrides: framelean_runtime::ManualSelection::empty(),
                },
            ),
            output: framelean_runtime::ExecutionOutputRequest {
                requested_path: PathBuf::from("/tmp/framelean-output.mp4"),
                collision_policy: framelean_runtime::OutputCollisionPolicy::FailIfExists,
            },
            priority: WorkPriority::Normal,
        }
    }

    fn hello() -> RequestEnvelope {
        RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: None,
            request_id: "hello-1".to_owned(),
            command: WorkerCommand::Hello(HelloCommand {
                minimum_protocol_version: 1,
                maximum_protocol_version: 1,
                client_name: "test-client".to_owned(),
                client_version: "1".to_owned(),
            }),
        }
    }

    fn establish_ready_session(
        worker: &mut WorkerCoordinator,
        runtime_tx: &Sender<RuntimeCommand>,
    ) -> String {
        worker.handle_runtime(RuntimeResult::Ready, runtime_tx);
        worker.handle_request(hello(), runtime_tx)[0]
            .session_id
            .clone()
    }

    fn completed_analysis(path: &std::path::Path) -> AnalyzeMediaResponse {
        let fingerprint = framelean_analysis::SourceFingerprint::from_local_file(path).unwrap();
        let quick_content_hash_hex: String = fingerprint
            .quick_content_hash()
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect();
        serde_json::from_value(serde_json::json!({
            "schema_version": "1.0",
            "analysis_id": "analysis-test",
            "analysis_revision": 1,
            "task_mode": "video_compress",
            "media_analysis_status": "complete",
            "configuration_status": "not_evaluated",
            "media": null,
            "source_fingerprint": {
                "source_id": fingerprint.source_id().unwrap(),
                "canonical_path": fingerprint.canonical_path().to_string_lossy(),
                "canonicalization_status": fingerprint.canonicalization_status(),
                "canonicalization_reason": fingerprint.canonicalization_reason(),
                "file_size_bytes": fingerprint.size_bytes(),
                "modified_time_unix_nanos": fingerprint
                    .modified_time_unix_nanos()
                    .map(|value| value.to_string()),
                "platform_file_id": null,
                "quick_content_hash_hex": quick_content_hash_hex
            },
            "requirements": null,
            "environment_summary": null,
            "engine_backend_summary": null,
            "capabilities": null,
            "configuration_options": null,
            "recommendation": null,
            "presets": [],
            "custom_target_size": null,
            "warnings": [],
            "error": null
        }))
        .unwrap()
    }

    #[test]
    fn handshake_is_required_and_sequence_is_monotonic() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let before = worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: None,
                request_id: "ping".to_owned(),
                command: WorkerCommand::Ping,
            },
            &runtime_tx,
        );
        assert!(matches!(before[0].output, WorkerOutput::Error(_)));

        let hello_output = worker.handle_request(hello(), &runtime_tx);
        assert_eq!(hello_output.len(), 1);
        let session_id = hello_output[0].session_id.clone();
        assert!(session_id.starts_with("session-"));
        assert_eq!(hello_output[0].sequence, before[0].sequence + 1);
    }

    #[test]
    fn oversized_request_id_is_rejected_without_echoing_it() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);

        let output = worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id),
                request_id: "x".repeat(MAX_REQUEST_ID_BYTES + 1),
                command: WorkerCommand::Ping,
            },
            &runtime_tx,
        );

        assert_eq!(output[0].request_id, "invalid-request");
        assert!(matches!(
            output[0].output,
            WorkerOutput::Error(WorkerError {
                code: WorkerErrorCode::InvalidRequest,
                ..
            })
        ));
    }

    #[test]
    fn unsupported_protocol_version_is_rejected_before_handshake() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();

        let output = worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION + 1,
                session_id: None,
                request_id: "hello-1".to_owned(),
                command: WorkerCommand::Hello(HelloCommand {
                    minimum_protocol_version: crate::protocol::PROTOCOL_VERSION + 1,
                    maximum_protocol_version: crate::protocol::PROTOCOL_VERSION + 1,
                    client_name: "test".to_owned(),
                    client_version: "1".to_owned(),
                }),
            },
            &runtime_tx,
        );

        assert!(matches!(
            output[0].output,
            WorkerOutput::Error(WorkerError {
                code: WorkerErrorCode::ProtocolVersionUnsupported,
                ..
            })
        ));
        assert!(worker.session_id.is_none());
    }

    #[test]
    fn request_id_reuse_with_different_content_is_rejected() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id.clone()),
                request_id: "request-1".to_owned(),
                command: WorkerCommand::Ping,
            },
            &runtime_tx,
        );

        let output = worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id),
                request_id: "request-1".to_owned(),
                command: WorkerCommand::Shutdown,
            },
            &runtime_tx,
        );

        assert!(matches!(
            output[0].output,
            WorkerOutput::Error(WorkerError {
                code: WorkerErrorCode::IdempotencyKeyReused,
                ..
            })
        ));
        assert!(!worker.draining);
    }

    #[test]
    fn accepted_work_waits_until_the_runtime_is_ready() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        worker.handle_request(hello(), &runtime_tx);
        let session_id = worker.session_id.clone().unwrap();
        let accepted = worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id),
                request_id: "analysis-1".to_owned(),
                command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                    client_task_id: "task-1".to_owned(),
                    client_file_id: "file-1".to_owned(),
                    source: ClientSourceFacts {
                        path: PathBuf::from("/tmp/input.mp4"),
                        file_size_bytes: 1,
                        modified_time_unix_nanos: None,
                    },
                    task_mode: framelean_runtime::TaskMode::VideoCompress,
                    priority: WorkPriority::Normal,
                    force_reanalysis: false,
                }),
            },
            &runtime_tx,
        );

        assert!(runtime_rx.try_recv().is_err());
        assert!(!accepted.iter().any(|output| matches!(
            output.output,
            WorkerOutput::Event(WorkerEvent::WorkStarted { .. })
        )));

        let ready = worker.handle_runtime(RuntimeResult::Ready, &runtime_tx);

        assert!(ready.iter().any(|output| matches!(
            output.output,
            WorkerOutput::Event(WorkerEvent::WorkStarted { .. })
        )));
        assert!(matches!(
            runtime_rx.recv().unwrap(),
            RuntimeCommand::Execute(_)
        ));
    }

    #[test]
    fn media_artifact_requests_use_the_control_queue() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let source = ClientSourceFacts {
            path: PathBuf::from("/tmp/input.mp4"),
            file_size_bytes: 1,
            modified_time_unix_nanos: None,
        };

        let preview = worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id.clone()),
                request_id: "preview-1".to_owned(),
                command: WorkerCommand::GeneratePreviewFrames(GeneratePreviewFramesCommand {
                    client_task_id: "task-1".to_owned(),
                    source: source.clone(),
                    output_directory: PathBuf::from("/tmp/previews"),
                    timestamps_us: vec![1_000_000],
                    max_width: Some(960),
                    priority: WorkPriority::Foreground,
                }),
            },
            &runtime_tx,
        );
        let thumbnail = worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id),
                request_id: "thumbnail-1".to_owned(),
                command: WorkerCommand::GenerateVideoThumbnail(GenerateVideoThumbnailCommand {
                    client_task_id: "task-2".to_owned(),
                    source,
                    output_path: PathBuf::from("/tmp/thumbnail.bmp"),
                    duration_us: Some(10_000_000),
                    max_width: 80,
                    priority: WorkPriority::Background,
                }),
            },
            &runtime_tx,
        );

        assert!(preview.iter().any(|output| matches!(
            output.output,
            WorkerOutput::Response(WorkerResponse::Accepted {
                queue_kind: QueueKind::Control,
                ..
            })
        )));
        assert!(thumbnail.iter().any(|output| matches!(
            output.output,
            WorkerOutput::Response(WorkerResponse::Accepted {
                queue_kind: QueueKind::Control,
                ..
            })
        )));
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("preview request should be dispatched to the runtime");
        };
        assert!(matches!(
            item.payload,
            WorkPayload::GeneratePreviewFrames(_)
        ));
        assert_eq!(worker.analysis_queue.len(), 0);
        assert_eq!(worker.control_queue.len(), 1);
    }

    #[test]
    fn runtime_startup_failure_terminates_every_accepted_work_item() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        worker.handle_request(hello(), &runtime_tx);
        let session_id = worker.session_id.clone().unwrap();
        for number in 1..=2 {
            worker.handle_request(
                RequestEnvelope {
                    protocol_version: crate::protocol::PROTOCOL_VERSION,
                    session_id: Some(session_id.clone()),
                    request_id: format!("analysis-{number}"),
                    command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                        client_task_id: format!("task-{number}"),
                        client_file_id: format!("file-{number}"),
                        source: ClientSourceFacts {
                            path: PathBuf::from(format!("/tmp/input-{number}.mp4")),
                            file_size_bytes: 1,
                            modified_time_unix_nanos: None,
                        },
                        task_mode: framelean_runtime::TaskMode::VideoCompress,
                        priority: WorkPriority::Normal,
                        force_reanalysis: false,
                    }),
                },
                &runtime_tx,
            );
        }

        let failed = worker.handle_runtime(
            RuntimeResult::Fatal(WorkerError {
                code: WorkerErrorCode::SnapshotStoreFailure,
                engine_code: None,
                message: "snapshot restore failed".to_owned(),
                retryable: true,
            }),
            &runtime_tx,
        );

        assert!(runtime_rx.try_recv().is_err());
        assert_eq!(
            failed
                .iter()
                .filter(|output| matches!(
                    output.output,
                    WorkerOutput::Event(WorkerEvent::WorkFailed { .. })
                ))
                .count(),
            2
        );
        assert!(
            worker
                .works
                .values()
                .all(|record| record.state == WorkState::Failed)
        );
    }

    #[test]
    fn expired_heartbeat_fails_active_work_and_requests_process_abort() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id),
                request_id: "analysis-1".to_owned(),
                command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                    client_task_id: "task-1".to_owned(),
                    client_file_id: "file-1".to_owned(),
                    source: ClientSourceFacts {
                        path: PathBuf::from("/tmp/input.mp4"),
                        file_size_bytes: 1,
                        modified_time_unix_nanos: None,
                    },
                    task_mode: TaskMode::VideoCompress,
                    priority: WorkPriority::Normal,
                    force_reanalysis: false,
                }),
            },
            &runtime_tx,
        );
        let now = std::time::Instant::now();
        worker.last_client_contact =
            Some(now - std::time::Duration::from_millis(HEARTBEAT_TIMEOUT_MS + 1));

        let expired = worker.handle_heartbeat_timeout(now);

        assert!(worker.stopping);
        assert!(worker.abort_executor);
        assert!(expired.iter().any(|output| matches!(
            &output.output,
            WorkerOutput::Event(WorkerEvent::WorkFailed { error, .. })
                if error.code == WorkerErrorCode::HeartbeatTimedOut
        )));
    }

    #[test]
    fn queued_ping_uses_its_actual_receive_time_for_heartbeat() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let now = Instant::now();
        let received_at = now - Duration::from_millis(HEARTBEAT_TIMEOUT_MS + 1);

        worker.handle_request_received_at(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id),
                request_id: "stale-ping".to_owned(),
                command: WorkerCommand::Ping,
            },
            received_at,
            &runtime_tx,
        );

        assert_eq!(worker.last_client_contact, Some(received_at));
        let expired = worker.handle_heartbeat_timeout(now);
        assert!(expired.iter().any(|output| matches!(
            output.output,
            WorkerOutput::Error(WorkerError {
                code: WorkerErrorCode::HeartbeatTimedOut,
                ..
            })
        )));
    }

    #[test]
    fn work_queue_capacity_is_enforced_with_explicit_backpressure() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);

        let mut last = Vec::new();
        for number in 0..=(MAX_QUEUED_WORK_ITEMS + 1) {
            last = worker.handle_request(
                RequestEnvelope {
                    protocol_version: crate::protocol::PROTOCOL_VERSION,
                    session_id: Some(session_id.clone()),
                    request_id: format!("analysis-{number}"),
                    command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                        client_task_id: format!("task-{number}"),
                        client_file_id: format!("file-{number}"),
                        source: ClientSourceFacts {
                            path: PathBuf::from(format!("/tmp/input-{number}.mp4")),
                            file_size_bytes: 1,
                            modified_time_unix_nanos: None,
                        },
                        task_mode: TaskMode::VideoCompress,
                        priority: WorkPriority::Normal,
                        force_reanalysis: false,
                    }),
                },
                &runtime_tx,
            );
        }

        assert!(matches!(
            last[0].output,
            WorkerOutput::Error(WorkerError {
                code: WorkerErrorCode::WorkerBusy,
                retryable: true,
                ..
            })
        ));
        assert_eq!(worker.analysis_queue.len(), MAX_QUEUED_WORK_ITEMS);
    }

    #[test]
    fn completed_idempotency_records_are_bounded_and_evictable() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);

        for number in 0..(MAX_REQUEST_CACHE_ENTRIES * 2) {
            let output = worker.handle_request(
                RequestEnvelope {
                    protocol_version: crate::protocol::PROTOCOL_VERSION,
                    session_id: Some(session_id.clone()),
                    request_id: format!("ping-{number}"),
                    command: WorkerCommand::Ping,
                },
                &runtime_tx,
            );
            assert!(matches!(
                output[0].output,
                WorkerOutput::Response(WorkerResponse::Pong)
            ));
        }

        assert!(worker.requests.len() <= MAX_REQUEST_CACHE_ENTRIES);
        assert!(worker.request_cache_bytes <= MAX_REQUEST_CACHE_BYTES);
        assert_eq!(worker.request_order.len(), worker.requests.len());
    }

    #[test]
    fn terminal_payload_cache_obeys_count_and_ttl_limits() {
        let mut worker = WorkerCoordinator::new();
        for number in 0..=MAX_TERMINAL_CACHE_ENTRIES {
            let work_id = format!("work-{number}");
            let item = WorkItem {
                work_id: work_id.clone(),
                request_id: format!("request-{number}"),
                priority: WorkPriority::Normal,
                payload: WorkPayload::Analyze(AnalyzeMediaCommand {
                    client_task_id: format!("task-{number}"),
                    client_file_id: format!("file-{number}"),
                    source: ClientSourceFacts {
                        path: PathBuf::from(format!("/tmp/input-{number}.mp4")),
                        file_size_bytes: 1,
                        modified_time_unix_nanos: None,
                    },
                    task_mode: TaskMode::VideoCompress,
                    priority: WorkPriority::Normal,
                    force_reanalysis: false,
                }),
            };
            worker.works.insert(
                work_id,
                WorkRecord {
                    state: WorkState::Running,
                    analysis_id: None,
                    waiters: Vec::new(),
                    terminal: None,
                    terminal_bytes: 0,
                    completed_at: None,
                },
            );
            worker.complete_work(
                &item,
                WorkState::Failed,
                None,
                WorkTerminal::Failed(invalid_worker_failure("fixture")),
            );
        }

        worker.prune_terminal_cache(Instant::now());
        assert!(worker.terminal_order.len() <= MAX_TERMINAL_CACHE_ENTRIES);
        assert!(worker.terminal_cache_bytes <= MAX_TERMINAL_CACHE_BYTES);

        let oldest = worker
            .terminal_order
            .front()
            .expect("terminal cache should retain recent records")
            .clone();
        worker.works.get_mut(&oldest).unwrap().completed_at =
            Some(Instant::now() - TERMINAL_CACHE_TTL - Duration::from_secs(1));
        worker.prune_terminal_cache(Instant::now());
        assert!(!worker.works.contains_key(&oldest));
    }

    #[test]
    fn expired_drain_deadline_aborts_a_hung_runtime() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id),
                request_id: "analysis-1".to_owned(),
                command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                    client_task_id: "task-1".to_owned(),
                    client_file_id: "file-1".to_owned(),
                    source: ClientSourceFacts {
                        path: PathBuf::from("/tmp/input.mp4"),
                        file_size_bytes: 1,
                        modified_time_unix_nanos: None,
                    },
                    task_mode: TaskMode::VideoCompress,
                    priority: WorkPriority::Normal,
                    force_reanalysis: false,
                }),
            },
            &runtime_tx,
        );
        let now = Instant::now();
        worker.handle_input_closed_at(now - DRAIN_TIMEOUT - Duration::from_millis(1), &runtime_tx);

        let expired = worker.handle_drain_timeout(now);

        assert!(worker.stopping);
        assert!(worker.abort_executor);
        assert!(worker.termination_error.is_some());
        assert!(expired.iter().any(|output| matches!(
            &output.output,
            WorkerOutput::Event(WorkerEvent::WorkFailed { error, .. })
                if error.code == WorkerErrorCode::WorkerDraining
        )));
    }

    #[test]
    fn duplicate_analysis_request_is_not_enqueued_twice() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let request = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: "analysis-1".to_owned(),
            command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                client_task_id: "task-1".to_owned(),
                client_file_id: "file-1".to_owned(),
                source: ClientSourceFacts {
                    path: PathBuf::from("/tmp/input.mp4"),
                    file_size_bytes: 1,
                    modified_time_unix_nanos: None,
                },
                task_mode: framelean_runtime::TaskMode::VideoCompress,
                priority: WorkPriority::Normal,
                force_reanalysis: false,
            }),
        };
        let first = worker.handle_request(request.clone(), &runtime_tx);
        let second = worker.handle_request(request, &runtime_tx);
        assert_eq!(worker.analysis_queue.len(), 0);
        assert_eq!(worker.active_work_id, Some("work-1".to_owned()));
        assert!(matches!(first[0].output, WorkerOutput::Response(_)));
        assert!(matches!(second[0].output, WorkerOutput::Response(_)));
        let RuntimeCommand::Execute(_) = runtime_rx.recv().unwrap() else {
            panic!("test runtime command should be an execution command");
        };
    }

    #[test]
    fn duplicate_ping_replays_the_same_semantic_response() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        worker.handle_request(hello(), &runtime_tx);
        let session_id = worker.session_id.clone().unwrap();
        let ping = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "ping-1".to_owned(),
            command: WorkerCommand::Ping,
        };

        let first = worker.handle_request(ping.clone(), &runtime_tx);
        let duplicate = worker.handle_request(ping, &runtime_tx);
        assert!(matches!(
            first[0].output,
            WorkerOutput::Response(WorkerResponse::Pong)
        ));
        assert!(matches!(
            duplicate[0].output,
            WorkerOutput::Response(WorkerResponse::Pong)
        ));
    }

    #[test]
    fn submit_execution_emits_a_real_submission_and_replays_it_by_request_id() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let command = submit_execution_command("client-task-1");
        let request = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "submit-1".to_owned(),
            command: WorkerCommand::SubmitExecution(command),
        };

        let accepted = worker.handle_request(request.clone(), &runtime_tx);
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("execution submission should be dispatched to the runtime");
        };
        let execution_id = framelean_core::TaskId::new("task-1").unwrap();
        let completed = worker.handle_runtime(
            RuntimeResult::Completed(Box::new(CompletedWork {
                item: *item,
                result: Ok(RuntimeCompletion::Execution(
                    framelean_runtime::ExecutionSubmissionResult {
                        execution_id: execution_id.clone(),
                        state: framelean_runtime::ExecutionTaskState::Queued,
                        queue_position: 1,
                        queue_revision: 3,
                    },
                )),
            })),
            &runtime_tx,
        );

        assert!(accepted.iter().any(|output| matches!(
            output.output,
            WorkerOutput::Response(WorkerResponse::Accepted {
                state: WorkState::Queued,
                ..
            })
        )));
        assert!(completed.iter().any(|output| matches!(
            &output.output,
            WorkerOutput::Event(WorkerEvent::ExecutionSubmitted {
                client_task_id,
                submission,
                ..
            }) if client_task_id == "client-task-1"
                && submission.execution_id == execution_id
                && submission.state == framelean_runtime::ExecutionTaskState::Queued
        )));

        let replay = worker.handle_request(request, &runtime_tx);
        assert_eq!(replay.len(), 2);
        assert!(matches!(
            &replay[1].output,
            WorkerOutput::Event(WorkerEvent::ExecutionSubmitted {
                client_task_id,
                submission,
                ..
            }) if client_task_id == "client-task-1"
                && submission.execution_id == execution_id
        ));
        assert!(runtime_rx.try_recv().is_err());
    }

    #[test]
    fn execution_chain_not_ready_is_replayed_as_work_failed_without_a_submission() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let request = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "submit-1".to_owned(),
            command: WorkerCommand::SubmitExecution(submit_execution_command("client-task-1")),
        };

        worker.handle_request(request.clone(), &runtime_tx);
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("execution submission should be dispatched to the runtime");
        };
        let failed = worker.handle_runtime(
            RuntimeResult::Completed(Box::new(CompletedWork {
                item: *item,
                result: Err(runtime_error(EngineError::with_code(
                    ErrorKind::Pipeline,
                    framelean_core::EngineErrorCode::EngineExecutionChainNotReady,
                    "media execution pipeline is not ready",
                ))),
            })),
            &runtime_tx,
        );

        assert!(failed.iter().any(|output| matches!(
            &output.output,
            WorkerOutput::Event(WorkerEvent::WorkFailed { error, .. })
                if error.engine_code
                    == Some(framelean_core::EngineErrorCode::EngineExecutionChainNotReady)
        )));
        assert!(!failed.iter().any(|output| matches!(
            output.output,
            WorkerOutput::Event(WorkerEvent::ExecutionSubmitted { .. })
        )));

        let replay = worker.handle_request(request, &runtime_tx);
        assert_eq!(replay.len(), 2);
        assert!(matches!(
            &replay[1].output,
            WorkerOutput::Event(WorkerEvent::WorkFailed { error, .. })
                if error.engine_code
                    == Some(framelean_core::EngineErrorCode::EngineExecutionChainNotReady)
        ));
        assert!(runtime_rx.try_recv().is_err());
    }

    #[test]
    fn duplicate_hello_resumes_the_same_session() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let first = worker.handle_request(hello(), &runtime_tx);
        let duplicate = worker.handle_request(hello(), &runtime_tx);

        assert_eq!(duplicate[0].session_id, first[0].session_id);
        assert!(matches!(
            duplicate[0].output,
            WorkerOutput::Response(WorkerResponse::Hello { resumed: true, .. })
        ));
    }

    #[test]
    fn reconnect_hello_with_a_new_request_id_resumes_the_same_session() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let first = worker.handle_request(hello(), &runtime_tx);
        let mut reconnect = hello();
        reconnect.request_id = "hello-reconnect".to_owned();

        let resumed = worker.handle_request(reconnect, &runtime_tx);

        assert_eq!(resumed[0].session_id, first[0].session_id);
        assert!(matches!(
            resumed[0].output,
            WorkerOutput::Response(WorkerResponse::Hello { resumed: true, .. })
        ));
    }

    #[test]
    fn duplicate_shutdown_is_idempotent_while_work_is_running() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id.clone()),
                request_id: "analysis-1".to_owned(),
                command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                    client_task_id: "task-1".to_owned(),
                    client_file_id: "file-1".to_owned(),
                    source: ClientSourceFacts {
                        path: PathBuf::from("/tmp/input.mp4"),
                        file_size_bytes: 1,
                        modified_time_unix_nanos: None,
                    },
                    task_mode: framelean_runtime::TaskMode::VideoCompress,
                    priority: WorkPriority::Normal,
                    force_reanalysis: false,
                }),
            },
            &runtime_tx,
        );
        let shutdown = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "shutdown-1".to_owned(),
            command: WorkerCommand::Shutdown,
        };

        let first = worker.handle_request(shutdown.clone(), &runtime_tx);
        let duplicate = worker.handle_request(shutdown, &runtime_tx);
        assert!(matches!(
            first[0].output,
            WorkerOutput::Response(WorkerResponse::ShutdownAccepted)
        ));
        assert!(matches!(
            duplicate[0].output,
            WorkerOutput::Response(WorkerResponse::ShutdownAccepted)
        ));
    }

    #[test]
    fn failed_work_dispatches_the_next_queued_request() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let request = |request_id: &str, task_id: &str| RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: request_id.to_owned(),
            command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                client_task_id: task_id.to_owned(),
                client_file_id: format!("file-{task_id}"),
                source: ClientSourceFacts {
                    path: PathBuf::from(format!("/tmp/{task_id}.mp4")),
                    file_size_bytes: 1,
                    modified_time_unix_nanos: None,
                },
                task_mode: framelean_runtime::TaskMode::VideoCompress,
                priority: WorkPriority::Normal,
                force_reanalysis: false,
            }),
        };

        worker.handle_request(request("request-1", "task-1"), &runtime_tx);
        let RuntimeCommand::Execute(first) = runtime_rx.recv().unwrap() else {
            panic!("first work should start");
        };
        worker.handle_request(request("request-2", "task-2"), &runtime_tx);
        assert!(runtime_rx.try_recv().is_err());

        let output = worker.handle_runtime(
            RuntimeResult::Completed(Box::new(CompletedWork {
                item: *first,
                result: Err(runtime_error(EngineError::new(
                    ErrorKind::Runtime,
                    "fixture failure",
                ))),
            })),
            &runtime_tx,
        );
        assert!(output.iter().any(|value| matches!(
            value.output,
            WorkerOutput::Event(WorkerEvent::WorkFailed { .. })
        )));
        let RuntimeCommand::Execute(second) = runtime_rx.recv().unwrap() else {
            panic!("second work should start after the first fails");
        };
        assert_eq!(second.work_id, "work-2");
    }

    #[test]
    fn equivalent_analysis_requests_share_one_work_item() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let request = |request_id: &str| RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: request_id.to_owned(),
            command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                client_task_id: "task-1".to_owned(),
                client_file_id: "file-1".to_owned(),
                source: ClientSourceFacts {
                    path: PathBuf::from("/tmp/input.mp4"),
                    file_size_bytes: 10,
                    modified_time_unix_nanos: Some("100".to_owned()),
                },
                task_mode: framelean_runtime::TaskMode::VideoCompress,
                priority: WorkPriority::Normal,
                force_reanalysis: false,
            }),
        };

        worker.handle_request(request("analysis-1"), &runtime_tx);
        worker.handle_request(request("analysis-2"), &runtime_tx);

        assert_eq!(worker.active_work_id.as_deref(), Some("work-1"));
        assert!(worker.analysis_queue.is_empty());
        assert_eq!(
            worker
                .requests
                .get(&(session_id, "analysis-2".to_owned()))
                .and_then(|value| value.work_id.as_deref()),
            Some("work-1")
        );
        assert!(matches!(
            runtime_rx.recv().unwrap(),
            RuntimeCommand::Execute(_)
        ));
        assert!(runtime_rx.try_recv().is_err());
    }

    #[test]
    fn completed_analysis_requires_snapshot_lookup_or_a_new_analysis_request() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let path = std::env::temp_dir().join(format!(
            "framelean-worker-replay-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::write(&path, b"first").unwrap();
        let fingerprint = framelean_analysis::SourceFingerprint::from_local_file(&path).unwrap();
        let request = |request_id: &str, task_id: &str| RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: request_id.to_owned(),
            command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                client_task_id: task_id.to_owned(),
                client_file_id: "file-1".to_owned(),
                source: ClientSourceFacts {
                    path: path.clone(),
                    file_size_bytes: fingerprint.size_bytes(),
                    modified_time_unix_nanos: fingerprint
                        .modified_time_unix_nanos()
                        .map(|value| value.to_string()),
                },
                task_mode: framelean_runtime::TaskMode::VideoCompress,
                priority: WorkPriority::Normal,
                force_reanalysis: false,
            }),
        };

        worker.handle_request(request("analysis-1", "task-1"), &runtime_tx);
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("analysis work should start");
        };
        worker.handle_runtime(
            RuntimeResult::Completed(Box::new(CompletedWork {
                item: *item,
                result: Ok(RuntimeCompletion::Analysis {
                    analysis: completed_analysis(&path),
                    snapshot: None,
                }),
            })),
            &runtime_tx,
        );

        let accepted = worker.handle_request(request("analysis-2", "task-2"), &runtime_tx);

        assert!(matches!(
            accepted[0].output,
            WorkerOutput::Response(WorkerResponse::Accepted {
                deduplicated: false,
                ..
            })
        ));
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("a new request id must perform source validation in the runtime");
        };
        assert_eq!(item.work_id, "work-2");
        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn completed_analysis_is_not_replayed_after_the_source_changes() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let path = std::env::temp_dir().join(format!(
            "framelean-worker-source-change-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::write(&path, b"first").unwrap();
        let fingerprint = framelean_analysis::SourceFingerprint::from_local_file(&path).unwrap();
        let command = AnalyzeMediaCommand {
            client_task_id: "task-1".to_owned(),
            client_file_id: "file-1".to_owned(),
            source: ClientSourceFacts {
                path: path.clone(),
                file_size_bytes: fingerprint.size_bytes(),
                modified_time_unix_nanos: fingerprint
                    .modified_time_unix_nanos()
                    .map(|value| value.to_string()),
            },
            task_mode: TaskMode::VideoCompress,
            priority: WorkPriority::Normal,
            force_reanalysis: false,
        };
        let request = |request_id: &str| RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: request_id.to_owned(),
            command: WorkerCommand::AnalyzeMedia(command.clone()),
        };
        worker.handle_request(request("analysis-1"), &runtime_tx);
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("analysis work should start");
        };
        worker.handle_runtime(
            RuntimeResult::Completed(Box::new(CompletedWork {
                item: *item,
                result: Ok(RuntimeCompletion::Analysis {
                    analysis: completed_analysis(&path),
                    snapshot: None,
                }),
            })),
            &runtime_tx,
        );
        std::fs::write(&path, b"other").unwrap();

        let accepted = worker.handle_request(request("analysis-2"), &runtime_tx);

        assert!(matches!(
            accepted[0].output,
            WorkerOutput::Response(WorkerResponse::Accepted {
                deduplicated: false,
                ..
            })
        ));
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("changed source should start a new analysis");
        };
        assert_eq!(item.work_id, "work-2");
        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn duplicate_failed_request_replays_its_terminal_error() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let request = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "analysis-1".to_owned(),
            command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                client_task_id: "task-1".to_owned(),
                client_file_id: "file-1".to_owned(),
                source: ClientSourceFacts {
                    path: PathBuf::from("/tmp/input.mp4"),
                    file_size_bytes: 10,
                    modified_time_unix_nanos: Some("100".to_owned()),
                },
                task_mode: framelean_runtime::TaskMode::VideoCompress,
                priority: WorkPriority::Normal,
                force_reanalysis: false,
            }),
        };
        worker.handle_request(request.clone(), &runtime_tx);
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("analysis work should start");
        };
        worker.handle_runtime(
            RuntimeResult::Completed(Box::new(CompletedWork {
                item: *item,
                result: Err(runtime_error(EngineError::new(
                    ErrorKind::Runtime,
                    "fixture failure",
                ))),
            })),
            &runtime_tx,
        );

        let replay = worker.handle_request(request, &runtime_tx);

        assert_eq!(replay.len(), 2);
        assert!(matches!(
            &replay[1].output,
            WorkerOutput::Event(WorkerEvent::WorkFailed { error, .. })
                if error.message == "fixture failure"
        ));
        assert!(runtime_rx.try_recv().is_err());
    }

    #[test]
    fn forced_reanalysis_creates_a_new_work_item() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let command = AnalyzeMediaCommand {
            client_task_id: "task-1".to_owned(),
            client_file_id: "file-1".to_owned(),
            source: ClientSourceFacts {
                path: PathBuf::from("/tmp/input.mp4"),
                file_size_bytes: 10,
                modified_time_unix_nanos: Some("100".to_owned()),
            },
            task_mode: framelean_runtime::TaskMode::VideoCompress,
            priority: WorkPriority::Normal,
            force_reanalysis: false,
        };
        worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id.clone()),
                request_id: "analysis-1".to_owned(),
                command: WorkerCommand::AnalyzeMedia(command.clone()),
            },
            &runtime_tx,
        );
        let mut forced = command;
        forced.force_reanalysis = true;
        worker.handle_request(
            RequestEnvelope {
                protocol_version: crate::protocol::PROTOCOL_VERSION,
                session_id: Some(session_id),
                request_id: "analysis-2".to_owned(),
                command: WorkerCommand::AnalyzeMedia(forced),
            },
            &runtime_tx,
        );

        assert_eq!(worker.active_work_id.as_deref(), Some("work-1"));
        assert_eq!(worker.analysis_queue.position("work-2"), Some(1));
    }

    #[test]
    fn older_failed_work_does_not_remove_newer_reanalysis_deduplication() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        let command = AnalyzeMediaCommand {
            client_task_id: "task-1".to_owned(),
            client_file_id: "file-1".to_owned(),
            source: ClientSourceFacts {
                path: PathBuf::from("/tmp/input.mp4"),
                file_size_bytes: 10,
                modified_time_unix_nanos: Some("100".to_owned()),
            },
            task_mode: framelean_runtime::TaskMode::VideoCompress,
            priority: WorkPriority::Normal,
            force_reanalysis: false,
        };
        let request = |request_id: &str, command: AnalyzeMediaCommand| RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: request_id.to_owned(),
            command: WorkerCommand::AnalyzeMedia(command),
        };
        worker.handle_request(request("analysis-1", command.clone()), &runtime_tx);
        let RuntimeCommand::Execute(first) = runtime_rx.recv().unwrap() else {
            panic!("first analysis should start");
        };
        let mut forced = command.clone();
        forced.force_reanalysis = true;
        worker.handle_request(request("analysis-2", forced), &runtime_tx);
        worker.handle_runtime(
            RuntimeResult::Completed(Box::new(CompletedWork {
                item: *first,
                result: Err(runtime_error(EngineError::new(
                    ErrorKind::Runtime,
                    "fixture failure",
                ))),
            })),
            &runtime_tx,
        );
        let RuntimeCommand::Execute(second) = runtime_rx.recv().unwrap() else {
            panic!("forced analysis should start");
        };
        assert_eq!(second.work_id, "work-2");

        worker.handle_request(request("analysis-3", command), &runtime_tx);
        assert!(worker.analysis_queue.is_empty());
        assert_eq!(
            worker
                .requests
                .get(&(session_id, "analysis-3".to_owned()))
                .and_then(|value| value.work_id.as_deref()),
            Some("work-2")
        );
    }

    #[test]
    fn persistence_failure_rolls_back_the_runtime_snapshot() {
        #[derive(Default)]
        struct RejectingSnapshotStore {
            saved_id: Option<AnalysisId>,
        }

        impl SnapshotStore for RejectingSnapshotStore {
            fn save(&mut self, snapshot: &framelean_runtime::AnalysisSnapshotRecord) -> Result<()> {
                self.saved_id = Some(snapshot.id.clone());
                Err(EngineError::new(
                    ErrorKind::Snapshot,
                    "fixture persistence failure",
                ))
            }

            fn load(
                &self,
                _analysis_id: &AnalysisId,
            ) -> Result<Option<framelean_runtime::AnalysisSnapshotRecord>> {
                Ok(None)
            }

            fn load_all(&self) -> Result<Vec<framelean_runtime::AnalysisSnapshotRecord>> {
                Ok(Vec::new())
            }
        }

        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../desktop-client/assets/icons/github-black.png");
        let fingerprint = framelean_analysis::SourceFingerprint::from_local_file(&path).unwrap();
        let mut runtime = build_default_runtime().unwrap();
        let mut store = RejectingSnapshotStore::default();
        let item = WorkItem {
            work_id: "work-1".to_owned(),
            request_id: "analysis-1".to_owned(),
            priority: WorkPriority::Normal,
            payload: WorkPayload::Analyze(AnalyzeMediaCommand {
                client_task_id: "task-1".to_owned(),
                client_file_id: "file-1".to_owned(),
                source: ClientSourceFacts {
                    path,
                    file_size_bytes: fingerprint.size_bytes(),
                    modified_time_unix_nanos: fingerprint
                        .modified_time_unix_nanos()
                        .map(|value| value.to_string()),
                },
                task_mode: TaskMode::ImageCompress,
                priority: WorkPriority::Normal,
                force_reanalysis: false,
            }),
        };

        let error = match execute_work(&mut runtime, &mut store, &item) {
            Err(error) => error,
            Ok(_) => panic!("snapshot persistence failure must fail the work item"),
        };

        assert_eq!(error.kind(), ErrorKind::Snapshot);
        let analysis_id = store
            .saved_id
            .expect("successful analysis should reach persistence");
        assert!(runtime.analysis_snapshot(&analysis_id).is_err());
    }

    #[test]
    fn memory_snapshot_store_starts_empty() {
        let store = MemorySnapshotStore::default();
        assert!(store.load_all().unwrap().is_empty());
    }

    #[test]
    fn analysis_batch_is_enqueued_atomically_and_replayed_without_duplicates() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        worker.active_work_id = Some("blocker".to_owned());
        let analyze = |task_id: &str| AnalyzeMediaCommand {
            client_task_id: task_id.to_owned(),
            client_file_id: task_id.to_owned(),
            source: ClientSourceFacts {
                path: PathBuf::from(format!("/tmp/{task_id}.wav")),
                file_size_bytes: 10,
                modified_time_unix_nanos: Some("100".to_owned()),
            },
            task_mode: TaskMode::AudioConvert,
            priority: WorkPriority::Normal,
            force_reanalysis: false,
        };
        let request = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "x".repeat(256),
            command: WorkerCommand::SubmitAnalysisBatch(SubmitAnalysisBatchCommand {
                items: vec![analyze("task-1"), analyze("task-2")],
            }),
        };

        let first = worker.handle_request(request.clone(), &runtime_tx);
        let replay = worker.handle_request(request, &runtime_tx);

        assert_eq!(worker.analysis_queue.len(), 2);
        assert_eq!(worker.analysis_queue.revision(), 2);
        assert!(matches!(
            first.last().map(|output| &output.output),
            Some(WorkerOutput::Response(WorkerResponse::BatchAccepted { items }))
                if items.len() == 2
                    && items[0].client_task_id == "task-1"
                    && items[0].child_request_id.len() <= 256
                    && items[0].queue_position == 1
                    && items[1].client_task_id == "task-2"
                    && items[1].child_request_id.len() <= 256
                    && items[1].queue_position == 2
        ));
        assert!(matches!(
            replay.as_slice(),
            [OutputEnvelope {
                output: WorkerOutput::Response(WorkerResponse::BatchAccepted { items }),
                ..
            }] if items.len() == 2
        ));
    }

    #[test]
    fn preempt_request_replay_enqueues_only_one_control_operation() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, _runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        worker.active_work_id = Some("blocker".to_owned());
        let request = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "preempt-1".to_owned(),
            command: WorkerCommand::PreemptAndStart(crate::protocol::PreemptAndStartCommand {
                execution_id: framelean_core::TaskId::new("execution-2").unwrap(),
            }),
        };

        let first = worker.handle_request(request.clone(), &runtime_tx);
        let replay = worker.handle_request(request, &runtime_tx);

        assert_eq!(worker.control_queue.len(), 1);
        assert!(matches!(
            first.first().map(|output| &output.output),
            Some(WorkerOutput::Response(WorkerResponse::Accepted {
                deduplicated: false,
                ..
            }))
        ));
        assert!(matches!(
            replay.first().map(|output| &output.output),
            Some(WorkerOutput::Response(WorkerResponse::Accepted {
                deduplicated: true,
                ..
            }))
        ));
    }

    #[test]
    fn apply_queue_order_atomically_reorders_analysis_and_replays_result() {
        let mut worker = WorkerCoordinator::new();
        let (runtime_tx, runtime_rx) = mpsc::channel();
        let session_id = establish_ready_session(&mut worker, &runtime_tx);
        worker.active_work_id = Some("blocker".to_owned());
        let analyze = |task_id: &str| AnalyzeMediaCommand {
            client_task_id: task_id.to_owned(),
            client_file_id: format!("file-{task_id}"),
            source: ClientSourceFacts {
                path: PathBuf::from(format!("/tmp/{task_id}.wav")),
                file_size_bytes: 10,
                modified_time_unix_nanos: Some("100".to_owned()),
            },
            task_mode: TaskMode::AudioConvert,
            priority: WorkPriority::Normal,
            force_reanalysis: false,
        };
        for (index, task_id) in ["task-1", "task-2"].iter().enumerate() {
            worker.handle_request(
                RequestEnvelope {
                    protocol_version: crate::protocol::PROTOCOL_VERSION,
                    session_id: Some(session_id.clone()),
                    request_id: format!("analysis-{index}"),
                    command: WorkerCommand::AnalyzeMedia(analyze(task_id)),
                },
                &runtime_tx,
            );
        }
        let request = RequestEnvelope {
            protocol_version: crate::protocol::PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "reorder-1".to_owned(),
            command: WorkerCommand::ApplyQueueOrder(ApplyQueueOrderCommand {
                order_revision: 8,
                expected_analysis_queue_revision: worker.analysis_queue.revision(),
                expected_execution_queue_revision: 0,
                ordered_task_ids: vec!["task-2".to_owned(), "task-1".to_owned()],
            }),
        };
        worker.handle_request(request.clone(), &runtime_tx);
        worker.active_work_id = None;
        let mut dispatch = Vec::new();
        worker.dispatch_next(&runtime_tx, &mut dispatch);
        let RuntimeCommand::Execute(item) = runtime_rx.recv().unwrap() else {
            panic!("queue order should dispatch to the runtime");
        };
        let WorkPayload::ApplyQueueOrder(work) = &item.payload else {
            panic!("runtime item should preserve queue-order work");
        };
        assert!(work.analysis_revision_matches);
        assert_eq!(work.ordered_analysis_work_ids, ["work-2", "work-1"]);

        let completed = worker.handle_runtime(
            RuntimeResult::Completed(Box::new(CompletedWork {
                item: *item,
                result: Ok(RuntimeCompletion::QueueOrderApplied {
                    order_revision: 8,
                    execution_lane: framelean_runtime::ExecutionLaneSnapshot {
                        queue_revision: 0,
                        active_executions: Vec::new(),
                        normal_waiting: Vec::new(),
                        video_resume_stack: Vec::new(),
                        auxiliary_resume_stack: Vec::new(),
                        user_paused: Vec::new(),
                    },
                }),
            })),
            &runtime_tx,
        );

        assert_eq!(
            worker
                .active_analysis
                .as_ref()
                .map(|entry| entry.client_task_id.as_str()),
            Some("task-2")
        );
        assert_eq!(worker.analysis_queue.ordered_work_ids(), ["work-1"]);
        assert!(matches!(
            &completed[0].output,
            WorkerOutput::Event(WorkerEvent::QueueOrderApplied { result, .. })
                if result.order_revision == 8
                    && result.analysis_positions[0].client_task_id == "task-2"
                    && result.analysis_positions[0].queue_position == 1
        ));
        let RuntimeCommand::Execute(_) = runtime_rx.recv().unwrap() else {
            panic!("reordered analysis head should dispatch next");
        };

        let replay = worker.handle_request(request, &runtime_tx);
        assert!(matches!(
            &replay[1].output,
            WorkerOutput::Event(WorkerEvent::QueueOrderApplied { result, .. })
                if result.order_revision == 8
        ));
        assert!(runtime_rx.try_recv().is_err());
    }
}
