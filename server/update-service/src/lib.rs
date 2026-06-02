use std::{
    collections::HashMap,
    env,
    path::{Component, Path as FsPath, PathBuf},
    sync::{Arc, Mutex},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header, HeaderMap, StatusCode, Uri},
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};
use hmac::{Hmac, Mac};
use semver::Version;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tokio_util::io::ReaderStream;

type HmacSha256 = Hmac<Sha256>;

const CLIENT_ID_HEADER: &str = "X-FrameLean-Client-Id";
const TIMESTAMP_HEADER: &str = "X-FrameLean-Timestamp";
const NONCE_HEADER: &str = "X-FrameLean-Nonce";
const SIGNATURE_HEADER: &str = "X-FrameLean-Signature";

#[derive(Clone)]
pub struct ServerConfig {
    pub storage_dir: PathBuf,
    pub public_base_url: String,
    pub hmac_secret: String,
    pub download_secret: String,
    pub auth_window: Duration,
    pub download_token_ttl: Duration,
}

impl ServerConfig {
    pub fn from_env() -> Result<Self, ConfigError> {
        let hmac_secret = env::var("FRAMELEAN_UPDATE_HMAC_SECRET")
            .map_err(|_| ConfigError::Missing("FRAMELEAN_UPDATE_HMAC_SECRET"))?;
        let download_secret =
            env::var("FRAMELEAN_UPDATE_DOWNLOAD_SECRET").unwrap_or_else(|_| hmac_secret.clone());
        let storage_dir = env::var("FRAMELEAN_UPDATE_STORAGE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("storage"));
        let public_base_url = env::var("FRAMELEAN_UPDATE_PUBLIC_BASE_URL")
            .unwrap_or_else(|_| "http://127.0.0.1:8080".to_string());

        Ok(Self {
            storage_dir,
            public_base_url,
            hmac_secret,
            download_secret,
            auth_window: Duration::from_secs(300),
            download_token_ttl: Duration::from_secs(1800),
        })
    }
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("missing required environment variable: {0}")]
    Missing(&'static str),
}

#[derive(Clone)]
pub struct AppState {
    store: ReleaseStore,
    auth: AuthConfig,
    public_base_url: String,
    download_token_ttl: Duration,
}

pub fn app(config: ServerConfig) -> Router {
    let state = AppState {
        store: ReleaseStore {
            storage_dir: config.storage_dir,
        },
        auth: AuthConfig {
            update_secret: config.hmac_secret.into_bytes(),
            download_secret: config.download_secret.into_bytes(),
            auth_window: config.auth_window,
            nonce_cache: Arc::new(Mutex::new(NonceCache::default())),
        },
        public_base_url: config.public_base_url.trim_end_matches('/').to_string(),
        download_token_ttl: config.download_token_ttl,
    };

    Router::new()
        .route("/health", get(health))
        .route("/api/v1/updates/check", get(check_update))
        .route("/api/v1/releases/{version}/notes", get(release_notes))
        .route("/api/v1/releases/{version}/packages", get(release_packages))
        .route(
            "/api/v1/releases/{version}/packages/{platform}",
            get(release_package),
        )
        .route(
            "/api/v1/releases/{version}/packages/{platform}/download",
            get(download_package),
        )
        .with_state(state)
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        ok: true,
        service: "framelean-updates",
    })
}

async fn check_update(
    State(state): State<AppState>,
    headers: HeaderMap,
    uri: Uri,
    Query(query): Query<CheckUpdateQuery>,
) -> Result<Json<CheckUpdateResponse>, ApiError> {
    require_update_auth(&state, &headers, "GET", &uri, &[])?;

    let index = state.store.load_index().await?;
    let latest = index.latest_release()?;
    let latest_version = parse_version(&latest.version)?;
    let current_version = parse_version(&query.current_version)?;

    if !latest.packages.contains_key(&query.platform) {
        return Err(ApiError::not_found(
            "platform_not_found",
            "No update package is available for this platform.",
        ));
    }

    let latest_release = if latest_version > current_version {
        Some(CheckReleaseSummary {
            version: latest.version.clone(),
            title: latest.title.clone(),
            notes_url: state.release_notes_url(&latest.version),
            package_url: state.release_package_url(&latest.version, &query.platform),
            release_page_url: latest
                .release_page_url
                .clone()
                .unwrap_or_else(|| state.release_notes_url(&latest.version)),
        })
    } else {
        None
    };

    Ok(Json(CheckUpdateResponse {
        schema_version: index.schema_version.unwrap_or(1),
        update_available: latest_release.is_some(),
        current_version: query.current_version,
        latest_version: latest.version.clone(),
        latest_release,
    }))
}

async fn release_notes(
    State(state): State<AppState>,
    headers: HeaderMap,
    uri: Uri,
    Path(version): Path<String>,
) -> Result<Response, ApiError> {
    require_update_auth(&state, &headers, "GET", &uri, &[])?;

    let index = state.store.load_index().await?;
    let release = index.release(&version)?;
    let notes_path = state.store.safe_path(&release.notes_path)?;
    let notes = tokio::fs::read_to_string(notes_path).await?;

    Ok((
        StatusCode::OK,
        [(header::CONTENT_TYPE, "text/markdown; charset=utf-8")],
        notes,
    )
        .into_response())
}

async fn release_packages(
    State(state): State<AppState>,
    headers: HeaderMap,
    uri: Uri,
    Path(version): Path<String>,
) -> Result<Json<PackagesResponse>, ApiError> {
    require_update_auth(&state, &headers, "GET", &uri, &[])?;

    let index = state.store.load_index().await?;
    let release = index.release(&version)?;
    let packages = release
        .packages
        .iter()
        .map(|(platform, package)| PlatformPackageSummary {
            platform: platform.clone(),
            name: package.name.clone(),
            package_url: state.release_package_url(&release.version, platform),
            size_bytes: package.size_bytes,
            sha256: package.sha256.clone(),
        })
        .collect();

    Ok(Json(PackagesResponse {
        schema_version: index.schema_version.unwrap_or(1),
        version: release.version.clone(),
        packages,
    }))
}

async fn release_package(
    State(state): State<AppState>,
    headers: HeaderMap,
    uri: Uri,
    Path((version, platform)): Path<(String, String)>,
) -> Result<Json<PackageResponse>, ApiError> {
    require_update_auth(&state, &headers, "GET", &uri, &[])?;
    package_response(state, version, platform).await.map(Json)
}

async fn download_package(
    State(state): State<AppState>,
    Query(query): Query<DownloadQuery>,
    Path((version, platform)): Path<(String, String)>,
) -> Result<Response, ApiError> {
    verify_download_token(&state, &version, &platform, &query.token)?;

    let index = state.store.load_index().await?;
    let release = index.release(&version)?;
    let package = release.package(&platform)?;
    let package_path = state.store.safe_path(&package.path)?;
    let file = tokio::fs::File::open(package_path).await?;
    let stream = ReaderStream::new(file);
    let body = Body::from_stream(stream);

    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "application/octet-stream".to_string()),
            (
                header::CONTENT_DISPOSITION,
                format!("attachment; filename=\"{}\"", package.name),
            ),
        ],
        body,
    )
        .into_response())
}

async fn package_response(
    state: AppState,
    version: String,
    platform: String,
) -> Result<PackageResponse, ApiError> {
    let index = state.store.load_index().await?;
    let release = index.release(&version)?;
    let package = release.package(&platform)?;
    let expires_at = current_unix_seconds() + state.download_token_ttl.as_secs();
    let token = sign_download_token(
        &state.auth.download_secret,
        &release.version,
        &platform,
        expires_at,
    );

    Ok(PackageResponse {
        schema_version: index.schema_version.unwrap_or(1),
        platform: platform.clone(),
        version: release.version.clone(),
        package: PackageAssetResponse {
            name: package.name.clone(),
            download_url: state.release_download_url(&release.version, &platform, &token),
            size_bytes: package.size_bytes,
            sha256: package.sha256.clone(),
        },
    })
}

#[derive(Clone)]
struct ReleaseStore {
    storage_dir: PathBuf,
}

impl ReleaseStore {
    async fn load_index(&self) -> Result<ReleaseIndex, ApiError> {
        let index_path = self.safe_path("releases.json")?;
        let text = tokio::fs::read_to_string(index_path).await?;
        serde_json::from_str(&text)
            .map_err(|error| ApiError::internal(format!("Release index JSON is invalid: {error}")))
    }

    fn safe_path(&self, relative_path: &str) -> Result<PathBuf, ApiError> {
        safe_storage_path(&self.storage_dir, relative_path)
    }
}

fn safe_storage_path(storage_dir: &FsPath, relative_path: &str) -> Result<PathBuf, ApiError> {
    let relative = FsPath::new(relative_path);
    if relative.is_absolute() {
        return Err(ApiError::bad_request(
            "invalid_storage_path",
            "Storage path must be relative.",
        ));
    }

    let mut clean = PathBuf::new();
    for component in relative.components() {
        match component {
            Component::Normal(value) => clean.push(value),
            Component::CurDir => {}
            _ => {
                return Err(ApiError::bad_request(
                    "invalid_storage_path",
                    "Storage path contains unsupported components.",
                ));
            }
        }
    }

    Ok(storage_dir.join(clean))
}

#[derive(Clone)]
struct AuthConfig {
    update_secret: Vec<u8>,
    download_secret: Vec<u8>,
    auth_window: Duration,
    nonce_cache: Arc<Mutex<NonceCache>>,
}

#[derive(Default)]
struct NonceCache {
    seen: HashMap<String, u64>,
}

impl NonceCache {
    fn insert_once(&mut self, key: String, now: u64, window: Duration) -> bool {
        let window_secs = window.as_secs();
        self.seen
            .retain(|_, timestamp| now.saturating_sub(*timestamp) <= window_secs);
        if self.seen.contains_key(&key) {
            return false;
        }

        self.seen.insert(key, now);
        true
    }
}

fn require_update_auth(
    state: &AppState,
    headers: &HeaderMap,
    method: &str,
    uri: &Uri,
    body: &[u8],
) -> Result<(), ApiError> {
    let client_id = required_header(headers, CLIENT_ID_HEADER)?;
    let timestamp = required_header(headers, TIMESTAMP_HEADER)?;
    let nonce = required_header(headers, NONCE_HEADER)?;
    let signature = required_header(headers, SIGNATURE_HEADER)?;
    let request_timestamp = timestamp
        .parse::<u64>()
        .map_err(|_| ApiError::unauthorized())?;
    let now = current_unix_seconds();

    if request_timestamp > now + state.auth.auth_window.as_secs()
        || now.saturating_sub(request_timestamp) > state.auth.auth_window.as_secs()
    {
        return Err(ApiError::unauthorized());
    }

    let nonce_key = format!("{client_id}:{nonce}");
    let mut nonce_cache = state
        .auth
        .nonce_cache
        .lock()
        .map_err(|_| ApiError::internal("Nonce cache lock failed."))?;
    if !nonce_cache.insert_once(nonce_key, now, state.auth.auth_window) {
        return Err(ApiError::unauthorized());
    }

    let path_with_query = uri
        .path_and_query()
        .map(|value| value.as_str())
        .unwrap_or(uri.path());
    verify_hmac_signature(
        &state.auth.update_secret,
        method,
        path_with_query,
        timestamp,
        nonce,
        body,
        signature,
    )
}

fn required_header<'a>(headers: &'a HeaderMap, name: &str) -> Result<&'a str, ApiError> {
    headers
        .get(name)
        .and_then(|value| value.to_str().ok())
        .filter(|value| !value.trim().is_empty())
        .map(str::trim)
        .ok_or_else(ApiError::unauthorized)
}

fn verify_hmac_signature(
    secret: &[u8],
    method: &str,
    path_with_query: &str,
    timestamp: &str,
    nonce: &str,
    body: &[u8],
    signature: &str,
) -> Result<(), ApiError> {
    let provided = decode_hex(signature)?;
    let mut mac = HmacSha256::new_from_slice(secret).map_err(|_| ApiError::unauthorized())?;
    mac.update(signed_update_payload(method, path_with_query, timestamp, nonce, body).as_bytes());
    mac.verify_slice(&provided)
        .map_err(|_| ApiError::unauthorized())
}

fn signed_update_payload(
    method: &str,
    path_with_query: &str,
    timestamp: &str,
    nonce: &str,
    body: &[u8],
) -> String {
    let body_hash = Sha256::digest(body);
    format!(
        "{}\n{}\n{}\n{}\n{}",
        method.to_uppercase(),
        path_with_query,
        timestamp,
        nonce,
        encode_hex(body_hash)
    )
}

fn sign_download_token(secret: &[u8], version: &str, platform: &str, expires_at: u64) -> String {
    let payload = download_token_payload(version, platform, expires_at);
    let mut mac = HmacSha256::new_from_slice(secret).expect("HMAC accepts any key length");
    mac.update(payload.as_bytes());
    let signature = encode_hex(mac.finalize().into_bytes());
    format!("{expires_at}.{signature}")
}

fn verify_download_token(
    state: &AppState,
    version: &str,
    platform: &str,
    token: &str,
) -> Result<(), ApiError> {
    let (expires_at, signature) = token.split_once('.').ok_or_else(ApiError::unauthorized)?;
    let expires_at = expires_at
        .parse::<u64>()
        .map_err(|_| ApiError::unauthorized())?;
    if expires_at < current_unix_seconds() {
        return Err(ApiError::unauthorized());
    }

    let provided = decode_hex(signature)?;
    let mut mac = HmacSha256::new_from_slice(&state.auth.download_secret)
        .map_err(|_| ApiError::unauthorized())?;
    mac.update(download_token_payload(version, platform, expires_at).as_bytes());
    mac.verify_slice(&provided)
        .map_err(|_| ApiError::unauthorized())
}

fn download_token_payload(version: &str, platform: &str, expires_at: u64) -> String {
    format!("{version}\n{platform}\n{expires_at}")
}

fn encode_hex(bytes: impl AsRef<[u8]>) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let bytes = bytes.as_ref();
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        output.push(HEX[(byte >> 4) as usize] as char);
        output.push(HEX[(byte & 0x0f) as usize] as char);
    }
    output
}

fn decode_hex(input: &str) -> Result<Vec<u8>, ApiError> {
    let bytes = input.as_bytes();
    if bytes.len() % 2 != 0 {
        return Err(ApiError::unauthorized());
    }

    let mut output = Vec::with_capacity(bytes.len() / 2);
    for pair in bytes.chunks_exact(2) {
        let high = hex_value(pair[0]).ok_or_else(ApiError::unauthorized)?;
        let low = hex_value(pair[1]).ok_or_else(ApiError::unauthorized)?;
        output.push((high << 4) | low);
    }

    Ok(output)
}

fn hex_value(value: u8) -> Option<u8> {
    match value {
        b'0'..=b'9' => Some(value - b'0'),
        b'a'..=b'f' => Some(value - b'a' + 10),
        b'A'..=b'F' => Some(value - b'A' + 10),
        _ => None,
    }
}

fn current_unix_seconds() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn parse_version(input: &str) -> Result<Version, ApiError> {
    let normalized = input
        .trim()
        .trim_start_matches(|value| value == 'v' || value == 'V');
    Version::parse(normalized)
        .map_err(|_| ApiError::bad_request("invalid_version", "Version must be semantic."))
}

impl AppState {
    fn release_notes_url(&self, version: &str) -> String {
        format!("{}/api/v1/releases/{version}/notes", self.public_base_url)
    }

    fn release_package_url(&self, version: &str, platform: &str) -> String {
        format!(
            "{}/api/v1/releases/{version}/packages/{platform}",
            self.public_base_url
        )
    }

    fn release_download_url(&self, version: &str, platform: &str, token: &str) -> String {
        format!(
            "{}/api/v1/releases/{version}/packages/{platform}/download?token={token}",
            self.public_base_url
        )
    }
}

#[derive(Deserialize)]
struct CheckUpdateQuery {
    platform: String,
    current_version: String,
}

#[derive(Deserialize)]
struct DownloadQuery {
    token: String,
}

#[derive(Serialize)]
struct HealthResponse {
    ok: bool,
    service: &'static str,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CheckUpdateResponse {
    schema_version: u32,
    update_available: bool,
    current_version: String,
    latest_version: String,
    latest_release: Option<CheckReleaseSummary>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CheckReleaseSummary {
    version: String,
    title: String,
    notes_url: String,
    package_url: String,
    release_page_url: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PackagesResponse {
    schema_version: u32,
    version: String,
    packages: Vec<PlatformPackageSummary>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PlatformPackageSummary {
    platform: String,
    name: String,
    package_url: String,
    size_bytes: Option<u64>,
    sha256: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PackageResponse {
    schema_version: u32,
    platform: String,
    version: String,
    package: PackageAssetResponse,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PackageAssetResponse {
    name: String,
    download_url: String,
    size_bytes: Option<u64>,
    sha256: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ReleaseIndex {
    schema_version: Option<u32>,
    latest_version: String,
    releases: Vec<ReleaseRecord>,
}

impl ReleaseIndex {
    fn latest_release(&self) -> Result<&ReleaseRecord, ApiError> {
        self.release(&self.latest_version)
    }

    fn release(&self, version: &str) -> Result<&ReleaseRecord, ApiError> {
        let requested = normalized_version_label(version);
        self.releases
            .iter()
            .find(|release| normalized_version_label(&release.version) == requested)
            .ok_or_else(|| ApiError::not_found("release_not_found", "Release was not found."))
    }
}

fn normalized_version_label(input: &str) -> String {
    input
        .trim()
        .trim_start_matches(|value| value == 'v' || value == 'V')
        .to_string()
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ReleaseRecord {
    version: String,
    title: String,
    release_page_url: Option<String>,
    notes_path: String,
    packages: HashMap<String, PackageRecord>,
}

impl ReleaseRecord {
    fn package(&self, platform: &str) -> Result<&PackageRecord, ApiError> {
        self.packages
            .get(platform)
            .ok_or_else(|| ApiError::not_found("platform_not_found", "Package was not found."))
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PackageRecord {
    name: String,
    path: String,
    size_bytes: Option<u64>,
    sha256: String,
}

#[derive(Debug)]
enum ApiError {
    Unauthorized,
    BadRequest { code: &'static str, message: String },
    NotFound { code: &'static str, message: String },
    Internal(String),
}

impl ApiError {
    fn unauthorized() -> Self {
        Self::Unauthorized
    }

    fn bad_request(code: &'static str, message: impl Into<String>) -> Self {
        Self::BadRequest {
            code,
            message: message.into(),
        }
    }

    fn not_found(code: &'static str, message: impl Into<String>) -> Self {
        Self::NotFound {
            code,
            message: message.into(),
        }
    }

    fn internal(message: impl Into<String>) -> Self {
        Self::Internal(message.into())
    }
}

impl From<std::io::Error> for ApiError {
    fn from(error: std::io::Error) -> Self {
        if error.kind() == std::io::ErrorKind::NotFound {
            return ApiError::not_found("file_not_found", "Requested file was not found.");
        }

        ApiError::internal(format!("I/O error: {error}"))
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, code, message) = match self {
            ApiError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "unauthorized",
                "Unauthorized".to_string(),
            ),
            ApiError::BadRequest { code, message } => (StatusCode::BAD_REQUEST, code, message),
            ApiError::NotFound { code, message } => (StatusCode::NOT_FOUND, code, message),
            ApiError::Internal(message) => {
                (StatusCode::INTERNAL_SERVER_ERROR, "internal_error", message)
            }
        };

        (
            status,
            Json(ErrorResponse {
                error: ErrorBody { code, message },
            }),
        )
            .into_response()
    }
}

#[derive(Serialize)]
struct ErrorResponse {
    error: ErrorBody,
}

#[derive(Serialize)]
struct ErrorBody {
    code: &'static str,
    message: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{body::to_bytes, http::Request};
    use serde_json::Value;
    use tempfile::TempDir;
    use tower::ServiceExt;

    #[tokio::test]
    async fn check_update_requires_hmac_headers() {
        let (_storage, app) = test_app();
        let response = app
            .oneshot(
                Request::builder()
                    .uri("/api/v1/updates/check?platform=macos-arm64&current_version=1.1.5")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn check_update_returns_latest_release_summary() {
        let (_storage, app) = test_app();
        let uri = "/api/v1/updates/check?platform=macos-arm64&current_version=1.1.5";
        let response = app.oneshot(signed_get(uri, "nonce-1")).await.unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        let json = response_json(response).await;
        assert_eq!(json["updateAvailable"], true);
        assert_eq!(json["latestVersion"], "1.1.6");
        assert_eq!(
            json["latestRelease"]["packageUrl"],
            "https://updates.example.com/api/v1/releases/1.1.6/packages/macos-arm64"
        );
    }

    #[tokio::test]
    async fn notes_endpoint_returns_markdown() {
        let (_storage, app) = test_app();
        let uri = "/api/v1/releases/1.1.6/notes";
        let response = app.oneshot(signed_get(uri, "nonce-2")).await.unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        let body = response_text(response).await;
        assert!(body.contains("新增自托管更新服务"));
    }

    #[tokio::test]
    async fn package_endpoint_returns_short_lived_download_url() {
        let (_storage, app) = test_app();
        let uri = "/api/v1/releases/1.1.6/packages/windows-x64";
        let response = app.oneshot(signed_get(uri, "nonce-3")).await.unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        let json = response_json(response).await;
        let download_url = json["package"]["downloadUrl"].as_str().unwrap();
        assert!(download_url.starts_with(
            "https://updates.example.com/api/v1/releases/1.1.6/packages/windows-x64/download?token="
        ));
    }

    #[tokio::test]
    async fn download_endpoint_accepts_valid_download_token() {
        let storage = test_storage();
        let config = test_config(storage.path().to_path_buf());
        let token = sign_download_token(
            config.download_secret.as_bytes(),
            "1.1.6",
            "macos-arm64",
            current_unix_seconds() + 60,
        );
        let app = app(config);
        let uri = format!("/api/v1/releases/1.1.6/packages/macos-arm64/download?token={token}");
        let response = app
            .oneshot(Request::builder().uri(uri).body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        let body = response_text(response).await;
        assert_eq!(body, "macos dmg placeholder");
    }

    fn test_app() -> (TempDir, Router) {
        let storage = test_storage();
        let app = app(test_config(storage.path().to_path_buf()));
        (storage, app)
    }

    fn test_config(storage_dir: PathBuf) -> ServerConfig {
        ServerConfig {
            storage_dir,
            public_base_url: "https://updates.example.com".to_string(),
            hmac_secret: "test-update-secret".to_string(),
            download_secret: "test-download-secret".to_string(),
            auth_window: Duration::from_secs(300),
            download_token_ttl: Duration::from_secs(1800),
        }
    }

    fn test_storage() -> TempDir {
        let dir = TempDir::new().unwrap();
        let release_dir = dir.path().join("releases/v1.1.6");
        std::fs::create_dir_all(&release_dir).unwrap();
        std::fs::write(
            release_dir.join("notes.md"),
            "## 更新内容\n- 新增自托管更新服务",
        )
        .unwrap();
        std::fs::write(
            release_dir.join("FrameLean-v1.1.6-macos-arm64.dmg"),
            "macos dmg placeholder",
        )
        .unwrap();
        std::fs::write(
            release_dir.join("FrameLean-v1.1.6-windows-x64-Setup.exe"),
            "windows installer placeholder",
        )
        .unwrap();
        std::fs::write(dir.path().join("releases.json"), test_release_index()).unwrap();
        dir
    }

    fn test_release_index() -> String {
        serde_json::json!({
            "schemaVersion": 1,
            "latestVersion": "1.1.6",
            "releases": [
                {
                    "version": "1.1.6",
                    "title": "FrameLean v1.1.6",
                    "releasePageUrl": "https://framelean.example.com/releases/1.1.6",
                    "notesPath": "releases/v1.1.6/notes.md",
                    "packages": {
                        "macos-arm64": {
                            "name": "FrameLean-v1.1.6-macos-arm64.dmg",
                            "path": "releases/v1.1.6/FrameLean-v1.1.6-macos-arm64.dmg",
                            "sizeBytes": 20,
                            "sha256": "macos-sha256"
                        },
                        "windows-x64": {
                            "name": "FrameLean-v1.1.6-windows-x64-Setup.exe",
                            "path": "releases/v1.1.6/FrameLean-v1.1.6-windows-x64-Setup.exe",
                            "sizeBytes": 29,
                            "sha256": "windows-sha256"
                        }
                    }
                }
            ]
        })
        .to_string()
    }

    fn signed_get(uri: &str, nonce: &str) -> Request<Body> {
        let timestamp = current_unix_seconds().to_string();
        let payload = signed_update_payload("GET", uri, &timestamp, nonce, &[]);
        let mut mac = HmacSha256::new_from_slice(b"test-update-secret").unwrap();
        mac.update(payload.as_bytes());
        let signature = encode_hex(mac.finalize().into_bytes());

        Request::builder()
            .method("GET")
            .uri(uri)
            .header(CLIENT_ID_HEADER, "test-client")
            .header(TIMESTAMP_HEADER, timestamp)
            .header(NONCE_HEADER, nonce)
            .header(SIGNATURE_HEADER, signature)
            .body(Body::empty())
            .unwrap()
    }

    async fn response_json(response: Response) -> Value {
        let bytes = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        serde_json::from_slice(&bytes).unwrap()
    }

    async fn response_text(response: Response) -> String {
        let bytes = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        String::from_utf8(bytes.to_vec()).unwrap()
    }
}
