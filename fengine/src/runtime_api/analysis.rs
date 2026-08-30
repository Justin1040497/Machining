use std::path::PathBuf;

use serde::de::Error as _;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::common::{
    AnalysisId, AnalysisRevision, FllErrorCode, ModelError, ModelResult, OpaqueJsonDocument,
    RuntimeRequestContext, TaskMode, expect_object, optional_string, required_string, required_u64,
};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExpectedSourceFacts {
    pub file_size_bytes: u64,
    pub modified_time_unix_nanos: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum LocalMediaSource {
    LocalFile(PathBuf),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalMediaAnalyzeRequest {
    pub source: LocalMediaSource,
    pub request_id: Option<String>,
    #[serde(default)]
    pub expected_source: Option<ExpectedSourceFacts>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnalyzeRequest {
    pub task_mode: TaskMode,
    pub media_request: LocalMediaAnalyzeRequest,
    pub context: RuntimeRequestContext,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecalculateConfigurationRequest {
    pub analysis_id: AnalysisId,
    pub expected_revision: AnalysisRevision,
    pub selection: Value,
    pub context: RuntimeRequestContext,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ErrorSummary {
    pub code: FllErrorCode,
    pub message: String,
    pub retryable: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AnalysisMetadata {
    pub analysis_id: AnalysisId,
    pub analysis_revision: AnalysisRevision,
    pub schema_version: Option<String>,
    pub media_analysis_status: String,
    pub configuration_status: String,
    pub error: Option<ErrorSummary>,
}

impl AnalysisMetadata {
    fn from_object(object: &serde_json::Map<String, Value>) -> ModelResult<Self> {
        let analysis_id = AnalysisId::new(required_string(object, "analysis_id")?);
        let analysis_revision = AnalysisRevision::new(required_u64(object, "analysis_revision")?);
        let schema_version = optional_string(object, "schema_version")?;
        let media_analysis_status = required_string(object, "media_analysis_status")?;
        let configuration_status = required_string(object, "configuration_status")?;
        let error = match object.get("error") {
            None | Some(Value::Null) => None,
            Some(value) => {
                let error_object = expect_object(value)?;
                Some(ErrorSummary {
                    code: FllErrorCode(required_string(error_object, "code")?),
                    message: required_string(error_object, "message")?,
                    retryable: error_object
                        .get("retryable")
                        .and_then(Value::as_bool)
                        .ok_or_else(|| {
                            ModelError::new(
                                "runtime document error field `retryable` must be a boolean",
                            )
                        })?,
                })
            }
        };

        Ok(Self {
            analysis_id,
            analysis_revision,
            schema_version,
            media_analysis_status,
            configuration_status,
            error,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AnalysisDocument {
    raw: OpaqueJsonDocument,
    metadata: AnalysisMetadata,
}

impl AnalysisDocument {
    pub fn from_value(raw: Value) -> ModelResult<Self> {
        let object = expect_object(&raw)?;
        let metadata = AnalysisMetadata::from_object(object)?;
        Ok(Self {
            raw: OpaqueJsonDocument::from_value(raw)?,
            metadata,
        })
    }

    #[allow(dead_code)]
    pub fn metadata(&self) -> &AnalysisMetadata {
        &self.metadata
    }

    pub fn into_value(self) -> Value {
        self.raw.into_value()
    }
}

impl Serialize for AnalysisDocument {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        self.raw.as_value().serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for AnalysisDocument {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        Self::from_value(Value::deserialize(deserializer)?).map_err(D::Error::custom)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DocumentIdentity {
    pub id: String,
    pub revision: u64,
}

impl DocumentIdentity {
    fn from_object(
        object: &serde_json::Map<String, Value>,
        id_field: &str,
        revision_field: &str,
    ) -> ModelResult<Self> {
        Ok(Self {
            id: required_string(object, id_field)?,
            revision: required_u64(object, revision_field)?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AnalysisSnapshotDocument {
    raw: OpaqueJsonDocument,
    identity: DocumentIdentity,
}

impl AnalysisSnapshotDocument {
    pub fn from_value(raw: Value) -> ModelResult<Self> {
        let object = expect_object(&raw)?;
        let identity = DocumentIdentity::from_object(object, "analysis_id", "analysis_revision")?;
        let raw = OpaqueJsonDocument::from_value(raw)?;
        Ok(Self { raw, identity })
    }

    #[allow(dead_code)]
    pub fn identity(&self) -> &DocumentIdentity {
        &self.identity
    }

    pub fn into_value(self) -> Value {
        self.raw.into_value()
    }
}

impl Serialize for AnalysisSnapshotDocument {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        self.raw.as_value().serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for AnalysisSnapshotDocument {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        Self::from_value(Value::deserialize(deserializer)?).map_err(D::Error::custom)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AnalysisSnapshotRecordDocument {
    raw: OpaqueJsonDocument,
    identity: DocumentIdentity,
}

impl AnalysisSnapshotRecordDocument {
    pub fn from_value(raw: Value) -> ModelResult<Self> {
        let object = expect_object(&raw)?;
        let identity = DocumentIdentity::from_object(object, "id", "revision")?;
        let raw = OpaqueJsonDocument::from_value(raw)?;
        Ok(Self { raw, identity })
    }

    #[allow(dead_code)]
    pub fn identity(&self) -> &DocumentIdentity {
        &self.identity
    }

    pub fn into_value(self) -> Value {
        self.raw.into_value()
    }
}

impl Serialize for AnalysisSnapshotRecordDocument {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        self.raw.as_value().serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for AnalysisSnapshotRecordDocument {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        Self::from_value(Value::deserialize(deserializer)?).map_err(D::Error::custom)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct RecalculateConfigurationDocument {
    raw: OpaqueJsonDocument,
}

impl RecalculateConfigurationDocument {
    pub fn from_value(raw: Value) -> ModelResult<Self> {
        Ok(Self {
            raw: OpaqueJsonDocument::from_value(raw)?,
        })
    }

    pub fn into_value(self) -> Value {
        self.raw.into_value()
    }
}

impl Serialize for RecalculateConfigurationDocument {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        self.raw.as_value().serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for RecalculateConfigurationDocument {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        Self::from_value(Value::deserialize(deserializer)?).map_err(D::Error::custom)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn analysis_document_preserves_unknown_nested_fields() {
        let value = json!({
            "schema_version": "1.0",
            "analysis_id": "analysis-1",
            "analysis_revision": 3,
            "media_analysis_status": "complete",
            "configuration_status": "available",
            "future": {"field": [1, 2, 3]},
            "error": null,
        });
        let document = AnalysisDocument::from_value(value.clone()).unwrap();
        assert_eq!(document.metadata().analysis_id.as_str(), "analysis-1");
        assert_eq!(document.metadata().analysis_revision.value(), 3);
        assert_eq!(serde_json::to_value(document).unwrap(), value);
    }

    #[test]
    fn snapshot_record_is_opaque_to_domain_consistency() {
        let value = json!({
            "id": "snapshot-1",
            "revision": 7,
            "media": {"source_id": "different-source"},
            "requirements": {"source_size_bytes": 99},
            "recommendation": {"candidate_id": "missing"},
        });
        let document = AnalysisSnapshotRecordDocument::from_value(value.clone()).unwrap();
        assert_eq!(document.identity().id, "snapshot-1");
        assert_eq!(document.identity().revision, 7);
        assert_eq!(serde_json::to_value(document).unwrap(), value);
    }

    #[test]
    fn ids_are_transparent_strings_at_the_model_boundary() {
        let id: super::AnalysisId = serde_json::from_value(json!("")).unwrap();
        assert_eq!(serde_json::to_value(id).unwrap(), json!(""));

        let document: AnalysisSnapshotDocument = serde_json::from_value(json!({
            "analysis_id": "",
            "analysis_revision": 1,
        }))
        .unwrap();
        assert_eq!(serde_json::to_value(document).unwrap()["analysis_id"], "");
    }
}
