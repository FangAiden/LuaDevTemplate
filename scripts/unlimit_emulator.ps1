param(
  [string]$ExtensionsRoot = (Join-Path $env:USERPROFILE ".aiot-ide\extensions"),
  [string]$Needle = "F.REL,F.VELA_MIWEAR_WATCH_5"
)

. (Join-Path $PSScriptRoot "internal\find_emulator_ext.ps1")

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

$bytes = [System.IO.File]::ReadAllBytes($targetFile)
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
