use std::fs;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use framelean_analysis::{
    AnalyzedMedia, AnimationInfo, AudioStreamInfo, HdrInfo, ImageInfo, MediaAnalysis,
    MediaAnalyzeRequest, MediaAnalyzer, MediaDescriptor, MediaKind, MediaSource,
    MediaStreamDescriptor, MediaWarning, SourceFingerprint, VideoStreamInfo,
};
use framelean_core::{
    BackendId, EngineErrorCode, FileSizeBytes, ObservationStatus, Observed, Result,
};
use framelean_decision::{
    DefaultCapabilityResolver, DefaultRecommendationEngine, ManualSelection, PresetId,
    PresetSelection, RecalculateSelection, TaskMode,
};
use framelean_environment::{
    CpuInfo, EnvironmentSnapshot, EnvironmentSnapshotProvider, ResourceMonitor, ResourceSample,
};
use framelean_media::capability::{
    BackendAvailability, BackendCapability, BackendCatalog, BackendCatalogProvider,
    BackendDescriptor, BackendEnvironmentRequirements, CapabilityConstraint, DecoderCapability,
    DemuxerCapability, EncoderCapability, HdrMode, MuxerCapability, MuxerCodecCombination,
    NativeSupportStatus, StreamKind,
};
use framelean_runtime::{
    AnalysisServices, AnalysisSnapshotPolicy, AnalyzeTaskRequest, EngineRuntime, EvictionStrategy,
    RecalculateConfigurationRequest, RequestContext,
};

struct TestAnalyzer;

impl MediaAnalyzer for TestAnalyzer {
    fn analyze(&self, request: &MediaAnalyzeRequest) -> Result<AnalyzedMedia> {
        let metadata = fs::metadata(request.source.path()).unwrap();
        let source_fingerprint = SourceFingerprint::from_local_file(request.source.path())?;
        let source_id = source_fingerprint.source_id()?;
        AnalyzedMedia::new(
            MediaAnalysis {
                status: framelean_analysis::MediaAnalysisStatus::Complete,
                source_id,
                file_name: "input.bin".to_owned(),
                display_path: None,
                file_size: FileSizeBytes::new(metadata.len()),
                kind: MediaKind::Video,
                format: Observed::detected("mp4".to_owned(), "test"),
                duration: Observed::detected(
                    framelean_media::MediaDuration::new(10, 1).unwrap(),
                    "fixture",
                ),
                descriptor: MediaDescriptor::Video {
                    streams: vec![MediaStreamDescriptor::Video(Box::new(VideoStreamInfo {
                        stream_index: 0,
                        codec: "h264".to_owned(),
                        profile: Observed::detected("main".to_owned(), "test"),
                        width: 1920,
                        height: 1080,
                        frame_rate: Observed::detected(
                            framelean_media::Rational::new(30, 1).unwrap(),
                            "test",
                        ),
                        frame_count: Observed::detected(300, "test"),
                        time_base: framelean_media::Rational::new(1, 90_000).unwrap(),
                        bit_depth: Observed::detected(8, "test"),
                        pixel_format: Observed::detected("yuv420p".to_owned(), "test"),
                        hdr: HdrInfo {
                            color_range: Observed::detected("tv".to_owned(), "test"),
                            color_space: Observed::detected("bt709".to_owned(), "test"),
                            color_transfer: Observed::detected("bt709".to_owned(), "test"),
                            color_primaries: Observed::detected("bt709".to_owned(), "test"),
                        },
                        bitrate: Observed::with_status(ObservationStatus::NotProbed, "test"),
                    }))],
                },
                provider: "test".to_owned(),
                provider_version: None,
                warnings: vec![MediaWarning {
                    code: EngineErrorCode::MediaBitDepthUnavailable,
                    message: "fixture media warning".to_owned(),
                }],
            },
            source_fingerprint,
        )
    }
}

struct TestSystem;

impl EnvironmentSnapshotProvider for TestSystem {
    fn snapshot(&self) -> Result<EnvironmentSnapshot> {
        Ok(EnvironmentSnapshot {
            observed_at_unix_ms: 1,
            operating_system: Observed::detected("test".to_owned(), "test"),
            os_version: Observed::detected("1".to_owned(), "test"),
            device_model: Observed::with_status(ObservationStatus::NotProbed, "test"),
            cpu: CpuInfo {
                model: Observed::detected("test".to_owned(), "test"),
                architecture: "test".to_owned(),
                physical_cores: Observed::detected(1, "test"),
                logical_cores: 1,
            },
            total_memory: framelean_core::MemoryBytes::new(1),
            gpus: Observed::detected(Vec::new(), "test"),
            native_media_frameworks: Vec::new(),
        })
    }
}

impl ResourceMonitor for TestSystem {
    fn sample(&self) -> Result<ResourceSample> {
        Ok(ResourceSample {
            sampled_at_unix_ms: 1,
            cpu_usage_basis_points: Observed::detected(0, "test"),
            used_memory: Observed::detected(framelean_core::MemoryBytes::new(0), "test"),
            gpu_usage_basis_points: Observed::with_status(ObservationStatus::Unsupported, "test"),
            used_gpu_memory: Observed::with_status(ObservationStatus::Unsupported, "test"),
            temperature_millidegrees_celsius: Observed::with_status(
                ObservationStatus::Unsupported,
                "test",
            ),
            power_milliwatts: Observed::with_status(ObservationStatus::Unsupported, "test"),
        })
    }
}

struct NativeOnlyCatalog;

impl BackendCatalogProvider for NativeOnlyCatalog {
    fn backend_catalog(&self) -> Result<BackendCatalog> {
        Ok(BackendCatalog::default())
    }
}

struct ReadyCatalog;

impl BackendCatalogProvider for ReadyCatalog {
    fn backend_catalog(&self) -> Result<BackendCatalog> {
        BackendCatalog::from_backends(vec![
            backend(
                "demux",
                BackendCapability::Demuxer(DemuxerCapability {
                    input_formats: vec!["mp4".to_owned()],
                    stream_types: vec![StreamKind::Video],
                    codec_restrictions: CapabilityConstraint::Restricted(vec!["h264".to_owned()]),
                    supports_multiple_streams: Observed::detected(true, "test"),
                    requires_seek: Observed::detected(true, "test"),
                    supports_custom_io: Observed::detected(true, "test"),
                }),
            ),
            backend(
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
            ),
            backend(
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
            ),
            backend(
                "muxer",
                BackendCapability::Muxer(MuxerCapability {
                    output_formats: vec!["mp4".to_owned()],
                    video_codecs: vec!["h264".to_owned()],
                    audio_codecs: Vec::new(),
                    supports_subtitles: Observed::detected(false, "test"),
                    supports_data: Observed::detected(false, "test"),
                    supports_attachments: Observed::detected(false, "test"),
                    supports_multiple_streams: Observed::detected(true, "test"),
                    codec_combinations: CapabilityConstraint::Restricted(vec![
                        MuxerCodecCombination {
                            video_codec: Some("h264".to_owned()),
                            audio_codec: None,
                        },
                    ]),
                    requires_seek: Observed::detected(true, "test"),
                }),
            ),
        ])
    }
}

fn backend(id: &str, capability: BackendCapability) -> BackendDescriptor {
    BackendDescriptor {
        id: BackendId::new(id).unwrap(),
        provider: "test".to_owned(),
        version: Some("1".to_owned()),
        availability: BackendAvailability::execution_ready(
            NativeSupportStatus::NativeInitializable,
        ),
        environment: BackendEnvironmentRequirements::unrestricted(),
        capability,
        source: "test".to_owned(),
    }
}

fn runtime() -> EngineRuntime {
    runtime_with_provider(Arc::new(NativeOnlyCatalog))
}

fn runtime_with_provider(provider: Arc<dyn BackendCatalogProvider>) -> EngineRuntime {
    let system = Arc::new(TestSystem);
    EngineRuntime::with_analysis_services(
        AnalysisServices {
            analyzer: Arc::new(TestAnalyzer),
            environment: system.clone(),
            resource_monitor: system,
            native_backend_providers: vec![provider],
            capability_resolver: Arc::new(DefaultCapabilityResolver),
            recommendation_engine: Arc::new(DefaultRecommendationEngine),
            size_estimator: None,
            estimator_policy: None,
        },
        AnalysisSnapshotPolicy::new(None, None, EvictionStrategy::LeastRecentlyUsed).unwrap(),
    )
}

#[test]
fn same_runtime_recalculates_but_native_only_chain_stays_unavailable() {
    let path = std::env::temp_dir().join(format!(
        "framelean-runtime-analysis-{}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::write(&path, b"fixture").unwrap();
    let mut runtime = runtime();
    let initial = runtime
        .analyze_media(AnalyzeTaskRequest {
            task_mode: TaskMode::VideoCompress,
            media_request: MediaAnalyzeRequest {
                source: MediaSource::local_file(&path).unwrap(),
                request_id: None,
            },
            context: RequestContext::default(),
        })
        .unwrap();
    assert_eq!(runtime.analysis_snapshot_count(), 1);
    assert!(!initial.capabilities.as_ref().unwrap().available);
    assert!(
        initial
            .warnings
            .iter()
            .any(|warning| { warning.code == EngineErrorCode::MediaBitDepthUnavailable })
    );
    let backend_summary = initial.engine_backend_summary.as_ref().unwrap();
    assert_eq!(backend_summary.plugin_backend_count, 0);
    assert_eq!(
        backend_summary.backend_count,
        backend_summary.native_backend_count
    );

    let recalculated = runtime
        .recalculate_configuration(RecalculateConfigurationRequest {
            analysis_id: initial.analysis_id,
            expected_revision: initial.analysis_revision,
            selection: RecalculateSelection::Preset(PresetSelection {
                preset_id: PresetId::new("balanced").unwrap(),
                overrides: ManualSelection::empty(),
            }),
            context: RequestContext::default(),
        })
        .unwrap();
    assert!(!recalculated.capabilities.available);
    assert_eq!(recalculated.analysis_revision, initial.analysis_revision);
    assert!(recalculated.resolved_configuration.is_none());
    assert!(
        recalculated
            .conflicts
            .iter()
            .any(|value| value.code == framelean_decision::ENGINE_EXECUTION_CHAIN_NOT_READY)
    );
    assert!(
        recalculated
            .warnings
            .iter()
            .any(|warning| { warning.code == EngineErrorCode::MediaBitDepthUnavailable })
    );
    fs::remove_file(path).unwrap();
}

#[test]
fn same_size_content_change_invalidates_snapshot() {
    let path = std::env::temp_dir().join(format!(
        "framelean-runtime-source-change-{}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::write(&path, b"first00").unwrap();
    let mut runtime = runtime();
    let initial = runtime
        .analyze_media(AnalyzeTaskRequest {
            task_mode: TaskMode::VideoCompress,
            media_request: MediaAnalyzeRequest {
                source: MediaSource::local_file(&path).unwrap(),
                request_id: None,
            },
            context: RequestContext::default(),
        })
        .unwrap();

    fs::write(&path, b"second0").unwrap();
    let error = runtime
        .recalculate_configuration(RecalculateConfigurationRequest {
            analysis_id: initial.analysis_id,
            expected_revision: initial.analysis_revision,
            selection: RecalculateSelection::Preset(PresetSelection {
                preset_id: PresetId::new("balanced").unwrap(),
                overrides: ManualSelection::empty(),
            }),
            context: RequestContext::default(),
        })
        .unwrap_err();
    assert_eq!(
        error.code(),
        framelean_core::EngineErrorCode::AnalysisSourceChanged
    );
    fs::remove_file(path).unwrap();
}

#[test]
fn successful_then_failed_selection_updates_snapshot_atomically() {
    let path = std::env::temp_dir().join(format!(
        "framelean-runtime-resolved-{}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::write(&path, b"fixture").unwrap();
    let mut runtime = runtime_with_provider(Arc::new(ReadyCatalog));
    let initial = runtime
        .analyze_media(AnalyzeTaskRequest {
            task_mode: TaskMode::VideoCompress,
            media_request: MediaAnalyzeRequest {
                source: MediaSource::local_file(&path).unwrap(),
                request_id: None,
            },
            context: RequestContext::default(),
        })
        .unwrap();
    assert!(initial.capabilities.as_ref().unwrap().available);

    let resolved = runtime
        .recalculate_configuration(RecalculateConfigurationRequest {
            analysis_id: initial.analysis_id.clone(),
            expected_revision: initial.analysis_revision,
            selection: RecalculateSelection::Manual(ManualSelection {
                container: Some("mp4".to_owned()),
                video_codec: Some("h264".to_owned()),
                audio_codec: None,
                output_pixel_format: Some("yuv420p".to_owned()),
                preserves_hdr: Some(false),
            }),
            context: RequestContext::default(),
        })
        .unwrap();
    assert!(resolved.resolved_configuration.is_some());
    assert_eq!(resolved.analysis_revision.value(), 2);

    let stale_error = runtime
        .recalculate_configuration(RecalculateConfigurationRequest {
            analysis_id: initial.analysis_id.clone(),
            expected_revision: initial.analysis_revision,
            selection: RecalculateSelection::Manual(ManualSelection::empty()),
            context: RequestContext::default(),
        })
        .unwrap_err();
    assert_eq!(
        stale_error.code(),
        framelean_core::EngineErrorCode::AnalysisRevisionConflict
    );

    let rejected = runtime
        .recalculate_configuration(RecalculateConfigurationRequest {
            analysis_id: initial.analysis_id,
            expected_revision: resolved.analysis_revision,
            selection: RecalculateSelection::Manual(ManualSelection {
                container: Some("mp4".to_owned()),
                video_codec: Some("hevc".to_owned()),
                audio_codec: None,
                output_pixel_format: None,
                preserves_hdr: None,
            }),
            context: RequestContext::default(),
        })
        .unwrap();
    assert!(rejected.resolved_configuration.is_none());
    assert_eq!(rejected.analysis_revision.value(), 2);
    assert_eq!(
        rejected.conflicts[0].code,
        framelean_core::EngineErrorCode::MediaCapabilityIncompatible
    );
    fs::remove_file(path).unwrap();
}

#[test]
fn aggregate_media_variants_serialize_for_client_responses() {
    let image = ImageInfo {
        codec: "png".to_owned(),
        width: 1,
        height: 1,
        pixel_format: Observed::detected("rgba".to_owned(), "test"),
        bit_depth: Observed::detected(8, "test"),
        alpha: Observed::detected(true, "test"),
        color_space: Observed::detected("srgb".to_owned(), "test"),
    };
    let audio = || {
        MediaStreamDescriptor::Audio(Box::new(AudioStreamInfo {
            stream_index: 1,
            codec: "aac".to_owned(),
            profile: Observed::detected("lc".to_owned(), "test"),
            sample_rate_hz: Observed::detected(48_000, "test"),
            channel_count: Observed::detected(2, "test"),
            channel_layout: Observed::detected("stereo".to_owned(), "test"),
            sample_format: Observed::detected("fltp".to_owned(), "test"),
            bitrate: Observed::detected(framelean_core::BitRateBps::new(128_000), "test"),
            duration: Observed::detected(
                framelean_media::MediaDuration::new(10, 1).unwrap(),
                "test",
            ),
        }))
    };
    let video = || {
        MediaStreamDescriptor::Video(Box::new(VideoStreamInfo {
            stream_index: 0,
            codec: "h264".to_owned(),
            profile: Observed::detected("main".to_owned(), "test"),
            width: 1920,
            height: 1080,
            frame_rate: Observed::detected(framelean_media::Rational::new(30, 1).unwrap(), "test"),
            frame_count: Observed::detected(300, "test"),
            time_base: framelean_media::Rational::new(1, 90_000).unwrap(),
            bit_depth: Observed::detected(8, "test"),
            pixel_format: Observed::detected("yuv420p".to_owned(), "test"),
            hdr: HdrInfo {
                color_range: Observed::detected("tv".to_owned(), "test"),
                color_space: Observed::detected("bt709".to_owned(), "test"),
                color_transfer: Observed::detected("bt709".to_owned(), "test"),
                color_primaries: Observed::detected("bt709".to_owned(), "test"),
            },
            bitrate: Observed::detected(framelean_core::BitRateBps::new(5_000_000), "test"),
        }))
    };

    let descriptors = vec![
        MediaDescriptor::Image {
            image: Box::new(image.clone()),
        },
        MediaDescriptor::AnimatedImage {
            image: Box::new(image),
            animation: Box::new(AnimationInfo {
                frame_rate: Observed::detected(
                    framelean_media::Rational::new(10, 1).unwrap(),
                    "test",
                ),
                frame_count: Observed::detected(10, "test"),
                duration: Observed::detected(
                    framelean_media::MediaDuration::new(1, 1).unwrap(),
                    "test",
                ),
            }),
        },
        MediaDescriptor::Audio {
            streams: vec![audio()],
        },
        MediaDescriptor::Video {
            streams: vec![video()],
        },
        MediaDescriptor::Video {
            streams: vec![video(), audio(), audio()],
        },
    ];
    for descriptor in descriptors {
        let json = serde_json::to_value(&descriptor).unwrap();
        assert!(json.get("type").is_some());
    }
}
