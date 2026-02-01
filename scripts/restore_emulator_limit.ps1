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

$backupCandidates = @()
$bak = $targetFile + ".bak"
if (Test-Path -LiteralPath $bak) {
  $backupCandidates += Get-Item -LiteralPath $bak
}

$bakPattern = [System.IO.Path]::GetFileName($targetFile) + ".bak.*"
$bakDir = Split-Path -Parent $targetFile
$bakMore = Get-ChildItem -Path $bakDir -File -Filter $bakPattern -ErrorAction SilentlyContinue
if ($bakMore) { $backupCandidates += $bakMore }

if (-not $backupCandidates -or $backupCandidates.Count -eq 0) {
  Write-Warning "No backup found next to target file. Nothing to restore."
  Write-Warning "Expected: $(Split-Path -Leaf $targetFile).bak (or .bak.*)"
  Write-Warning "Target file: $targetFile"
  exit 1
}

$chosenBackup = $backupCandidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$restoreBackup = $targetFile + ".restore.bak." + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item -LiteralPath $targetFile -Destination $restoreBackup -Force

Copy-Item -LiteralPath $chosenBackup.FullName -Destination $targetFile -Force

$bytes = [System.IO.File]::ReadAllBytes($targetFile)
$needleBytes = [System.Text.Encoding]::ASCII.GetBytes($Needle)
$containsNeedle = $false
if ($bytes.Length -ge $needleBytes.Length) {
  for ($i = 0; $i -le ($bytes.Length - $needleBytes.Length); $i++) {
    $isMatch = $true
    for ($j = 0; $j -lt $needleBytes.Length; $j++) {
      if ($bytes[$i + $j] -ne $needleBytes[$j]) { $isMatch = $false; break }
    }
    if ($isMatch) { $containsNeedle = $true; break }
  }
}

Write-Host "Restored from backup: $($chosenBackup.FullName)"
Write-Host "Safety backup of current file: $restoreBackup"
if (-not $containsNeedle) {
  Write-Warning "Restore completed, but the expected string was not found in the restored file."
  Write-Warning "The extension may have changed; verify manually if needed."
}
Write-Host "Restart AIOT IDE for changes to take effect."

