use std::path::PathBuf;

use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::common::{
    AnalysisId, AnalysisRevision, ExecutionId, FllErrorCode, RuntimeRequestContext,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OutputCollisionPolicy {
    FailIfExists,
    GenerateUnique,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionOutputRequest {
    pub requested_path: PathBuf,
    pub collision_policy: OutputCollisionPolicy,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExecutionSubmissionRequest {
    pub analysis_id: AnalysisId,
    pub expected_revision: AnalysisRevision,
    pub selection: Value,
    pub output: ExecutionOutputRequest,
    pub context: RuntimeRequestContext,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReorderExecutionsRequest {
    pub expected_revision: u64,
    pub ordered_execution_ids: Vec<ExecutionId>,
}

impl Serialize for ExecutionSubmissionRequest {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        #[derive(Serialize)]
        struct Wire<'a> {
            analysis_id: &'a AnalysisId,
            expected_revision: AnalysisRevision,
            selection: &'a Value,
            output: &'a ExecutionOutputRequest,
            context: &'a RuntimeRequestContext,
        }

        Wire {
            analysis_id: &self.analysis_id,
            expected_revision: self.expected_revision,
            selection: &self.selection,
            output: &self.output,
            context: &self.context,
        }
        .serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for ExecutionSubmissionRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        #[derive(Deserialize)]
        struct Wire {
            analysis_id: AnalysisId,
            expected_revision: AnalysisRevision,
            selection: Value,
            output: ExecutionOutputRequest,
            #[serde(default)]
            context: RuntimeRequestContext,
        }

        let wire = Wire::deserialize(deserializer)?;
        Ok(Self {
            analysis_id: wire.analysis_id,
            expected_revision: wire.expected_revision,
            selection: wire.selection,
            output: wire.output,
            context: wire.context,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionSubmissionResult {
    pub execution_id: ExecutionId,
    pub state: ExecutionTaskState,
    pub queue_position: usize,
    pub queue_revision: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExecutionTaskState {
    Queued,
    Running,
    Preempting,
    Preempted,
    Resuming,
    PauseRequested,
    Paused,
    CancelRequested,
    Cancelled,
    Completed,
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExecutionPauseReason {
    User,
    Preemption,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExecutionResourcePool {
    Video,
    Auxiliary,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct ExecutionProgress {
    pub media_time_us: u64,
    pub processed_bytes: u64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ScheduledExecutionProjection {
    pub execution_id: ExecutionId,
    pub resource_pool: ExecutionResourcePool,
    pub state: ExecutionTaskState,
    pub pause_reason: Option<ExecutionPauseReason>,
    pub preempted_by_execution_id: Option<ExecutionId>,
    pub checkpoint: Option<Value>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExecutionLaneSnapshot {
    pub queue_revision: u64,
    pub active_executions: Vec<ScheduledExecutionProjection>,
    pub normal_waiting: Vec<ScheduledExecutionProjection>,
    pub video_resume_stack: Vec<ScheduledExecutionProjection>,
    pub auxiliary_resume_stack: Vec<ScheduledExecutionProjection>,
    pub user_paused: Vec<ScheduledExecutionProjection>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionEvent {
    pub execution_id: ExecutionId,
    pub resource_pool: ExecutionResourcePool,
    pub sequence: u64,
    pub state: ExecutionTaskState,
    pub pause_reason: Option<ExecutionPauseReason>,
    pub preempted_by_execution_id: Option<ExecutionId>,
    pub resume_depth: usize,
    pub progress: Option<ExecutionProgress>,
    pub output_path: Option<PathBuf>,
    pub error_code: Option<FllErrorCode>,
    pub message: Option<String>,
}

impl Serialize for ScheduledExecutionProjection {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        #[derive(Serialize)]
        struct Wire<'a> {
            execution_id: &'a ExecutionId,
            resource_pool: ExecutionResourcePool,
            state: ExecutionTaskState,
            pause_reason: Option<ExecutionPauseReason>,
            preempted_by_execution_id: Option<&'a ExecutionId>,
            checkpoint: &'a Option<Value>,
        }

        Wire {
            execution_id: &self.execution_id,
            resource_pool: self.resource_pool,
            state: self.state,
            pause_reason: self.pause_reason,
            preempted_by_execution_id: self.preempted_by_execution_id.as_ref(),
            checkpoint: &self.checkpoint,
        }
        .serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for ScheduledExecutionProjection {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        #[derive(Deserialize)]
        struct Wire {
            execution_id: ExecutionId,
            resource_pool: ExecutionResourcePool,
            state: ExecutionTaskState,
            pause_reason: Option<ExecutionPauseReason>,
            preempted_by_execution_id: Option<ExecutionId>,
            checkpoint: Option<Value>,
        }

        let wire = Wire::deserialize(deserializer)?;
        Ok(Self {
            execution_id: wire.execution_id,
            resource_pool: wire.resource_pool,
            state: wire.state,
            pause_reason: wire.pause_reason,
            preempted_by_execution_id: wire.preempted_by_execution_id,
            checkpoint: wire.checkpoint,
        })
    }
}

impl Serialize for ExecutionLaneSnapshot {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        #[derive(Serialize)]
        struct Wire<'a> {
            queue_revision: u64,
            active_executions: &'a [ScheduledExecutionProjection],
            normal_waiting: &'a [ScheduledExecutionProjection],
            video_resume_stack: &'a [ScheduledExecutionProjection],
            auxiliary_resume_stack: &'a [ScheduledExecutionProjection],
            user_paused: &'a [ScheduledExecutionProjection],
        }

        Wire {
            queue_revision: self.queue_revision,
            active_executions: &self.active_executions,
            normal_waiting: &self.normal_waiting,
            video_resume_stack: &self.video_resume_stack,
            auxiliary_resume_stack: &self.auxiliary_resume_stack,
            user_paused: &self.user_paused,
        }
        .serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for ExecutionLaneSnapshot {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        #[derive(Deserialize)]
        struct Wire {
            queue_revision: u64,
            active_executions: Vec<ScheduledExecutionProjection>,
            normal_waiting: Vec<ScheduledExecutionProjection>,
            video_resume_stack: Vec<ScheduledExecutionProjection>,
            auxiliary_resume_stack: Vec<ScheduledExecutionProjection>,
            user_paused: Vec<ScheduledExecutionProjection>,
        }

        let wire = Wire::deserialize(deserializer)?;
        Ok(Self {
            queue_revision: wire.queue_revision,
            active_executions: wire.active_executions,
            normal_waiting: wire.normal_waiting,
            video_resume_stack: wire.video_resume_stack,
            auxiliary_resume_stack: wire.auxiliary_resume_stack,
            user_paused: wire.user_paused,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn selection_round_trips_as_opaque_json() {
        let request = ExecutionSubmissionRequest {
            analysis_id: AnalysisId::new("analysis-1"),
            expected_revision: AnalysisRevision::new(2),
            selection: json!({"future_override": {"value": true}}),
            output: ExecutionOutputRequest {
                requested_path: "/tmp/output.mkv".into(),
                collision_policy: OutputCollisionPolicy::FailIfExists,
            },
            context: RuntimeRequestContext::default(),
        };
        let value = serde_json::to_value(&request).unwrap();
        let decoded: ExecutionSubmissionRequest = serde_json::from_value(value.clone()).unwrap();
        assert_eq!(serde_json::to_value(decoded).unwrap(), value);
    }

    #[test]
    fn lane_projection_preserves_legacy_shape_and_opaque_checkpoint() {
        let value = serde_json::json!({
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
        let local: ExecutionLaneSnapshot = serde_json::from_value(value.clone()).unwrap();
        assert_eq!(serde_json::to_value(local).unwrap(), value);
    }

    #[test]
    fn reorder_request_round_trips_with_transparent_execution_ids() {
        let request = ReorderExecutionsRequest {
            expected_revision: 4,
            ordered_execution_ids: vec![
                ExecutionId::new("execution-2"),
                ExecutionId::new("execution-1"),
            ],
        };
        let value = serde_json::to_value(&request).unwrap();
        let decoded: ReorderExecutionsRequest = serde_json::from_value(value.clone()).unwrap();
        assert_eq!(serde_json::to_value(decoded).unwrap(), value);
    }

    #[test]
    fn event_shape_uses_transparent_ids_and_projection_labels() {
        let event = ExecutionEvent {
            execution_id: ExecutionId::new("execution-1"),
            resource_pool: ExecutionResourcePool::Auxiliary,
            sequence: 4,
            state: ExecutionTaskState::Paused,
            pause_reason: Some(ExecutionPauseReason::Preemption),
            preempted_by_execution_id: None,
            resume_depth: 1,
            progress: Some(ExecutionProgress {
                media_time_us: 12,
                processed_bytes: 34,
            }),
            output_path: None,
            error_code: Some(FllErrorCode("EXTERNAL_CODE".to_owned())),
            message: Some("paused".to_owned()),
        };
        let value = serde_json::to_value(event).unwrap();
        assert_eq!(value["execution_id"], "execution-1");
        assert_eq!(value["resource_pool"], "auxiliary");
        assert_eq!(value["state"], "paused");
        assert_eq!(value["error_code"], "EXTERNAL_CODE");
    }

    #[test]
    fn event_wire_shape_matches_legacy_document_and_accepts_unknown_code() {
        let value = serde_json::json!({
            "execution_id": "execution-1",
            "resource_pool": "auxiliary",
            "sequence": 4,
            "state": "failed",
            "pause_reason": null,
            "preempted_by_execution_id": null,
            "resume_depth": 0,
            "progress": {"media_time_us": 12, "processed_bytes": 34},
            "output_path": "/tmp/output.mkv",
            "error_code": "FUTURE_EXECUTION_CODE",
            "message": "future failure"
        });
        let local: ExecutionEvent = serde_json::from_value(value.clone()).unwrap();
        assert_eq!(serde_json::to_value(local).unwrap(), value);
    }
}
