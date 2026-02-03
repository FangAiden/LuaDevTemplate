# 公共模块：查找模拟器扩展中的 CreateEmulator.js
# 调用者需提供 $ExtensionsRoot 和 $Needle 变量

$ErrorActionPreference = "Stop"

if (-not $ExtensionsRoot) { $ExtensionsRoot = Join-Path $env:USERPROFILE ".aiot-ide\extensions" }
if (-not $Needle) { $Needle = "F.REL,F.VELA_MIWEAR_WATCH_5" }

function Get-EmulatorVersion([string]$dirName) {
  if ($dirName -match '^vela\.aiot-emulator-(\d+(?:\.\d+){1,3})') {
    try { return [version]$Matches[1] } catch { return $null }
  }
  return $null
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

# 导出：$targetFile, $Needle, $needleBytes, Contains-ByteSequence
$needleBytes = [System.Text.Encoding]::ASCII.GetBytes($Needle)
