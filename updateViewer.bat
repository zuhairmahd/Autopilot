@echo off
echo Updating autopilotLogViewer subtree...
git subtree pull --prefix autopilotLogViewer https://github.com/zuhairmahd/autopilotLogViewer master --squash
if errorlevel 1 (
    echo Error: Failed to update autopilotLogViewer subtree.
    exit /b 1
)
echo Successfully updated autopilotLogViewer subtree.

echo Building autopilotLogViewer...
cd autopilotLogViewer
call build.bat
if errorlevel 1 (
    echo Error: Build failed.
    cd ..
    exit /b 1
)
echo Build successful.
cd ..

echo Preparing to move build artifacts...
if exist logViewer (
    echo Removing existing logViewer folder...
    rmdir /s /q logViewer
    if errorlevel 1 (
        echo Error: Failed to remove existing logViewer folder.
        exit /b 1
    )
    echo Existing logViewer folder removed.
)

echo Moving build artifacts to logViewer...
move autopilotLogViewer\bin\Release\net9.0-windows logViewer
if errorlevel 1 (
    echo Error: Failed to move build artifacts.
    exit /b 1
)

echo Update completed successfully.
echo LogViewer is ready in the logViewer folder.

