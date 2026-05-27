param(
  [switch]$SkipPubGet,
  [switch]$SkipZip,
  [string]$BuildName = "",
  [string]$BuildNumber = "",
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

function New-ReleaseZip {
  param(
    [string]$SourceDirectory,
    [string]$DestinationPath
  )

  Add-Type -AssemblyName System.IO.Compression.FileSystem

  if (Test-Path -LiteralPath $DestinationPath) {
    Remove-Item -LiteralPath $DestinationPath -Force
  }

  $SourceRoot = (Resolve-Path -LiteralPath $SourceDirectory).Path.TrimEnd([char[]]@("\", "/"))
  $Archive = [System.IO.Compression.ZipFile]::Open(
    $DestinationPath,
    [System.IO.Compression.ZipArchiveMode]::Create
  )

  try {
    Get-ChildItem -LiteralPath $SourceRoot -Recurse -File | ForEach-Object {
      $RelativePath = $_.FullName.Substring($SourceRoot.Length).TrimStart([char[]]@("\", "/"))
      $EntryName = $RelativePath.Replace("\", "/")
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $Archive,
        $_.FullName,
        $EntryName,
        [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  }
  finally {
    $Archive.Dispose()
  }
}

function Assert-ZipLayout {
  param([string]$Path)

  Add-Type -AssemblyName System.IO.Compression.FileSystem

  $Archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $Entries = @($Archive.Entries | ForEach-Object { $_.FullName })
    $BackslashEntries = @($Entries | Where-Object { $_.Contains("\") })
    if ($BackslashEntries.Count -gt 0) {
      throw "Zip entries must use forward slashes. Invalid entries: $($BackslashEntries -join ', ')"
    }

    $RequiredEntries = @(
      "FrameLean.exe",
      "flutter_windows.dll",
      "data/app.so",
      "ffmpeg/ffmpeg.exe",
      "ffmpeg/ffprobe.exe",
      "legal/LICENSE",
      "legal/NOTICE"
    )

    foreach ($Entry in $RequiredEntries) {
      if ($Entries -notcontains $Entry) {
        throw "Required zip entry was not found: $Entry"
      }
    }
  }
  finally {
    $Archive.Dispose()
  }
}

if ($env:OS -ne "Windows_NT") {
  throw "This script only builds the Windows package. Run it on Windows."
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ReleaseDir = Join-Path $Root "build\windows\x64\runner\Release"
$ZipDir = Join-Path $Root "build\windows\x64\runner"
$FfmpegDir = Join-Path $Root "third_party\ffmpeg\windows-x64"
$LegalDir = Join-Path $Root "legal"
$PubspecPath = Join-Path $Root "pubspec.yaml"

Require-Command "flutter"
Require-File (Join-Path $FfmpegDir "ffmpeg.exe")
Require-File (Join-Path $FfmpegDir "ffprobe.exe")
Require-Directory $LegalDir
Require-File (Join-Path $Root "LICENSE")
Require-File (Join-Path $Root "NOTICE")

Push-Location $Root
try {
  if (-not $SkipPubGet) {
    Write-Host "Resolving Flutter dependencies..."
    Invoke-Checked "flutter" @("pub", "get")
  }

  $BuildArgs = @("build", "windows", "--release")
  if ($BuildName -ne "") {
    $BuildArgs += @("--build-name", $BuildName)
  }
  if ($BuildNumber -ne "") {
    $BuildArgs += @("--build-number", $BuildNumber)
  }
  if ($ExtraFlutterArgs) {
    $BuildArgs += $ExtraFlutterArgs
  }

  Write-Host "Building Windows release with: flutter $($BuildArgs -join ' ')"
  Invoke-Checked "flutter" $BuildArgs

  Require-Directory $ReleaseDir
  Require-File (Join-Path $ReleaseDir "FrameLean.exe")
  Require-File (Join-Path $ReleaseDir "flutter_windows.dll")
  Require-Directory (Join-Path $ReleaseDir "data")
  Require-File (Join-Path $ReleaseDir "ffmpeg\ffmpeg.exe")
  Require-File (Join-Path $ReleaseDir "ffmpeg\ffprobe.exe")
  Require-File (Join-Path $ReleaseDir "legal\COPYING")
  Require-File (Join-Path $ReleaseDir "legal\LICENSE")
  Require-File (Join-Path $ReleaseDir "legal\NOTICE")

  $VcRuntimeFiles = @(
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll"
  )
  $MissingVcRuntimeFiles = @(
    $VcRuntimeFiles | Where-Object {
      -not (Test-Path -LiteralPath (Join-Path $ReleaseDir $_) -PathType Leaf)
    }
  )
  if ($MissingVcRuntimeFiles.Count -gt 0) {
    Write-Warning "Visual C++ runtime DLLs are not bundled next to the executable: $($MissingVcRuntimeFiles -join ', ')"
    Write-Warning "For zip distribution, install the Visual C++ Redistributable on target machines or copy these DLLs into the Release directory before publishing."
  }

  Write-Host "Validating bundled FFmpeg runtime..."
  & (Join-Path $ReleaseDir "ffmpeg\ffmpeg.exe") -hide_banner -version | Select-Object -First 1
  & (Join-Path $ReleaseDir "ffmpeg\ffprobe.exe") -hide_banner -version | Select-Object -First 1

  if (-not $SkipZip) {
    $Pubspec = Get-Content -LiteralPath $PubspecPath -Raw
    $VersionMatch = [regex]::Match($Pubspec, "(?m)^version:\s*([^\s]+)")
    $Version = if ($VersionMatch.Success) { $VersionMatch.Groups[1].Value.Split("+")[0] } else { "unknown" }
    $ZipPath = Join-Path $ZipDir "FrameLean-v$Version-windows-x64.zip"

    Write-Host "Creating zip package: $ZipPath"
    New-ReleaseZip -SourceDirectory $ReleaseDir -DestinationPath $ZipPath
    Require-File $ZipPath
    Assert-ZipLayout -Path $ZipPath
  }

  Write-Host ""
  Write-Host "Windows release package is ready:"
  Write-Host $ReleaseDir
  if (-not $SkipZip) {
    Write-Host $ZipPath
  }
}
finally {
  Pop-Location
}
