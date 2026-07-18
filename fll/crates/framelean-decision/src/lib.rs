use std::collections::BTreeSet;

use framelean_analysis::{MediaAnalysis, MediaDescriptor, MediaKind, MediaStreamDescriptor};
use framelean_core::{
    BackendId, BitRateBps, EngineError, EngineErrorCode, ErrorKind, ObservationStatus, Result,
};
use framelean_environment::{EnvironmentSnapshot, ResourceSample};
use framelean_media::capability::{
    BackendCapability, BackendCatalog, BackendDescriptor, BackendKind, CapabilityConstraint,
    DecoderCapability, DemuxerCapability, EngineRegistrationStatus, HdrMode, HdrOperation,
    MuxerCapability, MuxerCodecCombination, ProcessorCapability, StreamKind,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

pub const ENGINE_EXECUTION_CHAIN_NOT_READY: EngineErrorCode =
    EngineErrorCode::EngineExecutionChainNotReady;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum TaskMode {
    VideoCompress,
    VideoConvert,
    AudioCompress,
    AudioConvert,
    ImageCompress,
    ImageConvert,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct PresetId(String);

impl PresetId {
    pub fn new(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        if value.trim().is_empty() {
            return Err(EngineError::invalid_identifier("preset"));
        }
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct EstimatorPolicyId(String);

impl EstimatorPolicyId {
    pub fn new(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        if value.trim().is_empty() {
            return Err(EngineError::invalid_identifier("estimator policy"));
        }
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ConfigurationStatus {
    Available,
    Unavailable,
    NotEvaluated,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct CapabilityExclusion {
    pub code: EngineErrorCode,
    pub message: String,
    pub backend_id: Option<BackendId>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct CapabilityDiagnostic {
    pub backend_id: BackendId,
    pub kind: BackendKind,
    pub native_status: String,
    pub engine_ready: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct VideoInputRequirement {
    pub stream_index: u32,
    pub codec: String,
    pub profile: Option<String>,
    pub width: u32,
    pub height: u32,
    pub frame_rate: Option<framelean_media::Rational>,
    pub pixel_format: Option<String>,
    pub bit_depth: Option<u8>,
    pub color_range: Option<String>,
    pub color_space: Option<String>,
    pub color_transfer: Option<String>,
    pub color_primaries: Option<String>,
    pub hdr_mode: HdrMode,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct AudioInputRequirement {
    pub stream_index: u32,
    pub codec: String,
    pub profile: Option<String>,
    pub sample_rate_hz: Option<u32>,
    pub channel_count: Option<u32>,
    pub channel_layout: Option<String>,
    pub sample_format: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ImageInputRequirement {
    pub codec: String,
    pub width: u32,
    pub height: u32,
    pub pixel_format: Option<String>,
    pub bit_depth: Option<u8>,
    pub alpha: Option<bool>,
    pub color_space: Option<String>,
    pub animated: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct AuxiliaryInputRequirement {
    pub stream_index: u32,
    pub codec: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct InputMediaRequirements {
    pub container: Option<String>,
    pub media_kind: MediaKind,
    pub duration_microseconds: Option<u64>,
    pub video_streams: Vec<VideoInputRequirement>,
    pub audio_streams: Vec<AudioInputRequirement>,
    pub subtitle_streams: Vec<AuxiliaryInputRequirement>,
    pub data_streams: Vec<AuxiliaryInputRequirement>,
    pub attachments: Vec<AuxiliaryInputRequirement>,
    pub image: Option<ImageInputRequirement>,
}

impl InputMediaRequirements {
    pub fn from_media_analysis(media: &MediaAnalysis) -> Self {
        let mut value = Self {
            container: detected(&media.format),
            media_kind: media.kind,
            duration_microseconds: media.duration.value.map(duration_microseconds),
            video_streams: Vec::new(),
            audio_streams: Vec::new(),
            subtitle_streams: Vec::new(),
            data_streams: Vec::new(),
            attachments: Vec::new(),
            image: None,
        };
        match &media.descriptor {
            MediaDescriptor::Video { streams }
            | MediaDescriptor::Audio { streams }
            | MediaDescriptor::Other { streams } => {
                for stream in streams {
                    match stream {
                        MediaStreamDescriptor::Video(stream) => {
                            value.video_streams.push(VideoInputRequirement {
                                stream_index: stream.stream_index,
                                codec: stream.codec.clone(),
                                profile: detected(&stream.profile),
                                width: stream.width,
                                height: stream.height,
                                frame_rate: detected(&stream.frame_rate),
                                pixel_format: detected(&stream.pixel_format),
                                bit_depth: detected(&stream.bit_depth),
                                color_range: detected(&stream.hdr.color_range),
                                color_space: detected(&stream.hdr.color_space),
                                color_transfer: detected(&stream.hdr.color_transfer),
                                color_primaries: detected(&stream.hdr.color_primaries),
                                hdr_mode: infer_hdr_mode(&stream.hdr),
                            });
                        }
                        MediaStreamDescriptor::Audio(stream) => {
                            value.audio_streams.push(AudioInputRequirement {
                                stream_index: stream.stream_index,
                                codec: stream.codec.clone(),
                                profile: detected(&stream.profile),
                                sample_rate_hz: detected(&stream.sample_rate_hz),
                                channel_count: detected(&stream.channel_count),
                                channel_layout: detected(&stream.channel_layout),
                                sample_format: detected(&stream.sample_format),
                            });
                        }
                        MediaStreamDescriptor::Subtitle(stream) => {
                            value.subtitle_streams.push(AuxiliaryInputRequirement {
                                stream_index: stream.stream_index,
                                codec: stream.codec.clone(),
                            })
                        }
                        MediaStreamDescriptor::Data(stream) => {
                            value.data_streams.push(AuxiliaryInputRequirement {
                                stream_index: stream.stream_index,
                                codec: stream.codec.clone(),
                            });
                        }
                        MediaStreamDescriptor::Attachment(stream) => {
                            value.attachments.push(AuxiliaryInputRequirement {
                                stream_index: stream.stream_index,
                                codec: stream.codec.clone(),
                            });
                        }
                    }
                }
            }
            MediaDescriptor::Image { image } | MediaDescriptor::AnimatedImage { image, .. } => {
                value.image = Some(ImageInputRequirement {
                    codec: image.codec.clone(),
                    width: image.width,
                    height: image.height,
                    pixel_format: detected(&image.pixel_format),
                    bit_depth: detected(&image.bit_depth),
                    alpha: detected(&image.alpha),
                    color_space: detected(&image.color_space),
                    animated: media.kind == MediaKind::AnimatedImage,
                });
            }
        }
        value
    }
}

fn detected<T: Clone>(value: &framelean_core::Observed<T>) -> Option<T> {
    (value.status == ObservationStatus::Detected)
        .then(|| value.value.clone())
        .flatten()
}

fn duration_microseconds(value: framelean_media::MediaDuration) -> u64 {
    if value.timescale() == 1_000_000 {
        value.value()
    } else {
        ((value.value() as u128 * 1_000_000) / value.timescale() as u128) as u64
    }
}

fn infer_hdr_mode(value: &framelean_analysis::HdrInfo) -> HdrMode {
    let transfer = detected(&value.color_transfer)
        .unwrap_or_default()
        .to_ascii_lowercase();
    let primaries = detected(&value.color_primaries)
        .unwrap_or_default()
        .to_ascii_lowercase();
    if transfer.contains("smpte2084") || transfer.contains("pq") {
        HdrMode::Hdr10
    } else if transfer.contains("arib") || transfer.contains("hlg") {
        HdrMode::Hlg
    } else if !transfer.is_empty() && !primaries.is_empty() {
        HdrMode::Sdr
    } else {
        HdrMode::Unknown
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct ExecutionChainId(String);

impl ExecutionChainId {
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct StreamBackendSelection {
    pub stream_index: u32,
    pub backend_id: BackendId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ProcessorSelection {
    pub backend_id: BackendId,
    pub operation: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ExecutionChainCandidate {
    pub id: ExecutionChainId,
    pub demuxer: BackendId,
    pub video_decoders: Vec<StreamBackendSelection>,
    pub audio_decoders: Vec<StreamBackendSelection>,
    pub processors: Vec<ProcessorSelection>,
    pub video_encoder: Option<BackendId>,
    pub audio_encoder: Option<BackendId>,
    pub muxer: BackendId,
    pub output_container: String,
    pub output_video_codec: Option<String>,
    pub output_video_profile: Option<String>,
    pub output_audio_codec: Option<String>,
    pub output_pixel_format: Option<String>,
    pub output_bit_depth: Option<u8>,
    pub output_hdr_mode: HdrMode,
    pub preserves_hdr: bool,
    pub requires_tone_mapping: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct CapabilitySet {
    pub available: bool,
    pub containers: Vec<String>,
    pub video_codecs: Vec<String>,
    pub audio_codecs: Vec<String>,
    pub image_formats: Vec<String>,
    pub demuxers: Vec<BackendId>,
    pub decoders: Vec<BackendId>,
    pub processors: Vec<BackendId>,
    pub encoders: Vec<BackendId>,
    pub muxers: Vec<BackendId>,
    pub execution_chains: Vec<ExecutionChainCandidate>,
    pub diagnostics: Vec<CapabilityDiagnostic>,
    pub exclusions: Vec<CapabilityExclusion>,
}

pub trait CapabilityResolver: Send + Sync {
    fn resolve(
        &self,
        requirements: &InputMediaRequirements,
        task_mode: TaskMode,
        environment: &EnvironmentSnapshot,
        catalog: &BackendCatalog,
    ) -> Result<CapabilitySet>;
}

#[derive(Default)]
pub struct DefaultCapabilityResolver;

impl CapabilityResolver for DefaultCapabilityResolver {
    fn resolve(
        &self,
        requirements: &InputMediaRequirements,
        task_mode: TaskMode,
        environment: &EnvironmentSnapshot,
        catalog: &BackendCatalog,
    ) -> Result<CapabilitySet> {
        let ready_demuxers: Vec<_> = catalog
            .execution_ready(BackendKind::Demuxer)
            .filter(|backend| environment_accepts(backend, environment))
            .filter(|backend| demuxer_accepts(backend, requirements))
            .collect();
        let ready_decoders: Vec<_> = catalog
            .execution_ready(BackendKind::Decoder)
            .filter(|backend| environment_accepts(backend, environment))
            .collect();
        let ready_processors: Vec<_> = catalog
            .execution_ready(BackendKind::Processor)
            .filter(|backend| environment_accepts(backend, environment))
            .collect();
        let ready_encoders: Vec<_> = catalog
            .execution_ready(BackendKind::Encoder)
            .filter(|backend| environment_accepts(backend, environment))
            .collect();
        let ready_muxers: Vec<_> = catalog
            .execution_ready(BackendKind::Muxer)
            .filter(|backend| environment_accepts(backend, environment))
            .collect();

        let mut chains = Vec::new();
        for demuxer in &ready_demuxers {
            let Some((video_decoders, audio_decoders)) =
                select_decoders(requirements, &ready_decoders)
            else {
                continue;
            };
            for muxer in &ready_muxers {
                let BackendCapability::Muxer(muxer_capability) = &muxer.capability else {
                    continue;
                };
                if !muxer_accepts_input(muxer_capability, requirements) {
                    continue;
                }
                for combination in muxer_combinations(muxer_capability) {
                    for output_format in &muxer_capability.output_formats {
                        if let Some(mut candidates) = build_output_candidates(
                            CandidateBuildContext {
                                requirements,
                                task_mode,
                                processors: &ready_processors,
                                encoders: &ready_encoders,
                                demuxer,
                                video_decoders: &video_decoders,
                                audio_decoders: &audio_decoders,
                                muxer,
                            },
                            output_format,
                            &combination,
                        ) {
                            chains.append(&mut candidates);
                        }
                    }
                }
            }
        }
        chains.sort_by(|left, right| left.id.as_str().cmp(right.id.as_str()));
        chains.dedup_by(|left, right| left.id == right.id);

        let diagnostics = catalog
            .backends
            .iter()
            .filter(|backend| {
                backend.availability.engine_registration
                    == EngineRegistrationStatus::EngineRegistered
                    || diagnostic_matches_input(backend, requirements)
            })
            .map(|backend| CapabilityDiagnostic {
                backend_id: backend.id.clone(),
                kind: backend.capability.kind(),
                native_status: native_status_name(backend.availability.native_support).to_owned(),
                engine_ready: backend.availability.is_execution_ready(),
            })
            .collect();
        let available = !chains.is_empty();
        let exclusions = if available {
            Vec::new()
        } else {
            vec![CapabilityExclusion {
                code: ENGINE_EXECUTION_CHAIN_NOT_READY,
                message: missing_chain_message(
                    &ready_demuxers,
                    &ready_decoders,
                    &ready_encoders,
                    &ready_muxers,
                ),
                backend_id: None,
            }]
        };

        let containers = unique(chains.iter().map(|chain| chain.output_container.clone()));
        Ok(CapabilitySet {
            available,
            containers,
            video_codecs: unique(
                chains
                    .iter()
                    .filter_map(|chain| chain.output_video_codec.clone()),
            ),
            audio_codecs: unique(
                chains
                    .iter()
                    .filter_map(|chain| chain.output_audio_codec.clone()),
            ),
            image_formats: if matches!(task_mode, TaskMode::ImageCompress | TaskMode::ImageConvert)
            {
                unique(chains.iter().map(|chain| chain.output_container.clone()))
            } else {
                Vec::new()
            },
            demuxers: unique_ids(chains.iter().map(|chain| &chain.demuxer)),
            decoders: unique_ids(chains.iter().flat_map(|chain| {
                chain
                    .video_decoders
                    .iter()
                    .chain(chain.audio_decoders.iter())
                    .map(|value| &value.backend_id)
            })),
            processors: unique_ids(
                chains
                    .iter()
                    .flat_map(|chain| chain.processors.iter().map(|value| &value.backend_id)),
            ),
            encoders: unique_ids(
                chains
                    .iter()
                    .flat_map(|chain| chain.video_encoder.iter().chain(chain.audio_encoder.iter())),
            ),
            muxers: unique_ids(chains.iter().map(|chain| &chain.muxer)),
            execution_chains: chains,
            diagnostics,
            exclusions,
        })
    }
}

fn diagnostic_matches_input(
    backend: &BackendDescriptor,
    requirements: &InputMediaRequirements,
) -> bool {
    match &backend.capability {
        BackendCapability::Demuxer(_) => demuxer_accepts(backend, requirements),
        BackendCapability::Decoder(capability) => {
            requirements
                .video_streams
                .iter()
                .any(|value| decoder_accepts_video(capability, value))
                || requirements
                    .audio_streams
                    .iter()
                    .any(|value| decoder_accepts_audio(capability, value))
        }
        _ => false,
    }
}

fn native_status_name(status: framelean_media::capability::NativeSupportStatus) -> &'static str {
    use framelean_media::capability::NativeSupportStatus;
    match status {
        NativeSupportStatus::NotProbed => "not_probed",
        NativeSupportStatus::NativeNotRequired => "native_not_required",
        NativeSupportStatus::NativeDiscovered => "native_discovered",
        NativeSupportStatus::NativeInitializable => "native_initializable",
        NativeSupportStatus::NativeUnavailable => "native_unavailable",
        NativeSupportStatus::NativeInitializationFailed => "native_initialization_failed",
        NativeSupportStatus::Unsupported => "unsupported",
    }
}

fn demuxer_accepts(backend: &BackendDescriptor, requirements: &InputMediaRequirements) -> bool {
    let BackendCapability::Demuxer(capability) = &backend.capability else {
        return false;
    };
    let stream_count = all_input_streams(requirements).count();
    requirements.container.as_deref().is_some_and(|format| {
        capability.input_formats.iter().any(|value| value == format)
            && (stream_count <= 1 || observed_true(&capability.supports_multiple_streams))
            && all_input_streams(requirements)
                .all(|(kind, codec)| demuxer_supports_stream(capability, kind, codec))
    })
}

fn demuxer_supports_stream(capability: &DemuxerCapability, kind: StreamKind, codec: &str) -> bool {
    capability.stream_types.contains(&kind)
        && capability.codec_restrictions.allows(&codec.to_owned())
}

fn all_input_streams(
    requirements: &InputMediaRequirements,
) -> impl Iterator<Item = (StreamKind, &str)> {
    requirements
        .video_streams
        .iter()
        .map(|v| (StreamKind::Video, v.codec.as_str()))
        .chain(
            requirements
                .audio_streams
                .iter()
                .map(|v| (StreamKind::Audio, v.codec.as_str())),
        )
        .chain(
            requirements
                .subtitle_streams
                .iter()
                .map(|v| (StreamKind::Subtitle, v.codec.as_str())),
        )
        .chain(
            requirements
                .data_streams
                .iter()
                .map(|v| (StreamKind::Data, v.codec.as_str())),
        )
        .chain(
            requirements
                .attachments
                .iter()
                .map(|v| (StreamKind::Attachment, v.codec.as_str())),
        )
        .chain(
            requirements
                .image
                .iter()
                .map(|v| (StreamKind::Video, v.codec.as_str())),
        )
}

fn select_decoders(
    requirements: &InputMediaRequirements,
    decoders: &[&BackendDescriptor],
) -> Option<(Vec<StreamBackendSelection>, Vec<StreamBackendSelection>)> {
    let mut video = Vec::new();
    for stream in &requirements.video_streams {
        let decoder = decoders.iter().copied().find(|backend| {
            matches!(&backend.capability, BackendCapability::Decoder(value) if decoder_accepts_video(value, stream))
        })?;
        video.push(StreamBackendSelection {
            stream_index: stream.stream_index,
            backend_id: decoder.id.clone(),
        });
    }
    if let Some(image) = &requirements.image {
        let decoder = decoders.iter().copied().find(|backend| matches!(&backend.capability, BackendCapability::Decoder(value) if decoder_accepts_image(value, image)))?;
        video.push(StreamBackendSelection {
            stream_index: 0,
            backend_id: decoder.id.clone(),
        });
    }
    let mut audio = Vec::new();
    for stream in &requirements.audio_streams {
        let decoder = decoders.iter().copied().find(|backend| matches!(&backend.capability, BackendCapability::Decoder(value) if decoder_accepts_audio(value, stream)))?;
        audio.push(StreamBackendSelection {
            stream_index: stream.stream_index,
            backend_id: decoder.id.clone(),
        });
    }
    Some((video, audio))
}

fn decoder_accepts_video(capability: &DecoderCapability, stream: &VideoInputRequirement) -> bool {
    capability.stream_type == StreamKind::Video
        && capability.codecs.contains(&stream.codec)
        && stream
            .profile
            .as_ref()
            .is_some_and(|v| capability.profiles.allows(v))
        && stream
            .pixel_format
            .as_ref()
            .is_some_and(|v| capability.pixel_or_sample_formats.allows(v))
        && stream
            .bit_depth
            .is_some_and(|v| capability.bit_depths.allows(&v))
}

fn decoder_accepts_audio(capability: &DecoderCapability, stream: &AudioInputRequirement) -> bool {
    capability.stream_type == StreamKind::Audio
        && capability.codecs.contains(&stream.codec)
        && stream
            .profile
            .as_ref()
            .is_some_and(|v| capability.profiles.allows(v))
        && stream
            .sample_format
            .as_ref()
            .is_some_and(|v| capability.pixel_or_sample_formats.allows(v))
}

fn decoder_accepts_image(capability: &DecoderCapability, image: &ImageInputRequirement) -> bool {
    capability.stream_type == StreamKind::Video
        && capability.codecs.contains(&image.codec)
        && image
            .pixel_format
            .as_ref()
            .is_some_and(|value| capability.pixel_or_sample_formats.allows(value))
        && image
            .bit_depth
            .is_some_and(|value| capability.bit_depths.allows(&value))
}

fn muxer_combinations(capability: &MuxerCapability) -> Vec<MuxerCodecCombination> {
    match &capability.codec_combinations {
        CapabilityConstraint::Restricted(values) => values.clone(),
        CapabilityConstraint::Unrestricted => {
            let videos: Vec<_> = if capability.video_codecs.is_empty() {
                vec![None]
            } else {
                capability.video_codecs.iter().cloned().map(Some).collect()
            };
            let audios: Vec<_> = if capability.audio_codecs.is_empty() {
                vec![None]
            } else {
                capability.audio_codecs.iter().cloned().map(Some).collect()
            };
            videos
                .into_iter()
                .flat_map(|video_codec| {
                    audios
                        .iter()
                        .cloned()
                        .map(move |audio_codec| MuxerCodecCombination {
                            video_codec: video_codec.clone(),
                            audio_codec,
                        })
                })
                .collect()
        }
        CapabilityConstraint::Unknown | CapabilityConstraint::Unsupported => Vec::new(),
    }
}

fn muxer_accepts_input(
    capability: &MuxerCapability,
    requirements: &InputMediaRequirements,
) -> bool {
    let stream_count = requirements.video_streams.len()
        + requirements.audio_streams.len()
        + requirements.subtitle_streams.len()
        + requirements.data_streams.len()
        + requirements.attachments.len()
        + usize::from(requirements.image.is_some());
    (stream_count <= 1 || observed_true(&capability.supports_multiple_streams))
        && (requirements.subtitle_streams.is_empty()
            || observed_true(&capability.supports_subtitles))
        && (requirements.data_streams.is_empty() || observed_true(&capability.supports_data))
        && (requirements.attachments.is_empty() || observed_true(&capability.supports_attachments))
}

fn observed_true(value: &framelean_core::Observed<bool>) -> bool {
    value.status == ObservationStatus::Detected && value.value == Some(true)
}

struct CandidateBuildContext<'a> {
    requirements: &'a InputMediaRequirements,
    task_mode: TaskMode,
    processors: &'a [&'a BackendDescriptor],
    encoders: &'a [&'a BackendDescriptor],
    demuxer: &'a BackendDescriptor,
    video_decoders: &'a [StreamBackendSelection],
    audio_decoders: &'a [StreamBackendSelection],
    muxer: &'a BackendDescriptor,
}

fn build_output_candidates(
    context: CandidateBuildContext<'_>,
    output_container: &str,
    combination: &MuxerCodecCombination,
) -> Option<Vec<ExecutionChainCandidate>> {
    let needs_video = matches!(
        context.task_mode,
        TaskMode::VideoCompress
            | TaskMode::VideoConvert
            | TaskMode::ImageCompress
            | TaskMode::ImageConvert
    );
    let needs_audio = matches!(
        context.task_mode,
        TaskMode::AudioCompress | TaskMode::AudioConvert
    ) || (!context.requirements.audio_streams.is_empty() && needs_video);
    if needs_video != combination.video_codec.is_some()
        || needs_audio != combination.audio_codec.is_some()
    {
        return None;
    }
    let video_encoders: Vec<Option<&BackendDescriptor>> = match &combination.video_codec {
        Some(codec) => context.encoders.iter().copied().filter(|backend| matches!(&backend.capability, BackendCapability::Encoder(value) if value.stream_type == StreamKind::Video && value.codecs.contains(codec) && constraint_has_support(&value.profiles))).map(Some).collect(),
        None => vec![None],
    };
    let audio_encoders: Vec<Option<&BackendDescriptor>> = match &combination.audio_codec {
        Some(codec) => context.encoders.iter().copied().filter(|backend| matches!(&backend.capability, BackendCapability::Encoder(value) if value.stream_type == StreamKind::Audio && value.codecs.contains(codec) && constraint_has_support(&value.profiles))).map(Some).collect(),
        None => vec![None],
    };
    if video_encoders.is_empty() || audio_encoders.is_empty() {
        return None;
    }
    let input_video = context
        .requirements
        .video_streams
        .first()
        .cloned()
        .or_else(|| {
            context
                .requirements
                .image
                .as_ref()
                .map(|image| VideoInputRequirement {
                    stream_index: 0,
                    codec: image.codec.clone(),
                    profile: None,
                    width: image.width,
                    height: image.height,
                    frame_rate: None,
                    pixel_format: image.pixel_format.clone(),
                    bit_depth: image.bit_depth,
                    color_range: None,
                    color_space: image.color_space.clone(),
                    color_transfer: None,
                    color_primaries: None,
                    hdr_mode: HdrMode::Sdr,
                })
        });
    let mut result = Vec::new();
    for video_encoder in &video_encoders {
        let video_options =
            output_video_options(input_video.as_ref(), *video_encoder, context.processors);
        if needs_video && video_options.is_empty() {
            continue;
        }
        let video_options = if needs_video {
            video_options
        } else {
            vec![(None, None, None, HdrMode::Sdr, false, false, Vec::new())]
        };
        for audio_encoder in &audio_encoders {
            if let Some(backend) = audio_encoder {
                let BackendCapability::Encoder(capability) = &backend.capability else {
                    continue;
                };
                let Some(sample) = context
                    .requirements
                    .audio_streams
                    .first()
                    .and_then(|v| v.sample_format.as_ref())
                else {
                    continue;
                };
                if !capability.pixel_or_sample_formats.allows(sample) {
                    continue;
                }
            }
            for (
                pixel_format,
                video_profile,
                bit_depth,
                hdr_mode,
                preserves_hdr,
                tone_mapping,
                selected_processors,
            ) in &video_options
            {
                let mut candidate = ExecutionChainCandidate {
                    id: ExecutionChainId(String::new()),
                    demuxer: context.demuxer.id.clone(),
                    video_decoders: context.video_decoders.to_vec(),
                    audio_decoders: context.audio_decoders.to_vec(),
                    processors: selected_processors.clone(),
                    video_encoder: video_encoder.map(|v| v.id.clone()),
                    audio_encoder: audio_encoder.map(|v| v.id.clone()),
                    muxer: context.muxer.id.clone(),
                    output_container: output_container.to_owned(),
                    output_video_codec: combination.video_codec.clone(),
                    output_video_profile: video_profile.clone(),
                    output_audio_codec: combination.audio_codec.clone(),
                    output_pixel_format: pixel_format.clone(),
                    output_bit_depth: *bit_depth,
                    output_hdr_mode: *hdr_mode,
                    preserves_hdr: *preserves_hdr,
                    requires_tone_mapping: *tone_mapping,
                };
                candidate.id = chain_id(&candidate);
                result.push(candidate);
            }
        }
    }
    Some(result)
}

type VideoOutputOption = (
    Option<String>,
    Option<String>,
    Option<u8>,
    HdrMode,
    bool,
    bool,
    Vec<ProcessorSelection>,
);

fn output_video_options(
    input: Option<&VideoInputRequirement>,
    encoder: Option<&BackendDescriptor>,
    processors: &[&BackendDescriptor],
) -> Vec<VideoOutputOption> {
    let (Some(input), Some(encoder)) = (input, encoder) else {
        return Vec::new();
    };
    let BackendCapability::Encoder(capability) = &encoder.capability else {
        return Vec::new();
    };
    let Some(profiles) = capability.profiles.values() else {
        return Vec::new();
    };
    let (Some(pixel), Some(depth)) = (input.pixel_format.as_ref(), input.bit_depth) else {
        return Vec::new();
    };
    let mut options = Vec::new();
    if capability.pixel_or_sample_formats.allows(pixel)
        && capability.bit_depths.allows(&depth)
        && capability.hdr_modes.allows(&input.hdr_mode)
    {
        for profile in profiles {
            options.push((
                Some(pixel.clone()),
                Some(profile.clone()),
                Some(depth),
                input.hdr_mode,
                input.hdr_mode != HdrMode::Sdr,
                false,
                Vec::new(),
            ));
        }
    }
    if capability.hdr_modes.allows(&input.hdr_mode)
        && let Some((backend, processor)) =
            processors
                .iter()
                .find_map(|backend| match &backend.capability {
                    BackendCapability::Processor(value)
                        if processor_supports_conversion(value, pixel, depth, input.hdr_mode) =>
                    {
                        Some((*backend, value))
                    }
                    _ => None,
                })
    {
        let output_pixel = processor
            .output_formats
            .values()
            .and_then(|values| {
                values
                    .iter()
                    .find(|value| capability.pixel_or_sample_formats.allows(value))
            })
            .cloned();
        let output_depth = processor
            .bit_depths
            .values()
            .and_then(|values| {
                values
                    .iter()
                    .find(|value| capability.bit_depths.allows(value))
            })
            .copied();
        if let (Some(output_pixel), Some(output_depth)) = (output_pixel, output_depth) {
            for profile in profiles {
                options.push((
                    Some(output_pixel.clone()),
                    Some(profile.clone()),
                    Some(output_depth),
                    input.hdr_mode,
                    input.hdr_mode != HdrMode::Sdr,
                    false,
                    vec![ProcessorSelection {
                        backend_id: backend.id.clone(),
                        operation: "pixel_format_conversion".to_owned(),
                    }],
                ));
            }
        }
    }
    if input.hdr_mode != HdrMode::Sdr
        && input.hdr_mode != HdrMode::Unknown
        && capability.hdr_modes.allows(&HdrMode::Sdr)
        && let Some((backend, processor)) =
            processors
                .iter()
                .find_map(|backend| match &backend.capability {
                    BackendCapability::Processor(value)
                        if processor_supports_tone_map(value, pixel, depth) =>
                    {
                        Some((*backend, value))
                    }
                    _ => None,
                })
    {
        let output_pixel = processor
            .output_formats
            .values()
            .and_then(|v| {
                v.iter()
                    .find(|v| capability.pixel_or_sample_formats.allows(v))
            })
            .cloned();
        let output_depth = processor
            .bit_depths
            .values()
            .and_then(|v| v.iter().find(|v| capability.bit_depths.allows(v)))
            .copied();
        if let (Some(output_pixel), Some(output_depth)) = (output_pixel, output_depth) {
            for profile in profiles {
                options.push((
                    Some(output_pixel.clone()),
                    Some(profile.clone()),
                    Some(output_depth),
                    HdrMode::Sdr,
                    false,
                    true,
                    vec![ProcessorSelection {
                        backend_id: backend.id.clone(),
                        operation: "tone_map_to_sdr".to_owned(),
                    }],
                ));
            }
        }
    }
    options
}

fn processor_supports_tone_map(
    capability: &ProcessorCapability,
    pixel: &String,
    depth: u8,
) -> bool {
    capability.stream_type == StreamKind::Video
        && capability.input_formats.allows(pixel)
        && capability.bit_depths.allows(&depth)
        && capability
            .hdr_operations
            .allows(&HdrOperation::ToneMapToSdr)
}

fn processor_supports_conversion(
    capability: &ProcessorCapability,
    pixel: &String,
    depth: u8,
    hdr_mode: HdrMode,
) -> bool {
    capability.stream_type == StreamKind::Video
        && capability.input_formats.allows(pixel)
        && capability.bit_depths.allows(&depth)
        && capability
            .operations
            .iter()
            .any(|operation| operation == "pixel_format_conversion")
        && (hdr_mode == HdrMode::Sdr || capability.hdr_operations.allows(&HdrOperation::Preserve))
}

fn constraint_has_support<T>(constraint: &CapabilityConstraint<T>) -> bool {
    matches!(constraint, CapabilityConstraint::Unrestricted)
        || matches!(constraint, CapabilityConstraint::Restricted(values) if !values.is_empty())
}

fn chain_id(candidate: &ExecutionChainCandidate) -> ExecutionChainId {
    let mut hash = blake3::Hasher::new();
    for value in [
        candidate.demuxer.as_str(),
        candidate.muxer.as_str(),
        &candidate.output_container,
    ] {
        hash.update(value.as_bytes());
        hash.update(&[0]);
    }
    for value in candidate
        .video_decoders
        .iter()
        .chain(candidate.audio_decoders.iter())
    {
        hash.update(&value.stream_index.to_le_bytes());
        hash.update(value.backend_id.as_str().as_bytes());
    }
    for value in &candidate.processors {
        hash.update(value.backend_id.as_str().as_bytes());
        hash.update(value.operation.as_bytes());
    }
    for value in [
        &candidate.output_video_codec,
        &candidate.output_video_profile,
        &candidate.output_audio_codec,
        &candidate.output_pixel_format,
    ]
    .into_iter()
    .flatten()
    {
        hash.update(value.as_bytes());
        hash.update(&[0]);
    }
    if let Some(value) = candidate.output_bit_depth {
        hash.update(&[value]);
    }
    ExecutionChainId(format!("chain-{}", &hash.finalize().to_hex()[..24]))
}

fn environment_accepts(backend: &BackendDescriptor, environment: &EnvironmentSnapshot) -> bool {
    let os = detected(&environment.operating_system);
    if !matches_environment_value(&backend.environment.operating_systems, os.as_ref())
        || !backend
            .environment
            .architectures
            .allows(&environment.cpu.architecture)
    {
        return false;
    }
    match &backend.environment.requires_gpu {
        CapabilityConstraint::Unrestricted => {}
        CapabilityConstraint::Restricted(values) if values.contains(&true) => {
            if environment
                .gpus
                .value
                .as_ref()
                .is_none_or(|value| value.is_empty())
            {
                return false;
            }
        }
        CapabilityConstraint::Restricted(values) if values.contains(&false) => {}
        CapabilityConstraint::Unknown
        | CapabilityConstraint::Unsupported
        | CapabilityConstraint::Restricted(_) => return false,
    }
    match &backend.environment.native_frameworks {
        CapabilityConstraint::Unrestricted => true,
        CapabilityConstraint::Restricted(required) => required.iter().all(|name| {
            environment.native_media_frameworks.iter().any(|framework| {
                framework.name == *name && framework.status.status == ObservationStatus::Detected
            })
        }),
        CapabilityConstraint::Unknown | CapabilityConstraint::Unsupported => false,
    }
}

fn matches_environment_value(
    constraint: &CapabilityConstraint<String>,
    value: Option<&String>,
) -> bool {
    match constraint {
        CapabilityConstraint::Unrestricted => true,
        CapabilityConstraint::Restricted(_) => value.is_some_and(|value| constraint.allows(value)),
        CapabilityConstraint::Unknown | CapabilityConstraint::Unsupported => false,
    }
}

fn unique(values: impl IntoIterator<Item = String>) -> Vec<String> {
    values
        .into_iter()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

fn unique_ids<'a>(values: impl IntoIterator<Item = &'a BackendId>) -> Vec<BackendId> {
    let mut ids = Vec::new();
    for id in values {
        if !ids.contains(id) {
            ids.push(id.clone());
        }
    }
    ids
}

fn missing_chain_message(
    demuxers: &[&BackendDescriptor],
    decoders: &[&BackendDescriptor],
    encoders: &[&BackendDescriptor],
    muxers: &[&BackendDescriptor],
) -> String {
    let mut missing = Vec::new();
    if demuxers.is_empty() {
        missing.push("demuxer");
    }
    if decoders.is_empty() {
        missing.push("decoder");
    }
    if encoders.is_empty() {
        missing.push("encoder");
    }
    if muxers.is_empty() {
        missing.push("muxer");
    }
    if missing.is_empty() {
        "registered stages do not form a compatible execution chain".to_owned()
    } else {
        format!(
            "FrameLean execution chain is missing: {}",
            missing.join(", ")
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum RecommendationStatus {
    Complete,
    Partial,
    Unavailable,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct RecommendedConfiguration {
    pub execution_chain_id: ExecutionChainId,
    pub container: String,
    pub video_codec: Option<String>,
    pub video_profile: Option<String>,
    pub audio_codec: Option<String>,
    pub demuxer_backend: BackendId,
    pub video_decoders: Vec<StreamBackendSelection>,
    pub audio_decoders: Vec<StreamBackendSelection>,
    pub video_encoder_backend: Option<BackendId>,
    pub audio_encoder_backend: Option<BackendId>,
    pub processors: Vec<ProcessorSelection>,
    pub muxer_backend: BackendId,
    pub output_pixel_format: Option<String>,
    pub output_bit_depth: Option<u8>,
    pub output_hdr_mode: HdrMode,
    pub preserves_hdr: bool,
    pub requires_tone_mapping: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Recommendation {
    pub status: RecommendationStatus,
    pub configuration: Option<RecommendedConfiguration>,
    pub reasons: Vec<String>,
    pub estimate: Option<SizeEstimate>,
    pub resource_sample_unix_ms: Option<u64>,
}

pub trait RecommendationEngine: Send + Sync {
    fn recommend(
        &self,
        requirements: &InputMediaRequirements,
        capabilities: &CapabilitySet,
        resource_sample: Option<&ResourceSample>,
    ) -> Recommendation;
}

#[derive(Default)]
pub struct DefaultRecommendationEngine;

impl RecommendationEngine for DefaultRecommendationEngine {
    fn recommend(
        &self,
        requirements: &InputMediaRequirements,
        capabilities: &CapabilitySet,
        resource_sample: Option<&ResourceSample>,
    ) -> Recommendation {
        let balanced = preset_policies()
            .into_iter()
            .find(|policy| policy.id.as_str() == "balanced")
            .expect("balanced product preset exists");
        let Some(chain) = capabilities
            .execution_chains
            .iter()
            .filter(|chain| preset_matches_candidate(&balanced, requirements, chain))
            .min_by_key(|chain| preset_rank(&balanced, chain))
        else {
            return Recommendation {
                status: RecommendationStatus::Unavailable,
                configuration: None,
                reasons: vec!["ENGINE_EXECUTION_CHAIN_NOT_READY".to_owned()],
                estimate: None,
                resource_sample_unix_ms: resource_sample.map(|value| value.sampled_at_unix_ms),
            };
        };
        Recommendation {
            status: RecommendationStatus::Complete,
            configuration: Some(RecommendedConfiguration {
                execution_chain_id: chain.id.clone(),
                container: chain.output_container.clone(),
                video_codec: chain.output_video_codec.clone(),
                video_profile: chain.output_video_profile.clone(),
                audio_codec: chain.output_audio_codec.clone(),
                demuxer_backend: chain.demuxer.clone(),
                video_decoders: chain.video_decoders.clone(),
                audio_decoders: chain.audio_decoders.clone(),
                video_encoder_backend: chain.video_encoder.clone(),
                audio_encoder_backend: chain.audio_encoder.clone(),
                processors: chain.processors.clone(),
                muxer_backend: chain.muxer.clone(),
                output_pixel_format: chain.output_pixel_format.clone(),
                output_bit_depth: chain.output_bit_depth,
                output_hdr_mode: chain.output_hdr_mode,
                preserves_hdr: chain.preserves_hdr,
                requires_tone_mapping: chain.requires_tone_mapping,
            }),
            reasons: vec!["balanced execution-ready chain".to_owned()],
            estimate: None,
            resource_sample_unix_ms: resource_sample.map(|value| value.sampled_at_unix_ms),
        }
    }
}

pub fn validate_recommendation(
    recommendation: &Recommendation,
    capabilities: &CapabilitySet,
) -> bool {
    let Some(configuration) = &recommendation.configuration else {
        return recommendation.status == RecommendationStatus::Unavailable;
    };
    capabilities.execution_chains.iter().any(|chain| {
        configuration.execution_chain_id == chain.id
            && configuration.container == chain.output_container
            && configuration.video_codec == chain.output_video_codec
            && configuration.video_profile == chain.output_video_profile
            && configuration.audio_codec == chain.output_audio_codec
            && configuration.demuxer_backend == chain.demuxer
            && configuration.video_decoders == chain.video_decoders
            && configuration.audio_decoders == chain.audio_decoders
            && configuration.video_encoder_backend == chain.video_encoder
            && configuration.audio_encoder_backend == chain.audio_encoder
            && configuration.processors == chain.processors
            && configuration.muxer_backend == chain.muxer
            && configuration.output_pixel_format == chain.output_pixel_format
            && configuration.output_bit_depth == chain.output_bit_depth
            && configuration.output_hdr_mode == chain.output_hdr_mode
            && configuration.preserves_hdr == chain.preserves_hdr
            && configuration.requires_tone_mapping == chain.requires_tone_mapping
    })
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct BitrateCeiling {
    pub minimum_height: u32,
    pub h264_bps: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct PresetPolicy {
    pub id: PresetId,
    pub display_name: String,
    pub description: String,
    pub applicable_task_modes: Vec<TaskMode>,
    pub preferred_containers: Vec<String>,
    pub preferred_video_codecs: Vec<String>,
    pub preferred_audio_codecs: Vec<String>,
    pub video_bitrate_ceilings: Vec<BitrateCeiling>,
    pub audio_bitrate_bps: u64,
    pub source_size_ratio_basis_points: u16,
    pub preserve_hdr: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct PresetDefinition {
    pub id: PresetId,
    pub display_name: String,
    pub description: String,
    pub applicable: bool,
    pub unavailable_reason: Option<String>,
    pub policy_version: u32,
    pub policy: PresetPolicy,
}

pub fn preset_policies() -> Vec<PresetPolicy> {
    [
        (
            "clear",
            "清晰优先",
            "保留细节",
            128_000,
            6500,
            [28_000_000, 8_000_000, 4_000_000, 2_000_000],
        ),
        (
            "balanced",
            "均衡推荐",
            "明显变小",
            96_000,
            5000,
            [16_000_000, 5_000_000, 2_500_000, 1_200_000],
        ),
        (
            "chat",
            "微信发送",
            "聊天分享",
            64_000,
            2500,
            [10_000_000, 3_000_000, 1_600_000, 800_000],
        ),
        (
            "compact",
            "体积优先",
            "尽量压小",
            48_000,
            1000,
            [7_000_000, 2_000_000, 1_100_000, 550_000],
        ),
    ]
    .into_iter()
    .map(
        |(id, name, description, audio, ratio, ceilings)| PresetPolicy {
            id: PresetId::new(id).expect("fixed preset identifiers are valid"),
            display_name: name.to_owned(),
            description: description.to_owned(),
            applicable_task_modes: vec![TaskMode::VideoCompress],
            preferred_containers: vec!["mp4".to_owned()],
            preferred_video_codecs: if id == "chat" {
                vec!["h264".to_owned()]
            } else {
                vec!["h264".to_owned(), "hevc".to_owned()]
            },
            preferred_audio_codecs: vec!["aac".to_owned()],
            video_bitrate_ceilings: [2160, 1080, 720, 0]
                .into_iter()
                .zip(ceilings)
                .map(|(minimum_height, h264_bps)| BitrateCeiling {
                    minimum_height,
                    h264_bps,
                })
                .collect(),
            audio_bitrate_bps: audio,
            source_size_ratio_basis_points: ratio,
            preserve_hdr: matches!(id, "clear" | "balanced"),
        },
    )
    .collect()
}

pub fn fixed_presets(
    requirements: &InputMediaRequirements,
    task_mode: TaskMode,
    capabilities: &CapabilitySet,
) -> Vec<PresetDefinition> {
    preset_policies()
        .into_iter()
        .map(|policy| {
            let applicable = capabilities.available
                && policy.applicable_task_modes.contains(&task_mode)
                && capabilities
                    .execution_chains
                    .iter()
                    .any(|chain| preset_matches_candidate(&policy, requirements, chain));
            PresetDefinition {
                id: policy.id.clone(),
                display_name: policy.display_name.clone(),
                description: policy.description.clone(),
                applicable,
                unavailable_reason: (!applicable).then(|| {
                    if !capabilities.available {
                        "ENGINE_EXECUTION_CHAIN_NOT_READY"
                    } else {
                        "PRESET_NOT_APPLICABLE"
                    }
                    .to_owned()
                }),
                policy_version: 1,
                policy,
            }
        })
        .collect()
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct CustomTargetSizeOptions {
    pub available: bool,
    pub unavailable_reason: Option<String>,
    pub minimum_bytes: Option<u64>,
    pub maximum_bytes: Option<u64>,
    pub default_bytes: Option<u64>,
    pub step_bytes: Option<u64>,
    pub display_unit: String,
}

impl CustomTargetSizeOptions {
    pub fn from_context(
        capabilities: &CapabilitySet,
        policy: Option<&EstimatorPolicy>,
        source_size_bytes: u64,
    ) -> Self {
        let calibrated_overhead =
            policy.and_then(|value| value.calibrated_container_overhead_bytes);
        let available = capabilities.available && calibrated_overhead.is_some();
        if available {
            let minimum = calibrated_overhead
                .expect("available target size has calibrated overhead")
                .saturating_add(1);
            return Self {
                available: true,
                unavailable_reason: None,
                minimum_bytes: Some(minimum),
                maximum_bytes: Some(source_size_bytes.max(minimum)),
                default_bytes: Some((source_size_bytes / 4).max(minimum)),
                step_bytes: Some((source_size_bytes / 100).max(1024 * 1024)),
                display_unit: "bytes".to_owned(),
            };
        }
        Self {
            available: false,
            unavailable_reason: Some(if capabilities.available {
                "ESTIMATOR_POLICY_NOT_CALIBRATED".to_owned()
            } else {
                "ENGINE_EXECUTION_CHAIN_NOT_READY".to_owned()
            }),
            minimum_bytes: None,
            maximum_bytes: None,
            default_bytes: None,
            step_bytes: None,
            display_unit: "bytes".to_owned(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct TargetSizeSelection {
    pub target_bytes: u64,
    pub allow_resolution_change: bool,
    pub allow_frame_rate_change: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ManualSelection {
    pub container: Option<String>,
    pub video_codec: Option<String>,
    pub audio_codec: Option<String>,
    pub output_pixel_format: Option<String>,
    pub preserves_hdr: Option<bool>,
}

impl ManualSelection {
    pub fn empty() -> Self {
        Self {
            container: None,
            video_codec: None,
            audio_codec: None,
            output_pixel_format: None,
            preserves_hdr: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct PresetSelection {
    pub preset_id: PresetId,
    pub overrides: ManualSelection,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "mode", content = "selection", rename_all = "snake_case")]
pub enum RecalculateSelection {
    Preset(PresetSelection),
    CustomTargetSize(TargetSizeSelection),
    Manual(ManualSelection),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum SelectionSource {
    Manual,
    Preset,
    CustomTargetSize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ResolvedConfiguration {
    pub selection_source: SelectionSource,
    pub selected_preset: Option<PresetId>,
    pub execution_chain_id: ExecutionChainId,
    pub container: String,
    pub video_codec: Option<String>,
    pub video_profile: Option<String>,
    pub audio_codec: Option<String>,
    pub video_encoder_backend: Option<BackendId>,
    pub audio_encoder_backend: Option<BackendId>,
    pub processors: Vec<ProcessorSelection>,
    pub muxer_backend: BackendId,
    pub output_pixel_format: Option<String>,
    pub output_bit_depth: Option<u8>,
    pub output_hdr_mode: HdrMode,
    pub target_size: Option<TargetBitrateSolution>,
    pub target_video_bitrate: Option<BitRateBps>,
    pub target_audio_bitrate: Option<BitRateBps>,
    pub preserves_hdr: bool,
    pub requires_tone_mapping: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct DecisionConflict {
    pub code: EngineErrorCode,
    pub field: Option<String>,
    pub message: String,
}

#[derive(Default)]
pub struct DecisionService;

impl DecisionService {
    pub fn resolve_selection(
        &self,
        selection: &RecalculateSelection,
        requirements: &InputMediaRequirements,
        task_mode: TaskMode,
        capabilities: &CapabilitySet,
        estimator: Option<(&dyn SizeEstimator, &EstimatorPolicy)>,
    ) -> std::result::Result<ResolvedConfiguration, DecisionConflict> {
        if !capabilities.available {
            return Err(conflict(
                ENGINE_EXECUTION_CHAIN_NOT_READY,
                None,
                "FrameLean has no execution-ready media chain",
            ));
        }
        let empty_manual = ManualSelection::empty();
        let (source, preset, manual, target) = match selection {
            RecalculateSelection::Manual(value) => (SelectionSource::Manual, None, value, None),
            RecalculateSelection::Preset(value) => {
                let Some(policy) = preset_policies()
                    .into_iter()
                    .find(|policy| policy.id == value.preset_id)
                else {
                    return Err(conflict(
                        EngineErrorCode::PresetNotApplicable,
                        Some("preset_id"),
                        "unknown preset",
                    ));
                };
                if !policy.applicable_task_modes.contains(&task_mode) {
                    return Err(conflict(
                        EngineErrorCode::PresetNotApplicable,
                        Some("preset_id"),
                        "preset is not applicable",
                    ));
                }
                if requirements_have_hdr(requirements) && !policy.preserve_hdr {
                    return Err(conflict(
                        EngineErrorCode::PresetNotApplicable,
                        Some("preset_id"),
                        "preset cannot preserve HDR input",
                    ));
                }
                (
                    SelectionSource::Preset,
                    Some(policy),
                    &value.overrides,
                    None,
                )
            }
            RecalculateSelection::CustomTargetSize(value) => (
                SelectionSource::CustomTargetSize,
                None,
                &empty_manual,
                Some(value),
            ),
        };
        let mut candidates: Vec<_> = capabilities
            .execution_chains
            .iter()
            .filter(|chain| {
                preset
                    .as_ref()
                    .is_none_or(|policy| preset_matches_candidate(policy, requirements, chain))
            })
            .collect();
        if candidates.is_empty() && preset.is_some() {
            return Err(conflict(
                EngineErrorCode::PresetNotApplicable,
                Some("preset_id"),
                "preset does not match an execution chain",
            ));
        }
        candidates.retain(|chain| manual_matches(manual, chain));
        if let Some(policy) = &preset {
            candidates.sort_by_key(|chain| preset_rank(policy, chain));
        }
        let Some(chain) = candidates.first().copied() else {
            return Err(conflict(
                EngineErrorCode::MediaCapabilityIncompatible,
                None,
                "selection does not match a complete execution chain",
            ));
        };
        let target_size = if let Some(target) = target {
            if target.target_bytes == 0 {
                return Err(conflict(
                    EngineErrorCode::TargetSizeUnachievable,
                    Some("target_bytes"),
                    "target size must be greater than zero",
                ));
            }
            let Some((estimator, policy)) = estimator
                .filter(|(_, policy)| policy.calibrated_container_overhead_bytes.is_some())
            else {
                return Err(conflict(
                    EngineErrorCode::TargetSizeUnachievable,
                    Some("target_bytes"),
                    "estimator policy is not calibrated",
                ));
            };
            let Some(duration) = requirements.duration_microseconds.filter(|v| *v > 0) else {
                return Err(conflict(
                    EngineErrorCode::TargetSizeUnachievable,
                    Some("target_bytes"),
                    "media duration is unavailable",
                ));
            };
            Some(
                estimator
                    .solve_target_bitrate(
                        target.target_bytes,
                        duration.div_ceil(1_000_000),
                        None,
                        policy,
                    )
                    .map_err(|error| {
                        conflict(
                            EngineErrorCode::TargetSizeUnachievable,
                            Some("target_bytes"),
                            error.message(),
                        )
                    })?,
            )
        } else {
            None
        };
        let (target_video_bitrate, target_audio_bitrate) = if let Some(policy) = preset.as_ref() {
            preset_bitrates(policy, requirements, chain)
        } else if let Some(solution) = target_size.as_ref() {
            (solution.video_bitrate, solution.audio_bitrate)
        } else {
            (None, None)
        };
        Ok(ResolvedConfiguration {
            selection_source: source,
            selected_preset: preset.map(|v| v.id),
            execution_chain_id: chain.id.clone(),
            container: chain.output_container.clone(),
            video_codec: chain.output_video_codec.clone(),
            video_profile: chain.output_video_profile.clone(),
            audio_codec: chain.output_audio_codec.clone(),
            video_encoder_backend: chain.video_encoder.clone(),
            audio_encoder_backend: chain.audio_encoder.clone(),
            processors: chain.processors.clone(),
            muxer_backend: chain.muxer.clone(),
            output_pixel_format: chain.output_pixel_format.clone(),
            output_bit_depth: chain.output_bit_depth,
            output_hdr_mode: chain.output_hdr_mode,
            target_size,
            target_video_bitrate,
            target_audio_bitrate,
            preserves_hdr: chain.preserves_hdr,
            requires_tone_mapping: chain.requires_tone_mapping,
        })
    }
}

fn manual_matches(value: &ManualSelection, chain: &ExecutionChainCandidate) -> bool {
    value
        .container
        .as_ref()
        .is_none_or(|v| v == &chain.output_container)
        && value
            .video_codec
            .as_ref()
            .is_none_or(|v| Some(v) == chain.output_video_codec.as_ref())
        && value
            .audio_codec
            .as_ref()
            .is_none_or(|v| Some(v) == chain.output_audio_codec.as_ref())
        && value
            .output_pixel_format
            .as_ref()
            .is_none_or(|v| Some(v) == chain.output_pixel_format.as_ref())
        && value.preserves_hdr.is_none_or(|v| v == chain.preserves_hdr)
}

fn preset_rank(
    policy: &PresetPolicy,
    chain: &ExecutionChainCandidate,
) -> (usize, usize, usize, String) {
    (
        policy
            .preferred_containers
            .iter()
            .position(|v| v == &chain.output_container)
            .unwrap_or(usize::MAX),
        chain
            .output_video_codec
            .as_ref()
            .and_then(|v| policy.preferred_video_codecs.iter().position(|p| p == v))
            .unwrap_or(usize::MAX),
        chain
            .output_audio_codec
            .as_ref()
            .and_then(|v| policy.preferred_audio_codecs.iter().position(|p| p == v))
            .unwrap_or(usize::MAX),
        chain.id.as_str().to_owned(),
    )
}

fn preset_matches_candidate(
    policy: &PresetPolicy,
    requirements: &InputMediaRequirements,
    chain: &ExecutionChainCandidate,
) -> bool {
    if !policy
        .preferred_containers
        .contains(&chain.output_container)
        || chain
            .output_video_codec
            .as_ref()
            .is_some_and(|codec| !policy.preferred_video_codecs.contains(codec))
        || chain
            .output_audio_codec
            .as_ref()
            .is_some_and(|codec| !policy.preferred_audio_codecs.contains(codec))
    {
        return false;
    }
    if requirements_have_hdr(requirements) {
        policy.preserve_hdr
            && chain.preserves_hdr
            && chain.output_video_codec.as_deref() == Some("hevc")
            && chain.output_video_profile.as_deref() == Some("main10")
            && chain.output_hdr_mode != HdrMode::Sdr
    } else {
        true
    }
}

fn preset_bitrates(
    policy: &PresetPolicy,
    requirements: &InputMediaRequirements,
    chain: &ExecutionChainCandidate,
) -> (Option<BitRateBps>, Option<BitRateBps>) {
    let height = requirements
        .video_streams
        .first()
        .map(|value| value.height)
        .or_else(|| requirements.image.as_ref().map(|value| value.height));
    let video = height.and_then(|height| {
        policy
            .video_bitrate_ceilings
            .iter()
            .find(|ceiling| height >= ceiling.minimum_height)
            .map(|ceiling| {
                let value = if chain.output_video_codec.as_deref() == Some("hevc") {
                    ceiling.h264_bps.saturating_mul(72) / 100
                } else {
                    ceiling.h264_bps
                };
                BitRateBps::new(value)
            })
    });
    let audio = chain
        .output_audio_codec
        .as_ref()
        .map(|_| BitRateBps::new(policy.audio_bitrate_bps));
    (video, audio)
}

fn conflict(
    code: EngineErrorCode,
    field: Option<&str>,
    message: impl Into<String>,
) -> DecisionConflict {
    DecisionConflict {
        code,
        field: field.map(str::to_owned),
        message: message.into(),
    }
}

fn requirements_have_hdr(requirements: &InputMediaRequirements) -> bool {
    requirements
        .video_streams
        .iter()
        .any(|value| !matches!(value.hdr_mode, HdrMode::Sdr | HdrMode::Unknown))
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct EstimatorPolicy {
    pub id: EstimatorPolicyId,
    pub version: u32,
    pub calibrated_container_overhead_bytes: Option<u64>,
    pub calibration_sample_count: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum EstimateConfidence {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct SizeEstimate {
    pub expected_bytes: u64,
    pub minimum_bytes: Option<u64>,
    pub maximum_bytes: Option<u64>,
    pub recommended_video_bitrate: Option<BitRateBps>,
    pub recommended_audio_bitrate: Option<BitRateBps>,
    pub confidence: EstimateConfidence,
    pub basis: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum EstimateMediaKind {
    Video,
    Audio,
    StaticImage,
    AnimatedImage,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum EstimateRequest {
    TimedStreams {
        media_kind: EstimateMediaKind,
        duration_seconds: u64,
        stream_bitrates: Vec<BitRateBps>,
    },
    StaticImage {
        format: String,
        width: u32,
        height: u32,
        quality: Option<u16>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct TargetBitrateSolution {
    pub target_bytes: u64,
    pub total_bitrate: BitRateBps,
    pub video_bitrate: Option<BitRateBps>,
    pub audio_bitrate: Option<BitRateBps>,
    pub confidence: EstimateConfidence,
}

pub trait SizeEstimator: Send + Sync {
    fn estimate(&self, request: &EstimateRequest, policy: &EstimatorPolicy)
    -> Result<SizeEstimate>;

    fn estimate_bitrate_output(
        &self,
        duration_seconds: u64,
        stream_bitrates: &[BitRateBps],
        policy: &EstimatorPolicy,
    ) -> Result<SizeEstimate> {
        self.estimate(
            &EstimateRequest::TimedStreams {
                media_kind: EstimateMediaKind::Video,
                duration_seconds,
                stream_bitrates: stream_bitrates.to_vec(),
            },
            policy,
        )
    }

    fn solve_target_bitrate(
        &self,
        target_bytes: u64,
        duration_seconds: u64,
        audio_bitrate: Option<BitRateBps>,
        policy: &EstimatorPolicy,
    ) -> Result<TargetBitrateSolution>;
}

#[derive(Default)]
pub struct DeterministicSizeEstimator;

impl SizeEstimator for DeterministicSizeEstimator {
    fn estimate(
        &self,
        request: &EstimateRequest,
        policy: &EstimatorPolicy,
    ) -> Result<SizeEstimate> {
        let EstimateRequest::TimedStreams {
            media_kind,
            duration_seconds,
            stream_bitrates,
        } = request
        else {
            return Err(EngineError::new(
                ErrorKind::Estimation,
                "static image estimator policy is not calibrated",
            ));
        };
        if *media_kind == EstimateMediaKind::StaticImage {
            return Err(EngineError::new(
                ErrorKind::Estimation,
                "static image estimator requires an image calibration curve",
            ));
        }
        if *duration_seconds == 0 {
            return Err(EngineError::new(
                ErrorKind::Estimation,
                "duration must be greater than zero",
            ));
        }
        let overhead = policy.calibrated_container_overhead_bytes.ok_or_else(|| {
            EngineError::new(
                ErrorKind::Estimation,
                "container overhead policy is not calibrated",
            )
        })?;
        let bits_per_second = stream_bitrates
            .iter()
            .try_fold(0_u64, |sum, value| sum.checked_add(value.value()))
            .ok_or_else(|| EngineError::new(ErrorKind::Estimation, "bitrate overflow"))?;
        let payload = bits_per_second
            .checked_mul(*duration_seconds)
            .and_then(|value| value.checked_add(7))
            .map(|value| value / 8)
            .ok_or_else(|| EngineError::new(ErrorKind::Estimation, "size overflow"))?;
        Ok(SizeEstimate {
            expected_bytes: payload.saturating_add(overhead),
            minimum_bytes: None,
            maximum_bytes: None,
            recommended_video_bitrate: None,
            recommended_audio_bitrate: None,
            confidence: if policy.calibration_sample_count == 0 {
                EstimateConfidence::Low
            } else {
                EstimateConfidence::Medium
            },
            basis: vec![format!("estimator_policy:{}", policy.id.as_str())],
        })
    }

    fn solve_target_bitrate(
        &self,
        target_bytes: u64,
        duration_seconds: u64,
        audio_bitrate: Option<BitRateBps>,
        policy: &EstimatorPolicy,
    ) -> Result<TargetBitrateSolution> {
        if target_bytes == 0 || duration_seconds == 0 {
            return Err(EngineError::new(
                ErrorKind::Estimation,
                "target bytes and duration must be greater than zero",
            ));
        }
        let overhead = policy.calibrated_container_overhead_bytes.ok_or_else(|| {
            EngineError::new(
                ErrorKind::Estimation,
                "container overhead policy is not calibrated",
            )
        })?;
        let payload_bytes = target_bytes.checked_sub(overhead).ok_or_else(|| {
            EngineError::new(
                ErrorKind::Estimation,
                "TARGET_SIZE_UNACHIEVABLE: target is below calibrated container overhead",
            )
        })?;
        let total_bitrate = payload_bytes
            .checked_mul(8)
            .map(|bits| bits / duration_seconds)
            .ok_or_else(|| EngineError::new(ErrorKind::Estimation, "bitrate overflow"))?;
        let audio = audio_bitrate.map(BitRateBps::value).unwrap_or(0);
        let video = total_bitrate.checked_sub(audio).ok_or_else(|| {
            EngineError::new(
                ErrorKind::Estimation,
                "TARGET_SIZE_UNACHIEVABLE: audio budget exceeds target payload",
            )
        })?;
        Ok(TargetBitrateSolution {
            target_bytes,
            total_bitrate: BitRateBps::new(total_bitrate),
            video_bitrate: Some(BitRateBps::new(video)),
            audio_bitrate,
            confidence: if policy.calibration_sample_count == 0 {
                EstimateConfidence::Low
            } else {
                EstimateConfidence::Medium
            },
        })
    }
}

#[cfg(test)]
mod tests {
    use framelean_analysis::{
        AudioStreamInfo, HdrInfo, MediaAnalysis, MediaDescriptor, MediaKind, SourceId,
        VideoStreamInfo,
    };
    use framelean_core::{FileSizeBytes, ObservationStatus, Observed};
    use framelean_environment::{CpuInfo, EnvironmentSnapshot};
    use framelean_media::MediaDuration;
    use framelean_media::capability::{
        BackendAvailability, BackendEnvironmentRequirements, DemuxerCapability, EncoderCapability,
        MuxerCapability, NativeSupportStatus, ProcessorCapability,
    };

    use super::*;

    fn environment() -> EnvironmentSnapshot {
        EnvironmentSnapshot {
            observed_at_unix_ms: 1,
            operating_system: Observed::detected("test".to_owned(), "test"),
            os_version: Observed::detected("1".to_owned(), "test"),
            device_model: unavailable(),
            cpu: CpuInfo {
                model: Observed::detected("test".to_owned(), "test"),
                architecture: "test-arch".to_owned(),
                physical_cores: Observed::detected(1, "test"),
                logical_cores: 1,
            },
            total_memory: framelean_core::MemoryBytes::new(1),
            gpus: Observed::detected(Vec::new(), "test"),
            native_media_frameworks: Vec::new(),
        }
    }

    fn media() -> MediaAnalysis {
        MediaAnalysis {
            status: framelean_analysis::MediaAnalysisStatus::Complete,
            source_id: SourceId::new("source-1").unwrap(),
            file_name: "input.mp4".to_owned(),
            display_path: None,
            file_size: FileSizeBytes::new(1),
            kind: MediaKind::Video,
            format: Observed::detected("mp4".to_owned(), "fixture"),
            duration: Observed::detected(MediaDuration::new(10, 1).unwrap(), "fixture"),
            descriptor: MediaDescriptor::Video {
                streams: vec![MediaStreamDescriptor::Video(Box::new(VideoStreamInfo {
                    stream_index: 0,
                    codec: "h264".to_owned(),
                    profile: Observed::detected("main".to_owned(), "fixture"),
                    width: 1920,
                    height: 1080,
                    frame_rate: Observed::detected(
                        framelean_media::Rational::new(30, 1).unwrap(),
                        "fixture",
                    ),
                    frame_count: Observed::detected(300, "fixture"),
                    time_base: framelean_media::Rational::new(1, 90_000).unwrap(),
                    bit_depth: Observed::detected(8, "fixture"),
                    pixel_format: Observed::detected("yuv420p".to_owned(), "fixture"),
                    hdr: HdrInfo {
                        color_range: Observed::detected("tv".to_owned(), "fixture"),
                        color_space: Observed::detected("bt709".to_owned(), "fixture"),
                        color_transfer: Observed::detected("bt709".to_owned(), "fixture"),
                        color_primaries: Observed::detected("bt709".to_owned(), "fixture"),
                    },
                    bitrate: unavailable(),
                }))],
            },
            provider: "fixture".to_owned(),
            provider_version: None,
            warnings: Vec::new(),
        }
    }

    fn unavailable<T>() -> Observed<T> {
        Observed::with_status(ObservationStatus::NotProbed, "fixture")
    }

    fn descriptor(id: &str, capability: BackendCapability, ready: bool) -> BackendDescriptor {
        BackendDescriptor {
            id: BackendId::new(id).unwrap(),
            provider: "fixture".to_owned(),
            version: None,
            availability: if ready {
                BackendAvailability::execution_ready(NativeSupportStatus::NativeInitializable)
            } else {
                BackendAvailability::native_only(NativeSupportStatus::NativeDiscovered)
            },
            environment: BackendEnvironmentRequirements::unrestricted(),
            capability,
            source: "fixture".to_owned(),
        }
    }

    fn complete_catalog(ready: bool) -> BackendCatalog {
        BackendCatalog::from_backends(vec![
            descriptor(
                "demux",
                BackendCapability::Demuxer(DemuxerCapability {
                    input_formats: vec!["mp4".to_owned()],
                    stream_types: vec![StreamKind::Video],
                    codec_restrictions: CapabilityConstraint::Restricted(vec!["h264".to_owned()]),
                    supports_multiple_streams: Observed::detected(true, "fixture"),
                    requires_seek: Observed::detected(true, "fixture"),
                    supports_custom_io: Observed::detected(true, "fixture"),
                }),
                ready,
            ),
            descriptor(
                "decoder",
                BackendCapability::Decoder(DecoderCapability {
                    stream_type: StreamKind::Video,
                    codecs: vec!["h264".to_owned()],
                    profiles: CapabilityConstraint::Restricted(vec!["main".to_owned()]),
                    pixel_or_sample_formats: CapabilityConstraint::Restricted(vec![
                        "yuv420p".to_owned(),
                    ]),
                    bit_depths: CapabilityConstraint::Restricted(vec![8]),
                }),
                ready,
            ),
            descriptor(
                "encoder",
                BackendCapability::Encoder(EncoderCapability {
                    stream_type: StreamKind::Video,
                    codecs: vec!["h264".to_owned()],
                    profiles: CapabilityConstraint::Restricted(vec!["main".to_owned()]),
                    pixel_or_sample_formats: CapabilityConstraint::Restricted(vec![
                        "yuv420p".to_owned(),
                    ]),
                    bit_depths: CapabilityConstraint::Restricted(vec![8]),
                    hdr_modes: CapabilityConstraint::Restricted(vec![HdrMode::Sdr]),
                    rate_control_modes: CapabilityConstraint::Restricted(vec![
                        "bitrate".to_owned(),
                    ]),
                }),
                ready,
            ),
            descriptor(
                "muxer",
                BackendCapability::Muxer(MuxerCapability {
                    output_formats: vec!["mp4".to_owned()],
                    video_codecs: vec!["h264".to_owned()],
                    audio_codecs: Vec::new(),
                    supports_subtitles: Observed::detected(false, "fixture"),
                    supports_data: Observed::detected(false, "fixture"),
                    supports_attachments: Observed::detected(false, "fixture"),
                    supports_multiple_streams: Observed::detected(true, "fixture"),
                    codec_combinations: CapabilityConstraint::Restricted(vec![
                        MuxerCodecCombination {
                            video_codec: Some("h264".to_owned()),
                            audio_codec: None,
                        },
                    ]),
                    requires_seek: Observed::detected(true, "fixture"),
                }),
                ready,
            ),
        ])
        .unwrap()
    }

    fn requirements() -> InputMediaRequirements {
        InputMediaRequirements::from_media_analysis(&media())
    }

    #[test]
    fn requirements_extract_profile_pixel_format_and_bit_depth() {
        let requirements = requirements();
        let video = &requirements.video_streams[0];
        assert_eq!(video.profile.as_deref(), Some("main"));
        assert_eq!(video.pixel_format.as_deref(), Some("yuv420p"));
        assert_eq!(video.bit_depth, Some(8));
        assert_eq!(video.hdr_mode, HdrMode::Sdr);
    }

    #[test]
    fn requirements_extract_audio_properties() {
        let mut media = media();
        media.kind = MediaKind::Audio;
        media.descriptor = MediaDescriptor::Audio {
            streams: vec![MediaStreamDescriptor::Audio(Box::new(AudioStreamInfo {
                stream_index: 2,
                codec: "aac".to_owned(),
                profile: Observed::detected("lc".to_owned(), "fixture"),
                sample_rate_hz: Observed::detected(48_000, "fixture"),
                channel_count: Observed::detected(2, "fixture"),
                channel_layout: Observed::detected("stereo".to_owned(), "fixture"),
                sample_format: Observed::detected("fltp".to_owned(), "fixture"),
                bitrate: unavailable(),
                duration: Observed::detected(MediaDuration::new(10, 1).unwrap(), "fixture"),
            }))],
        };
        let requirements = InputMediaRequirements::from_media_analysis(&media);
        let audio = &requirements.audio_streams[0];
        assert_eq!(audio.stream_index, 2);
        assert_eq!(audio.profile.as_deref(), Some("lc"));
        assert_eq!(audio.sample_rate_hz, Some(48_000));
        assert_eq!(audio.channel_count, Some(2));
        assert_eq!(audio.channel_layout.as_deref(), Some("stereo"));
        assert_eq!(audio.sample_format.as_deref(), Some("fltp"));
    }

    #[test]
    fn native_only_catalog_is_diagnostic_not_selectable() {
        let capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements(),
                TaskMode::VideoCompress,
                &environment(),
                &complete_catalog(false),
            )
            .unwrap();
        assert!(!capabilities.available);
        assert_eq!(
            capabilities.exclusions[0].code,
            ENGINE_EXECUTION_CHAIN_NOT_READY
        );
    }

    #[test]
    fn complete_ready_chain_is_atomic_and_recommendable() {
        let requirements = requirements();
        let capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &complete_catalog(true),
            )
            .unwrap();
        assert_eq!(capabilities.containers, vec!["mp4"]);
        assert_eq!(capabilities.execution_chains.len(), 1);
        let recommendation =
            DefaultRecommendationEngine.recommend(&requirements, &capabilities, None);
        assert!(validate_recommendation(&recommendation, &capabilities));
    }

    #[test]
    fn resolver_rejects_backend_for_another_operating_system() {
        let mut catalog = complete_catalog(true);
        catalog.backends[0].environment.operating_systems =
            CapabilityConstraint::Restricted(vec!["other".to_owned()]);
        let capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements(),
                TaskMode::VideoCompress,
                &environment(),
                &catalog,
            )
            .unwrap();
        assert!(!capabilities.available);
    }

    #[test]
    fn product_presets_use_client_authority_names() {
        let requirements = requirements();
        let capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &complete_catalog(true),
            )
            .unwrap();
        let ids: Vec<_> = fixed_presets(&requirements, TaskMode::VideoCompress, &capabilities)
            .into_iter()
            .map(|preset| preset.id.as_str().to_owned())
            .collect();
        assert_eq!(ids, ["clear", "balanced", "chat", "compact"]);
    }

    #[test]
    fn manual_selection_resolves_one_complete_candidate() {
        let requirements = requirements();
        let capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &complete_catalog(true),
            )
            .unwrap();
        let resolved = DecisionService
            .resolve_selection(
                &RecalculateSelection::Manual(ManualSelection {
                    container: Some("mp4".to_owned()),
                    video_codec: Some("h264".to_owned()),
                    audio_codec: None,
                    output_pixel_format: Some("yuv420p".to_owned()),
                    preserves_hdr: Some(false),
                }),
                &requirements,
                TaskMode::VideoCompress,
                &capabilities,
                None,
            )
            .unwrap();
        assert_eq!(
            resolved.execution_chain_id,
            capabilities.execution_chains[0].id
        );
    }

    #[test]
    fn output_profile_is_selected_from_encoder_not_input_profile() {
        let mut requirements = requirements();
        requirements.video_streams[0].profile = Some("high".to_owned());
        let mut catalog = complete_catalog(true);
        let BackendCapability::Decoder(decoder) = &mut catalog.backends[1].capability else {
            unreachable!();
        };
        decoder.profiles = CapabilityConstraint::Restricted(vec!["high".to_owned()]);
        let BackendCapability::Encoder(encoder) = &mut catalog.backends[2].capability else {
            unreachable!();
        };
        encoder.codecs = vec!["hevc".to_owned()];
        encoder.profiles = CapabilityConstraint::Restricted(vec!["main".to_owned()]);
        let BackendCapability::Muxer(muxer) = &mut catalog.backends[3].capability else {
            unreachable!();
        };
        muxer.video_codecs = vec!["hevc".to_owned()];
        muxer.codec_combinations = CapabilityConstraint::Restricted(vec![MuxerCodecCombination {
            video_codec: Some("hevc".to_owned()),
            audio_codec: None,
        }]);

        let capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &catalog,
            )
            .unwrap();
        assert_eq!(capabilities.execution_chains.len(), 1);
        assert_eq!(
            capabilities.execution_chains[0]
                .output_video_profile
                .as_deref(),
            Some("main")
        );
        let recommendation =
            DefaultRecommendationEngine.recommend(&requirements, &capabilities, None);
        assert_eq!(
            recommendation
                .configuration
                .unwrap()
                .video_profile
                .as_deref(),
            Some("main")
        );
    }

    #[test]
    fn chat_preset_rejects_non_h264_candidate() {
        let requirements = requirements();
        let mut capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &complete_catalog(true),
            )
            .unwrap();
        capabilities.execution_chains[0].output_video_codec = Some("hevc".to_owned());
        capabilities.execution_chains[0].output_video_profile = Some("main".to_owned());

        let chat = fixed_presets(&requirements, TaskMode::VideoCompress, &capabilities)
            .into_iter()
            .find(|preset| preset.id.as_str() == "chat")
            .unwrap();
        assert!(!chat.applicable);
        let conflict = DecisionService
            .resolve_selection(
                &RecalculateSelection::Preset(PresetSelection {
                    preset_id: PresetId::new("chat").unwrap(),
                    overrides: ManualSelection::empty(),
                }),
                &requirements,
                TaskMode::VideoCompress,
                &capabilities,
                None,
            )
            .unwrap_err();
        assert_eq!(conflict.code, EngineErrorCode::PresetNotApplicable);
    }

    #[test]
    fn hdr_input_requires_a_compatible_hdr_chain_or_tone_mapper() {
        let mut requirements = requirements();
        let video = &mut requirements.video_streams[0];
        video.profile = Some("main10".to_owned());
        video.pixel_format = Some("p010le".to_owned());
        video.bit_depth = Some(10);
        video.hdr_mode = HdrMode::Hdr10;
        let mut catalog = complete_catalog(true);
        let BackendCapability::Decoder(decoder) = &mut catalog.backends[1].capability else {
            unreachable!();
        };
        decoder.profiles = CapabilityConstraint::Restricted(vec!["main10".to_owned()]);
        decoder.pixel_or_sample_formats =
            CapabilityConstraint::Restricted(vec!["p010le".to_owned()]);
        decoder.bit_depths = CapabilityConstraint::Restricted(vec![10]);

        let unavailable = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &catalog,
            )
            .unwrap();
        assert!(!unavailable.available);

        catalog.backends.push(descriptor(
            "tone-map",
            BackendCapability::Processor(ProcessorCapability {
                stream_type: StreamKind::Video,
                input_formats: CapabilityConstraint::Restricted(vec!["p010le".to_owned()]),
                output_formats: CapabilityConstraint::Restricted(vec!["yuv420p".to_owned()]),
                bit_depths: CapabilityConstraint::Restricted(vec![10, 8]),
                hdr_operations: CapabilityConstraint::Restricted(vec![HdrOperation::ToneMapToSdr]),
                operations: vec!["tone_map_to_sdr".to_owned()],
            }),
            true,
        ));
        let available = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &catalog,
            )
            .unwrap();
        assert!(available.available);
        assert!(available.execution_chains.iter().all(|chain| {
            chain.requires_tone_mapping
                && chain
                    .processors
                    .iter()
                    .any(|processor| processor.operation == "tone_map_to_sdr")
        }));
    }

    #[test]
    fn manual_fields_from_different_candidates_are_rejected() {
        let requirements = requirements();
        let mut capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &complete_catalog(true),
            )
            .unwrap();
        let mut second = capabilities.execution_chains[0].clone();
        second.id = ExecutionChainId("chain-second".to_owned());
        second.output_container = "mkv".to_owned();
        second.output_video_codec = Some("hevc".to_owned());
        capabilities.execution_chains.push(second);

        let conflict = DecisionService
            .resolve_selection(
                &RecalculateSelection::Manual(ManualSelection {
                    container: Some("mp4".to_owned()),
                    video_codec: Some("hevc".to_owned()),
                    audio_codec: None,
                    output_pixel_format: None,
                    preserves_hdr: None,
                }),
                &requirements,
                TaskMode::VideoCompress,
                &capabilities,
                None,
            )
            .unwrap_err();
        assert_eq!(conflict.code, EngineErrorCode::MediaCapabilityIncompatible);
    }

    #[test]
    fn preset_does_not_override_explicit_incompatible_fields() {
        let requirements = requirements();
        let capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &complete_catalog(true),
            )
            .unwrap();
        let conflict = DecisionService
            .resolve_selection(
                &RecalculateSelection::Preset(PresetSelection {
                    preset_id: PresetId::new("chat").unwrap(),
                    overrides: ManualSelection {
                        container: None,
                        video_codec: Some("hevc".to_owned()),
                        audio_codec: None,
                        output_pixel_format: None,
                        preserves_hdr: None,
                    },
                }),
                &requirements,
                TaskMode::VideoCompress,
                &capabilities,
                None,
            )
            .unwrap_err();
        assert_eq!(conflict.code, EngineErrorCode::MediaCapabilityIncompatible);
    }

    #[test]
    fn preset_and_calibrated_target_size_resolve_complete_candidates() {
        let requirements = requirements();
        let capabilities = DefaultCapabilityResolver
            .resolve(
                &requirements,
                TaskMode::VideoCompress,
                &environment(),
                &complete_catalog(true),
            )
            .unwrap();
        let preset = DecisionService
            .resolve_selection(
                &RecalculateSelection::Preset(PresetSelection {
                    preset_id: PresetId::new("chat").unwrap(),
                    overrides: ManualSelection::empty(),
                }),
                &requirements,
                TaskMode::VideoCompress,
                &capabilities,
                None,
            )
            .unwrap();
        assert_eq!(preset.selection_source, SelectionSource::Preset);
        assert_eq!(preset.selected_preset.unwrap().as_str(), "chat");
        assert_eq!(preset.target_video_bitrate.unwrap().value(), 3_000_000);

        let policy = EstimatorPolicy {
            id: EstimatorPolicyId::new("calibrated").unwrap(),
            version: 1,
            calibrated_container_overhead_bytes: Some(1_000),
            calibration_sample_count: 1,
        };
        let options =
            CustomTargetSizeOptions::from_context(&capabilities, Some(&policy), 100_000_000);
        assert!(options.available);
        let target = DecisionService
            .resolve_selection(
                &RecalculateSelection::CustomTargetSize(TargetSizeSelection {
                    target_bytes: 101_000,
                    allow_resolution_change: false,
                    allow_frame_rate_change: false,
                }),
                &requirements,
                TaskMode::VideoCompress,
                &capabilities,
                Some((&DeterministicSizeEstimator, &policy)),
            )
            .unwrap();
        assert_eq!(target.selection_source, SelectionSource::CustomTargetSize);
        assert_eq!(target.target_size.unwrap().target_bytes, 101_000);
    }

    #[test]
    fn estimator_requires_calibrated_container_overhead() {
        let policy = EstimatorPolicy {
            id: EstimatorPolicyId::new("policy-1").unwrap(),
            version: 1,
            calibrated_container_overhead_bytes: None,
            calibration_sample_count: 0,
        };
        assert!(
            DeterministicSizeEstimator
                .estimate_bitrate_output(10, &[BitRateBps::new(1_000)], &policy)
                .is_err()
        );
    }

    #[test]
    fn target_solver_never_silently_raises_explicit_target() {
        let policy = EstimatorPolicy {
            id: EstimatorPolicyId::new("policy-1").unwrap(),
            version: 1,
            calibrated_container_overhead_bytes: Some(1_000),
            calibration_sample_count: 1,
        };
        let solution = DeterministicSizeEstimator
            .solve_target_bitrate(101_000, 10, Some(BitRateBps::new(10_000)), &policy)
            .unwrap();
        assert_eq!(solution.target_bytes, 101_000);
        assert_eq!(solution.total_bitrate.value(), 80_000);
        assert_eq!(solution.video_bitrate.unwrap().value(), 70_000);
    }
}
