use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreviewFramesRequest {
    pub input_path: PathBuf,
    pub output_directory: PathBuf,
    pub timestamps_us: Vec<u64>,
    pub max_width: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreviewFrameArtifact {
    pub index: usize,
    pub requested_timestamp_us: u64,
    pub decoded_timestamp_us: u64,
    pub width: u32,
    pub height: u32,
    pub output_path: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreviewFramesResult {
    pub output_directory: PathBuf,
    pub frames: Vec<PreviewFrameArtifact>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VideoThumbnailRequest {
    pub input_path: PathBuf,
    pub output_path: PathBuf,
    pub duration_us: Option<u64>,
    pub max_width: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VideoThumbnailResult {
    pub output_path: PathBuf,
    pub requested_timestamp_us: u64,
    pub decoded_timestamp_us: u64,
    pub width: u32,
    pub height: u32,
}
