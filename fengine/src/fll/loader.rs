use std::env;
use std::ffi::c_void;
use std::mem::size_of;
use std::path::{Path, PathBuf};

use framelean_core::{EngineError, EngineErrorCode, ErrorKind, Result};
use libloading::Library;

use super::abi::{self, ApiV1};
use super::documents::decode_response;

const MAX_BUFFER_BYTES: usize = 64 * 1024 * 1024;
const LIBRARY_ENV: &str = "FRAMELEAN_FLL_LIBRARY";

pub(crate) struct FllLoader {
    library: Library,
    api: ApiV1,
    handle: RuntimeHandle,
}

/// A runtime handle is an opaque pointer owned by the loaded FLL library. The FLL runtime
/// serializes access internally; this wrapper only stores the pointer as an integer so the host
/// can move the owning adapter into FEngine's executor thread without exposing the pointer in a
/// public API or implementing Send for the whole loader. It is converted back only at ABI calls,
/// while the Library remains owned by the same loader.
#[derive(Debug)]
struct RuntimeHandle(usize);

impl RuntimeHandle {
    fn new(pointer: *mut c_void) -> Self {
        Self(pointer as usize)
    }

    fn is_valid(&self) -> bool {
        self.0 != 0
    }

    fn as_ptr(&self) -> *mut c_void {
        self.0 as *mut c_void
    }
}

impl FllLoader {
    pub(crate) fn load(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref().to_path_buf();
        // SAFETY: loading a user-selected native library is the explicit Phase 2A boundary. The
        // handle remains owned by this value for the whole lifetime of the resolved symbols.
        let library = unsafe { Library::new(&path) }.map_err(|error| {
            EngineError::with_source_code(
                ErrorKind::NativeLibrary,
                EngineErrorCode::NativeLibraryUnavailable,
                format!("cannot load FLL dynamic library {}", path.display()),
                error,
            )
        })?;
        // SAFETY: the symbol name and function signature are part of the versioned FLL ABI.
        let get_api =
            unsafe { library.get::<abi::GetApi>(b"framelean_fll_get_api\0") }.map_err(|error| {
                EngineError::with_source_code(
                    ErrorKind::NativeLibrary,
                    EngineErrorCode::NativeLibraryUnavailable,
                    "FLL dynamic library does not export framelean_fll_get_api",
                    error,
                )
            })?;
        let get_api = *get_api;
        let mut api_pointer = std::ptr::null();
        // SAFETY: `api_pointer` is writable and the library owns the returned immutable table.
        let status = unsafe { get_api(abi::ABI_MAJOR, abi::ABI_MINOR, &mut api_pointer) };
        if status != abi::OK || api_pointer.is_null() {
            return Err(EngineError::with_code(
                ErrorKind::NativeLibrary,
                EngineErrorCode::NativeLibraryUnavailable,
                format!("FLL API bootstrap failed with status {status}"),
            ));
        }
        // SAFETY: a successful bootstrap returns a valid table that stays alive while `library`
        // is held. Copying the function table avoids retaining a `libloading::Symbol` borrow.
        let api = unsafe { *api_pointer };
        validate_api(&api)?;

        let mut handle = std::ptr::null_mut();
        let mut error_pointer = std::ptr::null_mut();
        let mut error_len = 0;
        // SAFETY: all output pointers refer to local writable storage and the function table was
        // validated immediately above.
        let status =
            unsafe { (api.runtime_create)(&mut handle, &mut error_pointer, &mut error_len) };
        if status != abi::OK || handle.is_null() {
            let error = decode_status_error(status, error_pointer, error_len, api.buffer_free);
            return Err(error);
        }

        Ok(Self {
            library,
            api,
            handle: RuntimeHandle::new(handle),
        })
    }

    pub(crate) fn invoke(&self, request: &[u8]) -> Result<Vec<u8>> {
        let mut response_pointer = std::ptr::null_mut();
        let mut response_len = 0;
        // SAFETY: request is a live, immutable byte slice and output pointers are local writable
        // storage. The runtime handle belongs to this loader.
        let status = unsafe {
            (self.api.invoke)(
                self.handle.as_ptr(),
                request.as_ptr(),
                request.len(),
                &mut response_pointer,
                &mut response_len,
            )
        };
        let response = take_buffer(response_pointer, response_len, self.api.buffer_free)?;
        if status == abi::OK {
            return Ok(response);
        }
        Err(decode_status_response_error(status, &response))
    }

    pub(crate) fn poll_event(&self) -> Result<Option<Vec<u8>>> {
        let mut event_pointer = std::ptr::null_mut();
        let mut event_len = 0;
        // SAFETY: output pointers are local writable storage and the runtime handle belongs to
        // this loader.
        let status = unsafe {
            (self.api.poll_event)(self.handle.as_ptr(), &mut event_pointer, &mut event_len)
        };
        if status == abi::NO_EVENT {
            return Ok(None);
        }
        let event = take_buffer(event_pointer, event_len, self.api.buffer_free)?;
        if status == abi::OK {
            Ok(Some(event))
        } else {
            Err(decode_status_response_error(status, &event))
        }
    }
}

impl Drop for FllLoader {
    fn drop(&mut self) {
        if self.handle.is_valid() {
            // SAFETY: the handle was created by this API table and is destroyed exactly once
            unsafe {
                (self.api.runtime_destroy)(self.handle.as_ptr());
            }
            self.handle = RuntimeHandle(0);
        }
        // Keep the field read in this impl as an explicit lifetime assertion: `library` must stay
        // alive until after runtime_destroy. Rust drops it after this custom destructor returns.
        let _ = &self.library;
    }
}

fn validate_api(api: &ApiV1) -> Result<()> {
    if api.abi_major != abi::ABI_MAJOR {
        return Err(EngineError::with_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::NativeLibraryUnavailable,
            format!(
                "unsupported FLL ABI {}.{}; expected {}.{}",
                api.abi_major,
                api.abi_minor,
                abi::ABI_MAJOR,
                abi::ABI_MINOR
            ),
        ));
    }
    if (api.struct_size as usize) < size_of::<ApiV1>() {
        return Err(EngineError::with_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::NativeLibraryUnavailable,
            format!(
                "FLL API table is too small: {} bytes; expected at least {}",
                api.struct_size,
                size_of::<ApiV1>()
            ),
        ));
    }
    Ok(())
}

fn take_buffer(pointer: *mut u8, length: usize, buffer_free: abi::BufferFree) -> Result<Vec<u8>> {
    if pointer.is_null() {
        if length == 0 {
            return Ok(Vec::new());
        }
        return Err(EngineError::with_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::InternalNativeLibraryError,
            "FLL returned a null buffer with a non-zero length",
        ));
    }
    if length == 0 || length > MAX_BUFFER_BYTES {
        // The exact length is still passed back to the library. Its ABI contract makes this a
        // no-op for an invalid length, after which the malformed provider is reported.
        unsafe { buffer_free(pointer, length) };
        return Err(EngineError::with_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::InternalNativeLibraryError,
            "FLL returned a buffer outside the bounded response limit",
        ));
    }
    // SAFETY: the FLL contract returns `length` readable bytes owned by the caller until the
    // matching buffer_free call. Copy before releasing the allocation.
    let bytes = unsafe { std::slice::from_raw_parts(pointer, length).to_vec() };
    // SAFETY: this is the exact pointer/length pair returned by the FLL operation.
    unsafe { buffer_free(pointer, length) };
    Ok(bytes)
}

fn decode_status_error(
    status: i32,
    pointer: *mut u8,
    length: usize,
    buffer_free: abi::BufferFree,
) -> EngineError {
    match take_buffer(pointer, length, buffer_free) {
        Ok(bytes) if !bytes.is_empty() => decode_status_response_error(status, &bytes),
        Ok(_) => native_status_error(status),
        Err(error) => error,
    }
}

fn decode_status_response_error(status: i32, response: &[u8]) -> EngineError {
    decode_response::<serde_json::Value>(response)
        .err()
        .unwrap_or_else(|| native_status_error(status))
}

fn native_status_error(status: i32) -> EngineError {
    let message = match status {
        abi::INVALID_ARGUMENT => "FLL rejected the request document",
        abi::RUNTIME_ERROR => "FLL runtime returned an error",
        abi::PANIC => "FLL runtime panicked at the ABI boundary",
        abi::BUFFER_ERROR => "FLL failed to return a response buffer",
        abi::ABI_MISMATCH => "FLL ABI negotiation failed",
        _ => "FLL returned an unknown ABI status",
    };
    EngineError::with_code(
        ErrorKind::NativeLibrary,
        if status == abi::PANIC {
            EngineErrorCode::InternalRuntimeError
        } else {
            EngineErrorCode::InternalNativeLibraryError
        },
        format!("{message} (status {status})"),
    )
}

pub fn resolve_default_library_path() -> Result<PathBuf> {
    if let Some(value) = env::var_os(LIBRARY_ENV) {
        let path = PathBuf::from(value);
        if path.as_os_str().is_empty() {
            return Err(EngineError::with_code(
                ErrorKind::NativeLibrary,
                EngineErrorCode::NativeLibraryUnavailable,
                format!("{LIBRARY_ENV} must not be empty"),
            ));
        }
        return Ok(path);
    }

    let names: &[&str] = if cfg!(target_os = "macos") {
        &["libframelean_fll.dylib", "framelean_fll.dylib"]
    } else if cfg!(target_os = "windows") {
        &["framelean_fll.dll"]
    } else {
        &["libframelean_fll.so"]
    };
    let executable = env::current_exe().map_err(|error| {
        EngineError::with_source_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::NativeLibraryUnavailable,
            "cannot locate the FEngine executable for FLL library discovery",
            error,
        )
    })?;
    let directory = executable.parent().ok_or_else(|| {
        EngineError::with_code(
            ErrorKind::NativeLibrary,
            EngineErrorCode::NativeLibraryUnavailable,
            "FEngine executable has no parent directory for FLL library discovery",
        )
    })?;
    names
        .iter()
        .map(|name| directory.join(name))
        .find(|path| path.is_file())
        .ok_or_else(|| {
            EngineError::with_code(
                ErrorKind::NativeLibrary,
                EngineErrorCode::NativeLibraryUnavailable,
                format!(
                    "cannot locate FLL dynamic library beside FEngine; set {LIBRARY_ENV} for an explicit development path"
                ),
            )
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn api_validation_rejects_short_tables() {
        let api = ApiV1 {
            struct_size: 1,
            abi_major: abi::ABI_MAJOR,
            abi_minor: abi::ABI_MINOR,
            runtime_create: missing_create,
            runtime_destroy: missing_destroy,
            invoke: missing_invoke,
            poll_event: missing_poll,
            buffer_free: missing_free,
        };
        assert!(validate_api(&api).is_err());
    }

    unsafe extern "C" fn missing_create(
        _: *mut *mut c_void,
        _: *mut *mut u8,
        _: *mut usize,
    ) -> i32 {
        abi::RUNTIME_ERROR
    }

    unsafe extern "C" fn missing_destroy(_: *mut c_void) -> i32 {
        abi::OK
    }

    unsafe extern "C" fn missing_invoke(
        _: *mut c_void,
        _: *const u8,
        _: usize,
        _: *mut *mut u8,
        _: *mut usize,
    ) -> i32 {
        abi::RUNTIME_ERROR
    }

    unsafe extern "C" fn missing_poll(_: *mut c_void, _: *mut *mut u8, _: *mut usize) -> i32 {
        abi::NO_EVENT
    }

    unsafe extern "C" fn missing_free(_: *mut u8, _: usize) {}
}
