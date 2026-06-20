#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE_ID="com.justin.framelean"
APP_NAME="FrameLean"
DRY_RUN=0
ASSUME_YES=0
REMOVE_APP_PATH=""
ADMIN_CLEANUP=0

usage() {
  cat <<USAGE
FrameLean clean uninstall helper

Usage:
  ./FrameLean-Clean-Uninstall.command [--dry-run] [--yes] [--admin-cleanup] [--remove-app /Applications/FrameLean.app]

This removes FrameLean-owned app data and temporary cache. It never scans or
deletes exported compression results.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --admin-cleanup)
      ADMIN_CLEANUP=1
      shift
      ;;
    --remove-app)
      if [[ $# -lt 2 ]]; then
        echo "--remove-app requires an app path" >&2
        exit 2
      fi
      REMOVE_APP_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

run_remove() {
  local target="$1"
  if [[ -z "$target" || ! -e "$target" ]]; then
    return
  fi

  echo "[FrameLean] Remove: $target"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    rm -rf "$target"
  fi
}

run_admin_remove() {
  local target="$1"
  if [[ -z "$target" || ! -e "$target" ]]; then
    return
  fi

  echo "[FrameLean] Remove managed path: $target"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    sudo rm -rf -- "$target"
  fi
}

confirm() {
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return
  fi

  echo "This will remove ${APP_NAME} app data, settings database, cache, and logs."
  echo "It will not scan or delete exported compression results."
  read -r -p "Type FrameLean to continue: " answer
  if [[ "$answer" != "FrameLean" ]]; then
    echo "[FrameLean] Cancelled"
    exit 1
  fi
}

confirm

DARWIN_USER_TEMP_DIR="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)"
SUPPORT_DIR="$HOME/Library/Application Support"
CACHE_DIR="$HOME/Library/Caches"
PREFERENCES_DIR="$HOME/Library/Preferences"

run_remove "$SUPPORT_DIR/$APP_BUNDLE_ID"
run_remove "$SUPPORT_DIR/$APP_NAME"
run_remove "$CACHE_DIR/$APP_BUNDLE_ID"
run_remove "$CACHE_DIR/$APP_NAME"
run_remove "$PREFERENCES_DIR/$APP_BUNDLE_ID.plist"
run_remove "$HOME/Library/Saved Application State/$APP_BUNDLE_ID.savedState"
run_remove "$HOME/Library/HTTPStorages/$APP_BUNDLE_ID"
run_remove "${TMPDIR:-}/framelean"
run_remove "$DARWIN_USER_TEMP_DIR/framelean"

if [[ "$ADMIN_CLEANUP" -eq 1 ]]; then
  run_admin_remove "/Library/Application Support/FrameLean"
fi

if [[ -n "$REMOVE_APP_PATH" ]]; then
  if [[ "$REMOVE_APP_PATH" != *"/FrameLean.app" ]]; then
    echo "--remove-app only accepts a FrameLean.app path" >&2
    exit 2
  fi
  run_remove "$REMOVE_APP_PATH"
fi

echo "[FrameLean] Clean uninstall finished"
