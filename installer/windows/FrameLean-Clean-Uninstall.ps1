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
  [switch]$Elevated,
  [string[]]$OriginalUserDataPaths = @(),
  [string[]]$OriginalTempPaths = @(),
  [string[]]$OriginalShortcutPaths = @(),
  [string]$OriginalUserRegistryRoot = ""
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

function Select-UniqueNonEmptyPath {
  param([string[]]$Paths)

  $Paths |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -Unique
}

function Resolve-DefaultUserDataPaths {
  Select-UniqueNonEmptyPath @(
    Join-ExistingPath $env:APPDATA "FrameLean",
    Join-ExistingPath $env:APPDATA "framelean",
    Join-ExistingPath $env:APPDATA "com.justin.framelean",
    Join-ExistingPath $env:APPDATA "com.justin\FrameLean",
    Join-ExistingPath $env:LOCALAPPDATA "FrameLean",
    Join-ExistingPath $env:LOCALAPPDATA "framelean",
    Join-ExistingPath $env:LOCALAPPDATA "com.justin.framelean",
    Join-ExistingPath $env:LOCALAPPDATA "com.justin\FrameLean"
  )
}

function Resolve-DefaultTempPaths {
  Select-UniqueNonEmptyPath @(
    Join-ExistingPath $env:TEMP "framelean",
    Join-ExistingPath $env:TEMP "FrameLean\uninstall"
  )
}

function Resolve-DefaultShortcutPaths {
  Select-UniqueNonEmptyPath @(
    Join-ExistingPath $env:APPDATA "Microsoft\Windows\Start Menu\Programs\FrameLean.lnk",
    Join-ExistingPath $env:APPDATA "Microsoft\Windows\Start Menu\Programs\FrameLean\FrameLean.lnk",
    Join-ExistingPath $env:USERPROFILE "Desktop\FrameLean.lnk",
    Join-ExistingPath $env:PUBLIC "Desktop\FrameLean.lnk"
  )
}

function Resolve-CurrentUserRegistryRoot {
  try {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if (-not [string]::IsNullOrWhiteSpace($sid)) {
      return "Registry::HKEY_USERS\$sid"
    }
  } catch {
    return ""
  }

  return ""
}

function Add-StringArrayArgument {
  param(
    [string[]]$ArgumentList,
    [string]$Name,
    [string[]]$Values
  )

  if ($null -eq $Values -or $Values.Count -eq 0) {
    return $ArgumentList
  }

  $next = @($ArgumentList) + "-$Name"
  foreach ($value in $Values) {
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      $next += Quote-NativeArgument $value
    }
  }

  return $next
}

if (($RemoveAll -or $RemoveMachineConfig) -and -not $Elevated -and -not (Test-Administrator)) {
  if ($OriginalUserDataPaths.Count -eq 0) {
    $OriginalUserDataPaths = Resolve-DefaultUserDataPaths
  }
  if ($OriginalTempPaths.Count -eq 0) {
    $OriginalTempPaths = Resolve-DefaultTempPaths
  }
  if ($OriginalShortcutPaths.Count -eq 0) {
    $OriginalShortcutPaths = Resolve-DefaultShortcutPaths
  }
  if ([string]::IsNullOrWhiteSpace($OriginalUserRegistryRoot)) {
    $OriginalUserRegistryRoot = Resolve-CurrentUserRegistryRoot
  }

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
  $elevatedArgs = Add-StringArrayArgument `
    -ArgumentList $elevatedArgs `
    -Name 'OriginalUserDataPaths' `
    -Values $OriginalUserDataPaths
  $elevatedArgs = Add-StringArrayArgument `
    -ArgumentList $elevatedArgs `
    -Name 'OriginalTempPaths' `
    -Values $OriginalTempPaths
  $elevatedArgs = Add-StringArrayArgument `
    -ArgumentList $elevatedArgs `
    -Name 'OriginalShortcutPaths' `
    -Values $OriginalShortcutPaths
  if (-not [string]::IsNullOrWhiteSpace($OriginalUserRegistryRoot)) {
    $elevatedArgs += @('-OriginalUserRegistryRoot', (Quote-NativeArgument $OriginalUserRegistryRoot))
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
$appDataPaths = if ($OriginalUserDataPaths.Count -gt 0) {
  Select-UniqueNonEmptyPath $OriginalUserDataPaths
} else {
  Resolve-DefaultUserDataPaths
}
$tempPaths = if ($OriginalTempPaths.Count -gt 0) {
  Select-UniqueNonEmptyPath $OriginalTempPaths
} else {
  Resolve-DefaultTempPaths
}
$shortcutPaths = if ($OriginalShortcutPaths.Count -gt 0) {
  Select-UniqueNonEmptyPath $OriginalShortcutPaths
} else {
  Resolve-DefaultShortcutPaths
}

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
  $userRegistryRoots = @('HKCU:')
  if (-not [string]::IsNullOrWhiteSpace($OriginalUserRegistryRoot)) {
    $userRegistryRoots += $OriginalUserRegistryRoot
  }

  $registryKeys = @()
  foreach ($root in ($userRegistryRoots | Select-Object -Unique)) {
    $registryKeys += @(
      "$root\Software\FrameLean\FrameLean",
      "$root\Software\FrameLean",
      "$root\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrameLean_is1",
      "$root\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($AppId)_is1"
    )
  }
  $registryKeys += @(
    "HKLM:\Software\FrameLean\FrameLean",
    "HKLM:\Software\FrameLean",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrameLean_is1",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($AppId)_is1"
  )

  foreach ($registryKey in ($registryKeys | Select-Object -Unique)) {
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
