#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [[ "$#" -eq 0 ]]; then
  echo "usage: $0 <Mach-O file or directory> [...]" >&2
  exit 64
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: Universal Mach-O verification must run on macOS" >&2
  exit 1
fi

for command_name in file lipo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "error: missing required command: $command_name" >&2
    exit 1
  fi
done

verified_count=0

verify_macho() {
  local path="$1"
  local file_type
  local architectures

  file_type="$(file -b "$path")"
  if [[ "$file_type" != Mach-O* ]]; then
    return
  fi

  architectures="$(lipo -archs "$path")"
  for required_arch in x86_64 arm64; do
    if [[ " $architectures " != *" $required_arch "* ]]; then
      echo "error: missing $required_arch slice: $path ($architectures)" >&2
      exit 1
    fi
  done

  echo "OK: $path ($architectures)"
  verified_count=$((verified_count + 1))
}

for target in "$@"; do
  if [[ -f "$target" ]]; then
    verify_macho "$target"
    continue
  fi

  if [[ -d "$target" ]]; then
    while IFS= read -r -d '' file_path; do
      verify_macho "$file_path"
    done < <(find "$target" -type f -print0)
    continue
  fi

  echo "error: verification target does not exist: $target" >&2
  exit 1
done

if [[ "$verified_count" -eq 0 ]]; then
  echo "error: no Mach-O files were found in the supplied targets" >&2
  exit 1
fi

echo "Verified $verified_count Universal 2 Mach-O file(s)."
