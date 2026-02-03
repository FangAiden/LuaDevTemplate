. (Join-Path $PSScriptRoot "load_config.ps1")

if (-not $config.watchfaceId) { throw "Missing watchfaceId in watchface.config.json" }

$watchfaceName = if ($config.watchfaceName) { [string]$config.watchfaceName } else { [string]$config.projectName }
$watchfaceId = [string]$config.watchfaceId
$powerConsumption = if ($config.power_consumption) { [string]$config.power_consumption } elseif ($config.powerConsumption) { [string]$config.powerConsumption } else { $null }

$deviceSerial = "emulator-5554"
$devicePath = "/data/app/watchface/watchface_list.json"
$watchfaceListPath = Join-Path $root "watchface\data\watchface_list.json"
$watchfaceListDir = Split-Path -Parent $watchfaceListPath

if (-not (Test-Path $watchfaceListDir)) {
  New-Item -ItemType Directory -Path $watchfaceListDir | Out-Null
}

Write-Host "Pulling watchface_list.json from $deviceSerial..."
& adb -s $deviceSerial pull $devicePath $watchfaceListPath
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$listText = Get-Content -Raw -Encoding UTF8 $watchfaceListPath
$listObj = $listText | ConvertFrom-Json
$watchfaceList = @($listObj.watchface_list)

$templateJson = @'
{
  "id": "167210065",
  "name": "LuaDev",
  "name_translation": [],
  "version": "0",
  "type": "1",
  "in_use": "1",
  "is_delete": "0",
  "editable": "0",
  "support_album": "0",
  "support_AOD": "0",
  "support_dark_mode": "0",
  "sku": "0",
  "power_consumption": "3",
  "theme_count": "1",
  "color_table": [],
  "color_group_table": [],
  "trial_period": "0",
  "theme_type_info": [
    { "name": "", "type": "0" }
  ]
}
'@

$template = $templateJson | ConvertFrom-Json
$template.id = $watchfaceId
$template.name = $watchfaceName
$template.in_use = "1"
if ($powerConsumption) {
  $template.power_consumption = $powerConsumption
}

$targetIndex = -1
for ($i = 0; $i -lt $watchfaceList.Count; $i++) {
  if ([string]$watchfaceList[$i].id -eq $watchfaceId) {
    $targetIndex = $i
    break
  }
}
if ($targetIndex -lt 0) {
  for ($i = 0; $i -lt $watchfaceList.Count; $i++) {
    if ([string]$watchfaceList[$i].type -eq "1") {
      $targetIndex = $i
      break
    }
  }
}

for ($i = 0; $i -lt $watchfaceList.Count; $i++) {
  $watchfaceList[$i].in_use = "0"
}

if ($targetIndex -ge 0) {
  $watchfaceList[$targetIndex] = $template
} else {
  $watchfaceList += $template
}

$listObj.watchface_list = $watchfaceList
$listText = $listObj | ConvertTo-Json -Depth 10
Write-Utf8NoBom -Path $watchfaceListPath -Content ($listText + "`r`n")

Write-Host "Synced watchface_list.json."
