use std::collections::HashMap;
use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

use framelean_core::{EngineError, ErrorKind, Result};

use crate::runtime_api::{AnalysisId, AnalysisSnapshotRecordDocument};

static TEMP_FILE_SEQUENCE: AtomicU64 = AtomicU64::new(1);
const DEFAULT_MAX_SNAPSHOT_ENTRIES: usize = 512;
const DEFAULT_MAX_SNAPSHOT_TOTAL_BYTES: usize = 4 * 1024 * 1024 * 1024;
const DEFAULT_MAX_SNAPSHOT_RECORD_BYTES: usize = 64 * 1024 * 1024;

pub(crate) trait SnapshotStore: Send {
    fn save(&mut self, snapshot: &AnalysisSnapshotRecordDocument) -> Result<()>;
    #[allow(dead_code)]
    fn load(&self, analysis_id: &AnalysisId) -> Result<Option<AnalysisSnapshotRecordDocument>>;
    fn load_all(&self) -> Result<Vec<AnalysisSnapshotRecordDocument>>;
}

impl<T: SnapshotStore + ?Sized> SnapshotStore for Box<T> {
    fn save(&mut self, snapshot: &AnalysisSnapshotRecordDocument) -> Result<()> {
        (**self).save(snapshot)
    }

    fn load(&self, analysis_id: &AnalysisId) -> Result<Option<AnalysisSnapshotRecordDocument>> {
        (**self).load(analysis_id)
    }

    fn load_all(&self) -> Result<Vec<AnalysisSnapshotRecordDocument>> {
        (**self).load_all()
    }
}

#[derive(Default)]
pub struct MemorySnapshotStore {
    snapshots: HashMap<AnalysisId, AnalysisSnapshotRecordDocument>,
}

impl SnapshotStore for MemorySnapshotStore {
    fn save(&mut self, snapshot: &AnalysisSnapshotRecordDocument) -> Result<()> {
        let identity = snapshot.identity();
        let snapshot_id = AnalysisId::new(identity.id.clone());
        if let Some(existing) = self.snapshots.get(&snapshot_id) {
            if existing.identity().revision != identity.revision {
                return Err(EngineError::with_code(
                    ErrorKind::Snapshot,
                    framelean_core::EngineErrorCode::AnalysisRevisionConflict,
                    "analysis snapshot id already stores a different revision",
                ));
            }
            return Err(EngineError::new(
                ErrorKind::Snapshot,
                "analysis snapshot id is already stored",
            ));
        }
        self.snapshots.insert(snapshot_id, snapshot.clone());
        Ok(())
    }

    fn load(&self, analysis_id: &AnalysisId) -> Result<Option<AnalysisSnapshotRecordDocument>> {
        Ok(self.snapshots.get(analysis_id).cloned())
    }

    fn load_all(&self) -> Result<Vec<AnalysisSnapshotRecordDocument>> {
        let mut snapshots: Vec<_> = self.snapshots.values().cloned().collect();
        snapshots.sort_by(|left, right| {
            left.identity()
                .id
                .as_str()
                .cmp(right.identity().id.as_str())
        });
        Ok(snapshots)
    }
}

pub struct DirectorySnapshotStore {
    root: PathBuf,
    _lock: File,
    limits: SnapshotStoreLimits,
    snapshot_count: usize,
    snapshot_bytes: usize,
}

#[derive(Debug, Clone, Copy)]
struct SnapshotStoreLimits {
    max_entries: usize,
    max_total_bytes: usize,
    max_record_bytes: usize,
}

impl DirectorySnapshotStore {
    pub fn new(root: impl Into<PathBuf>) -> Result<Self> {
        Self::new_with_limits(
            root,
            SnapshotStoreLimits {
                max_entries: DEFAULT_MAX_SNAPSHOT_ENTRIES,
                max_total_bytes: DEFAULT_MAX_SNAPSHOT_TOTAL_BYTES,
                max_record_bytes: DEFAULT_MAX_SNAPSHOT_RECORD_BYTES,
            },
        )
    }

    fn new_with_limits(root: impl Into<PathBuf>, limits: SnapshotStoreLimits) -> Result<Self> {
        if limits.max_entries == 0 || limits.max_total_bytes == 0 || limits.max_record_bytes == 0 {
            return Err(EngineError::new(
                ErrorKind::Snapshot,
                "analysis snapshot store limits must be greater than zero",
            ));
        }
        let root = root.into();
        fs::create_dir_all(&root).map_err(|error| {
            EngineError::with_source(
                ErrorKind::Snapshot,
                "cannot create analysis snapshot directory",
                error,
            )
        })?;
        if !root.is_dir() {
            return Err(EngineError::new(
                ErrorKind::Snapshot,
                "analysis snapshot path is not a directory",
            ));
        }
        let lock_path = root.join(".fengine-snapshot.lock");
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(&lock_path)
            .map_err(|error| {
                EngineError::with_source(
                    ErrorKind::Snapshot,
                    "cannot open analysis snapshot directory lock",
                    error,
                )
            })?;
        lock.try_lock().map_err(|error| {
            EngineError::new(
                ErrorKind::Snapshot,
                format!("analysis snapshot directory is already in use: {error}"),
            )
        })?;
        let (snapshot_count, snapshot_bytes) = snapshot_directory_usage(&root)?;
        if snapshot_count > limits.max_entries || snapshot_bytes > limits.max_total_bytes {
            return Err(EngineError::new(
                ErrorKind::Snapshot,
                "analysis snapshot directory already exceeds its capacity",
            ));
        }
        Ok(Self {
            root,
            _lock: lock,
            limits,
            snapshot_count,
            snapshot_bytes,
        })
    }

    fn path_for(&self, analysis_id: &AnalysisId) -> Result<PathBuf> {
        validate_file_stem(analysis_id.as_str())?;
        Ok(self.root.join(format!("{}.json", analysis_id.as_str())))
    }
}

impl SnapshotStore for DirectorySnapshotStore {
    fn save(&mut self, snapshot: &AnalysisSnapshotRecordDocument) -> Result<()> {
        let identity = snapshot.identity();
        let snapshot_id = AnalysisId::new(identity.id.clone());
        let path = self.path_for(&snapshot_id)?;
        if path.exists() {
            let existing = read_snapshot(&path)?;
            if existing.identity().revision != identity.revision {
                return Err(EngineError::with_code(
                    ErrorKind::Snapshot,
                    framelean_core::EngineErrorCode::AnalysisRevisionConflict,
                    "analysis snapshot id already stores a different revision",
                ));
            }
            return Err(EngineError::new(
                ErrorKind::Snapshot,
                "analysis snapshot id is already stored",
            ));
        }
        if self.snapshot_count >= self.limits.max_entries {
            return Err(EngineError::new(
                ErrorKind::Snapshot,
                "analysis snapshot store capacity is full",
            ));
        }

        let sequence = TEMP_FILE_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let temporary = self.root.join(format!(
            ".{}.tmp-{}-{sequence}",
            identity.id,
            std::process::id()
        ));
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temporary)
            .map_err(|error| {
                EngineError::with_source(
                    ErrorKind::Snapshot,
                    "cannot create temporary analysis snapshot",
                    error,
                )
            })?;
        let (write_result, exceeded, written) = {
            let mut bounded = BoundedFileWriter {
                file: &mut file,
                written: 0,
                maximum_bytes: self.limits.max_record_bytes,
                exceeded: false,
            };
            let write_result = (|| -> std::io::Result<()> {
                serde_json::to_writer_pretty(&mut bounded, snapshot)
                    .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidData, error))?;
                bounded.write_all(b"\n")?;
                bounded.file.sync_all()
            })();
            (write_result, bounded.exceeded, bounded.written)
        };
        drop(file);
        if let Err(error) = write_result {
            let _ = fs::remove_file(&temporary);
            let message = if exceeded {
                "analysis snapshot exceeds its record size limit"
            } else {
                "cannot write analysis snapshot"
            };
            return Err(EngineError::with_source(
                ErrorKind::Snapshot,
                message,
                error,
            ));
        }
        if self
            .snapshot_bytes
            .checked_add(written)
            .is_none_or(|value| value > self.limits.max_total_bytes)
        {
            let _ = fs::remove_file(&temporary);
            return Err(EngineError::new(
                ErrorKind::Snapshot,
                "analysis snapshot store capacity is full",
            ));
        }
        if let Err(error) = fs::rename(&temporary, &path) {
            let _ = fs::remove_file(&temporary);
            return Err(EngineError::with_source(
                ErrorKind::Snapshot,
                "cannot publish analysis snapshot",
                error,
            ));
        }
        sync_directory(&self.root).map_err(|error| {
            EngineError::with_source(
                ErrorKind::Snapshot,
                "cannot synchronize analysis snapshot directory",
                error,
            )
        })?;
        self.snapshot_count = self.snapshot_count.saturating_add(1);
        self.snapshot_bytes = self.snapshot_bytes.saturating_add(written);
        Ok(())
    }

    fn load(&self, analysis_id: &AnalysisId) -> Result<Option<AnalysisSnapshotRecordDocument>> {
        let path = self.path_for(analysis_id)?;
        if !path.exists() {
            return Ok(None);
        }
        read_snapshot(&path).map(Some)
    }

    fn load_all(&self) -> Result<Vec<AnalysisSnapshotRecordDocument>> {
        let mut paths = Vec::new();
        for entry in fs::read_dir(&self.root).map_err(|error| {
            EngineError::with_source(
                ErrorKind::Snapshot,
                "cannot list analysis snapshot directory",
                error,
            )
        })? {
            let path = entry
                .map_err(|error| {
                    EngineError::with_source(
                        ErrorKind::Snapshot,
                        "cannot inspect analysis snapshot entry",
                        error,
                    )
                })?
                .path();
            if path.extension().and_then(|value| value.to_str()) == Some("json") {
                paths.push(path);
            }
        }
        paths.sort();
        paths.iter().map(|path| read_snapshot(path)).collect()
    }
}

fn read_snapshot(path: &Path) -> Result<AnalysisSnapshotRecordDocument> {
    let bytes = fs::read(path).map_err(|error| {
        EngineError::with_source(ErrorKind::Snapshot, "cannot read analysis snapshot", error)
    })?;
    let snapshot: AnalysisSnapshotRecordDocument =
        serde_json::from_slice(&bytes).map_err(|error| {
            EngineError::with_source(
                ErrorKind::Snapshot,
                "cannot deserialize analysis snapshot",
                error,
            )
        })?;
    validate_snapshot_file_identity(path, &snapshot)?;
    Ok(snapshot)
}

fn snapshot_directory_usage(root: &Path) -> Result<(usize, usize)> {
    let mut count: usize = 0;
    let mut bytes: usize = 0;
    for entry in fs::read_dir(root).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Snapshot,
            "cannot inspect analysis snapshot directory usage",
            error,
        )
    })? {
        let path = entry
            .map_err(|error| {
                EngineError::with_source(
                    ErrorKind::Snapshot,
                    "cannot inspect analysis snapshot entry metadata",
                    error,
                )
            })?
            .path();
        if path.extension().and_then(|value| value.to_str()) == Some("json") {
            count = count.saturating_add(1);
            let length = fs::metadata(&path)
                .map_err(|error| {
                    EngineError::with_source(
                        ErrorKind::Snapshot,
                        "cannot inspect analysis snapshot size",
                        error,
                    )
                })?
                .len();
            bytes = bytes.saturating_add(usize::try_from(length).unwrap_or(usize::MAX));
        }
    }
    Ok((count, bytes))
}

struct BoundedFileWriter<'a> {
    file: &'a mut File,
    written: usize,
    maximum_bytes: usize,
    exceeded: bool,
}

impl std::io::Write for BoundedFileWriter<'_> {
    fn write(&mut self, buffer: &[u8]) -> std::io::Result<usize> {
        let next = self.written.checked_add(buffer.len()).ok_or_else(|| {
            std::io::Error::new(std::io::ErrorKind::InvalidData, "snapshot size overflow")
        })?;
        if next > self.maximum_bytes {
            self.exceeded = true;
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                "analysis snapshot exceeds its record size limit",
            ));
        }
        self.file.write_all(buffer)?;
        self.written = next;
        Ok(buffer.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        self.file.flush()
    }
}

fn validate_snapshot_file_identity(
    path: &Path,
    snapshot: &AnalysisSnapshotRecordDocument,
) -> Result<()> {
    let file_stem = path
        .file_stem()
        .and_then(|value| value.to_str())
        .ok_or_else(|| {
            EngineError::new(
                ErrorKind::Snapshot,
                "analysis snapshot file name is not valid UTF-8",
            )
        })?;
    validate_file_stem(file_stem)?;
    if file_stem != snapshot.identity().id.as_str() {
        return Err(EngineError::new(
            ErrorKind::Snapshot,
            "analysis snapshot file name does not match its analysis id",
        ));
    }
    Ok(())
}

#[cfg(unix)]
fn sync_directory(path: &Path) -> std::io::Result<()> {
    File::open(path)?.sync_all()
}

#[cfg(not(unix))]
fn sync_directory(_path: &Path) -> std::io::Result<()> {
    Ok(())
}

fn validate_file_stem(value: &str) -> Result<()> {
    if value.is_empty()
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
    {
        return Err(EngineError::new(
            ErrorKind::Snapshot,
            "analysis id cannot be used as a snapshot file name",
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::*;

    fn temporary_directory(label: &str) -> PathBuf {
        let suffix = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("framelean-{label}-{}-{suffix}", std::process::id()))
    }

    fn snapshot_record_with_id_and_revision(
        id: &str,
        revision: u64,
        future: serde_json::Value,
    ) -> AnalysisSnapshotRecordDocument {
        AnalysisSnapshotRecordDocument::from_value(serde_json::json!({
            "id": id,
            "revision": revision,
            "future": future,
        }))
        .unwrap()
    }

    fn snapshot_record() -> AnalysisSnapshotRecordDocument {
        snapshot_record_with_id_and_revision("analysis-1", 1, serde_json::json!({"opaque": true}))
    }

    #[test]
    fn snapshot_file_names_reject_path_syntax() {
        assert!(validate_file_stem("analysis-1").is_ok());
        assert!(validate_file_stem("../analysis-1").is_err());
        assert!(validate_file_stem("folder/analysis-1").is_err());
    }

    #[test]
    fn snapshot_directory_allows_only_one_active_store() {
        let root = temporary_directory("snapshot-store-lock");
        let first = DirectorySnapshotStore::new(&root).unwrap();

        let second = DirectorySnapshotStore::new(&root);

        assert!(second.is_err());
        drop(first);
        assert!(DirectorySnapshotStore::new(&root).is_ok());
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn directory_store_rejects_a_snapshot_file_whose_name_does_not_match_its_id() {
        let root = temporary_directory("snapshot-store-file-id");
        let store = DirectorySnapshotStore::new(&root).unwrap();
        let record = snapshot_record();
        let alias = AnalysisId::new("analysis-alias");
        fs::write(
            root.join("analysis-alias.json"),
            serde_json::to_vec_pretty(&record).unwrap(),
        )
        .unwrap();

        let error = store.load(&alias).unwrap_err();

        assert_eq!(error.kind(), ErrorKind::Snapshot);
        assert!(error.message().contains("file name"));
        drop(store);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn directory_store_rejects_a_duplicate_analysis_id_without_overwriting() {
        let root = temporary_directory("snapshot-store-duplicate");
        let mut store = DirectorySnapshotStore::new(&root).unwrap();
        let record = snapshot_record();
        store.save(&record).unwrap();
        let analysis_id = AnalysisId::new(record.identity().id.clone());
        let saved = fs::read(store.path_for(&analysis_id).unwrap()).unwrap();

        let error = store.save(&record).unwrap_err();

        assert_eq!(error.kind(), ErrorKind::Snapshot);
        assert!(error.message().contains("already"));
        assert_eq!(
            fs::read(store.path_for(&analysis_id).unwrap()).unwrap(),
            saved
        );
        drop(store);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn directory_store_rejects_a_conflicting_revision_without_overwriting() {
        let root = temporary_directory("snapshot-store-revision");
        let mut store = DirectorySnapshotStore::new(&root).unwrap();
        let record = snapshot_record();
        store.save(&record).unwrap();
        let conflicting = snapshot_record_with_id_and_revision(
            "analysis-1",
            2,
            serde_json::json!({"opaque": true}),
        );

        let error = store.save(&conflicting).unwrap_err();

        assert_eq!(
            error.code(),
            framelean_core::EngineErrorCode::AnalysisRevisionConflict
        );
        assert_eq!(
            store
                .load(&AnalysisId::new("analysis-1"))
                .unwrap()
                .unwrap()
                .identity()
                .revision,
            1
        );
        drop(store);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn directory_store_rejects_new_snapshots_after_its_capacity_is_reached() {
        let root = temporary_directory("snapshot-store-capacity");
        let limits = SnapshotStoreLimits {
            max_entries: 1,
            max_total_bytes: usize::MAX,
            max_record_bytes: usize::MAX,
        };
        let mut store = DirectorySnapshotStore::new_with_limits(&root, limits).unwrap();
        let first = snapshot_record();
        store.save(&first).unwrap();
        let second = snapshot_record_with_id_and_revision(
            "analysis-second",
            1,
            serde_json::json!({"opaque": true}),
        );

        let error = store.save(&second).unwrap_err();

        assert_eq!(error.kind(), ErrorKind::Snapshot);
        assert!(error.message().contains("capacity"));
        assert!(
            store
                .load(&AnalysisId::new("analysis-second"))
                .unwrap()
                .is_none()
        );
        drop(store);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn directory_store_bounds_snapshot_serialization_without_publishing_a_partial_file() {
        let root = temporary_directory("snapshot-store-record-limit");
        let limits = SnapshotStoreLimits {
            max_entries: 1,
            max_total_bytes: usize::MAX,
            max_record_bytes: 64,
        };
        let mut store = DirectorySnapshotStore::new_with_limits(&root, limits).unwrap();
        let record = snapshot_record_with_id_and_revision(
            "analysis-1",
            1,
            serde_json::Value::String("x".repeat(128)),
        );

        let error = store.save(&record).unwrap_err();

        assert_eq!(error.kind(), ErrorKind::Snapshot);
        assert!(error.message().contains("size limit"));
        assert!(
            store
                .load(&AnalysisId::new("analysis-1"))
                .unwrap()
                .is_none()
        );
        assert!(
            fs::read_dir(&root)
                .unwrap()
                .filter_map(std::result::Result::ok)
                .all(
                    |entry| entry.path().extension().and_then(|value| value.to_str())
                        != Some("json")
                )
        );
        drop(store);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn directory_store_preserves_structurally_valid_opaque_snapshot_documents() {
        let root = temporary_directory("snapshot-store-opaque");
        let mut store = DirectorySnapshotStore::new(&root).unwrap();
        let expected = serde_json::json!({
            "id": "analysis-opaque",
            "revision": 7,
            "future": {
                "opaque": true,
                "nested": ["kept", 3]
            }
        });
        let record = AnalysisSnapshotRecordDocument::from_value(expected.clone()).unwrap();

        store.save(&record).unwrap();
        let loaded = store
            .load(&AnalysisId::new("analysis-opaque"))
            .unwrap()
            .unwrap();

        assert_eq!(serde_json::to_value(loaded).unwrap(), expected);
        drop(store);
        fs::remove_dir_all(root).unwrap();
    }
}
