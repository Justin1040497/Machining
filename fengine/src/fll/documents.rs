use framelean_core::{EngineError, EngineErrorCode, ErrorKind, Result};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::abi::DOCUMENT_VERSION;
pub(crate) use crate::runtime_api::ExecutionEvent as ExecutionEventDocument;

#[derive(Debug, Serialize)]
pub(crate) struct RequestDocument<'a, T> {
    pub document_version: u16,
    pub operation: &'a str,
    pub payload: T,
}

impl<'a, T> RequestDocument<'a, T> {
    pub(crate) fn new(operation: &'a str, payload: T) -> Self {
        Self {
            document_version: DOCUMENT_VERSION,
            operation,
            payload,
        }
    }
}

#[derive(Debug, Deserialize)]
struct ResponseDocument {
    document_version: u16,
    ok: bool,
    error: Option<RemoteError>,
}

#[derive(Debug, Deserialize)]
struct RemoteError {
    kind: ErrorKind,
    code: EngineErrorCode,
    message: String,
    #[allow(dead_code)]
    retryable: bool,
}

pub(crate) fn decode_response_value(bytes: &[u8]) -> Result<Value> {
    let raw: serde_json::Value = serde_json::from_slice(bytes).map_err(|error| {
        EngineError::with_source_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::InternalNativeLibraryError,
            "FLL returned an invalid response document",
            error,
        )
    })?;
    let response: ResponseDocument = serde_json::from_value(raw.clone()).map_err(|error| {
        EngineError::with_source_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::InternalNativeLibraryError,
            "FLL returned an invalid response envelope",
            error,
        )
    })?;
    if response.document_version != DOCUMENT_VERSION {
        return Err(EngineError::with_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::InternalNativeLibraryError,
            format!(
                "unsupported FLL response document version {}; expected {}",
                response.document_version, DOCUMENT_VERSION
            ),
        ));
    }
    if !response.ok {
        let error = response.error.ok_or_else(|| {
            EngineError::with_code(
                ErrorKind::NativeLibrary,
                EngineErrorCode::InternalNativeLibraryError,
                "FLL returned a failed response without a structured error",
            )
        })?;
        return Err(EngineError::with_code(
            error.kind,
            error.code,
            error.message,
        ));
    }
    let result = raw.get("result").cloned().ok_or_else(|| {
        EngineError::with_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::InternalNativeLibraryError,
            "FLL returned a successful response without a result",
        )
    })?;
    Ok(result)
}

pub(crate) fn decode_response<T: DeserializeOwned>(bytes: &[u8]) -> Result<T> {
    let result = decode_response_value(bytes)?;
    serde_json::from_value(result).map_err(|error| {
        EngineError::with_source_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::InternalNativeLibraryError,
            "FLL returned a result with an unexpected shape",
            error,
        )
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn request_document_matches_fll_envelope() {
        let document = RequestDocument::new("ping", json!({"probe": true}));
        let value = serde_json::to_value(document).unwrap();
        assert_eq!(value["document_version"], DOCUMENT_VERSION);
        assert_eq!(value["operation"], "ping");
        assert_eq!(value["payload"]["probe"], true);
    }

    #[test]
    fn structured_failure_maps_to_engine_error() {
        let bytes = serde_json::to_vec(&json!({
            "document_version": DOCUMENT_VERSION,
            "ok": false,
            "error": {
                "kind": "analysis",
                "code": "ANALYSIS_SOURCE_CHANGED",
                "message": "source changed",
                "retryable": true,
            }
        }))
        .unwrap();
        let error = decode_response::<serde_json::Value>(&bytes).unwrap_err();
        assert_eq!(error.kind(), ErrorKind::Analysis);
        assert_eq!(error.code(), EngineErrorCode::AnalysisSourceChanged);
        assert_eq!(error.message(), "source changed");
    }

    #[test]
    fn successful_unit_result_accepts_json_null() {
        let bytes = serde_json::to_vec(&json!({
            "document_version": DOCUMENT_VERSION,
            "ok": true,
            "result": null,
        }))
        .unwrap();
        decode_response::<()>(&bytes).unwrap();
    }
}
