#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from typing import Optional


GITHUB_API_BASE = "https://api.github.com"
GITEE_API_BASE = "https://gitee.com/api/v5"
CURL_CONNECT_TIMEOUT_SECONDS = 30
CURL_RETRY_COUNT = 3
CURL_RETRY_DELAY_SECONDS = 5
TRANSFER_MAX_TIME_SECONDS = 7200
TRANSFER_LOW_SPEED_LIMIT_BYTES_PER_SECOND = 1024
TRANSFER_LOW_SPEED_TIME_SECONDS = 120


class SyncError(RuntimeError):
    pass


def main() -> int:
    args = parse_args()
    github_token = required_env("GH_TOKEN")
    gitee_token = required_env("GITEE_ACCESS_TOKEN")
    ensure_curl_available()

    if args.overwrite and not args.confirm_overwrite and not args.dry_run:
        raise SyncError(
            "Refusing to overwrite Gitee releases without --confirm-overwrite."
        )

    releases = list_github_releases(
        repo=args.github_repo,
        token=github_token,
        include_drafts=args.include_drafts,
    )
    releases.reverse()
    log(f"Found {len(releases)} GitHub releases to sync.")

    if args.dry_run:
        log("Dry run enabled. No Gitee releases or attachments will be changed.")

    if args.overwrite:
        gitee_releases = list_gitee_releases(
            owner=args.gitee_owner,
            repo=args.gitee_repo,
            token=gitee_token,
        )
        log(f"Found {len(gitee_releases)} existing Gitee releases.")
        if not args.dry_run:
            for index, release in enumerate(gitee_releases, start=1):
                release_id = release.get("id")
                tag_name = release.get("tag_name") or release.get("tagName")
                log(
                    f"Deleting Gitee release {index}/{len(gitee_releases)}: "
                    f"{tag_name or release_id}."
                )
                delete_gitee_release(
                    owner=args.gitee_owner,
                    repo=args.gitee_repo,
                    release_id=release_id,
                    token=gitee_token,
                )

    processed_assets = 0
    with tempfile.TemporaryDirectory(prefix="framelean-release-sync-") as tmp:
        for index, release in enumerate(releases, start=1):
            processed_assets += sync_release(
                release=release,
                release_index=index,
                release_total=len(releases),
                download_dir=tmp,
                github_token=github_token,
                gitee_token=gitee_token,
                gitee_owner=args.gitee_owner,
                gitee_repo=args.gitee_repo,
                default_target_commitish=args.default_target_commitish,
                dry_run=args.dry_run,
            )

    if args.dry_run:
        log(
            "Gitee release sync dry run finished. "
            f"Planned {len(releases)} releases and {processed_assets} assets."
        )
    else:
        log(
            "Gitee release sync finished. "
            f"Synced {len(releases)} releases and {processed_assets} assets."
        )
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Synchronize GitHub Releases to Gitee Releases."
    )
    parser.add_argument("--github-repo", required=True, help="owner/repo on GitHub")
    parser.add_argument("--gitee-owner", required=True, help="Gitee owner path")
    parser.add_argument("--gitee-repo", required=True, help="Gitee repository path")
    parser.add_argument(
        "--default-target-commitish",
        default="main",
        help="Fallback target commitish when a GitHub release has none.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Delete all existing Gitee releases before syncing.",
    )
    parser.add_argument(
        "--confirm-overwrite",
        action="store_true",
        help="Required together with --overwrite.",
    )
    parser.add_argument(
        "--include-drafts",
        action="store_true",
        help="Publish GitHub draft releases to Gitee as normal releases.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned work without changing Gitee.",
    )
    return parser.parse_args()


def required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SyncError(f"Missing required environment variable: {name}")
    return value


def ensure_curl_available() -> None:
    if shutil.which("curl") is None:
        raise SyncError("curl is required for release asset transfers.")


def list_github_releases(repo: str, token: str, include_drafts: bool) -> list[dict]:
    releases: list[dict] = []
    page = 1
    while True:
        url = (
            f"{GITHUB_API_BASE}/repos/{repo}/releases?"
            + urllib.parse.urlencode({"per_page": 100, "page": page})
        )
        batch = request_json("GET", url, token=token, provider="GitHub")
        if not isinstance(batch, list):
            raise SyncError("GitHub releases response is not a list.")
        for release in batch:
            if include_drafts or not release.get("draft", False):
                releases.append(release)
        if len(batch) < 100:
            return releases
        page += 1


def list_gitee_releases(owner: str, repo: str, token: str) -> list[dict]:
    releases: list[dict] = []
    page = 1
    while True:
        url = (
            f"{GITEE_API_BASE}/repos/{owner}/{repo}/releases?"
            + urllib.parse.urlencode({"per_page": 100, "page": page})
        )
        batch = request_json("GET", url, token=token, provider="Gitee")
        if not isinstance(batch, list):
            raise SyncError("Gitee releases response is not a list.")
        releases.extend(batch)
        if len(batch) < 100:
            return releases
        page += 1


def sync_release(
    *,
    release: dict,
    release_index: int,
    release_total: int,
    download_dir: str,
    github_token: str,
    gitee_token: str,
    gitee_owner: str,
    gitee_repo: str,
    default_target_commitish: str,
    dry_run: bool,
) -> int:
    tag_name = release.get("tag_name")
    if not tag_name:
        raise SyncError("GitHub release is missing tag_name.")

    release_name = release.get("name") or tag_name
    target_commitish = release.get("target_commitish") or default_target_commitish
    assets = release.get("assets") or []
    log(
        f"Release {release_index}/{release_total}: "
        f"{tag_name} - {release_name} ({len(assets)} assets)."
    )

    if dry_run:
        for asset_index, asset in enumerate(assets, start=1):
            asset_name = asset.get("name") or "<unnamed asset>"
            log(
                f"  Asset {asset_index}/{len(assets)}: would upload "
                f"{asset_name} ({format_bytes(asset.get('size'))})."
            )
        return len(assets)

    gitee_release = create_gitee_release(
        owner=gitee_owner,
        repo=gitee_repo,
        token=gitee_token,
        payload={
            "tag_name": tag_name,
            "target_commitish": target_commitish,
            "name": release_name,
            "body": release.get("body") or "",
            "prerelease": bool(release.get("prerelease", False)),
        },
    )
    release_id = gitee_release.get("id")
    if release_id is None:
        raise SyncError(f"Gitee did not return an id for release {tag_name}.")
    log(f"  Created Gitee release id {release_id}.")

    release_dir = os.path.join(download_dir, sanitize_path_component(tag_name))
    shutil.rmtree(release_dir, ignore_errors=True)
    os.makedirs(release_dir, exist_ok=True)

    for asset_index, asset in enumerate(assets, start=1):
        asset_name = asset.get("name")
        download_urls = unique_strings(
            asset.get("url"),
            asset.get("browser_download_url"),
        )
        if not asset_name or not download_urls:
            raise SyncError(f"GitHub release {tag_name} has an invalid asset.")
        asset_path = os.path.join(release_dir, asset_name)
        log(
            f"  Asset {asset_index}/{len(assets)}: downloading "
            f"{asset_name} ({format_bytes(asset.get('size'))})."
        )
        download_file(download_urls, asset_path, github_token, label=asset_name)
        log(
            f"  Asset {asset_index}/{len(assets)}: downloaded "
            f"{asset_name} ({format_file_size(asset_path)})."
        )
        log(
            f"  Asset {asset_index}/{len(assets)}: uploading "
            f"{asset_name} to Gitee."
        )
        upload_gitee_asset(
            owner=gitee_owner,
            repo=gitee_repo,
            release_id=release_id,
            file_path=asset_path,
            token=gitee_token,
        )
        log(f"  Asset {asset_index}/{len(assets)}: uploaded {asset_name}.")
    return len(assets)


def create_gitee_release(
    *, owner: str, repo: str, token: str, payload: dict
) -> dict:
    url = f"{GITEE_API_BASE}/repos/{owner}/{repo}/releases"
    result = request_json("POST", url, token=token, provider="Gitee", body=payload)
    if not isinstance(result, dict):
        raise SyncError("Gitee create release response is not an object.")
    return result


def delete_gitee_release(*, owner: str, repo: str, release_id: object, token: str) -> None:
    if release_id is None:
        raise SyncError("Cannot delete a Gitee release without id.")
    url = f"{GITEE_API_BASE}/repos/{owner}/{repo}/releases/{release_id}"
    request_json("DELETE", url, token=token, provider="Gitee", allow_empty=True)


def upload_gitee_asset(
    *, owner: str, repo: str, release_id: object, file_path: str, token: str
) -> None:
    url = f"{GITEE_API_BASE}/repos/{owner}/{repo}/releases/{release_id}/attach_files"
    response_path = temporary_response_path("framelean-gitee-upload-")
    try:
        run_curl(
            transfer_curl_args()
            + [
                "--progress-bar",
                "--request",
                "POST",
                "--header",
                "Accept: application/json",
                "--header",
                f"Authorization: Bearer {token}",
                "--form",
                f"file=@{file_path}",
                "--output",
                response_path,
                url,
            ],
            failure_context="Gitee asset upload",
            response_path=response_path,
        )
    finally:
        remove_file_if_exists(response_path)


def request_json(
    method: str,
    url: str,
    *,
    token: str,
    provider: str,
    body: Optional[dict] = None,
    allow_empty: bool = False,
):
    headers = {
        "Accept": "application/json",
        "User-Agent": "FrameLean release sync",
        "Authorization": f"Bearer {token}",
    }
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = response.read()
            if not payload and allow_empty:
                return None
            if not payload:
                raise SyncError(f"{provider} returned an empty response.")
            return json.loads(payload.decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise SyncError(
            f"{provider} API {method} {url} failed with HTTP {error.code}: {detail}"
        ) from error
    except urllib.error.URLError as error:
        raise SyncError(f"{provider} API {method} {url} failed: {error}") from error


def download_file(
    urls: list[str], destination: str, token: str, *, label: str
) -> None:
    last_error: Optional[SyncError] = None
    for index, url in enumerate(urls, start=1):
        if index > 1:
            log(f"    Retrying {label} with alternate GitHub asset URL.")
        try:
            run_curl(
                transfer_curl_args()
                + [
                    "--progress-bar",
                    "--header",
                    "Accept: application/octet-stream",
                    "--header",
                    "User-Agent: FrameLean release sync",
                    "--header",
                    f"Authorization: Bearer {token}",
                    "--output",
                    destination,
                    url,
                ],
                failure_context=f"GitHub asset download ({label})",
            )
            return
        except SyncError as error:
            remove_file_if_exists(destination)
            last_error = error
            if index < len(urls):
                log(f"    Download source {index} failed for {label}: {error}")

    if last_error is not None:
        raise last_error
    raise SyncError(f"GitHub release asset has no download URL: {label}")


def transfer_curl_args() -> list[str]:
    return [
        "curl",
        "--fail-with-body",
        "--show-error",
        "--location",
        "--retry",
        str(CURL_RETRY_COUNT),
        "--retry-delay",
        str(CURL_RETRY_DELAY_SECONDS),
        "--retry-all-errors",
        "--connect-timeout",
        str(CURL_CONNECT_TIMEOUT_SECONDS),
        "--max-time",
        str(TRANSFER_MAX_TIME_SECONDS),
        "--speed-time",
        str(TRANSFER_LOW_SPEED_TIME_SECONDS),
        "--speed-limit",
        str(TRANSFER_LOW_SPEED_LIMIT_BYTES_PER_SECOND),
    ]


def run_curl(
    command: list[str],
    *,
    failure_context: str,
    response_path: Optional[str] = None,
) -> None:
    sys.stdout.flush()
    sys.stderr.flush()
    result = subprocess.run(command, check=False)
    if result.returncode == 0:
        return

    response = read_response_excerpt(response_path)
    if response:
        raise SyncError(
            f"{failure_context} failed with exit code {result.returncode}: {response}"
        )
    raise SyncError(f"{failure_context} failed with exit code {result.returncode}.")


def temporary_response_path(prefix: str) -> str:
    descriptor, path = tempfile.mkstemp(prefix=prefix, suffix=".json")
    os.close(descriptor)
    return path


def read_response_excerpt(path: Optional[str]) -> str:
    if not path or not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8", errors="replace") as file:
        return file.read(2000).strip()


def remove_file_if_exists(path: str) -> None:
    try:
        os.remove(path)
    except FileNotFoundError:
        pass


def unique_strings(*values: object) -> list[str]:
    result: list[str] = []
    for value in values:
        if not isinstance(value, str) or not value:
            continue
        if value not in result:
            result.append(value)
    return result


def format_file_size(path: str) -> str:
    return format_bytes(os.path.getsize(path))


def format_bytes(value: object) -> str:
    try:
        size = float(value)
    except (TypeError, ValueError):
        return "unknown size"
    if size < 0:
        return "unknown size"

    units = ["B", "KB", "MB", "GB", "TB"]
    unit_index = 0
    while size >= 1024 and unit_index < len(units) - 1:
        size /= 1024
        unit_index += 1
    if units[unit_index] == "B":
        return f"{int(size)} B"
    return f"{size:.1f} {units[unit_index]}"


def log(message: str) -> None:
    print(message, flush=True)


def sanitize_path_component(value: str) -> str:
    return "".join(char if char.isalnum() or char in "._-" else "_" for char in value)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SyncError as error:
        print(f"release sync failed: {error}", file=sys.stderr)
        raise SystemExit(1)
