param(
  [switch]$SkipPubGet,
  [string]$BuildName = "",
  [string]$BuildNumber = "",
  [string]$IsccPath = "",
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraFlutterArgs
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Require-File {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required file was not found: $Path"
  }
}

function Require-Directory {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Required directory was not found: $Path"
  }
}

function Get-PubspecVersion {
  param([string]$Path)

  $pubspec = Get-Content -LiteralPath $Path -Raw
  $versionMatch = [regex]::Match(
    $pubspec,
    "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[^\s]+)?\s*$"
  )

  if (-not $versionMatch.Success) {
    throw "Could not read semantic version from $Path"
  }

  return $versionMatch.Groups[1].Value
}

function Resolve-IsccPath {
  param([string]$ExplicitPath)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    Require-File $ExplicitPath
    return (Resolve-Path -LiteralPath $ExplicitPath).Path
  }

  $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidatePaths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
  )

  foreach ($candidatePath in $candidatePaths) {
    if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
      return $candidatePath
    }
  }

  throw "Missing required command: ISCC.exe. Install Inno Setup 6 or pass -IsccPath."
}

function Assert-FfmpegCapability {
  param(
    [string]$Output,
    [string[]]$RequiredNames,
    [string]$CapabilityName
  )

  foreach ($name in $RequiredNames) {
    if ($Output -notmatch [regex]::Escape($name)) {
      throw "Bundled FFmpeg runtime is missing required $CapabilityName`: $name"
    }
  }
}

if ($env:OS -ne "Windows_NT") {
  throw "Windows installer packaging must run on Windows."
}

$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$releaseDir = Join-Path $root "build\windows\x64\runner\Release"
$installerDir = Join-Path $root "build\windows\x64\installer"
$buildScript = Join-Path $root "scripts\release\build_windows.ps1"
$pubspecPath = Join-Path $root "pubspec.yaml"
$issPath = Join-Path $root "installer\windows\FrameLean.iss"
$cleanupScriptPath = Join-Path $root "installer\windows\FrameLean-Clean-Uninstall.ps1"
$thirdPartyQmcDir = Join-Path $root "third_party\audio_adapters\qmc\windows-x64"
$releaseQmcAdapter = Join-Path $releaseDir "audio_adapters\qmc\framelean-qmc-adapter.exe"

Require-Command "flutter"
$iscc = Resolve-IsccPath -ExplicitPath $IsccPath
Require-File $buildScript
Require-File $pubspecPath
Require-File $issPath
Require-File $cleanupScriptPath

$buildArgs = @("-ExecutionPolicy", "Bypass", "-File", $buildScript, "-SkipZip")
if ($SkipPubGet) {
  $buildArgs += "-SkipPubGet"
}
if (-not [string]::IsNullOrWhiteSpace($BuildName)) {
  $buildArgs += @("-BuildName", $BuildName)
}
if (-not [string]::IsNullOrWhiteSpace($BuildNumber)) {
  $buildArgs += @("-BuildNumber", $BuildNumber)
}
if ($ExtraFlutterArgs) {
  $buildArgs += $ExtraFlutterArgs
}

& powershell.exe $buildArgs
if ($LASTEXITCODE -ne 0) {
  throw "Windows release build failed with exit code $LASTEXITCODE."
}

Require-Directory $releaseDir
foreach ($relativePath in @(
  "FrameLean.exe",
  "flutter_windows.dll",
  "data\app.so",
  "ffmpeg\ffmpeg.exe",
  "ffmpeg\ffprobe.exe",
  "legal\LICENSE",
  "legal\NOTICE.md"
)) {
  Require-File (Join-Path $releaseDir $relativePath)
}

$ffmpegPath = Join-Path $releaseDir "ffmpeg\ffmpeg.exe"
$ffprobePath = Join-Path $releaseDir "ffmpeg\ffprobe.exe"
$encoderOutput = (& $ffmpegPath -hide_banner -encoders 2>$null) -join "`n"
$decoderOutput = (& $ffmpegPath -hide_banner -decoders 2>$null) -join "`n"
$demuxerOutput = (& $ffmpegPath -hide_banner -demuxers 2>$null) -join "`n"
& $ffprobePath -version | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Bundled ffprobe.exe failed version validation."
}

Assert-FfmpegCapability -Output $encoderOutput -RequiredNames @(
  "libx264",
  "libmp3lame",
  "libwebp",
  "libopus"
) -CapabilityName "encoder"
Assert-FfmpegCapability -Output $decoderOutput -RequiredNames @(
  "opus",
  "vorbis"
) -CapabilityName "decoder"
Assert-FfmpegCapability -Output $demuxerOutput -RequiredNames @(
  "ogg"
) -CapabilityName "demuxer"

if (Test-Path -LiteralPath $thirdPartyQmcDir -PathType Container) {
  Require-File $releaseQmcAdapter
}

$releaseToolsDir = Join-Path $releaseDir "tools"
New-Item -ItemType Directory -Path $releaseToolsDir -Force | Out-Null
Copy-Item -LiteralPath $cleanupScriptPath `
  -Destination (Join-Path $releaseToolsDir "FrameLean-Clean-Uninstall.ps1") `
  -Force

New-Item -ItemType Directory -Path $installerDir -Force | Out-Null
$version = Get-PubspecVersion -Path $pubspecPath
& $iscc $issPath `
  "/DAppVersion=$version" `
  "/DSourceDir=$releaseDir" `
  "/DOutputDir=$installerDir"
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup failed with exit code $LASTEXITCODE."
}

$setupPath = Join-Path $installerDir "FrameLean-v$version-windows-x64-setup.exe"
Require-File $setupPath
Write-Host "Windows installer created: $setupPath"
