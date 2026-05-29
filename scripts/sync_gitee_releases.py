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


class SyncError(RuntimeError):
    pass


def main() -> int:
    args = parse_args()
    github_token = required_env("GH_TOKEN")
    gitee_token = required_env("GITEE_ACCESS_TOKEN")

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
    print(f"Found {len(releases)} GitHub releases to sync.")

    if args.dry_run:
        print("Dry run enabled. No Gitee releases or attachments will be changed.")

    if args.overwrite:
        gitee_releases = list_gitee_releases(
            owner=args.gitee_owner,
            repo=args.gitee_repo,
            token=gitee_token,
        )
        print(f"Found {len(gitee_releases)} existing Gitee releases.")
        if not args.dry_run:
            for release in gitee_releases:
                release_id = release.get("id")
                tag_name = release.get("tag_name") or release.get("tagName")
                print(f"Deleting Gitee release {tag_name or release_id}.")
                delete_gitee_release(
                    owner=args.gitee_owner,
                    repo=args.gitee_repo,
                    release_id=release_id,
                    token=gitee_token,
                )

    with tempfile.TemporaryDirectory(prefix="framelean-release-sync-") as tmp:
        for release in releases:
            sync_release(
                release=release,
                download_dir=tmp,
                github_token=github_token,
                gitee_token=gitee_token,
                gitee_owner=args.gitee_owner,
                gitee_repo=args.gitee_repo,
                default_target_commitish=args.default_target_commitish,
                dry_run=args.dry_run,
            )

    print("Gitee release sync finished.")
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
    download_dir: str,
    github_token: str,
    gitee_token: str,
    gitee_owner: str,
    gitee_repo: str,
    default_target_commitish: str,
    dry_run: bool,
) -> None:
    tag_name = release.get("tag_name")
    if not tag_name:
        raise SyncError("GitHub release is missing tag_name.")

    release_name = release.get("name") or tag_name
    target_commitish = release.get("target_commitish") or default_target_commitish
    assets = release.get("assets") or []
    print(f"Syncing {tag_name}: {release_name} ({len(assets)} assets).")

    if dry_run:
        for asset in assets:
            print(f"Would upload {asset.get('name')}.")
        return

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

    release_dir = os.path.join(download_dir, sanitize_path_component(tag_name))
    shutil.rmtree(release_dir, ignore_errors=True)
    os.makedirs(release_dir, exist_ok=True)

    for asset in assets:
        asset_name = asset.get("name")
        download_url = asset.get("url") or asset.get("browser_download_url")
        if not asset_name or not download_url:
            raise SyncError(f"GitHub release {tag_name} has an invalid asset.")
        asset_path = os.path.join(release_dir, asset_name)
        print(f"Downloading {asset_name}.")
        download_file(download_url, asset_path, github_token)
        print(f"Uploading {asset_name} to Gitee release {tag_name}.")
        upload_gitee_asset(
            owner=gitee_owner,
            repo=gitee_repo,
            release_id=release_id,
            file_path=asset_path,
            token=gitee_token,
        )


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
    result = subprocess.run(
        [
            "curl",
            "--fail",
            "--show-error",
            "--silent",
            "--location",
            "--request",
            "POST",
            "--header",
            "Accept: application/json",
            "--header",
            f"Authorization: Bearer {token}",
            "--form",
            f"file=@{file_path}",
            url,
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        raise SyncError(
            "Gitee asset upload failed: " + (result.stderr.strip() or result.stdout)
        )


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


def download_file(url: str, destination: str, token: str) -> None:
    headers = {
        "Accept": "application/octet-stream",
        "User-Agent": "FrameLean release sync",
        "Authorization": f"Bearer {token}",
    }
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            with open(destination, "wb") as file:
                shutil.copyfileobj(response, file)
    except urllib.error.URLError as error:
        raise SyncError(f"Failed to download GitHub asset {url}: {error}") from error


def sanitize_path_component(value: str) -> str:
    return "".join(char if char.isalnum() or char in "._-" else "_" for char in value)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SyncError as error:
        print(f"release sync failed: {error}", file=sys.stderr)
        raise SystemExit(1)
