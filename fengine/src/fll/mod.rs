//! FEngine's Phase 2A dynamic FLL adapter.
//!
//! This module intentionally defines the C ABI locally instead of depending on the Rust FFI
//! crate. The typed `RuntimeHost` DTOs remain a temporary Phase 2A compatibility layer; the
//! loader and document boundary are the seam that Phase 2B will use to move those DTOs into
//! FEngine-owned transport models.

mod abi;
mod documents;
mod dynamic_host;
mod loader;

pub use dynamic_host::DynamicRuntimeHost;
pub use loader::resolve_default_library_path;
