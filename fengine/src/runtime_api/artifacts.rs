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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn preview_transport_matches_ffi_wire_shape() {
        let request_value = json!({
            "input_path": "/tmp/input.mp4",
            "output_directory": "/tmp/frames",
            "timestamps_us": [0, 1_250_000],
            "max_width": 640
        });
        let request: PreviewFramesRequest = serde_json::from_value(request_value.clone()).unwrap();
        assert_eq!(serde_json::to_value(request).unwrap(), request_value);

        let result_value = json!({
            "output_directory": "/tmp/frames",
            "frames": [{
                "index": 1,
                "requested_timestamp_us": 1_250_000,
                "decoded_timestamp_us": 1_249_800,
                "width": 640,
                "height": 360,
                "output_path": "/tmp/frames/frame_1.bmp"
            }]
        });
        let result: PreviewFramesResult = serde_json::from_value(result_value.clone()).unwrap();
        assert_eq!(serde_json::to_value(result).unwrap(), result_value);
    }

    #[test]
    fn thumbnail_transport_matches_ffi_wire_shape() {
        let request_value = json!({
            "input_path": "/tmp/input.mp4",
            "output_path": "/tmp/thumbnail.bmp",
            "duration_us": 2_000_000,
            "max_width": 640
        });
        let request: VideoThumbnailRequest = serde_json::from_value(request_value.clone()).unwrap();
        assert_eq!(serde_json::to_value(request).unwrap(), request_value);

        let result_value = json!({
            "output_path": "/tmp/thumbnail.bmp",
            "requested_timestamp_us": 1_000_000,
            "decoded_timestamp_us": 999_800,
            "width": 640,
            "height": 360
        });
        let result: VideoThumbnailResult = serde_json::from_value(result_value.clone()).unwrap();
        assert_eq!(serde_json::to_value(result).unwrap(), result_value);
    }
}
