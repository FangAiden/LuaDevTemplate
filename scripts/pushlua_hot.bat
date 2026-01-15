@echo off
REM 热部署：仅 Lua + 热更标记
for /f "tokens=2 delims=: " %%A in ('chcp') do set "_ORIG_CP=%%A"
chcp 65001 >nul
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT=%%~fI"

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
echo Delete dir: %DEST_PATH%lua
echo Push main: %ROOT%\watchface\lua\main.lua ^> %DEST_PATH%lua\main.lua
echo Push config: %ROOT%\watchface\lua\config.lua ^> %DEST_PATH%lua\config.lua
echo Push app: %ROOT%\watchface\lua\fprj\app ^> %DEST_PATH%lua
echo Push stamp: %STAMP_NAME%
echo ==========================================

adb shell "rm -rf '%DEST_PATH%lua'"

adb shell "mkdir '%DEST_PATH%lua'"
adb shell "mkdir '%DEST_PATH%lua/app'"

adb shell "rm -rf '%DEST_PATH%%STAMP_DIR%'"
adb shell "mkdir '%DEST_PATH%%STAMP_DIR%'"

adb push "%ROOT%\watchface\lua\main.lua" "%DEST_PATH%lua/main.lua"
adb push "%ROOT%\watchface\lua\config.lua" "%DEST_PATH%lua/config.lua"
adb push "%ROOT%\watchface\lua\fprj\app" "%DEST_PATH%lua"

adb push "%STAMP_LOCAL%" "%DEST_PATH%%STAMP_DIR%/%STAMP_NAME%"

del /f /q "%STAMP_LOCAL%" >nul 2>&1

endlocal
