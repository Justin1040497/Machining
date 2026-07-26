use std::collections::{HashSet, VecDeque};
use std::path::PathBuf;

use framelean_core::{AnalysisId, EngineError, Result, TaskId};
use framelean_decision::RecalculateSelection;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use crate::{AnalysisRevision, RequestContext};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum OutputCollisionPolicy {
    FailIfExists,
    GenerateUnique,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ExecutionOutputRequest {
    pub requested_path: PathBuf,
    pub collision_policy: OutputCollisionPolicy,
}

impl ExecutionOutputRequest {
    pub(crate) fn validate(&self) -> framelean_core::Result<()> {
        if self.requested_path.as_os_str().is_empty() || self.requested_path.file_name().is_none() {
            return Err(framelean_core::EngineError::invalid_argument(
                "execution output path must identify a file",
            ));
        }
        if !self.requested_path.is_absolute() {
            return Err(framelean_core::EngineError::invalid_argument(
                "execution output path must be absolute",
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ExecutionSubmissionRequest {
    pub analysis_id: AnalysisId,
    pub expected_revision: AnalysisRevision,
    pub selection: RecalculateSelection,
    pub output: ExecutionOutputRequest,
    #[serde(default)]
    pub context: RequestContext,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ExecutionSubmissionResult {
    pub execution_id: TaskId,
    pub state: ExecutionTaskState,
    pub queue_position: usize,
    pub queue_revision: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ExecutionPauseReason {
    User,
    Preemption,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ExecutionCheckpoint {
    pub media_time_us: u64,
    pub processed_bytes: u64,
    pub opaque_token: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ScheduledExecution {
    pub execution_id: TaskId,
    pub state: ExecutionTaskState,
    pub pause_reason: Option<ExecutionPauseReason>,
    pub preempted_by_execution_id: Option<TaskId>,
    pub checkpoint: Option<ExecutionCheckpoint>,
}

impl ScheduledExecution {
    pub fn queued(execution_id: TaskId) -> Self {
        Self {
            execution_id,
            state: ExecutionTaskState::Queued,
            pause_reason: None,
            preempted_by_execution_id: None,
            checkpoint: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ExecutionLaneSnapshot {
    pub queue_revision: u64,
    pub active: Option<ScheduledExecution>,
    pub normal_waiting: Vec<ScheduledExecution>,
    pub resume_stack: Vec<ScheduledExecution>,
    pub user_paused: Vec<ScheduledExecution>,
}

pub trait ExecutionLaneControl {
    fn pause_at_checkpoint(&mut self, execution_id: &TaskId) -> Result<ExecutionCheckpoint>;
    fn start(&mut self, execution_id: &TaskId) -> Result<()>;
    fn resume(&mut self, execution_id: &TaskId, checkpoint: &ExecutionCheckpoint) -> Result<()>;
}

#[derive(Debug, Default)]
pub struct ExecutionScheduler {
    queue_revision: u64,
    active: Option<ScheduledExecution>,
    normal_waiting: VecDeque<ScheduledExecution>,
    resume_stack: Vec<ScheduledExecution>,
}

impl ExecutionScheduler {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn enqueue(&mut self, execution_id: TaskId) -> Result<usize> {
        if self.contains(&execution_id) {
            return Err(EngineError::invalid_argument(
                "execution is already present in the scheduler",
            ));
        }
        self.normal_waiting
            .push_back(ScheduledExecution::queued(execution_id));
        self.bump_revision();
        Ok(self.normal_waiting.len())
    }

    pub fn snapshot(&self) -> ExecutionLaneSnapshot {
        ExecutionLaneSnapshot {
            queue_revision: self.queue_revision,
            active: self.active.clone(),
            normal_waiting: self.normal_waiting.iter().cloned().collect(),
            resume_stack: self.resume_stack.clone(),
            user_paused: Vec::new(),
        }
    }

    pub fn start_next(&mut self, control: &mut dyn ExecutionLaneControl) -> Result<Option<TaskId>> {
        if self.active.is_some() {
            return Ok(None);
        }
        if let Some(entry) = self.resume_stack.last() {
            let checkpoint = entry.checkpoint.as_ref().ok_or_else(|| {
                EngineError::invalid_task_state("preempted execution has no checkpoint")
            })?;
            control.resume(&entry.execution_id, checkpoint)?;
            let mut resumed = self
                .resume_stack
                .pop()
                .expect("resume stack entry was inspected before removal");
            resumed.state = ExecutionTaskState::Running;
            resumed.pause_reason = None;
            resumed.preempted_by_execution_id = None;
            resumed.checkpoint = None;
            let execution_id = resumed.execution_id.clone();
            self.active = Some(resumed);
            self.bump_revision();
            return Ok(Some(execution_id));
        }
        let Some(entry) = self.normal_waiting.front() else {
            return Ok(None);
        };
        control.start(&entry.execution_id)?;
        let mut started = self
            .normal_waiting
            .pop_front()
            .expect("waiting entry was inspected before removal");
        started.state = ExecutionTaskState::Running;
        let execution_id = started.execution_id.clone();
        self.active = Some(started);
        self.bump_revision();
        Ok(Some(execution_id))
    }

    pub fn preempt_and_start(
        &mut self,
        target_execution_id: &TaskId,
        control: &mut dyn ExecutionLaneControl,
    ) -> Result<()> {
        let active = self.active.as_ref().ok_or_else(|| {
            EngineError::invalid_task_state("cannot preempt an idle execution lane")
        })?;
        if active.execution_id == *target_execution_id {
            return Ok(());
        }
        let target_position = self
            .normal_waiting
            .iter()
            .position(|entry| entry.execution_id == *target_execution_id)
            .ok_or_else(|| {
                EngineError::invalid_task_state(
                    "preemption target is not in the normal waiting queue",
                )
            })?;

        let active_id = active.execution_id.clone();
        let checkpoint = control.pause_at_checkpoint(&active_id)?;
        if let Err(start_error) = control.start(target_execution_id) {
            return match control.resume(&active_id, &checkpoint) {
                Ok(()) => Err(start_error),
                Err(resume_error) => Err(EngineError::invalid_task_state(format!(
                    "preemption target failed to start and the active execution could not be restored: {}; restore error: {}",
                    start_error.message(),
                    resume_error.message()
                ))),
            };
        }

        let mut preempted = self
            .active
            .take()
            .expect("active execution was validated before preemption");
        preempted.state = ExecutionTaskState::Preempted;
        preempted.pause_reason = Some(ExecutionPauseReason::Preemption);
        preempted.preempted_by_execution_id = Some(target_execution_id.clone());
        preempted.checkpoint = Some(checkpoint);
        self.resume_stack.push(preempted);

        let mut target = self
            .normal_waiting
            .remove(target_position)
            .expect("preemption target position was validated before removal");
        target.state = ExecutionTaskState::Running;
        target.pause_reason = None;
        target.preempted_by_execution_id = None;
        target.checkpoint = None;
        self.active = Some(target);
        self.bump_revision();
        Ok(())
    }

    pub fn finish_active(
        &mut self,
        terminal_state: ExecutionTaskState,
        control: &mut dyn ExecutionLaneControl,
    ) -> Result<Option<TaskId>> {
        self.clear_active_terminal(terminal_state)?;
        self.start_next(control)
    }

    pub fn clear_active_terminal(&mut self, terminal_state: ExecutionTaskState) -> Result<TaskId> {
        if !matches!(
            terminal_state,
            ExecutionTaskState::Completed
                | ExecutionTaskState::Failed
                | ExecutionTaskState::Cancelled
        ) {
            return Err(EngineError::invalid_argument(
                "finish_active requires a terminal execution state",
            ));
        }
        let finished = self.active.take().ok_or_else(|| {
            EngineError::invalid_task_state("cannot finish an idle execution lane")
        })?;
        self.bump_revision();
        Ok(finished.execution_id)
    }

    pub fn pause_active_for_user(
        &mut self,
        control: &mut dyn ExecutionLaneControl,
    ) -> Result<ScheduledExecution> {
        let active_id = self
            .active
            .as_ref()
            .map(|entry| entry.execution_id.clone())
            .ok_or_else(|| {
                EngineError::invalid_task_state("cannot pause an idle execution lane")
            })?;
        let checkpoint = control.pause_at_checkpoint(&active_id)?;
        let mut paused = self
            .active
            .take()
            .expect("active execution was validated before user pause");
        paused.state = ExecutionTaskState::Paused;
        paused.pause_reason = Some(ExecutionPauseReason::User);
        paused.checkpoint = Some(checkpoint.clone());
        self.bump_revision();
        Ok(paused)
    }

    pub fn resume_user_paused(
        &mut self,
        mut paused: ScheduledExecution,
        control: &mut dyn ExecutionLaneControl,
    ) -> Result<()> {
        if self.active.is_some() {
            return Err(EngineError::invalid_task_state(
                "cannot resume a user-paused execution while the lane is active",
            ));
        }
        if paused.pause_reason != Some(ExecutionPauseReason::User)
            || paused.state != ExecutionTaskState::Paused
        {
            return Err(EngineError::invalid_task_state(
                "only a user-paused execution can be resumed explicitly",
            ));
        }
        let checkpoint = paused.checkpoint.as_ref().ok_or_else(|| {
            EngineError::invalid_task_state("user-paused execution has no checkpoint")
        })?;
        control.resume(&paused.execution_id, checkpoint)?;
        paused.state = ExecutionTaskState::Running;
        paused.pause_reason = None;
        paused.checkpoint = None;
        self.active = Some(paused);
        self.bump_revision();
        Ok(())
    }

    pub fn reorder_waiting(
        &mut self,
        expected_revision: u64,
        ordered_execution_ids: &[TaskId],
    ) -> Result<u64> {
        if expected_revision != self.queue_revision {
            return Err(EngineError::with_code(
                framelean_core::ErrorKind::Runtime,
                framelean_core::EngineErrorCode::QueueRevisionConflict,
                format!(
                    "execution queue revision conflict: expected {expected_revision}, current {}",
                    self.queue_revision
                ),
            ));
        }
        let mut requested = HashSet::with_capacity(ordered_execution_ids.len());
        for execution_id in ordered_execution_ids {
            if !requested.insert(execution_id.as_str()) {
                return Err(EngineError::invalid_argument(
                    "execution queue order contains a duplicate execution id",
                ));
            }
            if !self
                .normal_waiting
                .iter()
                .any(|entry| entry.execution_id == *execution_id)
            {
                return Err(EngineError::invalid_argument(
                    "execution queue order contains an unknown execution id",
                ));
            }
        }
        if self
            .normal_waiting
            .iter()
            .any(|entry| !requested.contains(entry.execution_id.as_str()))
        {
            return Err(EngineError::invalid_argument(
                "execution queue order omits a waiting execution id",
            ));
        }
        let changed = self
            .normal_waiting
            .iter()
            .map(|entry| &entry.execution_id)
            .ne(ordered_execution_ids.iter());
        if !changed {
            return Ok(self.queue_revision);
        }
        let mut remaining = std::mem::take(&mut self.normal_waiting);
        for execution_id in ordered_execution_ids {
            let index = remaining
                .iter()
                .position(|entry| entry.execution_id == *execution_id)
                .expect("waiting execution order was validated before mutation");
            self.normal_waiting.push_back(
                remaining
                    .remove(index)
                    .expect("validated waiting execution must still exist"),
            );
        }
        self.bump_revision();
        Ok(self.queue_revision)
    }

    pub fn remove_non_active(&mut self, execution_id: &TaskId) -> Option<ScheduledExecution> {
        if let Some(position) = self
            .normal_waiting
            .iter()
            .position(|entry| entry.execution_id == *execution_id)
        {
            let removed = self.normal_waiting.remove(position);
            if removed.is_some() {
                self.bump_revision();
            }
            return removed;
        }
        if let Some(position) = self
            .resume_stack
            .iter()
            .position(|entry| entry.execution_id == *execution_id)
        {
            let removed = self.resume_stack.remove(position);
            self.bump_revision();
            return Some(removed);
        }
        None
    }

    fn bump_revision(&mut self) {
        self.queue_revision = self.queue_revision.saturating_add(1);
    }

    fn contains(&self, execution_id: &TaskId) -> bool {
        self.active
            .as_ref()
            .is_some_and(|entry| entry.execution_id == *execution_id)
            || self
                .normal_waiting
                .iter()
                .any(|entry| entry.execution_id == *execution_id)
            || self
                .resume_stack
                .iter()
                .any(|entry| entry.execution_id == *execution_id)
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;

    #[derive(Default)]
    struct RecordingControl {
        calls: Vec<String>,
        fail_pause_for: Option<TaskId>,
        fail_start_for: Option<TaskId>,
    }

    impl ExecutionLaneControl for RecordingControl {
        fn pause_at_checkpoint(&mut self, execution_id: &TaskId) -> Result<ExecutionCheckpoint> {
            self.calls.push(format!("pause:{execution_id}"));
            if self.fail_pause_for.as_ref() == Some(execution_id) {
                return Err(EngineError::invalid_task_state("checkpoint pause failed"));
            }
            Ok(ExecutionCheckpoint {
                media_time_us: self.calls.len() as u64,
                processed_bytes: self.calls.len() as u64 * 100,
                opaque_token: format!("checkpoint:{execution_id}"),
            })
        }

        fn start(&mut self, execution_id: &TaskId) -> Result<()> {
            self.calls.push(format!("start:{execution_id}"));
            if self.fail_start_for.as_ref() == Some(execution_id) {
                return Err(EngineError::invalid_task_state("execution start failed"));
            }
            Ok(())
        }

        fn resume(
            &mut self,
            execution_id: &TaskId,
            _checkpoint: &ExecutionCheckpoint,
        ) -> Result<()> {
            self.calls.push(format!("resume:{execution_id}"));
            Ok(())
        }
    }

    fn execution_id(value: &str) -> TaskId {
        TaskId::new(value).unwrap()
    }

    #[test]
    fn output_request_requires_an_absolute_file_path() {
        let relative = ExecutionOutputRequest {
            requested_path: PathBuf::from("output.mp4"),
            collision_policy: OutputCollisionPolicy::FailIfExists,
        };
        let directory = ExecutionOutputRequest {
            requested_path: PathBuf::from("/"),
            collision_policy: OutputCollisionPolicy::FailIfExists,
        };

        assert!(relative.validate().is_err());
        assert!(directory.validate().is_err());
    }

    #[test]
    fn nested_preemption_resumes_in_strict_lifo_order() {
        let a1 = execution_id("a1");
        let a2 = execution_id("a2");
        let a3 = execution_id("a3");
        let mut scheduler = ExecutionScheduler::new();
        let mut control = RecordingControl::default();
        scheduler.enqueue(a1.clone()).unwrap();
        scheduler.enqueue(a2.clone()).unwrap();
        scheduler.enqueue(a3.clone()).unwrap();

        assert_eq!(
            scheduler.start_next(&mut control).unwrap(),
            Some(a1.clone())
        );
        scheduler.preempt_and_start(&a3, &mut control).unwrap();
        scheduler.preempt_and_start(&a2, &mut control).unwrap();

        let snapshot = scheduler.snapshot();
        assert_eq!(snapshot.active.unwrap().execution_id, a2);
        assert!(snapshot.normal_waiting.is_empty());
        assert_eq!(
            snapshot
                .resume_stack
                .iter()
                .map(|entry| entry.execution_id.clone())
                .collect::<Vec<_>>(),
            [a1.clone(), a3.clone()]
        );
        assert_eq!(
            scheduler
                .finish_active(ExecutionTaskState::Completed, &mut control)
                .unwrap(),
            Some(a3.clone())
        );
        assert_eq!(
            scheduler
                .finish_active(ExecutionTaskState::Failed, &mut control)
                .unwrap(),
            Some(a1.clone())
        );
        assert_eq!(
            scheduler
                .finish_active(ExecutionTaskState::Cancelled, &mut control)
                .unwrap(),
            None
        );
        assert_eq!(
            control.calls,
            [
                "start:a1",
                "pause:a1",
                "start:a3",
                "pause:a3",
                "start:a2",
                "resume:a3",
                "resume:a1",
            ]
        );
    }

    #[test]
    fn failed_safe_pause_keeps_active_and_target_in_place() {
        let active = execution_id("active");
        let target = execution_id("target");
        let mut scheduler = ExecutionScheduler::new();
        let mut control = RecordingControl::default();
        scheduler.enqueue(active.clone()).unwrap();
        scheduler.enqueue(target.clone()).unwrap();
        scheduler.start_next(&mut control).unwrap();
        control.fail_pause_for = Some(active.clone());

        assert!(scheduler.preempt_and_start(&target, &mut control).is_err());
        let snapshot = scheduler.snapshot();
        assert_eq!(snapshot.active.unwrap().execution_id, active);
        assert_eq!(snapshot.normal_waiting[0].execution_id, target);
        assert!(snapshot.resume_stack.is_empty());
    }

    #[test]
    fn failed_target_start_restores_active_without_mutating_scheduler() {
        let active = execution_id("active");
        let target = execution_id("target");
        let mut scheduler = ExecutionScheduler::new();
        let mut control = RecordingControl::default();
        scheduler.enqueue(active.clone()).unwrap();
        scheduler.enqueue(target.clone()).unwrap();
        scheduler.start_next(&mut control).unwrap();
        control.fail_start_for = Some(target.clone());

        assert!(scheduler.preempt_and_start(&target, &mut control).is_err());
        let snapshot = scheduler.snapshot();
        assert_eq!(snapshot.active.unwrap().execution_id, active);
        assert_eq!(snapshot.normal_waiting[0].execution_id, target);
        assert!(snapshot.resume_stack.is_empty());
        assert_eq!(
            control.calls,
            [
                "start:active",
                "pause:active",
                "start:target",
                "resume:active"
            ]
        );
    }

    #[test]
    fn user_paused_execution_is_not_added_to_the_auto_resume_stack() {
        let active = execution_id("active");
        let waiting = execution_id("waiting");
        let mut scheduler = ExecutionScheduler::new();
        let mut control = RecordingControl::default();
        scheduler.enqueue(active.clone()).unwrap();
        scheduler.enqueue(waiting.clone()).unwrap();
        scheduler.start_next(&mut control).unwrap();

        let paused = scheduler.pause_active_for_user(&mut control).unwrap();
        let snapshot = scheduler.snapshot();
        assert!(snapshot.active.is_none());
        assert!(snapshot.resume_stack.is_empty());
        assert_eq!(snapshot.normal_waiting[0].execution_id, waiting.clone());
        assert_eq!(scheduler.start_next(&mut control).unwrap(), Some(waiting));
        assert_eq!(paused.execution_id, active);
        assert_eq!(paused.pause_reason, Some(ExecutionPauseReason::User));
    }
}
