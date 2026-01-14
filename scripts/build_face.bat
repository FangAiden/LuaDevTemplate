@echo off
setlocal

REM ============================================================
REM Build LuaDevTemplate real-device Lua project (.fprj -> .face)
REM Usage:
REM   build_face.bat [face_file_name] [id]
REM Defaults (from watchface.config.json):
REM   face_file_name = <projectName>.face
REM   id             = <watchfaceId>
REM Output:
REM   <repo>\bin\<face_file_name>
REM ============================================================

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT=%%~fI"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%internal\sync_watchface_config.ps1"
if errorlevel 1 exit /b 1

set "CONFIG=%ROOT%\watchface.config.json"

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-Content -Raw -Encoding UTF8 '%CONFIG%' | ConvertFrom-Json).watchfaceId"`) do set "FACE_ID=%%A"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-Content -Raw -Encoding UTF8 '%CONFIG%' | ConvertFrom-Json).projectName"`) do set "PROJECT_NAME=%%A"

set "FACE_NAME=%PROJECT_NAME%.face"

if not "%~1"=="" set "FACE_NAME=%~1"
if not "%~2"=="" set "FACE_ID=%~2"

if "%FACE_ID%"=="" (
  echo [ERROR] watchfaceId not found in watchface.config.json
  exit /b 1
)

if "%PROJECT_NAME%"=="" (
  echo [ERROR] projectName not found in watchface.config.json
  exit /b 1
)

set "COMPILER_EXE=%ROOT%\watchface\tools\Compiler.exe"
set "FPRJ=%ROOT%\watchface\lua\app\%PROJECT_NAME%.fprj"
set "OUTDIR=%ROOT%\bin"

for %%I in ("%COMPILER_EXE%") do set "COMPILER_EXE=%%~fI"
for %%I in ("%FPRJ%") do set "FPRJ=%%~fI"
for %%I in ("%OUTDIR%") do set "OUTDIR=%%~fI"

if not exist "%COMPILER_EXE%" (
  echo [ERROR] Compiler.exe not found: "%COMPILER_EXE%"
  exit /b 1
)

if not exist "%FPRJ%" (
  echo [ERROR] Project .fprj not found: "%FPRJ%"
  exit /b 1
)

if not exist "%OUTDIR%" (
  mkdir "%OUTDIR%" >nul 2>&1
)

echo ==========================================
echo Compiler: "%COMPILER_EXE%"
echo Project : "%FPRJ%"
echo Output  : "%OUTDIR%" "%FACE_NAME%" %FACE_ID%
echo ==========================================

"%COMPILER_EXE%" -b "%FPRJ%" "%OUTDIR%" "%FACE_NAME%" %FACE_ID%
if errorlevel 1 (
  echo [ERROR] Build failed.
  exit /b 1
)

echo Done: "%OUTDIR%\%FACE_NAME%"
set "RESOURCE_DIR=%ROOT%\watchface\data"
set "RESOURCE_BIN=%RESOURCE_DIR%\resource.bin"

if not exist "%RESOURCE_DIR%" (
  mkdir "%RESOURCE_DIR%" >nul 2>&1
)

copy /Y "%OUTDIR%\%FACE_NAME%" "%RESOURCE_BIN%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to generate resource.bin: "%RESOURCE_BIN%"
  exit /b 1
)

echo Generated: "%RESOURCE_BIN%"
exit /b 0
