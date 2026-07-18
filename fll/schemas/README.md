# Runtime JSON Schemas

These schemas are generated from the aggregate DTOs owned by
`framelean-runtime`. Regenerate them with:

```bash
cargo run -p framelean-runtime --example export_schemas
```

The internal `AnalyzeTaskRequest` is intentionally excluded because it owns an
OS-native `PathBuf` and is not yet an IPC contract.

The checked-in v1 schemas are updated in place during the pre-release 0.1
phase. The current revision includes atomic execution-chain capabilities,
structured error codes, product preset policies, and resolved configuration.
