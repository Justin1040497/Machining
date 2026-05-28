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

function Import-ZipAssemblies {
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
}

function Get-PubspecVersion {
  param([string]$Path)

  $Pubspec = Get-Content -LiteralPath $Path -Raw
  $VersionMatch = [regex]::Match($Pubspec, "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[^\s]+)?\s*$")
  if (-not $VersionMatch.Success) {
    throw "Could not read semantic version from $Path"
  }

  return $VersionMatch.Groups[1].Value
}

function New-ReleaseZip {
  param(
    [string]$SourceDirectory,
    [string]$DestinationPath,
    [string]$RootEntryName
  )

  Import-ZipAssemblies

  if ($RootEntryName -eq "") {
    throw "RootEntryName is required."
  }

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
      $EntryName = "$RootEntryName/$($RelativePath.Replace("\", "/"))"
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
  param(
    [string]$Path,
    [string]$RootEntryName
  )

  Import-ZipAssemblies

  $Archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $Entries = @($Archive.Entries | ForEach-Object { $_.FullName })
    $BackslashEntries = @($Entries | Where-Object { $_.Contains("\") })
    if ($BackslashEntries.Count -gt 0) {
      throw "Zip entries must use forward slashes. Invalid entries: $($BackslashEntries -join ', ')"
    }

    $RootPrefix = "$RootEntryName/"
    $UnexpectedEntries = @($Entries | Where-Object { -not $_.StartsWith($RootPrefix) })
    if ($UnexpectedEntries.Count -gt 0) {
      throw "Zip entries must be under $RootPrefix. Invalid entries: $($UnexpectedEntries -join ', ')"
    }

    $RequiredEntries = @(
      "${RootPrefix}FrameLean.exe",
      "${RootPrefix}flutter_windows.dll",
      "${RootPrefix}data/app.so",
      "${RootPrefix}ffmpeg/ffmpeg.exe",
      "${RootPrefix}ffmpeg/ffprobe.exe",
      "${RootPrefix}legal/LICENSE",
      "${RootPrefix}legal/NOTICE"
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
    $Version = Get-PubspecVersion -Path $PubspecPath
    $PackageName = "FrameLean-v$Version-windows-x64"
    $ZipPath = Join-Path $ZipDir "$PackageName.zip"

    Write-Host "Creating zip package: $ZipPath"
    New-ReleaseZip -SourceDirectory $ReleaseDir -DestinationPath $ZipPath -RootEntryName $PackageName
    Require-File $ZipPath
    Assert-ZipLayout -Path $ZipPath -RootEntryName $PackageName
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
