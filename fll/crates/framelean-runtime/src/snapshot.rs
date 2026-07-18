use std::collections::{HashMap, VecDeque};
use std::time::{Duration, Instant};

use framelean_analysis::{MediaAnalysis, MediaAnalyzeRequest, SourceFingerprint};
use framelean_core::{AnalysisId, EngineError, EngineErrorCode, ErrorKind, Result};
use framelean_decision::{
    CapabilitySet, CustomTargetSizeOptions, PresetDefinition, Recommendation,
    ResolvedConfiguration, TaskMode,
};
use framelean_environment::{EnvironmentSnapshot, ResourceSample};
use framelean_media::capability::BackendCatalog;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(
    Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, JsonSchema,
)]
#[serde(transparent)]
pub struct AnalysisRevision(u64);

impl AnalysisRevision {
    pub const fn initial() -> Self {
        Self(1)
    }

    pub const fn value(self) -> u64 {
        self.0
    }

    pub fn next(self) -> Result<Self> {
        self.0
            .checked_add(1)
            .map(Self)
            .ok_or_else(|| EngineError::new(ErrorKind::Snapshot, "analysis revision overflow"))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EvictionStrategy {
    LeastRecentlyUsed,
    Oldest,
    RejectNew,
}

#[derive(Debug, Clone)]
pub struct AnalysisSnapshotPolicy {
    pub max_entries: Option<usize>,
    pub idle_ttl: Option<Duration>,
    pub eviction_strategy: EvictionStrategy,
}

impl AnalysisSnapshotPolicy {
    pub fn new(
        max_entries: Option<usize>,
        idle_ttl: Option<Duration>,
        eviction_strategy: EvictionStrategy,
    ) -> Result<Self> {
        if max_entries == Some(0) {
            return Err(EngineError::invalid_argument(
                "snapshot max entries must be greater than zero",
            ));
        }
        if idle_ttl.is_some_and(|value| value.is_zero()) {
            return Err(EngineError::invalid_argument(
                "snapshot idle TTL must be greater than zero",
            ));
        }
        Ok(Self {
            max_entries,
            idle_ttl,
            eviction_strategy,
        })
    }
}

#[derive(Clone)]
pub(crate) struct AnalysisSnapshot {
    pub id: AnalysisId,
    pub revision: AnalysisRevision,
    pub task_mode: TaskMode,
    pub media_request: MediaAnalyzeRequest,
    pub media: MediaAnalysis,
    pub source_fingerprint: SourceFingerprint,
    pub environment: EnvironmentSnapshot,
    pub resource_sample: Option<ResourceSample>,
    pub backend_catalog: BackendCatalog,
    pub capabilities: CapabilitySet,
    pub recommendation: Recommendation,
    pub presets: Vec<PresetDefinition>,
    pub custom_target_size: CustomTargetSizeOptions,
    pub resolved_configuration: Option<ResolvedConfiguration>,
    pub created_at: Instant,
    pub last_accessed_at: Instant,
}

pub struct AnalysisSnapshotStore {
    policy: AnalysisSnapshotPolicy,
    snapshots: HashMap<AnalysisId, AnalysisSnapshot>,
    access_order: VecDeque<AnalysisId>,
}

impl AnalysisSnapshotStore {
    pub fn new(policy: AnalysisSnapshotPolicy) -> Self {
        Self {
            policy,
            snapshots: HashMap::new(),
            access_order: VecDeque::new(),
        }
    }

    pub(crate) fn insert(&mut self, snapshot: AnalysisSnapshot) -> Result<()> {
        self.remove_expired();
        if self
            .policy
            .max_entries
            .is_some_and(|maximum| self.snapshots.len() >= maximum)
        {
            match self.policy.eviction_strategy {
                EvictionStrategy::RejectNew => {
                    return Err(EngineError::new(
                        ErrorKind::Snapshot,
                        "analysis snapshot capacity reached",
                    ));
                }
                EvictionStrategy::LeastRecentlyUsed => self.evict_access_order(),
                EvictionStrategy::Oldest => self.evict_oldest(),
            }
        }
        self.access_order.push_back(snapshot.id.clone());
        self.snapshots.insert(snapshot.id.clone(), snapshot);
        Ok(())
    }

    pub(crate) fn get_mut(&mut self, id: &AnalysisId) -> Result<&mut AnalysisSnapshot> {
        self.remove_expired();
        let snapshot = self.snapshots.get_mut(id).ok_or_else(|| {
            EngineError::with_code(
                ErrorKind::Snapshot,
                EngineErrorCode::AnalysisSnapshotExpired,
                "analysis snapshot is missing or expired",
            )
        })?;
        snapshot.last_accessed_at = Instant::now();
        self.access_order.retain(|value| value != id);
        self.access_order.push_back(id.clone());
        Ok(snapshot)
    }

    pub fn len(&self) -> usize {
        self.snapshots.len()
    }

    pub fn is_empty(&self) -> bool {
        self.snapshots.is_empty()
    }

    fn remove_expired(&mut self) {
        let Some(ttl) = self.policy.idle_ttl else {
            return;
        };
        let now = Instant::now();
        self.snapshots
            .retain(|_, snapshot| now.duration_since(snapshot.last_accessed_at) < ttl);
        self.access_order
            .retain(|id| self.snapshots.contains_key(id));
    }

    fn evict_access_order(&mut self) {
        if let Some(id) = self.access_order.pop_front() {
            self.snapshots.remove(&id);
        }
    }

    fn evict_oldest(&mut self) {
        if let Some(id) = self
            .snapshots
            .values()
            .min_by_key(|snapshot| snapshot.created_at)
            .map(|snapshot| snapshot.id.clone())
        {
            self.snapshots.remove(&id);
            self.access_order.retain(|value| value != &id);
        }
    }
}
