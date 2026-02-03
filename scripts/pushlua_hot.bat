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
echo Push app:   %ROOT%\watchface\fprj\app ^> %DEST_PATH%
echo Push user main as _app_main.lua
echo Inject:     %ROOT%\scripts\reloader.lua ^> %DEST_PATH%lua/main.lua
echo Push stamp: %STAMP_NAME%
echo ==========================================

adb shell "rm -rf '%DEST_PATH%lua'"
adb shell "rm -rf '%DEST_PATH%%STAMP_DIR%'"
adb shell "mkdir '%DEST_PATH%%STAMP_DIR%'"

REM 镜像真机：将 fprj/app 内容释放到设备根目录
adb push "%ROOT%\watchface\fprj\app" "%DEST_PATH%"

REM 用户 main.lua 推送为 _app_main.lua，再用重载器覆盖 main.lua
adb push "%ROOT%\watchface\fprj\app\lua\main.lua" "%DEST_PATH%lua/_app_main.lua"
adb push "%ROOT%\scripts\reloader.lua" "%DEST_PATH%lua/main.lua"

adb push "%STAMP_LOCAL%" "%DEST_PATH%%STAMP_DIR%/%STAMP_NAME%"

del /f /q "%STAMP_LOCAL%" >nul 2>&1

endlocal
