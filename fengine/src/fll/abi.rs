use std::ffi::c_void;

pub const ABI_MAJOR: u16 = 1;
pub const ABI_MINOR: u16 = 0;
pub const DOCUMENT_VERSION: u16 = 1;

pub const OK: i32 = 0;
pub const INVALID_ARGUMENT: i32 = 1;
pub const RUNTIME_ERROR: i32 = 2;
pub const PANIC: i32 = 3;
pub const BUFFER_ERROR: i32 = 4;
pub const NO_EVENT: i32 = 5;
pub const ABI_MISMATCH: i32 = 6;

pub type RuntimeCreate = unsafe extern "C" fn(
    out_handle: *mut *mut c_void,
    out_error: *mut *mut u8,
    out_error_len: *mut usize,
) -> i32;
pub type RuntimeDestroy = unsafe extern "C" fn(handle: *mut c_void) -> i32;
pub type Invoke = unsafe extern "C" fn(
    handle: *mut c_void,
    request: *const u8,
    request_len: usize,
    out_response: *mut *mut u8,
    out_response_len: *mut usize,
) -> i32;
pub type PollEvent = unsafe extern "C" fn(
    handle: *mut c_void,
    out_event: *mut *mut u8,
    out_event_len: *mut usize,
) -> i32;
pub type BufferFree = unsafe extern "C" fn(buffer: *mut u8, buffer_len: usize);
pub type GetApi = unsafe extern "C" fn(
    requested_major: u16,
    requested_minor: u16,
    out_api: *mut *const ApiV1,
) -> i32;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct ApiV1 {
    pub struct_size: u32,
    pub abi_major: u16,
    pub abi_minor: u16,
    pub runtime_create: RuntimeCreate,
    pub runtime_destroy: RuntimeDestroy,
    pub invoke: Invoke,
    pub poll_event: PollEvent,
    pub buffer_free: BufferFree,
}
