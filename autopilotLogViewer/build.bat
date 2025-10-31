@echo off
setlocal enabledelayedexpansion

echo.
echo ========================================
echo   Autopilot Log Viewer Build
echo ========================================
echo.

REM Check for .NET SDK
echo Checking .NET SDK...
dotnet --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] .NET SDK not found. Install from: https://dotnet.microsoft.com/download
    exit /b 1
)
for /f "tokens=*" %%i in ('dotnet --version') do set DOTNET_VERSION=%%i
echo [OK] .NET SDK %DOTNET_VERSION%
echo.

REM Verify solution file
if not exist "AutopilotLogViewer.sln" (
    echo [ERROR] Solution file not found: AutopilotLogViewer.sln
    exit /b 1
)

REM Clean build artifacts
echo Cleaning build artifacts...
if exist bin (
    echo   Removing bin folder...
    rmdir /s /q bin
)
if exist artifacts (
    echo   Removing artifacts folder...
    rmdir /s /q artifacts
)

REM Clean obj and bin directories in all projects
for /d /r src %%d in (bin obj) do (
    if exist "%%d" (
        echo   Removing %%d
        rmdir /s /q "%%d"
    )
)
echo [OK] Cleaned build artifacts
echo.

REM Restore NuGet packages
echo Restoring NuGet packages...
dotnet restore AutopilotLogViewer.sln --verbosity minimal
if %ERRORLEVEL% neq 0 (
    echo [ERROR] NuGet restore failed
    exit /b 1
)
echo [OK] Packages restored
echo.

REM Build the solution
echo Building AutopilotLogViewer (net9.0-windows)...
dotnet publish src\Autopilot.LogViewer.UI\Autopilot.LogViewer.UI.csproj --configuration Release --framework net9.0-windows --output bin\Release\net9.0-windows --no-self-contained --nologo --verbosity minimal /p:DebugType=portable
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed
    exit /b 1
)
echo.

REM Verify output files
set BUILD_SUCCESS=1
if exist "bin\Release\net9.0-windows\AutopilotLogViewer.exe" (
    for %%A in ("bin\Release\net9.0-windows\AutopilotLogViewer.exe") do set EXE_SIZE=%%~zA
    set /a EXE_KB=!EXE_SIZE! / 1024
    echo [OK] AutopilotLogViewer.exe ^(!EXE_KB! KB^)
) else (
    echo [ERROR] AutopilotLogViewer.exe not found
    set BUILD_SUCCESS=0
)

if exist "bin\Release\net9.0-windows\Autopilot.LogViewer.Core.dll" (
    for %%A in ("bin\Release\net9.0-windows\Autopilot.LogViewer.Core.dll") do set CORE_SIZE=%%~zA
    set /a CORE_KB=!CORE_SIZE! / 1024
    echo [OK] Autopilot.LogViewer.Core.dll ^(!CORE_KB! KB^)
) else (
    echo [ERROR] Autopilot.LogViewer.Core.dll not found
    set BUILD_SUCCESS=0
)

if exist "bin\Release\net9.0-windows\Autopilot.LogCore.dll" (
    for %%A in ("bin\Release\net9.0-windows\Autopilot.LogCore.dll") do set LOG_SIZE=%%~zA
    set /a LOG_KB=!LOG_SIZE! / 1024
    echo [OK] Autopilot.LogCore.dll ^(!LOG_KB! KB^)
) else (
echo [ERROR]     Autopilot.LogCore.dll not found
    set BUILD_SUCCESS=0
)

echo.
echo ========================================
if %BUILD_SUCCESS%==1 (
    echo   BUILD SUCCESSFUL
    echo ========================================
    echo.
    echo Build Summary:
    echo   Configuration: Release
    echo   Framework: net9.0-windows
    echo   Output: bin\Release\net9.0-windows
    echo.
    echo To run:
    echo   bin\Release\net9.0-windows\AutopilotLogViewer.exe
    echo.
    exit /b 0
) else (
    echo   BUILD FAILED
    echo ========================================
    echo.
    echo Some required files were not created.
    echo.
    exit /b 1
)

