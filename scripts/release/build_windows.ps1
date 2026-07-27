param(
  [switch]$SkipPubGet,
  [switch]$SkipZip,
  [switch]$SkipInstaller,
  [string]$BuildName = "",
  [string]$BuildNumber = "",
  [string]$IsccPath = "",
  [string]$UpdateBaseUrl = $env:FRAMELEAN_UPDATE_BASE_URL,
  [string]$ReleaseKeyId = $env:FRAMELEAN_RELEASE_KEY_ID,
  [string]$ReleasePublicKey = $env:FRAMELEAN_RELEASE_PUBLIC_KEY,
  [string]$ReleasePrivateKeyFile = $env:FRAMELEAN_RELEASE_PRIVATE_KEY_FILE,
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

function Require-Value {
  param(
    [string]$Name,
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "Missing required release setting: $Name"
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

function Resolve-IsccPath {
  param([string]$ExplicitPath)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    Require-File $ExplicitPath
    return (Resolve-Path -LiteralPath $ExplicitPath).Path
  }

  $Command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
  if ($Command) {
    return $Command.Source
  }

  $CandidatePaths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
  )

  foreach ($CandidatePath in $CandidatePaths) {
    if (Test-Path -LiteralPath $CandidatePath -PathType Leaf) {
      return $CandidatePath
    }
  }

  throw "Missing required command: ISCC.exe. Install Inno Setup 6 or pass -IsccPath."
}

function Assert-NativeVersionOutput {
  param(
    [string]$Path,
    [string]$Name
  )

  $Output = & $Path --version 2>&1
  $ExitCode = $LASTEXITCODE
  if ($ExitCode -ne 0) {
    throw "Bundled $Name failed version validation with exit code $ExitCode.`n$($Output -join "`n")"
  }

  $FirstLine = @(
    $Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  ) | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($FirstLine)) {
    throw "Bundled $Name produced no version output."
  }

  Write-Host $FirstLine
}

function Get-VcRuntimeCandidateDirectories {
  $CandidateDirectories = @()

  if (-not [string]::IsNullOrWhiteSpace($env:VCToolsRedistDir)) {
    foreach ($CrtDirectoryName in @(
      "Microsoft.VC143.CRT",
      "Microsoft.VC142.CRT"
    )) {
      $CandidateDirectories += Join-Path `
        (Join-Path $env:VCToolsRedistDir "x64") `
        $CrtDirectoryName
    }
  }

  $VswhereCandidates = @()
  $VswhereCommand = Get-Command "vswhere.exe" -ErrorAction SilentlyContinue
  if ($VswhereCommand) {
    $VswhereCandidates += $VswhereCommand.Source
  }

  if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
    $VswhereCandidates += Join-Path `
      ${env:ProgramFiles(x86)} `
      "Microsoft Visual Studio\Installer\vswhere.exe"
  }

  foreach ($VswherePath in @($VswhereCandidates | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $VswherePath -PathType Leaf)) {
      continue
    }

    $InstallationPath = (
      & $VswherePath `
        -latest `
        -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath
    ) | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($InstallationPath)) {
      continue
    }

    $RedistRoot = Join-Path $InstallationPath "VC\Redist\MSVC"
    if (-not (Test-Path -LiteralPath $RedistRoot -PathType Container)) {
      continue
    }

    $VersionDirectories = Get-ChildItem -LiteralPath $RedistRoot -Directory |
      Sort-Object Name -Descending
    foreach ($VersionDirectory in $VersionDirectories) {
      $X64Directory = Join-Path $VersionDirectory.FullName "x64"
      if (-not (Test-Path -LiteralPath $X64Directory -PathType Container)) {
        continue
      }

      $CrtDirectories = Get-ChildItem `
        -LiteralPath $X64Directory `
        -Directory `
        -Filter "Microsoft.VC*.CRT" |
        Sort-Object Name -Descending
      foreach ($CrtDirectory in $CrtDirectories) {
        $CandidateDirectories += $CrtDirectory.FullName
      }
    }
  }

  return @(
    $CandidateDirectories |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      Select-Object -Unique
  )
}

function Install-VcRuntime {
  param(
    [string]$DestinationDirectory,
    [string[]]$RequiredFiles
  )

  $MissingFiles = @(
    $RequiredFiles | Where-Object {
      -not (Test-Path -LiteralPath (Join-Path $DestinationDirectory $_) -PathType Leaf)
    }
  )
  if ($MissingFiles.Count -eq 0) {
    Write-Host "Visual C++ runtime is already bundled."
    return
  }

  $SourceDirectory = $null
  foreach ($CandidateDirectory in @(Get-VcRuntimeCandidateDirectories)) {
    $ContainsAllFiles = @(
      $RequiredFiles | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $CandidateDirectory $_) -PathType Leaf)
      }
    ).Count -eq 0
    if ($ContainsAllFiles) {
      $SourceDirectory = $CandidateDirectory
      break
    }
  }

  if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
    throw "Visual C++ x64 runtime files were not found. Install the Visual Studio C++ desktop workload with redistributable components."
  }

  Write-Host "Bundling Visual C++ runtime from: $SourceDirectory"
  foreach ($FileName in $RequiredFiles) {
    Copy-Item `
      -LiteralPath (Join-Path $SourceDirectory $FileName) `
      -Destination (Join-Path $DestinationDirectory $FileName) `
      -Force
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
      "${RootPrefix}FrameLeanUpdaterHelper.exe",
      "${RootPrefix}flutter_windows.dll",
      "${RootPrefix}msvcp140.dll",
      "${RootPrefix}vcruntime140.dll",
      "${RootPrefix}vcruntime140_1.dll",
      "${RootPrefix}data/app.so",
      "${RootPrefix}framelean-engine.exe",
      "${RootPrefix}legal/LICENSE",
      "${RootPrefix}legal/NOTICE.md"
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

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ClientRoot = Join-Path $Root "desktop-client"
$ReleaseDir = Join-Path $ClientRoot "build\windows\x64\runner\Release"
$ZipDir = Join-Path $ClientRoot "build\windows\x64\runner"
$InstallerDir = Join-Path $ClientRoot "build\windows\x64\installer"
$FEngineDir = Join-Path $Root "build\dependencies\fengine\windows-x64"
$QmcAdapterDir = Join-Path $Root "build\dependencies\qmc\windows-x64"
$LegalDir = Join-Path $Root "legal"
$PubspecPath = Join-Path $ClientRoot "pubspec.yaml"
$IssPath = Join-Path $Root "installer\windows\FrameLean.iss"
$UpdaterHelperSourcePath = Join-Path $Root "tools\windows_updater_helper.dart"
$UpdateSignerPath = Join-Path $Root "tools\sign_windows_update.dart"
$ReleaseToolsDir = Join-Path $ReleaseDir "tools"
$QmcAdapterNames = @(
  "framelean-qmc-adapter.exe",
  "qmc-decrypt.exe"
)
$VcRuntimeFiles = @(
  "msvcp140.dll",
  "vcruntime140.dll",
  "vcruntime140_1.dll"
)

# Extract version and build number from pubspec.yaml
$PubspecContent = Get-Content $PubspecPath -Raw
$PubspecVersionMatch = [regex]::Match($PubspecContent, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)')
if (-not $PubspecVersionMatch.Success) {
  throw "Could not parse version from $PubspecPath"
}
$PubspecVersion = $PubspecVersionMatch.Groups[1].Value
$PubspecBuild = $PubspecVersionMatch.Groups[2].Value

Require-Command "flutter"
Require-Command "dart"
Require-File (Join-Path $FEngineDir "framelean-engine.exe")
Require-Directory $LegalDir
Require-File (Join-Path $Root "LICENSE")
Require-File (Join-Path $LegalDir "NOTICE.md")
Require-File $UpdaterHelperSourcePath
Require-File $UpdateSignerPath
Require-Value "FRAMELEAN_UPDATE_BASE_URL" $UpdateBaseUrl
Require-Value "FRAMELEAN_RELEASE_KEY_ID" $ReleaseKeyId
Require-Value "FRAMELEAN_RELEASE_PUBLIC_KEY" $ReleasePublicKey
Require-Value "FRAMELEAN_RELEASE_PRIVATE_KEY_FILE" $ReleasePrivateKeyFile
Require-File $ReleasePrivateKeyFile
$ReleasePrivateKeyFile = (Resolve-Path -LiteralPath $ReleasePrivateKeyFile).Path
if (-not $UpdateBaseUrl.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "FRAMELEAN_UPDATE_BASE_URL must use HTTPS for a release build."
}

$Iscc = $null
if (-not $SkipInstaller) {
  Require-File $IssPath
  $Iscc = Resolve-IsccPath -ExplicitPath $IsccPath
}

$Version = if ([string]::IsNullOrWhiteSpace($BuildName)) {
  Get-PubspecVersion -Path $PubspecPath
} else {
  $BuildName.Trim()
}
$PackageName = "FrameLean-v$Version-windows-x64"
$ZipPath = Join-Path $ZipDir "$PackageName.zip"
$SetupPath = Join-Path $InstallerDir "$PackageName-setup.exe"

Push-Location $ClientRoot
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
  $BuildArgs += @(
    "--dart-define=FRAMELEAN_UPDATE_BASE_URL=$UpdateBaseUrl",
    "--dart-define=FRAMELEAN_TRUSTED_RELEASE_KEY_IDS=$ReleaseKeyId",
    "--dart-define=FRAMELEAN_RELEASE_PUBLIC_KEYS=$ReleaseKeyId=$ReleasePublicKey",
    "--dart-define=FRAMELEAN_REQUIRE_RELEASE_SIGNATURE=true"
  )

  Write-Host "Generating build info from pubspec.yaml..."
  Invoke-Checked "dart" @("run", (Join-Path $Root "tools\generate_build_info.dart"))

  Write-Host "Building Windows release with: flutter $($BuildArgs -join ' ')"
  Invoke-Checked "flutter" $BuildArgs

  Require-Directory $ReleaseDir
  Require-File (Join-Path $ReleaseDir "FrameLean.exe")
  Require-File (Join-Path $ReleaseDir "flutter_windows.dll")
  Require-Directory (Join-Path $ReleaseDir "data")
  Require-File (Join-Path $ReleaseDir "framelean-engine.exe")
  Require-File (Join-Path $ReleaseDir "legal\COPYING")
  Require-File (Join-Path $ReleaseDir "legal\LICENSE")
  Require-File (Join-Path $ReleaseDir "legal\NOTICE.md")
  Install-VcRuntime `
    -DestinationDirectory $ReleaseDir `
    -RequiredFiles $VcRuntimeFiles
  foreach ($VcRuntimeFile in $VcRuntimeFiles) {
    Require-File (Join-Path $ReleaseDir $VcRuntimeFile)
  }

  Write-Host "Building updater helper..."
  Invoke-Checked "dart" @(
    "compile",
    "exe",
    $UpdaterHelperSourcePath,
    "-o",
    (Join-Path $ReleaseDir "FrameLeanUpdaterHelper.exe")
  )
  Require-File (Join-Path $ReleaseDir "FrameLeanUpdaterHelper.exe")

  $QmcAdapterSources = @(
    $QmcAdapterNames | ForEach-Object {
      Join-Path $QmcAdapterDir $_
    }
  )
  $HasQmcAdapterSource = @($QmcAdapterSources | Where-Object {
    Test-Path -LiteralPath $_ -PathType Leaf
  }).Count -gt 0
  if ($HasQmcAdapterSource) {
    $ReleaseQmcDir = Join-Path $ReleaseDir "audio_adapters\qmc"
    $HasQmcAdapterTarget = @($QmcAdapterNames | Where-Object {
      Test-Path -LiteralPath (Join-Path $ReleaseQmcDir $_) -PathType Leaf
    }).Count -gt 0
    if (-not $HasQmcAdapterTarget) {
      throw "QMC audio adapter source exists but was not copied into the release directory."
    }
    Require-File (Join-Path $ReleaseQmcDir "LICENSE-MIT")
    Require-File (Join-Path $ReleaseQmcDir "LICENSE-APACHE")
  }

  Write-Host "Validating bundled FEngine runtime..."
  Assert-NativeVersionOutput `
    -Path (Join-Path $ReleaseDir "framelean-engine.exe") `
    -Name "framelean-engine.exe"

  if (Test-Path -LiteralPath $ReleaseToolsDir -PathType Container) {
    Remove-Item -LiteralPath $ReleaseToolsDir -Recurse -Force
  }

  if (-not $SkipZip) {
    Write-Host "Creating zip package: $ZipPath"
    New-ReleaseZip -SourceDirectory $ReleaseDir -DestinationPath $ZipPath -RootEntryName $PackageName
    Require-File $ZipPath
    Assert-ZipLayout -Path $ZipPath -RootEntryName $PackageName
  }

  if (-not $SkipInstaller) {
    New-Item -ItemType Directory -Path $ReleaseToolsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $InstallerDir -Force | Out-Null
    if (Test-Path -LiteralPath $SetupPath -PathType Leaf) {
      Remove-Item -LiteralPath $SetupPath -Force
    }

    & $Iscc $IssPath `
      "/DAppVersion=$Version" `
      "/DSourceDir=$ReleaseDir" `
      "/DOutputDir=$InstallerDir"
    if ($LASTEXITCODE -ne 0) {
      throw "Inno Setup failed with exit code $LASTEXITCODE."
    }
    Require-File $SetupPath

    Write-Host "Signing Windows update installer..."
    Invoke-Checked "dart" @(
      "run",
      $UpdateSignerPath,
      "--input",
      $SetupPath,
      "--private-key",
      $ReleasePrivateKeyFile,
      "--key-id",
      $ReleaseKeyId,
      "--public-key",
      $ReleasePublicKey,
      "--output",
      "$SetupPath.update.json",
      "--version",
      $PubspecVersion,
      "--build-number",
      $PubspecBuild
    )
    Require-File "$SetupPath.update.json"
  }

  Write-Host ""
  Write-Host "Windows release packages are ready:"
  Write-Host $ReleaseDir
  if (-not $SkipZip) {
    Write-Host $ZipPath
  }
  if (-not $SkipInstaller) {
    Write-Host $SetupPath
    Write-Host "$SetupPath.update.json"
  }
}
finally {
  Pop-Location
}
