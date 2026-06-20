param(
  [string]$ExtensionsRoot = (Join-Path $env:USERPROFILE ".aiot-ide\extensions")
)

# 使用正则表达式匹配特征，因为混淆后的变量名可能是 F, U 或其他任意字母
[string]$NeedleRegex = "[a-zA-Z_$]\.REL,[a-zA-Z_$]\.VELA_MIWEAR_WATCH_5"

. (Join-Path $PSScriptRoot "internal\find_emulator_ext.ps1")

# 读取为 UTF-8 字符串
$content = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)

$matches = [System.Text.RegularExpressions.Regex]::Matches($content, $NeedleRegex)
if ($matches.Count -eq 0) {
  Write-Warning "Replace failed: pattern not found: $NeedleRegex"
  Write-Warning "The extension may have been updated, or the file is already patched."
  Write-Warning "Target file: $targetFile"
  exit 1
}

$backupPath = $targetFile + ".bak"
if (Test-Path -LiteralPath $backupPath) {
  $backupPath = $targetFile + ".bak." + (Get-Date -Format "yyyyMMdd_HHmmss")
}

Copy-Item -LiteralPath $targetFile -Destination $backupPath -Force

# 将匹配到的模式替换为空
$newContent = [System.Text.RegularExpressions.Regex]::Replace($content, $NeedleRegex, "")

# 保存为无 BOM 的 UTF-8 编码
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($targetFile, $newContent, $utf8NoBom)

$verifyContent = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)
if ([System.Text.RegularExpressions.Regex]::IsMatch($verifyContent, $NeedleRegex)) {
  Write-Error "Post-write check failed: pattern still present: $targetFile"
  Write-Host "You can restore from backup: $backupPath"
  exit 1
}

Write-Host "Removed occurrences: $($matches.Count)"
Write-Host "Done. Patched file: $targetFile"
Write-Host "Backup: $backupPath"
Write-Host "Restart AIOT IDE for changes to take effect."
