use std::path::PathBuf;
use std::sync::Arc;

use framelean_core::Result;
use framelean_decision::ResolvedConfiguration;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExecutionBackendRequest {
    pub source_path: PathBuf,
    pub working_output_path: PathBuf,
    pub configuration: ResolvedConfiguration,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ExecutionProgress {
    pub media_time_us: u64,
    pub processed_bytes: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExecutionBackendControl {
    Continue,
    Cancel,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExecutionBackendOutcome {
    Completed(ExecutionProgress),
    Cancelled(ExecutionProgress),
}

pub trait ExecutionBackendObserver {
    fn on_progress(&mut self, progress: ExecutionProgress) -> ExecutionBackendControl;
}

pub trait ExecutionBackend: Send + Sync {
    fn execute(
        &self,
        request: &ExecutionBackendRequest,
        observer: &mut dyn ExecutionBackendObserver,
    ) -> Result<ExecutionBackendOutcome>;
}

#[derive(Clone)]
pub struct ExecutionServices {
    pub backend: Arc<dyn ExecutionBackend>,
}
