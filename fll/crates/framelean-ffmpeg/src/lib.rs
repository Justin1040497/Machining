use std::ffi::{CStr, CString, c_void};
use std::path::Path;
use std::ptr;

use framelean_analysis::{
    AnalyzedMedia, AnimationInfo, AudioStreamInfo, DataStreamInfo, HdrInfo, ImageInfo,
    MediaAnalysis, MediaAnalyzeRequest, MediaAnalyzer, MediaDescriptor, MediaKind,
    MediaStreamDescriptor, SourceFingerprint, SubtitleStreamInfo, VideoStreamInfo,
};
use framelean_core::{
    BackendId, BitRateBps, EngineError, ErrorKind, FileSizeBytes, ObservationStatus, Observed,
    Result,
};
use framelean_media::capability::{
    BackendAvailability, BackendCapability, BackendCatalog, BackendCatalogProvider,
    BackendDescriptor, BackendEnvironmentRequirements, CapabilityConstraint, DecoderCapability,
    DemuxerCapability, EncoderCapability, HdrMode, MuxerCapability, NativeSupportStatus,
    StreamKind,
};
use framelean_media::{MediaDuration, Rational};
use rusty_ffmpeg::ffi;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LibraryVersions {
    pub avformat: u32,
    pub avcodec: u32,
    pub avutil: u32,
}

pub fn library_versions() -> Result<LibraryVersions> {
    // SAFETY: version functions take no pointers and have no ownership requirements.
    Ok(unsafe {
        LibraryVersions {
            avformat: ffi::avformat_version(),
            avcodec: ffi::avcodec_version(),
            avutil: ffi::avutil_version(),
        }
    })
}

#[derive(Default)]
pub struct FfmpegAdapter;

impl FfmpegAdapter {
    pub fn new() -> Result<Self> {
        let versions = library_versions()?;
        if versions.avformat == 0 || versions.avcodec == 0 || versions.avutil == 0 {
            return Err(EngineError::with_code(
                ErrorKind::NativeLibrary,
                framelean_core::EngineErrorCode::NativeLibraryUnavailable,
                "FFmpeg libraries returned an invalid version",
            ));
        }
        Ok(Self)
    }
}

struct InputContext(*mut ffi::AVFormatContext);

impl InputContext {
    fn open(path: &Path) -> Result<Self> {
        let path = path_c_string(path)?;
        let mut context = ptr::null_mut();
        // SAFETY: context is an out pointer initialized to null; path remains alive for the call.
        let result = unsafe {
            ffi::avformat_open_input(&mut context, path.as_ptr(), ptr::null(), ptr::null_mut())
        };
        if result < 0 {
            return Err(media_native_error(
                framelean_core::EngineErrorCode::MediaInvalidFormat,
                "failed to open media input",
                result,
            ));
        }
        // SAFETY: avformat_open_input initialized context on success.
        let result = unsafe { ffi::avformat_find_stream_info(context, ptr::null_mut()) };
        if result < 0 {
            // SAFETY: context was allocated by avformat_open_input.
            unsafe { ffi::avformat_close_input(&mut context) };
            return Err(media_native_error(
                framelean_core::EngineErrorCode::MediaInfoReadFailed,
                "failed to read media stream information",
                result,
            ));
        }
        Ok(Self(context))
    }

    fn as_ref(&self) -> &ffi::AVFormatContext {
        // SAFETY: InputContext owns a non-null context until Drop.
        unsafe { &*self.0 }
    }
}

impl Drop for InputContext {
    fn drop(&mut self) {
        // SAFETY: context is owned by this guard and closed exactly once.
        unsafe { ffi::avformat_close_input(&mut self.0) };
    }
}

struct Packet(*mut ffi::AVPacket);

impl Packet {
    fn new() -> Result<Self> {
        // SAFETY: allocation has no pointer preconditions and is owned by this guard.
        let packet = unsafe { ffi::av_packet_alloc() };
        if packet.is_null() {
            return Err(EngineError::with_code(
                ErrorKind::Analysis,
                framelean_core::EngineErrorCode::MediaInfoReadFailed,
                "failed to allocate packet for bounded image scan",
            ));
        }
        Ok(Self(packet))
    }
}

impl Drop for Packet {
    fn drop(&mut self) {
        // SAFETY: packet is owned by this guard and freed exactly once.
        unsafe { ffi::av_packet_free(&mut self.0) };
    }
}

fn probe_image_packet_evidence(path: &Path, stream_index: u32) -> Result<Observed<bool>> {
    const MAX_PACKETS: usize = 256;
    const MAX_BYTES: u64 = 16 * 1024 * 1024;

    let input = InputContext::open(path)?;
    let packet = Packet::new()?;
    let mut total_bytes = 0_u64;
    let mut matching_packets = 0_u64;
    for _ in 0..MAX_PACKETS {
        // SAFETY: both pointers are valid and owned for the duration of the call.
        let result = unsafe { ffi::av_read_frame(input.0, packet.0) };
        if result < 0 {
            return Ok(if matching_packets >= 2 {
                Observed::detected(true, "libavformat:bounded_packet_scan")
            } else {
                unavailable("bounded packet scan found insufficient animation evidence")
            });
        }
        // SAFETY: av_read_frame initialized the packet on success.
        let value = unsafe { &*packet.0 };
        total_bytes = total_bytes.saturating_add(value.size.max(0) as u64);
        if value.stream_index == stream_index as i32 {
            matching_packets += 1;
        }
        // SAFETY: packet is initialized and remains allocated for reuse.
        unsafe { ffi::av_packet_unref(packet.0) };
        if matching_packets >= 2 {
            return Ok(Observed::detected(true, "libavformat:bounded_packet_scan"));
        }
        if total_bytes >= MAX_BYTES {
            break;
        }
    }
    Ok(unavailable("bounded packet scan limit reached"))
}

impl MediaAnalyzer for FfmpegAdapter {
    fn analyze(&self, request: &MediaAnalyzeRequest) -> Result<AnalyzedMedia> {
        let path = request.source.path();
        let fingerprint = SourceFingerprint::from_local_file(path)?;

        let input = InputContext::open(path)?;
        let context = input.as_ref();
        let format_names = c_string_list(unsafe {
            context
                .iformat
                .as_ref()
                .map_or(ptr::null(), |format| format.name)
        });
        let format_name = format_names.first().cloned();
        let (mut streams, unrecognized_streams) = map_streams(context)?;
        if streams.is_empty() {
            return Err(EngineError::with_code(
                ErrorKind::Analysis,
                framelean_core::EngineErrorCode::MediaInfoReadFailed,
                "media input contains no recognized streams",
            ));
        }

        let mut duration = if context.duration > 0 {
            Observed::detected(
                MediaDuration::new(context.duration as u64, ffi::AV_TIME_BASE)?,
                "libavformat",
            )
        } else {
            Observed::with_status(
                ObservationStatus::NotProbed,
                "container duration unavailable",
            )
        };
        let animation_format = format_name.as_deref().is_some_and(is_animation_format);
        let packet_animation_evidence = if animation_format
            && let Some(video) = streams.iter_mut().find_map(|stream| match stream {
                MediaStreamDescriptor::Video(value) => Some(value),
                _ => None,
            })
            && video.frame_count.status != ObservationStatus::Detected
        {
            Some(probe_image_packet_evidence(path, video.stream_index)?)
        } else {
            None
        };
        let animation_unknown = animation_format
            && streams
                .iter()
                .find_map(|stream| match stream {
                    MediaStreamDescriptor::Video(value) => Some(&value.frame_count),
                    _ => None,
                })
                .is_some_and(|value| value.status != ObservationStatus::Detected)
            && packet_animation_evidence.is_some();
        let (kind, descriptor) = classify_media(format_name.as_deref(), streams, &duration)?;
        if kind == MediaKind::Image {
            duration = Observed::with_status(
                ObservationStatus::NotApplicable,
                "static images do not have a duration",
            );
        }
        let source_id = fingerprint.source_id()?;
        let file_name = path
            .file_name()
            .map(|value| value.to_string_lossy().into_owned())
            .unwrap_or_else(|| "media".to_owned());

        let warnings = analysis_warnings(
            kind,
            &descriptor,
            &duration,
            unrecognized_streams,
            animation_unknown,
        );
        let status = if warnings.is_empty() {
            framelean_analysis::MediaAnalysisStatus::Complete
        } else {
            framelean_analysis::MediaAnalysisStatus::Partial
        };

        let media = MediaAnalysis {
            status,
            source_id,
            file_name,
            display_path: Some(path.to_string_lossy().into_owned()),
            file_size: FileSizeBytes::new(fingerprint.size_bytes()),
            kind,
            format: format_name.map_or_else(
                || {
                    Observed::with_status(
                        ObservationStatus::Failed,
                        "libavformat did not expose an input format name",
                    )
                },
                |value| Observed::detected(value, "libavformat"),
            ),
            duration,
            descriptor,
            provider: "framelean-ffmpeg".to_owned(),
            provider_version: Some(format_version(library_versions()?.avformat)),
            warnings,
        };
        let completed_fingerprint = SourceFingerprint::from_local_file(path)?;
        if completed_fingerprint != fingerprint {
            return Err(EngineError::with_code(
                ErrorKind::Analysis,
                framelean_core::EngineErrorCode::AnalysisSourceChanged,
                "media source changed during analysis",
            ));
        }
        AnalyzedMedia::new(media, fingerprint)
    }
}

impl BackendCatalogProvider for FfmpegAdapter {
    fn backend_catalog(&self) -> Result<BackendCatalog> {
        let versions = library_versions()?;
        let avformat_version = Some(format_version(versions.avformat));
        let codec_version = Some(format_version(versions.avcodec));
        let mut backends = Vec::new();
        backends.extend(demuxer_backends(avformat_version.clone())?);
        backends.extend(codec_backends(codec_version)?);
        backends.extend(muxer_backends(avformat_version)?);
        BackendCatalog::from_backends(backends)
    }
}

fn map_streams(context: &ffi::AVFormatContext) -> Result<(Vec<MediaStreamDescriptor>, usize)> {
    let mut streams = Vec::new();
    let mut unrecognized = 0;
    for index in 0..context.nb_streams as usize {
        // SAFETY: index is bounded by nb_streams and streams is owned by AVFormatContext.
        let stream = unsafe { &**context.streams.add(index) };
        // SAFETY: codecpar is owned by AVStream and valid while context lives.
        let parameters = unsafe { stream.codecpar.as_ref() }.ok_or_else(|| {
            EngineError::new(ErrorKind::Analysis, "media stream has no codec parameters")
        })?;
        let codec = codec_name(parameters.codec_id);
        match parameters.codec_type {
            ffi::AVMEDIA_TYPE_VIDEO => streams.push(MediaStreamDescriptor::Video(Box::new(
                map_video_stream(index as u32, stream, parameters, codec)?,
            ))),
            ffi::AVMEDIA_TYPE_AUDIO => streams.push(MediaStreamDescriptor::Audio(Box::new(
                map_audio_stream(index as u32, stream, parameters, codec)?,
            ))),
            ffi::AVMEDIA_TYPE_SUBTITLE => {
                streams.push(MediaStreamDescriptor::Subtitle(SubtitleStreamInfo {
                    stream_index: index as u32,
                    codec,
                }))
            }
            ffi::AVMEDIA_TYPE_DATA => streams.push(MediaStreamDescriptor::Data(DataStreamInfo {
                stream_index: index as u32,
                codec,
            })),
            ffi::AVMEDIA_TYPE_ATTACHMENT => {
                streams.push(MediaStreamDescriptor::Attachment(DataStreamInfo {
                    stream_index: index as u32,
                    codec,
                }))
            }
            _ => unrecognized += 1,
        }
    }
    Ok((streams, unrecognized))
}

fn map_video_stream(
    index: u32,
    stream: &ffi::AVStream,
    parameters: &ffi::AVCodecParameters,
    codec: String,
) -> Result<VideoStreamInfo> {
    let frame_rate = rational_observed(stream.avg_frame_rate, "libavformat");
    let time_base = rational(stream.time_base)?;
    Ok(VideoStreamInfo {
        stream_index: index,
        codec,
        profile: profile_name(parameters),
        width: parameters.width.max(0) as u32,
        height: parameters.height.max(0) as u32,
        frame_rate,
        frame_count: if stream.nb_frames > 0 {
            Observed::detected(stream.nb_frames as u64, "libavformat")
        } else {
            unavailable("stream frame count unavailable")
        },
        time_base,
        bit_depth: video_bit_depth(parameters),
        pixel_format: pixel_format_name(parameters.format),
        hdr: HdrInfo {
            color_range: enum_name(
                // SAFETY: FFmpeg returns a static string or null.
                unsafe { ffi::av_color_range_name(parameters.color_range) },
                "libavutil",
            ),
            color_space: enum_name(
                // SAFETY: FFmpeg returns a static string or null.
                unsafe { ffi::av_color_space_name(parameters.color_space) },
                "libavutil",
            ),
            color_transfer: enum_name(
                // SAFETY: FFmpeg returns a static string or null.
                unsafe { ffi::av_color_transfer_name(parameters.color_trc) },
                "libavutil",
            ),
            color_primaries: enum_name(
                // SAFETY: FFmpeg returns a static string or null.
                unsafe { ffi::av_color_primaries_name(parameters.color_primaries) },
                "libavutil",
            ),
        },
        bitrate: bitrate(parameters.bit_rate),
    })
}

fn map_audio_stream(
    index: u32,
    stream: &ffi::AVStream,
    parameters: &ffi::AVCodecParameters,
    codec: String,
) -> Result<AudioStreamInfo> {
    let duration = stream_duration(stream.duration, stream.time_base);
    Ok(AudioStreamInfo {
        stream_index: index,
        codec,
        profile: profile_name(parameters),
        sample_rate_hz: positive_u32(parameters.sample_rate, "libavcodec"),
        channel_count: if parameters.ch_layout.nb_channels > 0 {
            Observed::detected(parameters.ch_layout.nb_channels as u32, "libavutil")
        } else {
            unavailable("channel count unavailable")
        },
        channel_layout: channel_layout_name(&parameters.ch_layout),
        sample_format: sample_format_name(parameters.format),
        bitrate: bitrate(parameters.bit_rate),
        duration,
    })
}

fn classify_media(
    format: Option<&str>,
    streams: Vec<MediaStreamDescriptor>,
    duration: &Observed<MediaDuration>,
) -> Result<(MediaKind, MediaDescriptor)> {
    let videos: Vec<_> = streams
        .iter()
        .filter_map(|stream| match stream {
            MediaStreamDescriptor::Video(value) => Some(value),
            _ => None,
        })
        .collect();
    let has_audio = streams
        .iter()
        .any(|stream| matches!(stream, MediaStreamDescriptor::Audio(_)));
    let image_format = format.is_some_and(|value| {
        value.contains("image")
            || value.contains("jpeg")
            || value.contains("png")
            || value.contains("webp")
            || value.contains("gif")
            || value.contains("apng")
    });
    if videos.len() == 1 && !has_audio && image_format {
        let video = videos[0];
        let image = ImageInfo {
            codec: video.codec.clone(),
            width: video.width,
            height: video.height,
            pixel_format: video.pixel_format.clone(),
            bit_depth: video.bit_depth.clone(),
            alpha: unavailable("alpha requires pixel format component inspection"),
            color_space: video.hdr.color_space.clone(),
        };
        let animated = video.frame_count.value.is_some_and(|value| value > 1);
        if animated {
            return Ok((
                MediaKind::AnimatedImage,
                MediaDescriptor::AnimatedImage {
                    image: Box::new(image),
                    animation: Box::new(AnimationInfo {
                        frame_rate: video.frame_rate.clone(),
                        frame_count: video.frame_count.clone(),
                        duration: duration.clone(),
                    }),
                },
            ));
        }
        return Ok((
            MediaKind::Image,
            MediaDescriptor::Image {
                image: Box::new(image),
            },
        ));
    }
    if !videos.is_empty() {
        return Ok((MediaKind::Video, MediaDescriptor::Video { streams }));
    }
    if has_audio {
        return Ok((MediaKind::Audio, MediaDescriptor::Audio { streams }));
    }
    Ok((MediaKind::Other, MediaDescriptor::Other { streams }))
}

fn is_animation_format(value: &str) -> bool {
    value.contains("gif") || value.contains("apng") || value.contains("webp")
}

fn analysis_warnings(
    kind: MediaKind,
    descriptor: &MediaDescriptor,
    duration: &Observed<MediaDuration>,
    unrecognized_streams: usize,
    animation_unknown: bool,
) -> Vec<framelean_analysis::MediaWarning> {
    let mut warnings = Vec::new();
    if unrecognized_streams > 0 {
        warnings.push(media_warning(
            framelean_core::EngineErrorCode::MediaStreamUnrecognized,
            format!("{unrecognized_streams} media streams were not recognized"),
        ));
    }
    if matches!(
        kind,
        MediaKind::Video | MediaKind::Audio | MediaKind::AnimatedImage
    ) && duration.status != ObservationStatus::Detected
    {
        warnings.push(media_warning(
            framelean_core::EngineErrorCode::MediaDurationUnavailable,
            "media duration is unavailable",
        ));
    }
    if animation_unknown {
        warnings.push(media_warning(
            framelean_core::EngineErrorCode::MediaAnimationStateNotProbed,
            "bounded packet scan could not determine whether the image is animated",
        ));
    }
    match descriptor {
        MediaDescriptor::Video { streams }
        | MediaDescriptor::Audio { streams }
        | MediaDescriptor::Other { streams } => {
            for stream in streams {
                if let MediaStreamDescriptor::Video(video) = stream {
                    append_video_warnings(video, &mut warnings);
                }
            }
        }
        MediaDescriptor::Image { image } | MediaDescriptor::AnimatedImage { image, .. } => {
            if image.pixel_format.status != ObservationStatus::Detected {
                warnings.push(media_warning(
                    framelean_core::EngineErrorCode::MediaPixelFormatUnavailable,
                    "image pixel format is unavailable",
                ));
            }
            if image.bit_depth.status != ObservationStatus::Detected {
                warnings.push(media_warning(
                    framelean_core::EngineErrorCode::MediaBitDepthUnavailable,
                    "image bit depth is unavailable",
                ));
            }
        }
    }
    warnings
}

fn append_video_warnings(
    video: &VideoStreamInfo,
    warnings: &mut Vec<framelean_analysis::MediaWarning>,
) {
    if video.profile.status != ObservationStatus::Detected {
        warnings.push(media_warning(
            framelean_core::EngineErrorCode::MediaProfileUnavailable,
            format!("video stream {} profile is unavailable", video.stream_index),
        ));
    }
    if video.pixel_format.status != ObservationStatus::Detected {
        warnings.push(media_warning(
            framelean_core::EngineErrorCode::MediaPixelFormatUnavailable,
            format!(
                "video stream {} pixel format is unavailable",
                video.stream_index
            ),
        ));
    }
    if video.bit_depth.status != ObservationStatus::Detected {
        warnings.push(media_warning(
            framelean_core::EngineErrorCode::MediaBitDepthUnavailable,
            format!(
                "video stream {} bit depth is unavailable",
                video.stream_index
            ),
        ));
    }
    if [
        &video.hdr.color_range,
        &video.hdr.color_space,
        &video.hdr.color_transfer,
        &video.hdr.color_primaries,
    ]
    .iter()
    .any(|value| value.status != ObservationStatus::Detected)
    {
        warnings.push(media_warning(
            framelean_core::EngineErrorCode::MediaHdrStateIncomplete,
            format!(
                "video stream {} HDR state is incomplete",
                video.stream_index
            ),
        ));
    }
}

fn media_warning(
    code: framelean_core::EngineErrorCode,
    message: impl Into<String>,
) -> framelean_analysis::MediaWarning {
    framelean_analysis::MediaWarning {
        code,
        message: message.into(),
    }
}

fn demuxer_backends(version: Option<String>) -> Result<Vec<BackendDescriptor>> {
    let mut opaque: *mut c_void = ptr::null_mut();
    let mut backends = Vec::new();
    loop {
        // SAFETY: opaque is FFmpeg's iterator state and is only passed back to this API.
        let format = unsafe { ffi::av_demuxer_iterate(&mut opaque) };
        let Some(format) = (unsafe { format.as_ref() }) else {
            break;
        };
        let names = c_string_list(format.name);
        let Some(primary) = names.first() else {
            continue;
        };
        backends.push(BackendDescriptor {
            id: BackendId::new(format!("ffmpeg.demuxer.{primary}"))?,
            provider: "framelean-ffmpeg".to_owned(),
            version: version.clone(),
            availability: BackendAvailability::native_only(NativeSupportStatus::NativeDiscovered),
            environment: BackendEnvironmentRequirements::unrestricted(),
            capability: BackendCapability::Demuxer(DemuxerCapability {
                input_formats: names,
                stream_types: all_stream_kinds(),
                codec_restrictions: CapabilityConstraint::Unknown,
                supports_multiple_streams: unavailable(
                    "per-format multi-stream support requires qualification",
                ),
                requires_seek: unavailable("seek requirements require format qualification"),
                supports_custom_io: unavailable(
                    "custom IO support requires per-format initialization qualification",
                ),
            }),
            source: "libavformat:av_demuxer_iterate".to_owned(),
        });
    }
    Ok(backends)
}

fn muxer_backends(version: Option<String>) -> Result<Vec<BackendDescriptor>> {
    let mut opaque: *mut c_void = ptr::null_mut();
    let mut backends = Vec::new();
    loop {
        // SAFETY: opaque is FFmpeg's iterator state and is only passed back to this API.
        let format = unsafe { ffi::av_muxer_iterate(&mut opaque) };
        let Some(format) = (unsafe { format.as_ref() }) else {
            break;
        };
        let names = c_string_list(format.name);
        let Some(primary) = names.first() else {
            continue;
        };
        let video = codec_name_option(format.video_codec);
        let audio = codec_name_option(format.audio_codec);
        backends.push(BackendDescriptor {
            id: BackendId::new(format!(
                "ffmpeg.muxer.{primary}.{}",
                slug(c_string(format.long_name).as_deref().unwrap_or("format"))
            ))?,
            provider: "framelean-ffmpeg".to_owned(),
            version: version.clone(),
            availability: BackendAvailability::native_only(NativeSupportStatus::NativeDiscovered),
            environment: BackendEnvironmentRequirements::unrestricted(),
            capability: BackendCapability::Muxer(MuxerCapability {
                output_formats: names,
                video_codecs: video.into_iter().collect(),
                audio_codecs: audio.into_iter().collect(),
                supports_subtitles: Observed::detected(
                    format.subtitle_codec != ffi::AV_CODEC_ID_NONE,
                    "libavformat default subtitle codec",
                ),
                supports_data: unavailable("data stream support requires format qualification"),
                supports_attachments: unavailable(
                    "attachment support requires format qualification",
                ),
                supports_multiple_streams: unavailable(
                    "per-format multi-stream support requires qualification",
                ),
                codec_combinations: CapabilityConstraint::Unknown,
                requires_seek: unavailable("seek requirements require format qualification"),
            }),
            source: "libavformat:av_muxer_iterate".to_owned(),
        });
    }
    Ok(backends)
}

fn codec_backends(version: Option<String>) -> Result<Vec<BackendDescriptor>> {
    let mut opaque: *mut c_void = ptr::null_mut();
    let mut backends = Vec::new();
    loop {
        // SAFETY: opaque is FFmpeg's iterator state and is only passed back to this API.
        let codec = unsafe { ffi::av_codec_iterate(&mut opaque) };
        let Some(codec) = (unsafe { codec.as_ref() }) else {
            break;
        };
        let name = c_string(codec.name).unwrap_or_else(|| codec_name(codec.id));
        let stream_type = match codec.type_ {
            ffi::AVMEDIA_TYPE_VIDEO => StreamKind::Video,
            ffi::AVMEDIA_TYPE_AUDIO => StreamKind::Audio,
            ffi::AVMEDIA_TYPE_SUBTITLE => StreamKind::Subtitle,
            _ => continue,
        };
        let native_status = NativeSupportStatus::NativeDiscovered;
        // SAFETY: codec descriptor is valid for the duration of the process.
        if unsafe { ffi::av_codec_is_decoder(codec) } != 0 {
            backends.push(BackendDescriptor {
                id: BackendId::new(format!("ffmpeg.decoder.{name}"))?,
                provider: "framelean-ffmpeg".to_owned(),
                version: version.clone(),
                availability: BackendAvailability::native_only(native_status),
                environment: BackendEnvironmentRequirements::unrestricted(),
                capability: BackendCapability::Decoder(DecoderCapability {
                    stream_type,
                    codecs: vec![codec_name(codec.id)],
                    profiles: CapabilityConstraint::Unknown,
                    pixel_or_sample_formats: CapabilityConstraint::Unknown,
                    bit_depths: CapabilityConstraint::Unknown,
                }),
                source: "libavcodec:av_codec_iterate".to_owned(),
            });
        }
        // SAFETY: codec descriptor is valid for the duration of the process.
        if unsafe { ffi::av_codec_is_encoder(codec) } != 0 {
            backends.push(BackendDescriptor {
                id: BackendId::new(format!("ffmpeg.encoder.{name}"))?,
                provider: "framelean-ffmpeg".to_owned(),
                version: version.clone(),
                availability: BackendAvailability::native_only(native_status),
                environment: BackendEnvironmentRequirements::unrestricted(),
                capability: BackendCapability::Encoder(EncoderCapability {
                    stream_type,
                    codecs: vec![codec_name(codec.id)],
                    profiles: CapabilityConstraint::Unknown,
                    pixel_or_sample_formats: CapabilityConstraint::Unknown,
                    bit_depths: CapabilityConstraint::Unknown,
                    hdr_modes: CapabilityConstraint::<HdrMode>::Unknown,
                    rate_control_modes: CapabilityConstraint::Unknown,
                }),
                source: "libavcodec:av_codec_iterate".to_owned(),
            });
        }
    }
    Ok(backends)
}

fn c_string(pointer: *const std::ffi::c_char) -> Option<String> {
    if pointer.is_null() {
        return None;
    }
    // SAFETY: FFmpeg API returns a null-terminated static or context-owned string.
    Some(
        unsafe { CStr::from_ptr(pointer) }
            .to_string_lossy()
            .into_owned(),
    )
}

fn c_string_list(pointer: *const std::ffi::c_char) -> Vec<String> {
    c_string(pointer)
        .map(|value| {
            value
                .split(',')
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default()
}

fn codec_name(codec: ffi::AVCodecID) -> String {
    // SAFETY: avcodec_get_name returns a static string for any codec ID.
    c_string(unsafe { ffi::avcodec_get_name(codec) }).unwrap_or_else(|| format!("codec-{codec}"))
}

fn codec_name_option(codec: ffi::AVCodecID) -> Option<String> {
    (codec != ffi::AV_CODEC_ID_NONE).then(|| codec_name(codec))
}

fn profile_name(parameters: &ffi::AVCodecParameters) -> Observed<String> {
    if parameters.profile < 0 {
        return unavailable("codec profile unavailable");
    }
    // SAFETY: function returns a static string or null.
    enum_name(
        unsafe { ffi::avcodec_profile_name(parameters.codec_id, parameters.profile) },
        "libavcodec",
    )
}

fn pixel_format_name(format: i32) -> Observed<String> {
    if format < 0 {
        return unavailable("pixel format unavailable");
    }
    // SAFETY: enum value comes from AVCodecParameters.
    enum_name(unsafe { ffi::av_get_pix_fmt_name(format) }, "libavutil")
}

fn sample_format_name(format: i32) -> Observed<String> {
    if format < 0 {
        return unavailable("sample format unavailable");
    }
    // SAFETY: enum value comes from AVCodecParameters.
    enum_name(unsafe { ffi::av_get_sample_fmt_name(format) }, "libavutil")
}

fn channel_layout_name(layout: &ffi::AVChannelLayout) -> Observed<String> {
    let mut buffer = [0_i8; 128];
    // SAFETY: buffer is writable and layout comes from AVCodecParameters.
    let result =
        unsafe { ffi::av_channel_layout_describe(layout, buffer.as_mut_ptr(), buffer.len()) };
    if result < 0 {
        unavailable("channel layout unavailable")
    } else {
        enum_name(buffer.as_ptr(), "libavutil")
    }
}

fn enum_name(pointer: *const std::ffi::c_char, source: &str) -> Observed<String> {
    c_string(pointer).map_or_else(
        || unavailable("native value unavailable"),
        |value| Observed::detected(value, source),
    )
}

fn rational(value: ffi::AVRational) -> Result<Rational> {
    Rational::new(value.num as i64, value.den.max(1) as u64)
}

fn rational_observed(value: ffi::AVRational, source: &str) -> Observed<Rational> {
    if value.num <= 0 || value.den <= 0 {
        unavailable("rational value unavailable")
    } else {
        Observed::detected(
            Rational::new(value.num as i64, value.den as u64)
                .expect("validated rational denominator"),
            source,
        )
    }
}

fn bitrate(value: i64) -> Observed<BitRateBps> {
    if value > 0 {
        Observed::detected(BitRateBps::new(value as u64), "libavcodec")
    } else {
        unavailable("bitrate unavailable")
    }
}

fn positive_u8(value: i32, source: &str) -> Observed<u8> {
    if value > 0 && value <= u8::MAX as i32 {
        Observed::detected(value as u8, source)
    } else {
        unavailable("value unavailable")
    }
}

fn video_bit_depth(parameters: &ffi::AVCodecParameters) -> Observed<u8> {
    if parameters.bits_per_raw_sample > 0 {
        return positive_u8(
            parameters.bits_per_raw_sample,
            "libavcodec:bits_per_raw_sample",
        );
    }
    if parameters.format == ffi::AV_PIX_FMT_NONE {
        return unavailable("video bit depth unavailable");
    }
    pixel_format_descriptor_bit_depth(parameters.format)
}

fn pixel_format_descriptor_bit_depth(format: ffi::AVPixelFormat) -> Observed<u8> {
    // SAFETY: av_pix_fmt_desc_get accepts every AVPixelFormat value and returns either null or a
    // process-lifetime static descriptor.
    let descriptor = unsafe { ffi::av_pix_fmt_desc_get(format) };
    let Some(descriptor) = (unsafe { descriptor.as_ref() }) else {
        return unavailable("pixel format descriptor unavailable");
    };
    descriptor.comp[..usize::from(descriptor.nb_components)]
        .iter()
        .filter_map(|component| u8::try_from(component.depth).ok())
        .max()
        .filter(|depth| *depth > 0)
        .map_or_else(
            || unavailable("pixel format descriptor has no component depth"),
            |depth| Observed::detected(depth, "libavutil:pixel_format_descriptor"),
        )
}

fn positive_u32(value: i32, source: &str) -> Observed<u32> {
    if value > 0 {
        Observed::detected(value as u32, source)
    } else {
        unavailable("value unavailable")
    }
}

fn unavailable<T>(reason: &str) -> Observed<T> {
    Observed::with_status(ObservationStatus::NotProbed, reason)
}

fn stream_duration(duration: i64, time_base: ffi::AVRational) -> Observed<MediaDuration> {
    if duration <= 0 || duration == ffi::AV_NOPTS_VALUE || time_base.num <= 0 || time_base.den <= 0
    {
        return unavailable("stream duration unavailable");
    }
    // SAFETY: av_rescale_q is a pure integer conversion and both rationals are valid.
    let microseconds = unsafe {
        ffi::av_rescale_q(
            duration,
            time_base,
            ffi::AVRational {
                num: 1,
                den: ffi::AV_TIME_BASE as i32,
            },
        )
    };
    if microseconds <= 0 || microseconds == ffi::AV_NOPTS_VALUE {
        return unavailable("stream duration rescaling failed");
    }
    Observed::detected(
        MediaDuration::new(microseconds as u64, ffi::AV_TIME_BASE)
            .expect("FFmpeg microsecond time base is valid"),
        "libavutil:av_rescale_q",
    )
}

fn format_version(version: u32) -> String {
    format!(
        "{}.{}.{}",
        version >> 16,
        (version >> 8) & 0xff,
        version & 0xff
    )
}

fn media_native_error(
    error_code: framelean_core::EngineErrorCode,
    message: &str,
    code: i32,
) -> EngineError {
    let mut buffer = [0_i8; 256];
    // SAFETY: buffer is writable for its full length.
    let description = unsafe {
        if ffi::av_strerror(code, buffer.as_mut_ptr(), buffer.len()) == 0 {
            CStr::from_ptr(buffer.as_ptr())
                .to_string_lossy()
                .into_owned()
        } else {
            format!("FFmpeg error {code}")
        }
    };
    EngineError::with_code(
        ErrorKind::Analysis,
        error_code,
        format!("{message}: {description}"),
    )
}

#[cfg(unix)]
fn path_c_string(path: &Path) -> Result<CString> {
    use std::os::unix::ffi::OsStrExt;
    CString::new(path.as_os_str().as_bytes()).map_err(|_| {
        EngineError::invalid_argument("local media path contains an embedded null byte")
    })
}

#[cfg(not(unix))]
fn path_c_string(path: &Path) -> Result<CString> {
    let value = path.to_str().ok_or_else(|| {
        EngineError::with_code(
            ErrorKind::Analysis,
            framelean_core::EngineErrorCode::MediaInvalidFormat,
            "non-Unicode Windows paths require the planned custom AVIO adapter",
        )
    })?;
    CString::new(value)
        .map_err(|_| EngineError::invalid_argument("local media path contains a null character"))
}

fn all_stream_kinds() -> Vec<StreamKind> {
    vec![
        StreamKind::Video,
        StreamKind::Audio,
        StreamKind::Subtitle,
        StreamKind::Data,
        StreamKind::Attachment,
    ]
}

fn slug(value: &str) -> String {
    let slug: String = value
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect();
    slug.split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

#[cfg(test)]
mod tests {
    use framelean_media::capability::{EngineExecutionReadiness, EngineRegistrationStatus};

    use super::*;

    #[test]
    fn linked_libraries_report_versions() {
        let versions = library_versions().unwrap();
        assert!(versions.avformat > 0);
        assert!(versions.avcodec > 0);
        assert!(versions.avutil > 0);
    }

    #[test]
    fn audio_duration_uses_complete_time_base() {
        let duration = stream_duration(
            48_000,
            ffi::AVRational {
                num: 1,
                den: 48_000,
            },
        );
        assert_eq!(duration.value.unwrap().value(), 1_000_000);

        let duration = stream_duration(
            48_000,
            ffi::AVRational {
                num: 1024,
                den: 48_000,
            },
        );
        assert_eq!(duration.value.unwrap().value(), 1_024_000_000);
    }

    #[test]
    fn audio_duration_rejects_unavailable_and_invalid_values() {
        for value in [0, -1, ffi::AV_NOPTS_VALUE] {
            let duration = stream_duration(
                value,
                ffi::AVRational {
                    num: 1,
                    den: 48_000,
                },
            );
            assert_eq!(duration.status, ObservationStatus::NotProbed);
            assert!(duration.value.is_none());
        }
        let duration = stream_duration(
            i64::MAX,
            ffi::AVRational {
                num: i32::MAX,
                den: 1,
            },
        );
        assert_eq!(duration.status, ObservationStatus::NotProbed);
        assert!(duration.value.is_none());
    }

    #[test]
    fn allocating_codec_context_is_not_reported_as_initializable() {
        let catalog = FfmpegAdapter::new().unwrap().backend_catalog().unwrap();
        assert!(catalog.backends.iter().all(|backend| {
            backend.availability.native_support != NativeSupportStatus::NativeInitializable
        }));
    }

    #[test]
    fn static_webp_is_not_animated_merely_because_duration_exists() {
        let duration = Observed::detected(MediaDuration::new(1, 1).unwrap(), "fixture");
        let (kind, _) = classify_media(
            Some("webp_pipe"),
            vec![MediaStreamDescriptor::Video(Box::new(image_stream(1)))],
            &duration,
        )
        .unwrap();
        assert_eq!(kind, MediaKind::Image);
    }

    #[test]
    fn multi_frame_image_is_classified_as_animated() {
        let duration = Observed::detected(MediaDuration::new(1, 1).unwrap(), "fixture");
        let (kind, _) = classify_media(
            Some("gif"),
            vec![MediaStreamDescriptor::Video(Box::new(image_stream(2)))],
            &duration,
        )
        .unwrap();
        assert_eq!(kind, MediaKind::AnimatedImage);
    }

    #[test]
    fn image_classification_requires_frame_count_evidence() {
        let duration = Observed::detected(MediaDuration::new(1, 1).unwrap(), "fixture");
        for format in ["png_pipe", "jpeg_pipe", "webp_pipe", "gif", "apng"] {
            let (kind, _) = classify_media(
                Some(format),
                vec![MediaStreamDescriptor::Video(Box::new(image_stream(1)))],
                &duration,
            )
            .unwrap();
            assert_eq!(kind, MediaKind::Image, "{format}");
        }
        for format in ["webp_pipe", "gif", "apng"] {
            let (kind, _) = classify_media(
                Some(format),
                vec![MediaStreamDescriptor::Video(Box::new(image_stream(2)))],
                &duration,
            )
            .unwrap();
            assert_eq!(kind, MediaKind::AnimatedImage, "{format}");
        }

        let mut unknown = image_stream(1);
        unknown.frame_count = unavailable("fixture");
        let (kind, _) = classify_media(
            Some("gif"),
            vec![MediaStreamDescriptor::Video(Box::new(unknown))],
            &duration,
        )
        .unwrap();
        assert_eq!(kind, MediaKind::Image);
    }

    #[test]
    fn decision_critical_missing_video_facts_produce_partial_warnings() {
        let descriptor = MediaDescriptor::Video {
            streams: vec![MediaStreamDescriptor::Video(Box::new(image_stream(1)))],
        };
        let warnings = analysis_warnings(
            MediaKind::Video,
            &descriptor,
            &unavailable("fixture"),
            1,
            false,
        );
        let codes: Vec<_> = warnings.iter().map(|warning| warning.code).collect();
        assert!(codes.contains(&framelean_core::EngineErrorCode::MediaDurationUnavailable));
        assert!(codes.contains(&framelean_core::EngineErrorCode::MediaStreamUnrecognized));
        assert!(codes.contains(&framelean_core::EngineErrorCode::MediaProfileUnavailable));
        assert!(codes.contains(&framelean_core::EngineErrorCode::MediaHdrStateIncomplete));
    }

    #[test]
    fn bit_depth_falls_back_to_pixel_format_descriptor() {
        let depth = pixel_format_descriptor_bit_depth(ffi::AV_PIX_FMT_YUV420P10LE);
        assert_eq!(depth.status, ObservationStatus::Detected);
        assert_eq!(depth.value, Some(10));
    }

    fn image_stream(frame_count: u64) -> VideoStreamInfo {
        VideoStreamInfo {
            stream_index: 0,
            codec: "webp".to_owned(),
            profile: unavailable("fixture"),
            width: 100,
            height: 100,
            frame_rate: unavailable("fixture"),
            frame_count: Observed::detected(frame_count, "fixture"),
            time_base: Rational::new(1, 1_000).unwrap(),
            bit_depth: Observed::detected(8, "fixture"),
            pixel_format: Observed::detected("yuva420p".to_owned(), "fixture"),
            hdr: HdrInfo {
                color_range: unavailable("fixture"),
                color_space: unavailable("fixture"),
                color_transfer: unavailable("fixture"),
                color_primaries: unavailable("fixture"),
            },
            bitrate: unavailable("fixture"),
        }
    }

    #[test]
    fn ffmpeg_catalog_never_claims_engine_execution_readiness() {
        let catalog = FfmpegAdapter::new().unwrap().backend_catalog().unwrap();
        assert!(!catalog.backends.is_empty());
        assert!(catalog.backends.iter().all(|backend| {
            backend.availability.engine_registration == EngineRegistrationStatus::NotRegistered
                && backend.availability.engine_execution_readiness
                    == EngineExecutionReadiness::NotReady
        }));
        assert!(
            catalog
                .backends
                .iter()
                .any(|backend| matches!(backend.capability, BackendCapability::Demuxer(_)))
        );
        assert!(
            catalog
                .backends
                .iter()
                .any(|backend| matches!(backend.capability, BackendCapability::Muxer(_)))
        );
    }
}
