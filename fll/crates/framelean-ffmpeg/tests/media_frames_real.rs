use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use framelean_ffmpeg::{
    FfmpegAdapter, PreviewFramesRequest, TranscodeControl, TranscodeOutcome, VideoThumbnailRequest,
    VideoTranscodeRequest,
};

#[test]
fn real_libav_video_generates_preview_frames_and_a_visible_thumbnail() {
    let fixture = TestDirectory::new("media-frames");
    let input_path = fixture.path.join("three-frames.avi");
    fs::write(&input_path, uncompressed_avi_fixture()).unwrap();

    let adapter = FfmpegAdapter::new().unwrap();
    let preview_directory = fixture.path.join("previews");
    let previews = adapter
        .generate_preview_frames(&PreviewFramesRequest {
            input_path: input_path.clone(),
            output_directory: preview_directory.clone(),
            timestamps_us: vec![0, 1_000_000],
            max_width: Some(1),
        })
        .unwrap();

    assert_eq!(previews.output_directory, preview_directory);
    assert_eq!(previews.frames.len(), 2);
    assert_eq!(previews.frames[0].requested_timestamp_us, 0);
    assert_eq!(previews.frames[1].requested_timestamp_us, 1_000_000);
    for frame in &previews.frames {
        assert_eq!((frame.width, frame.height), (1, 1));
        assert_valid_bmp(&frame.output_path, 1, 1);
    }
    assert!(fs::read_dir(&preview_directory).unwrap().all(|entry| {
        !entry
            .unwrap()
            .file_name()
            .to_string_lossy()
            .contains(".tmp-")
    }));

    let thumbnail_path = fixture.path.join("thumbnail.bmp");
    let thumbnail = adapter
        .generate_video_thumbnail(&VideoThumbnailRequest {
            input_path,
            output_path: thumbnail_path.clone(),
            duration_us: Some(1_500_000),
            max_width: 1,
        })
        .unwrap();

    assert_eq!(thumbnail.output_path, thumbnail_path);
    assert_eq!((thumbnail.width, thumbnail.height), (1, 1));
    assert!(thumbnail.requested_timestamp_us >= 100_000);
    let thumbnail_bytes = assert_valid_bmp(&thumbnail.output_path, 1, 1);
    assert!(
        thumbnail_bytes[54..].iter().any(|value| *value != 0),
        "thumbnail policy must skip the black frames and publish a visible frame"
    );
    assert!(
        !thumbnail
            .output_path
            .with_extension(format!("tmp-{}", std::process::id()))
            .exists()
    );
}

#[test]
fn real_libav_decodes_converts_encodes_and_muxes_video_without_cli() {
    let fixture = TestDirectory::new("video-transcode");
    let input_path = fixture.path.join("input.avi");
    let output_path = fixture.path.join("output.mp4");
    fs::write(&input_path, uncompressed_avi_fixture()).unwrap();

    let adapter = FfmpegAdapter::new().unwrap();
    let mut progress_events = Vec::new();
    let outcome = adapter
        .transcode_video(
            &VideoTranscodeRequest {
                input_path,
                output_path: output_path.clone(),
                input_stream_index: 0,
                decoder_name: "rawvideo".to_owned(),
                encoder_name: "libx264".to_owned(),
                output_pixel_format: "yuv420p".to_owned(),
                output_profile: Some("main".to_owned()),
                target_bitrate_bps: Some(180_000),
            },
            |progress| {
                progress_events.push(progress);
                TranscodeControl::Continue
            },
        )
        .unwrap();

    let TranscodeOutcome::Completed(progress) = outcome else {
        panic!("video transcode unexpectedly cancelled");
    };
    assert!(progress.processed_bytes > 0);
    assert!(progress.decoded_frames >= 3);
    assert!(progress.encoded_packets > 0);
    assert!(!progress_events.is_empty());
    assert!(fs::metadata(&output_path).unwrap().len() > 64);

    let previews = adapter
        .generate_preview_frames(&PreviewFramesRequest {
            input_path: output_path,
            output_directory: fixture.path.join("transcoded-previews"),
            timestamps_us: vec![0],
            max_width: Some(2),
        })
        .unwrap();
    assert_eq!(previews.frames.len(), 1);
    assert_valid_bmp(&previews.frames[0].output_path, 2, 2);
}

fn assert_valid_bmp(path: &Path, width: i32, height: i32) -> Vec<u8> {
    let bytes = fs::read(path).unwrap();
    assert_eq!(&bytes[0..2], b"BM");
    assert_eq!(i32::from_le_bytes(bytes[18..22].try_into().unwrap()), width);
    assert_eq!(
        i32::from_le_bytes(bytes[22..26].try_into().unwrap()),
        height
    );
    assert_eq!(u16::from_le_bytes(bytes[28..30].try_into().unwrap()), 24);
    bytes
}

fn uncompressed_avi_fixture() -> Vec<u8> {
    const WIDTH: u32 = 2;
    const HEIGHT: u32 = 2;
    const FRAME_BYTES: u32 = 16;
    let frames = [
        vec![0; FRAME_BYTES as usize],
        vec![0; FRAME_BYTES as usize],
        visible_bgr_frame(),
    ];

    let mut main_header = Vec::with_capacity(56);
    push_u32(&mut main_header, 500_000);
    push_u32(&mut main_header, FRAME_BYTES * 2);
    push_u32(&mut main_header, 0);
    push_u32(&mut main_header, 0x10);
    push_u32(&mut main_header, frames.len() as u32);
    push_u32(&mut main_header, 0);
    push_u32(&mut main_header, 1);
    push_u32(&mut main_header, FRAME_BYTES);
    push_u32(&mut main_header, WIDTH);
    push_u32(&mut main_header, HEIGHT);
    main_header.extend_from_slice(&[0; 16]);

    let mut stream_header = Vec::with_capacity(56);
    stream_header.extend_from_slice(b"vids");
    stream_header.extend_from_slice(b"DIB ");
    push_u32(&mut stream_header, 0);
    push_u16(&mut stream_header, 0);
    push_u16(&mut stream_header, 0);
    push_u32(&mut stream_header, 0);
    push_u32(&mut stream_header, 1);
    push_u32(&mut stream_header, 2);
    push_u32(&mut stream_header, 0);
    push_u32(&mut stream_header, frames.len() as u32);
    push_u32(&mut stream_header, FRAME_BYTES);
    push_u32(&mut stream_header, u32::MAX);
    push_u32(&mut stream_header, 0);
    push_i16(&mut stream_header, 0);
    push_i16(&mut stream_header, 0);
    push_i16(&mut stream_header, WIDTH as i16);
    push_i16(&mut stream_header, HEIGHT as i16);

    let mut bitmap_info = Vec::with_capacity(40);
    push_u32(&mut bitmap_info, 40);
    push_i32(&mut bitmap_info, WIDTH as i32);
    push_i32(&mut bitmap_info, HEIGHT as i32);
    push_u16(&mut bitmap_info, 1);
    push_u16(&mut bitmap_info, 24);
    push_u32(&mut bitmap_info, 0);
    push_u32(&mut bitmap_info, FRAME_BYTES);
    push_i32(&mut bitmap_info, 0);
    push_i32(&mut bitmap_info, 0);
    push_u32(&mut bitmap_info, 0);
    push_u32(&mut bitmap_info, 0);

    let stream_list = list_chunk(
        b"strl",
        [
            riff_chunk(b"strh", stream_header),
            riff_chunk(b"strf", bitmap_info),
        ]
        .concat(),
    );
    let header_list = list_chunk(
        b"hdrl",
        [riff_chunk(b"avih", main_header), stream_list].concat(),
    );

    let mut movie_data = Vec::new();
    let mut index_data = Vec::new();
    let mut offset = 4_u32;
    for frame in frames {
        let frame_size = frame.len() as u32;
        movie_data.extend_from_slice(&riff_chunk(b"00db", frame));
        index_data.extend_from_slice(b"00db");
        push_u32(&mut index_data, 0x10);
        push_u32(&mut index_data, offset);
        push_u32(&mut index_data, frame_size);
        offset += 8 + frame_size + (frame_size & 1);
    }

    let contents = [
        header_list,
        list_chunk(b"movi", movie_data),
        riff_chunk(b"idx1", index_data),
    ]
    .concat();
    riff_file(b"AVI ", contents)
}

fn visible_bgr_frame() -> Vec<u8> {
    let mut frame = Vec::with_capacity(16);
    for _ in 0..2 {
        frame.extend_from_slice(&[0, 255, 0, 0, 255, 0]);
        frame.extend_from_slice(&[0, 0]);
    }
    frame
}

fn riff_file(kind: &[u8; 4], contents: Vec<u8>) -> Vec<u8> {
    let mut bytes = Vec::with_capacity(12 + contents.len());
    bytes.extend_from_slice(b"RIFF");
    push_u32(&mut bytes, (4 + contents.len()) as u32);
    bytes.extend_from_slice(kind);
    bytes.extend_from_slice(&contents);
    bytes
}

fn list_chunk(kind: &[u8; 4], contents: Vec<u8>) -> Vec<u8> {
    let mut data = Vec::with_capacity(4 + contents.len());
    data.extend_from_slice(kind);
    data.extend_from_slice(&contents);
    riff_chunk(b"LIST", data)
}

fn riff_chunk(tag: &[u8; 4], mut data: Vec<u8>) -> Vec<u8> {
    let data_len = data.len();
    let mut bytes = Vec::with_capacity(8 + data_len + (data_len & 1));
    bytes.extend_from_slice(tag);
    push_u32(&mut bytes, data_len as u32);
    bytes.append(&mut data);
    if data_len & 1 != 0 {
        bytes.push(0);
    }
    bytes
}

fn push_u16(bytes: &mut Vec<u8>, value: u16) {
    bytes.extend_from_slice(&value.to_le_bytes());
}

fn push_i16(bytes: &mut Vec<u8>, value: i16) {
    bytes.extend_from_slice(&value.to_le_bytes());
}

fn push_u32(bytes: &mut Vec<u8>, value: u32) {
    bytes.extend_from_slice(&value.to_le_bytes());
}

fn push_i32(bytes: &mut Vec<u8>, value: i32) {
    bytes.extend_from_slice(&value.to_le_bytes());
}

struct TestDirectory {
    path: PathBuf,
}

impl TestDirectory {
    fn new(label: &str) -> Self {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path =
            std::env::temp_dir().join(format!("framelean-{label}-{}-{nonce}", std::process::id()));
        fs::create_dir_all(&path).unwrap();
        Self { path }
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.path);
    }
}
