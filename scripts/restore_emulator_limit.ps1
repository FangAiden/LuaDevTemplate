param(
  [string]$ExtensionsRoot = (Join-Path $env:USERPROFILE ".aiot-ide\extensions"),
  [string]$Needle = "F.REL,F.VELA_MIWEAR_WATCH_5"
)

. (Join-Path $PSScriptRoot "internal\find_emulator_ext.ps1")

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
$containsNeedle = Contains-ByteSequence $bytes $needleBytes

Write-Host "Restored from backup: $($chosenBackup.FullName)"
Write-Host "Safety backup of current file: $restoreBackup"
if (-not $containsNeedle) {
  Write-Warning "Restore completed, but the expected string was not found in the restored file."
  Write-Warning "The extension may have changed; verify manually if needed."
}
Write-Host "Restart AIOT IDE for changes to take effect."
