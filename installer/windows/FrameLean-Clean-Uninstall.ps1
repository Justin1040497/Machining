param(
  [switch]$RemoveAll,
  [switch]$RemoveUserData,
  [switch]$RemoveRegistry,
  [switch]$RemoveTemp,
  [switch]$RemoveInstallDir,
  [switch]$RemoveMachineConfig,
  [switch]$Force,
  [switch]$DryRun,
  [int]$WaitForPid = 0,
  [string]$InstallDir = "",
  [switch]$LaunchedFromApp,
  [switch]$Elevated
)

$ErrorActionPreference = "Stop"

$AppId = "{7E8C56BB-B9B6-4D87-A4BE-97E6F60B113A}"
$AppName = "FrameLean"

if ($RemoveAll) {
  $RemoveUserData = $true
  $RemoveRegistry = $true
  $RemoveTemp = $true
  $RemoveInstallDir = $true
  $RemoveMachineConfig = $true
}

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Quote-NativeArgument {
  param([string]$Value)
  return '"' + $Value.Replace('"', '\"') + '"'
}

if (($RemoveAll -or $RemoveMachineConfig) -and -not $Elevated -and -not (Test-Administrator)) {
  $elevatedArgs = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', (Quote-NativeArgument $PSCommandPath),
    '-Elevated'
  )
  foreach ($switchName in @(
    'RemoveAll',
    'RemoveUserData',
    'RemoveRegistry',
    'RemoveTemp',
    'RemoveInstallDir',
    'RemoveMachineConfig',
    'Force',
    'DryRun',
    'LaunchedFromApp'
  )) {
    if ((Get-Variable -Name $switchName -ValueOnly)) {
      $elevatedArgs += "-$switchName"
    }
  }
  if ($WaitForPid -gt 0) {
    $elevatedArgs += @('-WaitForPid', $WaitForPid)
  }
  if (-not [string]::IsNullOrWhiteSpace($InstallDir)) {
    $elevatedArgs += @('-InstallDir', (Quote-NativeArgument $InstallDir))
  }
  $process = Start-Process `
    -FilePath 'PowerShell' `
    -ArgumentList ($elevatedArgs -join ' ') `
    -Verb RunAs `
    -Wait `
    -PassThru
  exit $process.ExitCode
}

function Write-Step {
  param([string]$Message)
  Write-Host "[FrameLean] $Message"
}

function Join-ExistingPath {
  param(
    [string]$Base,
    [string]$Child
  )

  if ([string]::IsNullOrWhiteSpace($Base)) {
    return $null
  }

  return Join-Path -Path $Base -ChildPath $Child
}

function Remove-OwnedPath {
  param(
    [string]$Path,
    [switch]$DirectoryOnly
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return
  }

  if ($DirectoryOnly -and -not (Test-Path -LiteralPath $Path -PathType Container)) {
    return
  }

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  Write-Step "Remove path: $Path"
  if (-not $DryRun) {
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
  }
}

function Remove-OwnedRegistryKey {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  Write-Step "Remove registry key: $Path"
  if (-not $DryRun) {
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
  }
}

function Wait-FrameLeanProcess {
  param([int]$ProcessId)

  if ($ProcessId -le 0) {
    return
  }

  $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($null -eq $process) {
    return
  }

  Write-Step "Wait for FrameLean process to exit: $ProcessId"
  Wait-Process -Id $ProcessId -Timeout 60 -ErrorAction SilentlyContinue
}

function Resolve-InstallDir {
  if (-not [string]::IsNullOrWhiteSpace($InstallDir)) {
    return $InstallDir
  }

  $registryPaths = @(
    "HKCU:\Software\FrameLean\FrameLean",
    "HKLM:\Software\FrameLean\FrameLean"
  )

  foreach ($registryPath in $registryPaths) {
    if (Test-Path -LiteralPath $registryPath) {
      $installPath = (Get-ItemProperty -LiteralPath $registryPath -ErrorAction SilentlyContinue).InstallPath
      if (-not [string]::IsNullOrWhiteSpace($installPath)) {
        return $installPath
      }
    }
  }

  return ""
}

if (-not $Force) {
  Write-Host "This will remove FrameLean application data, cache, registry entries, and optionally the install directory."
  $answer = Read-Host "Type FrameLean to continue"
  if ($answer -ne "FrameLean") {
    Write-Step "Cancelled"
    exit 1
  }
}

Wait-FrameLeanProcess -ProcessId $WaitForPid

$resolvedInstallDir = Resolve-InstallDir
$appDataPaths = @(
  Join-ExistingPath $env:APPDATA "FrameLean",
  Join-ExistingPath $env:APPDATA "framelean",
  Join-ExistingPath $env:APPDATA "com.justin.framelean",
  Join-ExistingPath $env:APPDATA "com.justin\FrameLean",
  Join-ExistingPath $env:LOCALAPPDATA "FrameLean",
  Join-ExistingPath $env:LOCALAPPDATA "framelean",
  Join-ExistingPath $env:LOCALAPPDATA "com.justin.framelean",
  Join-ExistingPath $env:LOCALAPPDATA "com.justin\FrameLean"
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

$tempPaths = @(
  Join-ExistingPath $env:TEMP "framelean",
  Join-ExistingPath $env:TEMP "FrameLean\uninstall"
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

$shortcutPaths = @(
  Join-ExistingPath $env:APPDATA "Microsoft\Windows\Start Menu\Programs\FrameLean.lnk",
  Join-ExistingPath $env:APPDATA "Microsoft\Windows\Start Menu\Programs\FrameLean\FrameLean.lnk",
  Join-ExistingPath $env:USERPROFILE "Desktop\FrameLean.lnk",
  Join-ExistingPath $env:PUBLIC "Desktop\FrameLean.lnk"
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

if ($RemoveUserData) {
  foreach ($path in $appDataPaths) {
    Remove-OwnedPath -Path $path -DirectoryOnly
  }
}

if ($RemoveTemp) {
  foreach ($path in $tempPaths) {
    Remove-OwnedPath -Path $path -DirectoryOnly
  }
}

if ($RemoveRegistry) {
  $registryKeys = @(
    "HKCU:\Software\FrameLean\FrameLean",
    "HKCU:\Software\FrameLean",
    "HKLM:\Software\FrameLean\FrameLean",
    "HKLM:\Software\FrameLean",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrameLean_is1",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($AppId)_is1",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrameLean_is1",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($AppId)_is1"
  )

  foreach ($registryKey in $registryKeys) {
    Remove-OwnedRegistryKey -Path $registryKey
  }
}

if ($RemoveMachineConfig) {
  Remove-OwnedPath -Path (Join-ExistingPath $env:ProgramData 'FrameLean') -DirectoryOnly
  Remove-OwnedRegistryKey -Path 'HKLM:\Software\Policies\FrameLean'
}

if ($RemoveAll) {
  foreach ($path in $shortcutPaths) {
    Remove-OwnedPath -Path $path
  }
}

if ($RemoveInstallDir -and -not [string]::IsNullOrWhiteSpace($resolvedInstallDir)) {
  Remove-OwnedPath -Path $resolvedInstallDir -DirectoryOnly
}

Write-Step "Clean uninstall finished"
