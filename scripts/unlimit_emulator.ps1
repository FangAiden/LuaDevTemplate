param(
  [string]$ExtensionsRoot = (Join-Path $env:USERPROFILE ".aiot-ide\extensions"),
  [string]$Needle = "F.REL,F.VELA_MIWEAR_WATCH_5"
)

$ErrorActionPreference = "Stop"

function Get-EmulatorVersion([string]$dirName) {
  if ($dirName -match '^vela\.aiot-emulator-(\d+(?:\.\d+){1,3})') {
    try { return [version]$Matches[1] } catch { return $null }
  }
  return $null
}

function Remove-ByteSequence([byte[]]$haystack, [byte[]]$needle) {
  if (-not $needle -or $needle.Length -eq 0) { return @($haystack, 0) }
  if (-not $haystack -or $haystack.Length -eq 0) { return @($haystack, 0) }
  if ($needle.Length -gt $haystack.Length) { return @($haystack, 0) }

  $removed = 0
  $ms = New-Object System.IO.MemoryStream

  for ($i = 0; $i -lt $haystack.Length;) {
    $isMatch = $false
    if (($i + $needle.Length) -le $haystack.Length) {
      $isMatch = $true
      for ($j = 0; $j -lt $needle.Length; $j++) {
        if ($haystack[$i + $j] -ne $needle[$j]) { $isMatch = $false; break }
      }
    }

    if ($isMatch) {
      $removed++
      $i += $needle.Length
      continue
    }

    $ms.WriteByte($haystack[$i])
    $i++
  }

  return @($ms.ToArray(), $removed)
}

function Contains-ByteSequence([byte[]]$haystack, [byte[]]$needle) {
  if (-not $needle -or $needle.Length -eq 0) { return $true }
  if (-not $haystack -or $haystack.Length -eq 0) { return $false }
  if ($needle.Length -gt $haystack.Length) { return $false }

  for ($i = 0; $i -le ($haystack.Length - $needle.Length); $i++) {
    $isMatch = $true
    for ($j = 0; $j -lt $needle.Length; $j++) {
      if ($haystack[$i + $j] -ne $needle[$j]) { $isMatch = $false; break }
    }
    if ($isMatch) { return $true }
  }
  return $false
}

if ([string]::IsNullOrWhiteSpace($ExtensionsRoot)) {
  Write-Error "ExtensionsRoot cannot be empty."
  exit 1
}

if (-not (Test-Path -LiteralPath $ExtensionsRoot)) {
  Write-Error "Extensions root not found: $ExtensionsRoot"
  exit 1
}

$emulatorDirs = Get-ChildItem -Directory -Path $ExtensionsRoot -Filter "vela.aiot-emulator-*" -ErrorAction SilentlyContinue
if (-not $emulatorDirs -or $emulatorDirs.Count -eq 0) {
  Write-Error "No vela.aiot-emulator extension found under: $ExtensionsRoot"
  exit 1
}

$candidates =
  $emulatorDirs |
  ForEach-Object {
    [pscustomobject]@{
      Dir           = $_
      Version       = (Get-EmulatorVersion $_.Name)
      LastWriteTime = $_.LastWriteTime
    }
  } |
  Sort-Object `
    @{ Expression = { if ($_.Version) { $_.Version } else { [version]"0.0.0.0" } }; Descending = $true }, `
    @{ Expression = { $_.LastWriteTime }; Descending = $true }

$selected = $candidates | Select-Object -First 1
$selectedDir = $selected.Dir.FullName
$selectedName = $selected.Dir.Name
$selectedVersionText = if ($selected.Version) { $selected.Version.ToString() } else { "unknown" }

Write-Host "Using extension directory: $selectedName (version=$selectedVersionText)"

$defaultFile = Join-Path $selectedDir "dist\webview\assets\CreateEmulator.js"
$targetFile = $null

if (Test-Path -LiteralPath $defaultFile) {
  $targetFile = $defaultFile
} else {
  $found = Get-ChildItem -Path $selectedDir -Recurse -File -Filter "CreateEmulator.js" -ErrorAction SilentlyContinue
  if ($found) {
    $targetFile = (
      $found |
      Sort-Object `
        @{ Expression = { $_.FullName -like "*dist\webview\assets\CreateEmulator.js" }; Descending = $true }, `
        @{ Expression = { $_.FullName.Length }; Ascending = $true } |
      Select-Object -First 1
    ).FullName
    Write-Host "Default path not found; using search result: $targetFile"
  }
}

if (-not $targetFile -or -not (Test-Path -LiteralPath $targetFile)) {
  Write-Warning "CreateEmulator.js not found. The extension may have been updated and this script is not compatible."
  Write-Warning "Extension directory: $selectedDir"
  exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($targetFile)
$needleBytes = [System.Text.Encoding]::ASCII.GetBytes($Needle)
if (-not (Contains-ByteSequence $bytes $needleBytes)) {
  Write-Warning "Replace failed: needle not found: $Needle"
  Write-Warning "The extension may have been updated; this script may be out of date."
  Write-Warning "Target file: $targetFile"
  exit 1
}

$backupPath = $targetFile + ".bak"
if (Test-Path -LiteralPath $backupPath) {
  $backupPath = $targetFile + ".bak." + (Get-Date -Format "yyyyMMdd_HHmmss")
}

Copy-Item -LiteralPath $targetFile -Destination $backupPath -Force

$result = Remove-ByteSequence $bytes $needleBytes
$newBytes = $result[0]
$removed = [int]$result[1]
if ($removed -le 0) {
  Write-Warning "Replace failed: needle not found: $Needle"
  Write-Warning "The extension may have been updated; this script may be out of date."
  Write-Warning "Target file: $targetFile"
  exit 1
}

[System.IO.File]::WriteAllBytes($targetFile, $newBytes)

$verifyBytes = [System.IO.File]::ReadAllBytes($targetFile)
if (Contains-ByteSequence $verifyBytes $needleBytes) {
  Write-Error "Post-write check failed: needle still present: $targetFile"
  Write-Host "You can restore from backup: $backupPath"
  exit 1
}

Write-Host "Removed occurrences: $removed"
Write-Host "Done. Patched file: $targetFile"
Write-Host "Backup: $backupPath"
Write-Host "Restart AIOT IDE for changes to take effect."
