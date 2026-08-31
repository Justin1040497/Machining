use std::fmt;

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelError {
    message: String,
}

impl ModelError {
    pub(crate) fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl fmt::Display for ModelError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.message)
    }
}

impl std::error::Error for ModelError {}

pub type ModelResult<T> = std::result::Result<T, ModelError>;

#[derive(Debug, Clone, PartialEq)]
pub struct OpaqueJsonDocument {
    raw: Value,
}

impl OpaqueJsonDocument {
    pub fn from_value(raw: Value) -> ModelResult<Self> {
        if !raw.is_object() {
            return Err(ModelError::new("runtime document must be a JSON object"));
        }
        Ok(Self { raw })
    }

    pub fn as_value(&self) -> &Value {
        &self.raw
    }

    pub fn into_value(self) -> Value {
        self.raw
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AnalysisId(String);

impl AnalysisId {
    #[allow(dead_code)]
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    #[allow(dead_code)]
    pub fn as_str(&self) -> &str {
        &self.0
    }

    #[allow(dead_code)]
    pub fn into_string(self) -> String {
        self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ExecutionId(String);

impl ExecutionId {
    #[allow(dead_code)]
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    #[allow(dead_code)]
    pub fn as_str(&self) -> &str {
        &self.0
    }

    pub fn into_string(self) -> String {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AnalysisRevision(u64);

impl AnalysisRevision {
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    #[allow(dead_code)]
    pub const fn value(self) -> u64 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskMode {
    VideoCompress,
    VideoConvert,
    AudioCompress,
    AudioConvert,
    ImageCompress,
    ImageConvert,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimeRequestContext {
    pub request_id: Option<String>,
    pub client_file_id: Option<String>,
    pub correlation_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct FllErrorCode(pub String);

pub(crate) fn expect_object(value: &Value) -> ModelResult<&Map<String, Value>> {
    value
        .as_object()
        .ok_or_else(|| ModelError::new("runtime document must be a JSON object"))
}

pub(crate) fn required_string(object: &Map<String, Value>, field: &str) -> ModelResult<String> {
    object
        .get(field)
        .and_then(Value::as_str)
        .map(str::to_owned)
        .ok_or_else(|| {
            ModelError::new(format!("runtime document field `{field}` must be a string"))
        })
}

pub(crate) fn required_u64(object: &Map<String, Value>, field: &str) -> ModelResult<u64> {
    object.get(field).and_then(Value::as_u64).ok_or_else(|| {
        ModelError::new(format!(
            "runtime document field `{field}` must be an unsigned integer"
        ))
    })
}

pub(crate) fn optional_string(
    object: &Map<String, Value>,
    field: &str,
) -> ModelResult<Option<String>> {
    match object.get(field) {
        None | Some(Value::Null) => Ok(None),
        Some(value) => value
            .as_str()
            .map(|value| Some(value.to_owned()))
            .ok_or_else(|| {
                ModelError::new(format!(
                    "runtime document field `{field}` must be a string or null"
                ))
            }),
    }
}
