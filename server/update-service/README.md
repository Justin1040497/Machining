# FrameLean Update Service

Rust self-hosted update API for FrameLean.

## Required Environment

```text
FRAMELEAN_UPDATE_HMAC_SECRET=<client request signing secret>
FRAMELEAN_UPDATE_DOWNLOAD_SECRET=<download token signing secret, optional>
FRAMELEAN_UPDATE_PUBLIC_BASE_URL=https://updates.example.com
FRAMELEAN_UPDATE_STORAGE_DIR=/srv/framelean-updates/storage
FRAMELEAN_UPDATE_BIND_ADDR=127.0.0.1:8080
```

`FRAMELEAN_UPDATE_HMAC_SECRET` is embedded into the desktop build with
`--dart-define`, so it only blocks casual unauthenticated access. It is not DRM.

## Local Run

```bash
cargo run --manifest-path server/update-service/Cargo.toml
```

Use `examples/storage/releases.json` as the starting storage layout.

## Client Build Defines

```bash
flutter build macos \
  --dart-define=FRAMELEAN_UPDATE_BASE_URL=https://updates.example.com \
  --dart-define=FRAMELEAN_UPDATE_HMAC_SECRET=<client request signing secret>
```
