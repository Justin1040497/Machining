use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use framelean_core::{EngineError, EngineErrorCode, ErrorKind, Result};
use framelean_decision::ResolvedConfiguration;
use framelean_ffmpeg::{
    FfmpegAdapter, RemuxControl, RemuxOutcome, TranscodeControl, TranscodeOutcome,
    VideoTranscodeRequest,
};
use framelean_pipeline::MediaPipelinePlan;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExecutionBackendRequest {
    pub source_path: PathBuf,
    pub working_output_path: PathBuf,
    pub pipeline: MediaPipelinePlan,
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

impl ExecutionServices {
    pub fn ffmpeg(adapter: Arc<FfmpegAdapter>) -> Self {
        Self {
            backend: Arc::new(FfmpegExecutionBackend::new(adapter)),
        }
    }
}

pub struct FfmpegExecutionBackend {
    adapter: Arc<FfmpegAdapter>,
    #[cfg(any(test, debug_assertions))]
    progress_delay: Duration,
}

impl FfmpegExecutionBackend {
    pub fn new(adapter: Arc<FfmpegAdapter>) -> Self {
        Self {
            adapter,
            #[cfg(any(test, debug_assertions))]
            progress_delay: progress_delay_from_test_environment(),
        }
    }

    #[cfg(any(test, debug_assertions))]
    #[doc(hidden)]
    pub fn with_progress_delay(adapter: Arc<FfmpegAdapter>, progress_delay: Duration) -> Self {
        Self {
            adapter,
            progress_delay,
        }
    }

    fn on_progress(
        &self,
        observer: &mut dyn ExecutionBackendObserver,
        media_time_us: u64,
        processed_bytes: u64,
    ) -> ExecutionBackendControl {
        #[cfg(any(test, debug_assertions))]
        if !self.progress_delay.is_zero() {
            std::thread::sleep(self.progress_delay);
        }
        observer.on_progress(ExecutionProgress {
            media_time_us,
            processed_bytes,
        })
    }

    fn execute_remux(
        &self,
        request: &ExecutionBackendRequest,
        observer: &mut dyn ExecutionBackendObserver,
    ) -> Result<ExecutionBackendOutcome> {
        let outcome = self.adapter.remux(
            &request.source_path,
            &request.working_output_path,
            |progress| match self.on_progress(
                observer,
                progress.media_time_us,
                progress.processed_bytes,
            ) {
                ExecutionBackendControl::Continue => RemuxControl::Continue,
                ExecutionBackendControl::Cancel => RemuxControl::Cancel,
            },
        )?;
        Ok(match outcome {
            RemuxOutcome::Completed(progress) => {
                ExecutionBackendOutcome::Completed(ExecutionProgress {
                    media_time_us: progress.media_time_us,
                    processed_bytes: progress.processed_bytes,
                })
            }
            RemuxOutcome::Cancelled(progress) => {
                ExecutionBackendOutcome::Cancelled(ExecutionProgress {
                    media_time_us: progress.media_time_us,
                    processed_bytes: progress.processed_bytes,
                })
            }
        })
    }

    fn execute_video_transcode(
        &self,
        request: &ExecutionBackendRequest,
        observer: &mut dyn ExecutionBackendObserver,
    ) -> Result<ExecutionBackendOutcome> {
        let configuration = &request.configuration;
        if configuration.video_decoders.len() != 1
            || !configuration.audio_decoders.is_empty()
            || configuration.audio_encoder_backend.is_some()
        {
            return Err(chain_not_ready(
                "the current native transcode backend supports one video stream without audio",
            ));
        }
        if configuration.processors.iter().any(|processor| {
            processor.backend_id.as_str() != "ffmpeg.processor.swscale.pixel-format-conversion"
                || processor.operation != "pixel_format_conversion"
        }) {
            return Err(chain_not_ready(
                "the selected execution chain contains an unsupported processor",
            ));
        }
        let decoder = &configuration.video_decoders[0];
        let decoder_name = backend_component(&decoder.backend_id, "ffmpeg.decoder.")?;
        let encoder_backend = configuration
            .video_encoder_backend
            .as_ref()
            .ok_or_else(|| chain_not_ready("the video encoder stage is missing"))?;
        let encoder_name = backend_component(encoder_backend, "ffmpeg.encoder.")?;
        let output_pixel_format = configuration
            .output_pixel_format
            .clone()
            .ok_or_else(|| chain_not_ready("the video output pixel format is missing"))?;
        if configuration.container != "mp4"
            || !configuration
                .muxer_backend
                .as_str()
                .starts_with("ffmpeg.muxer.mp4.")
        {
            return Err(chain_not_ready(
                "the current native transcode backend supports the MP4 muxer",
            ));
        }

        let outcome = self.adapter.transcode_video(
            &VideoTranscodeRequest {
                input_path: request.source_path.clone(),
                output_path: request.working_output_path.clone(),
                input_stream_index: decoder.stream_index,
                decoder_name,
                encoder_name,
                output_pixel_format,
                output_profile: configuration.video_profile.clone(),
                target_bitrate_bps: configuration
                    .target_video_bitrate
                    .map(|value| value.value()),
            },
            |progress| match self.on_progress(
                observer,
                progress.media_time_us,
                progress.processed_bytes,
            ) {
                ExecutionBackendControl::Continue => TranscodeControl::Continue,
                ExecutionBackendControl::Cancel => TranscodeControl::Cancel,
            },
        )?;
        Ok(match outcome {
            TranscodeOutcome::Completed(progress) => {
                ExecutionBackendOutcome::Completed(ExecutionProgress {
                    media_time_us: progress.media_time_us,
                    processed_bytes: progress.processed_bytes,
                })
            }
            TranscodeOutcome::Cancelled(progress) => {
                ExecutionBackendOutcome::Cancelled(ExecutionProgress {
                    media_time_us: progress.media_time_us,
                    processed_bytes: progress.processed_bytes,
                })
            }
        })
    }
}

impl ExecutionBackend for FfmpegExecutionBackend {
    fn execute(
        &self,
        request: &ExecutionBackendRequest,
        observer: &mut dyn ExecutionBackendObserver,
    ) -> Result<ExecutionBackendOutcome> {
        if request.pipeline.has_transform_stages() {
            self.execute_video_transcode(request, observer)
        } else {
            self.execute_remux(request, observer)
        }
    }
}

fn backend_component(backend_id: &framelean_core::BackendId, prefix: &str) -> Result<String> {
    backend_id
        .as_str()
        .strip_prefix(prefix)
        .map(str::to_owned)
        .ok_or_else(|| {
            chain_not_ready(format!(
                "selected backend {backend_id} is not provided by framelean-ffmpeg"
            ))
        })
}

fn chain_not_ready(message: impl Into<String>) -> EngineError {
    EngineError::with_code(
        ErrorKind::Pipeline,
        EngineErrorCode::EngineExecutionChainNotReady,
        message,
    )
}

#[cfg(any(test, debug_assertions))]
fn progress_delay_from_test_environment() -> Duration {
    std::env::var("FRAMELEAN_TEST_REMUX_PROGRESS_DELAY_MS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .filter(|milliseconds| *milliseconds > 0)
        .map(Duration::from_millis)
        .unwrap_or(Duration::ZERO)
}
