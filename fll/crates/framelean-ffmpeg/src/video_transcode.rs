use std::ffi::{CStr, CString};
use std::path::PathBuf;
use std::ptr;

use framelean_core::{EngineError, EngineErrorCode, ErrorKind, Result};
use rusty_ffmpeg::ffi;

use super::{InputContext, OutputContext, Packet};

const MICROSECONDS_TIME_BASE: ffi::AVRational = ffi::AVRational {
    num: 1,
    den: 1_000_000,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VideoTranscodeRequest {
    pub input_path: PathBuf,
    pub output_path: PathBuf,
    pub input_stream_index: u32,
    pub decoder_name: String,
    pub encoder_name: String,
    pub output_pixel_format: String,
    pub output_profile: Option<String>,
    pub target_bitrate_bps: Option<u64>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct TranscodeProgress {
    pub media_time_us: u64,
    pub processed_bytes: u64,
    pub decoded_frames: u64,
    pub encoded_packets: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TranscodeControl {
    Continue,
    Cancel,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TranscodeOutcome {
    Completed(TranscodeProgress),
    Cancelled(TranscodeProgress),
}

pub(super) fn transcode_video(
    request: &VideoTranscodeRequest,
    mut control: impl FnMut(TranscodeProgress) -> TranscodeControl,
) -> Result<TranscodeOutcome> {
    validate_request(request)?;
    let input = InputContext::open(&request.input_path)?;
    let input_stream = selected_video_stream(&input, request.input_stream_index)?;
    validate_video_only_input(&input, request.input_stream_index)?;

    let decoder_name = c_string(&request.decoder_name, "decoder name")?;
    // SAFETY: decoder_name is a valid, null-terminated codec name.
    let decoder = unsafe { ffi::avcodec_find_decoder_by_name(decoder_name.as_ptr()) };
    if decoder.is_null() {
        return Err(chain_not_ready(format!(
            "selected decoder {} is unavailable",
            request.decoder_name
        )));
    }
    let decoder_context = CodecContext::decoder(decoder, input_stream.codecpar)?;

    let encoder_name = c_string(&request.encoder_name, "encoder name")?;
    // SAFETY: encoder_name is a valid, null-terminated codec name.
    let encoder = unsafe { ffi::avcodec_find_encoder_by_name(encoder_name.as_ptr()) };
    if encoder.is_null() {
        return Err(chain_not_ready(format!(
            "selected encoder {} is unavailable",
            request.encoder_name
        )));
    }

    let output_pixel_format = c_string(&request.output_pixel_format, "output pixel format")?;
    // SAFETY: output_pixel_format is a valid, null-terminated pixel format name.
    let pixel_format = unsafe { ffi::av_get_pix_fmt(output_pixel_format.as_ptr()) };
    if pixel_format == ffi::AV_PIX_FMT_NONE {
        return Err(chain_not_ready(format!(
            "selected output pixel format {} is unavailable",
            request.output_pixel_format
        )));
    }
    if !codec_supports_pixel_format(encoder, pixel_format) {
        return Err(chain_not_ready(format!(
            "encoder {} does not support pixel format {}",
            request.encoder_name, request.output_pixel_format
        )));
    }

    let mut output = OutputContext::create(&request.output_path)?;
    let frame_rate = input_frame_rate(&input, input_stream);
    let encoder_context = CodecContext::video_encoder(
        encoder,
        &decoder_context,
        pixel_format,
        frame_rate,
        request.target_bitrate_bps,
        request.output_profile.as_deref(),
        output_requires_global_header(&output),
    )?;
    let output_stream = create_output_stream(&mut output, &encoder_context)?;
    output.open_io(&request.output_path)?;
    output.write_header()?;

    let input_time_base = input_stream.time_base;
    let encoder_time_base = encoder_context.as_ref().time_base;
    let output_time_base = unsafe { (*output_stream).time_base };
    let input_packet = Packet::new_for_execution()?;
    let encoded_packet = Packet::new_for_execution()?;
    let decoded_frame = Frame::new()?;
    let mut converter = FrameConverter::default();
    let mut next_pts = 0_i64;
    let mut progress = TranscodeProgress::default();

    loop {
        // SAFETY: input and packet are valid owned pointers.
        let read_result = unsafe { ffi::av_read_frame(input.0, input_packet.0) };
        if read_result == ffi::AVERROR_EOF {
            break;
        }
        if read_result < 0 {
            return Err(native_execution_error(
                EngineErrorCode::MediaInfoReadFailed,
                "failed while reading video packets",
                read_result,
            ));
        }
        // SAFETY: av_read_frame initialized the packet.
        let packet_ref = unsafe { &*input_packet.0 };
        if packet_ref.stream_index != request.input_stream_index as i32 {
            // SAFETY: packet is allocated and initialized.
            unsafe { ffi::av_packet_unref(input_packet.0) };
            continue;
        }

        update_input_progress(&mut progress, packet_ref, input_time_base);
        if control(progress) == TranscodeControl::Cancel {
            // SAFETY: packet is allocated and initialized.
            unsafe { ffi::av_packet_unref(input_packet.0) };
            return Ok(TranscodeOutcome::Cancelled(progress));
        }

        send_packet(decoder_context.0, input_packet.0)?;
        // SAFETY: decoder has consumed or referenced the packet contents.
        unsafe { ffi::av_packet_unref(input_packet.0) };
        receive_and_encode_frames(
            decoder_context.0,
            &decoded_frame,
            &mut converter,
            encoder_context.0,
            &encoded_packet,
            output.context,
            output_stream,
            input_time_base,
            encoder_time_base,
            output_time_base,
            &mut next_pts,
            &mut progress,
        )?;
    }

    send_packet(decoder_context.0, ptr::null())?;
    receive_and_encode_frames(
        decoder_context.0,
        &decoded_frame,
        &mut converter,
        encoder_context.0,
        &encoded_packet,
        output.context,
        output_stream,
        input_time_base,
        encoder_time_base,
        output_time_base,
        &mut next_pts,
        &mut progress,
    )?;
    send_frame(encoder_context.0, ptr::null())?;
    drain_encoder(
        encoder_context.0,
        &encoded_packet,
        output.context,
        output_stream,
        encoder_time_base,
        output_time_base,
        &mut progress,
    )?;
    output.write_trailer()?;
    Ok(TranscodeOutcome::Completed(progress))
}

fn validate_request(request: &VideoTranscodeRequest) -> Result<()> {
    if request.decoder_name.trim().is_empty()
        || request.encoder_name.trim().is_empty()
        || request.output_pixel_format.trim().is_empty()
    {
        return Err(EngineError::invalid_argument(
            "video transcode decoder, encoder, and pixel format must be specified",
        ));
    }
    if request.target_bitrate_bps == Some(0) {
        return Err(EngineError::invalid_argument(
            "video target bitrate must be greater than zero",
        ));
    }
    Ok(())
}

fn selected_video_stream(input: &InputContext, stream_index: u32) -> Result<&ffi::AVStream> {
    if stream_index >= input.as_ref().nb_streams {
        return Err(chain_not_ready("selected video stream does not exist"));
    }
    // SAFETY: stream_index is bounded by nb_streams.
    let stream = unsafe { &**input.as_ref().streams.add(stream_index as usize) };
    // SAFETY: codecpar is owned by the input stream.
    let parameters = unsafe { &*stream.codecpar };
    if parameters.codec_type != ffi::AVMEDIA_TYPE_VIDEO {
        return Err(chain_not_ready("selected stream is not video"));
    }
    Ok(stream)
}

fn validate_video_only_input(input: &InputContext, selected_stream_index: u32) -> Result<()> {
    if input.as_ref().nb_streams != 1 || selected_stream_index != 0 {
        return Err(chain_not_ready(
            "the current video transcode backend supports exactly one video stream",
        ));
    }
    Ok(())
}

fn c_string(value: &str, field: &str) -> Result<CString> {
    CString::new(value)
        .map_err(|_| EngineError::invalid_argument(format!("{field} contains a null byte")))
}

struct CodecContext(*mut ffi::AVCodecContext);

impl CodecContext {
    fn decoder(
        codec: *const ffi::AVCodec,
        parameters: *const ffi::AVCodecParameters,
    ) -> Result<Self> {
        // SAFETY: codec is a process-owned descriptor returned by libavcodec.
        let context = unsafe { ffi::avcodec_alloc_context3(codec) };
        if context.is_null() {
            return Err(native_allocation_error("video decoder context"));
        }
        let owned = Self(context);
        // SAFETY: both pointers are valid and context is exclusively owned.
        let copy_result = unsafe { ffi::avcodec_parameters_to_context(owned.0, parameters) };
        if copy_result < 0 {
            return Err(native_execution_error(
                EngineErrorCode::MediaInfoReadFailed,
                "failed to initialize video decoder parameters",
                copy_result,
            ));
        }
        // SAFETY: context and codec are compatible and options are omitted.
        let open_result = unsafe { ffi::avcodec_open2(owned.0, codec, ptr::null_mut()) };
        if open_result < 0 {
            return Err(native_execution_error(
                EngineErrorCode::MediaCapabilityIncompatible,
                "failed to open the selected video decoder",
                open_result,
            ));
        }
        Ok(owned)
    }

    #[allow(clippy::too_many_arguments)]
    fn video_encoder(
        codec: *const ffi::AVCodec,
        decoder: &CodecContext,
        pixel_format: ffi::AVPixelFormat,
        frame_rate: ffi::AVRational,
        target_bitrate_bps: Option<u64>,
        profile: Option<&str>,
        global_header: bool,
    ) -> Result<Self> {
        // SAFETY: codec is a process-owned descriptor returned by libavcodec.
        let context = unsafe { ffi::avcodec_alloc_context3(codec) };
        if context.is_null() {
            return Err(native_allocation_error("video encoder context"));
        }
        let owned = Self(context);
        let decoder = decoder.as_ref();
        let frame_rate = valid_frame_rate(frame_rate);
        // SAFETY: context is exclusively owned and fields are initialized before open.
        unsafe {
            (*owned.0).width = decoder.width;
            (*owned.0).height = decoder.height;
            (*owned.0).sample_aspect_ratio = decoder.sample_aspect_ratio;
            (*owned.0).pix_fmt = pixel_format;
            (*owned.0).framerate = frame_rate;
            (*owned.0).time_base = ffi::av_inv_q(frame_rate);
            (*owned.0).bit_rate =
                target_bitrate_bps.unwrap_or(2_000_000).min(i64::MAX as u64) as i64;
            (*owned.0).gop_size = 48;
            (*owned.0).max_b_frames = 2;
            (*owned.0).color_range = decoder.color_range;
            (*owned.0).color_primaries = decoder.color_primaries;
            (*owned.0).color_trc = decoder.color_trc;
            (*owned.0).colorspace = decoder.colorspace;
            if global_header {
                (*owned.0).flags |= ffi::AV_CODEC_FLAG_GLOBAL_HEADER as i32;
            }
        }
        let mut options = ptr::null_mut();
        set_dictionary_option(&mut options, "preset", "medium")?;
        if let Some(profile) = profile {
            set_dictionary_option(&mut options, "profile", profile)?;
        }
        // SAFETY: context and codec are compatible; options is owned and freed below.
        let open_result = unsafe { ffi::avcodec_open2(owned.0, codec, &mut options) };
        // SAFETY: options is either null or owned by this call site.
        unsafe { ffi::av_dict_free(&mut options) };
        if open_result < 0 {
            return Err(native_execution_error(
                EngineErrorCode::MediaCapabilityIncompatible,
                "failed to open the selected video encoder",
                open_result,
            ));
        }
        Ok(owned)
    }

    fn as_ref(&self) -> &ffi::AVCodecContext {
        // SAFETY: CodecContext owns a non-null context until Drop.
        unsafe { &*self.0 }
    }
}

impl Drop for CodecContext {
    fn drop(&mut self) {
        // SAFETY: context is owned by this guard and freed exactly once.
        unsafe { ffi::avcodec_free_context(&mut self.0) };
    }
}

struct Frame(*mut ffi::AVFrame);

impl Frame {
    fn new() -> Result<Self> {
        // SAFETY: allocation has no pointer preconditions.
        let frame = unsafe { ffi::av_frame_alloc() };
        if frame.is_null() {
            return Err(native_allocation_error("video frame"));
        }
        Ok(Self(frame))
    }

    fn new_video(width: i32, height: i32, pixel_format: ffi::AVPixelFormat) -> Result<Self> {
        let frame = Self::new()?;
        // SAFETY: frame is exclusively owned and fields are initialized before allocation.
        unsafe {
            (*frame.0).width = width;
            (*frame.0).height = height;
            (*frame.0).format = pixel_format;
        }
        // SAFETY: frame dimensions and pixel format were initialized above.
        let result = unsafe { ffi::av_frame_get_buffer(frame.0, 32) };
        if result < 0 {
            return Err(native_execution_error(
                EngineErrorCode::MediaPixelFormatUnavailable,
                "failed to allocate converted video frame",
                result,
            ));
        }
        Ok(frame)
    }
}

impl Drop for Frame {
    fn drop(&mut self) {
        // SAFETY: frame is owned by this guard and freed exactly once.
        unsafe { ffi::av_frame_free(&mut self.0) };
    }
}

#[derive(Default)]
struct FrameConverter {
    context: *mut ffi::SwsContext,
    source_width: i32,
    source_height: i32,
    source_format: ffi::AVPixelFormat,
    output: Option<Frame>,
}

impl FrameConverter {
    fn convert(
        &mut self,
        source: *const ffi::AVFrame,
        target_format: ffi::AVPixelFormat,
    ) -> Result<*const ffi::AVFrame> {
        // SAFETY: source was populated by avcodec_receive_frame.
        let source_ref = unsafe { &*source };
        if source_ref.format == target_format {
            return Ok(source);
        }
        let source_format = source_ref.format as ffi::AVPixelFormat;
        if self.context.is_null()
            || self.source_width != source_ref.width
            || self.source_height != source_ref.height
            || self.source_format != source_format
        {
            self.reset();
            // SAFETY: dimensions and pixel formats come from decoder/encoder contexts.
            self.context = unsafe {
                ffi::sws_getContext(
                    source_ref.width,
                    source_ref.height,
                    source_format,
                    source_ref.width,
                    source_ref.height,
                    target_format,
                    ffi::SWS_BICUBIC as i32,
                    ptr::null_mut(),
                    ptr::null_mut(),
                    ptr::null(),
                )
            };
            if self.context.is_null() {
                return Err(chain_not_ready(
                    "failed to initialize the selected video processor",
                ));
            }
            self.output = Some(Frame::new_video(
                source_ref.width,
                source_ref.height,
                target_format,
            )?);
            self.source_width = source_ref.width;
            self.source_height = source_ref.height;
            self.source_format = source_format;
        }
        let output = self
            .output
            .as_ref()
            .expect("converter output is allocated with its context");
        // SAFETY: output frame owns writable buffers.
        let writable = unsafe { ffi::av_frame_make_writable(output.0) };
        if writable < 0 {
            return Err(native_execution_error(
                EngineErrorCode::MediaPixelFormatUnavailable,
                "converted video frame is not writable",
                writable,
            ));
        }
        // SAFETY: source data is decoder-owned and output buffers match the target format.
        let scaled = unsafe {
            ffi::sws_scale(
                self.context,
                source_ref.data.as_ptr() as *const *const u8,
                source_ref.linesize.as_ptr(),
                0,
                source_ref.height,
                (*output.0).data.as_ptr(),
                (*output.0).linesize.as_ptr(),
            )
        };
        if scaled != source_ref.height {
            return Err(chain_not_ready(
                "selected video processor returned an incomplete frame",
            ));
        }
        // SAFETY: both frames are valid and output is exclusively owned.
        unsafe {
            (*output.0).pts = source_ref.pts;
            (*output.0).sample_aspect_ratio = source_ref.sample_aspect_ratio;
            (*output.0).color_range = source_ref.color_range;
            (*output.0).color_primaries = source_ref.color_primaries;
            (*output.0).color_trc = source_ref.color_trc;
            (*output.0).colorspace = source_ref.colorspace;
        }
        Ok(output.0)
    }

    fn reset(&mut self) {
        if !self.context.is_null() {
            // SAFETY: context is owned by this converter and freed exactly once.
            unsafe { ffi::sws_freeContext(self.context) };
            self.context = ptr::null_mut();
        }
        self.output = None;
    }
}

impl Drop for FrameConverter {
    fn drop(&mut self) {
        self.reset();
    }
}

#[allow(clippy::too_many_arguments)]
fn receive_and_encode_frames(
    decoder: *mut ffi::AVCodecContext,
    decoded_frame: &Frame,
    converter: &mut FrameConverter,
    encoder: *mut ffi::AVCodecContext,
    encoded_packet: &Packet,
    output: *mut ffi::AVFormatContext,
    output_stream: *mut ffi::AVStream,
    input_time_base: ffi::AVRational,
    encoder_time_base: ffi::AVRational,
    output_time_base: ffi::AVRational,
    next_pts: &mut i64,
    progress: &mut TranscodeProgress,
) -> Result<()> {
    loop {
        // SAFETY: decoder and frame are valid and exclusively used here.
        let result = unsafe { ffi::avcodec_receive_frame(decoder, decoded_frame.0) };
        if result == ffi::AVERROR(ffi::EAGAIN) || result == ffi::AVERROR_EOF {
            return Ok(());
        }
        if result < 0 {
            return Err(native_execution_error(
                EngineErrorCode::MediaInfoReadFailed,
                "failed to receive a decoded video frame",
                result,
            ));
        }
        // SAFETY: avcodec_receive_frame populated the frame.
        let frame_ref = unsafe { &mut *decoded_frame.0 };
        let source_timestamp = if frame_ref.best_effort_timestamp != ffi::AV_NOPTS_VALUE {
            frame_ref.best_effort_timestamp
        } else {
            frame_ref.pts
        };
        let pts = if source_timestamp == ffi::AV_NOPTS_VALUE {
            *next_pts
        } else {
            // SAFETY: stream and encoder time bases are valid.
            unsafe { ffi::av_rescale_q(source_timestamp, input_time_base, encoder_time_base) }
                .max(*next_pts)
        };
        frame_ref.pts = pts;
        *next_pts = pts.saturating_add(1);
        let converted = converter.convert(decoded_frame.0, unsafe { (*encoder).pix_fmt })?;
        send_frame(encoder, converted)?;
        progress.decoded_frames = progress.decoded_frames.saturating_add(1);
        drain_encoder(
            encoder,
            encoded_packet,
            output,
            output_stream,
            encoder_time_base,
            output_time_base,
            progress,
        )?;
        // SAFETY: decoded frame is allocated and may release references for reuse.
        unsafe { ffi::av_frame_unref(decoded_frame.0) };
    }
}

fn drain_encoder(
    encoder: *mut ffi::AVCodecContext,
    encoded_packet: &Packet,
    output: *mut ffi::AVFormatContext,
    output_stream: *mut ffi::AVStream,
    encoder_time_base: ffi::AVRational,
    output_time_base: ffi::AVRational,
    progress: &mut TranscodeProgress,
) -> Result<()> {
    loop {
        // SAFETY: encoder and packet are valid and exclusively used here.
        let result = unsafe { ffi::avcodec_receive_packet(encoder, encoded_packet.0) };
        if result == ffi::AVERROR(ffi::EAGAIN) || result == ffi::AVERROR_EOF {
            return Ok(());
        }
        if result < 0 {
            return Err(native_execution_error(
                EngineErrorCode::MediaInfoReadFailed,
                "failed to receive an encoded video packet",
                result,
            ));
        }
        // SAFETY: packet and output stream are valid.
        unsafe {
            ffi::av_packet_rescale_ts(encoded_packet.0, encoder_time_base, output_time_base);
            (*encoded_packet.0).stream_index = (*output_stream).index;
        }
        // SAFETY: output header was written and packet timestamps use output time base.
        let write_result = unsafe { ffi::av_interleaved_write_frame(output, encoded_packet.0) };
        if write_result < 0 {
            return Err(native_execution_error(
                EngineErrorCode::OutputContainerNotWritable,
                "failed to write encoded video packet",
                write_result,
            ));
        }
        progress.encoded_packets = progress.encoded_packets.saturating_add(1);
        // SAFETY: packet is allocated and may release references for reuse.
        unsafe { ffi::av_packet_unref(encoded_packet.0) };
    }
}

fn send_packet(decoder: *mut ffi::AVCodecContext, packet: *const ffi::AVPacket) -> Result<()> {
    // SAFETY: decoder is open and packet is either valid or null for flush.
    let result = unsafe { ffi::avcodec_send_packet(decoder, packet) };
    if result < 0 && result != ffi::AVERROR_EOF {
        return Err(native_execution_error(
            EngineErrorCode::MediaInfoReadFailed,
            "failed to send a packet to the video decoder",
            result,
        ));
    }
    Ok(())
}

fn send_frame(encoder: *mut ffi::AVCodecContext, frame: *const ffi::AVFrame) -> Result<()> {
    // SAFETY: encoder is open and frame is either valid or null for flush.
    let result = unsafe { ffi::avcodec_send_frame(encoder, frame) };
    if result < 0 && result != ffi::AVERROR_EOF {
        return Err(native_execution_error(
            EngineErrorCode::MediaInfoReadFailed,
            "failed to send a frame to the video encoder",
            result,
        ));
    }
    Ok(())
}

fn create_output_stream(
    output: &mut OutputContext,
    encoder: &CodecContext,
) -> Result<*mut ffi::AVStream> {
    // SAFETY: output owns a valid format context.
    let stream = unsafe { ffi::avformat_new_stream(output.context, ptr::null()) };
    if stream.is_null() {
        return Err(EngineError::with_code(
            ErrorKind::Runtime,
            EngineErrorCode::OutputContainerNotWritable,
            "failed to create encoded video output stream",
        ));
    }
    // SAFETY: stream codec parameters and encoder context are valid.
    let result = unsafe { ffi::avcodec_parameters_from_context((*stream).codecpar, encoder.0) };
    if result < 0 {
        return Err(native_execution_error(
            EngineErrorCode::OutputContainerNotWritable,
            "failed to export encoded video parameters",
            result,
        ));
    }
    // SAFETY: stream is owned by output and exclusively initialized here.
    unsafe {
        (*(*stream).codecpar).codec_tag = 0;
        (*stream).time_base = encoder.as_ref().time_base;
    }
    Ok(stream)
}

fn output_requires_global_header(output: &OutputContext) -> bool {
    // SAFETY: output format is initialized with the context.
    unsafe { (*output.as_ref().oformat).flags & ffi::AVFMT_GLOBALHEADER as i32 != 0 }
}

fn input_frame_rate(input: &InputContext, stream: &ffi::AVStream) -> ffi::AVRational {
    // SAFETY: input and stream belong to the same live format context.
    let guessed =
        unsafe { ffi::av_guess_frame_rate(input.0, stream as *const _ as *mut _, ptr::null_mut()) };
    if guessed.num > 0 && guessed.den > 0 {
        guessed
    } else if stream.avg_frame_rate.num > 0 && stream.avg_frame_rate.den > 0 {
        stream.avg_frame_rate
    } else if stream.r_frame_rate.num > 0 && stream.r_frame_rate.den > 0 {
        stream.r_frame_rate
    } else {
        ffi::AVRational { num: 30, den: 1 }
    }
}

fn valid_frame_rate(value: ffi::AVRational) -> ffi::AVRational {
    if value.num > 0 && value.den > 0 {
        value
    } else {
        ffi::AVRational { num: 30, den: 1 }
    }
}

fn codec_supports_pixel_format(
    codec: *const ffi::AVCodec,
    pixel_format: ffi::AVPixelFormat,
) -> bool {
    // SAFETY: codec is a valid process-owned descriptor.
    let formats = unsafe { (*codec).pix_fmts };
    if formats.is_null() {
        return false;
    }
    let mut index = 0;
    loop {
        // SAFETY: pix_fmts is terminated by AV_PIX_FMT_NONE.
        let current = unsafe { *formats.add(index) };
        if current == ffi::AV_PIX_FMT_NONE {
            return false;
        }
        if current == pixel_format {
            return true;
        }
        index += 1;
    }
}

fn set_dictionary_option(
    dictionary: &mut *mut ffi::AVDictionary,
    key: &str,
    value: &str,
) -> Result<()> {
    let key = c_string(key, "encoder option key")?;
    let value = c_string(value, "encoder option value")?;
    // SAFETY: dictionary is an owned out pointer and strings live for the call.
    let result = unsafe { ffi::av_dict_set(dictionary, key.as_ptr(), value.as_ptr(), 0) };
    if result < 0 {
        return Err(native_execution_error(
            EngineErrorCode::MediaCapabilityIncompatible,
            "failed to configure the selected video encoder",
            result,
        ));
    }
    Ok(())
}

fn update_input_progress(
    progress: &mut TranscodeProgress,
    packet: &ffi::AVPacket,
    time_base: ffi::AVRational,
) {
    let timestamp = if packet.pts != ffi::AV_NOPTS_VALUE {
        packet.pts
    } else {
        packet.dts
    };
    if timestamp != ffi::AV_NOPTS_VALUE {
        // SAFETY: packet and microsecond time bases are valid.
        let media_time_us =
            unsafe { ffi::av_rescale_q(timestamp, time_base, MICROSECONDS_TIME_BASE) };
        progress.media_time_us = progress.media_time_us.max(media_time_us.max(0) as u64);
    }
    progress.processed_bytes = progress
        .processed_bytes
        .saturating_add(packet.size.max(0) as u64);
}

fn native_allocation_error(resource: &str) -> EngineError {
    EngineError::with_code(
        ErrorKind::Runtime,
        EngineErrorCode::NativeLibraryUnavailable,
        format!("failed to allocate {resource}"),
    )
}

fn chain_not_ready(message: impl Into<String>) -> EngineError {
    EngineError::with_code(
        ErrorKind::Pipeline,
        EngineErrorCode::EngineExecutionChainNotReady,
        message,
    )
}

fn native_execution_error(error_code: EngineErrorCode, message: &str, code: i32) -> EngineError {
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
        ErrorKind::Runtime,
        error_code,
        format!("{message}: {description}"),
    )
}
