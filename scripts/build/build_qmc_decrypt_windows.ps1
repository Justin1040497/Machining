param(
  [string]$RepoUrl = "https://github.com/bczhc/qmc-decrypt.git",
  [string]$RepoCommit = "12d758a6a08635b4ab85b6dca05025fdbcc26520"
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Invoke-Checked {
  param(
    [string]$FilePath,
    [string[]]$Arguments
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
  }
}

Require-Command "git"
Require-Command "cargo"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$BuildDir = Join-Path $Root "build\qmc-decrypt-windows-x64"
$SourceDir = Join-Path $BuildDir "qmc-decrypt"
$OutDir = Join-Path $Root "build\dependencies\qmc\windows-x64"

if (Test-Path -LiteralPath $BuildDir) {
  Remove-Item -LiteralPath $BuildDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir, $OutDir | Out-Null

Invoke-Checked "git" @("clone", "--recursive", $RepoUrl, $SourceDir)
Push-Location $SourceDir
try {
  Invoke-Checked "git" @("checkout", $RepoCommit)
  Invoke-Checked "git" @("submodule", "update", "--init", "--recursive")
  Invoke-Checked "cargo" @("build", "--release", "--locked")

  Copy-Item -LiteralPath (Join-Path $SourceDir "target\release\qmc-decrypt.exe") -Destination (Join-Path $OutDir "qmc-decrypt.exe") -Force
  Copy-Item -LiteralPath (Join-Path $SourceDir "LICENSE-MIT") -Destination (Join-Path $OutDir "LICENSE-MIT") -Force
  Copy-Item -LiteralPath (Join-Path $SourceDir "LICENSE-APACHE") -Destination (Join-Path $OutDir "LICENSE-APACHE") -Force
  Copy-Item -LiteralPath (Join-Path $SourceDir "README.md") -Destination (Join-Path $OutDir "README-upstream.md") -Force

  @"
qmc-decrypt source: $RepoUrl
qmc-decrypt commit: $RepoCommit
Built by: scripts/build/build_qmc_decrypt_windows.ps1
"@ | Set-Content -LiteralPath (Join-Path $OutDir "qmc-decrypt-build-info.txt") -Encoding UTF8

  # The pinned qmc-decrypt CLI does not implement --version; --help is the
  # side-effect-free startup probe available in this upstream binary.
  Invoke-Checked (Join-Path $OutDir "qmc-decrypt.exe") @("--help")
}
finally {
  Pop-Location
}

Write-Host ""
Write-Host "QMC adapter is ready:"
Write-Host (Join-Path $OutDir "qmc-decrypt.exe")
