$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$configPath = Join-Path $root "watchface.config.json"
if (-not (Test-Path $configPath)) {
  Write-Error "watchface.config.json not found at $configPath"
  exit 1
}

$configRaw = Get-Content -Raw -Encoding UTF8 $configPath
$config = $configRaw | ConvertFrom-Json

# Match: (Math.random() * 10 ** 12).toFixed(0)
# Compiler.exe uses Int32, so keep within 1..2147483647.
$rng = New-Object System.Random
$max = [int]::MaxValue
$value = [math]::Round($rng.NextDouble() * $max, 0, [MidpointRounding]::AwayFromZero)
if ($value -lt 1) { $value = 1 }
$watchfaceId = ([int]$value).ToString()

$config.watchfaceId = $watchfaceId

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$json = $config | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($configPath, $json + "`r`n", $utf8NoBom)

Write-Host "Generated watchfaceId: $watchfaceId"
