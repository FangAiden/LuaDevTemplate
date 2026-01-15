@echo off
REM 全新部署：资源+列表+Lua+重启
for /f "tokens=2 delims=: " %%A in ('chcp') do set "_ORIG_CP=%%A"
chcp 65001 >nul
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT=%%~fI"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%internal\sync_watchface_list.ps1"
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%internal\sync_watchface_config.ps1"
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%internal\build_resource_bin.ps1"
if errorlevel 1 exit /b 1

call "%SCRIPT_DIR%build_face.bat"
if errorlevel 1 exit /b 1

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-Content -Raw -Encoding UTF8 '%ROOT%\watchface.config.json' | ConvertFrom-Json).watchfaceId"`) do set "WATCHFACE_ID=%%A"

if "%WATCHFACE_ID%"=="" (
  echo [ERROR] watchfaceId not found in watchface.config.json
  exit /b 1
)

set "DEST_PATH=/data/app/watchface/market/%WATCHFACE_ID%/"
set "STAMP_DIR=.hotreload"

for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')"`) do set "STAMP_NAME=%%T"
set "STAMP_LOCAL=%TEMP%\%STAMP_NAME%"
type nul > "%STAMP_LOCAL%"

echo ==========================================
echo Delete dir: %DEST_PATH%
echo Push main: %ROOT%\watchface\lua\main.lua ^> %DEST_PATH%lua\main.lua
echo Push config: %ROOT%\watchface\lua\config.lua ^> %DEST_PATH%lua\config.lua
echo Push app: %ROOT%\watchface\lua\fprj\app\lua ^> %DEST_PATH%lua\app\lua
echo Push resource.bin: %ROOT%\watchface\data\resource.bin
echo Push preview.bin: %ROOT%\watchface\data\preview.bin
echo Push watchface_list.json: %ROOT%\watchface\data\watchface_list.json
echo Push stamp: %STAMP_NAME%
echo ==========================================

adb shell "rm -rf '%DEST_PATH%'"

adb shell "mkdir '%DEST_PATH%'"
adb shell "mkdir '%DEST_PATH%lua'"
adb shell "mkdir '%DEST_PATH%lua/app'"
adb shell "mkdir '%DEST_PATH%%STAMP_DIR%'"

adb push "%ROOT%\watchface\lua\main.lua" "%DEST_PATH%lua/main.lua"
adb push "%ROOT%\watchface\lua\config.lua" "%DEST_PATH%lua/config.lua"
adb push "%ROOT%\watchface\lua\fprj\app\lua" "%DEST_PATH%lua/app"

adb push "%ROOT%\watchface\data\resource.bin" "%DEST_PATH%"

adb push "%ROOT%\watchface\data\preview.bin" "%DEST_PATH%"

adb push "%ROOT%\watchface\data\watchface_list.json" "/data/app/watchface/"

adb push "%STAMP_LOCAL%" "%DEST_PATH%%STAMP_DIR%/%STAMP_NAME%"

del /f /q "%STAMP_LOCAL%" >nul 2>&1

adb reboot
if errorlevel 1 exit /b 1

endlocal
