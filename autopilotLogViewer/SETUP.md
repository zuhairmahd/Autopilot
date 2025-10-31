# AutopilotLogViewer Subtree - Quick Start Guide

This guide provides step-by-step instructions for setting up the AutopilotLogViewer as a git subtree.

## Current Status

The `AutopilotLogViewer/` directory has been created with:
- ✅ Build script (`Build-LogViewer.ps1`)
- ✅ README and documentation
- ✅ Solution file (`.sln`)
- ✅ `.gitignore` and `LICENSE`
- ✅ Documentation copied from main repo

## Next Steps

### Option 1: Copy Source Files and Create Standalone Repository (Recommended)

This option creates a completely independent repository that can be maintained separately.

```bash
# Step 1: Copy source files from main repository to subtree directory
cd /c/Users/zuhai/code/Autopilot

# Copy LogCore (dependency)
cp -r src/Autopilot.LogCore/* AutopilotLogViewer/src/Autopilot.LogCore/

# Copy LogViewer.Core
cp -r src/Autopilot.LogViewer.Core/* AutopilotLogViewer/src/Autopilot.LogViewer.Core/

# Copy LogViewer.UI
cp -r src/Autopilot.LogViewer.UI/* AutopilotLogViewer/src/Autopilot.LogViewer.UI/

# Step 2: Test the standalone build
cd AutopilotLogViewer
./Build-LogViewer.ps1 -Configuration Release -Verbose

# If build succeeds, continue to Step 3

# Step 3: Initialize git repository in AutopilotLogViewer/
git init

# Step 4: Add all files
git add .

# Step 5: Commit
git commit -m "Initial commit: Autopilot Log Viewer v1.0.0

- WPF application for viewing Autopilot log files
- Multi-format support (Standard + CMTrace)
- Advanced filtering (Level, Module, Search)
- Full accessibility (JAWS, NVDA)
- Standalone build script
- Extracted from main Autopilot repository"

# Step 6: Create GitHub repository (do this in GitHub web interface)
# Repository name: AutopilotLogViewer
# Description: Accessible WPF log viewer for Autopilot with JAWS/NVDA support
# Visibility: Public or Private (your choice)

# Step 7: Push to GitHub
git remote add origin https://github.com/yourusername/AutopilotLogViewer.git
git branch -M main
git push -u origin main

# Step 8: Tag the initial release
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release"
git push origin v1.0.0

# Step 9: Return to main Autopilot repository
cd /c/Users/zuhai/code/Autopilot

# Step 10: Remove the temporary AutopilotLogViewer directory
# IMPORTANT: Make sure you pushed to GitHub first!
git rm -rf AutopilotLogViewer

# Step 11: Add the LogViewer as a subtree
git subtree add --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash

# Step 12: Commit the subtree
git commit -m "Add AutopilotLogViewer as git subtree

- LogViewer can now be maintained independently
- Replaces previous local LogViewer files
- See AutopilotLogViewer/docs/SUBTREE_INTEGRATION.md for details"

# Step 13: Push to main repository
git push origin dotnet
```

### Option 2: Use Git Subtree Split (Alternative)

This option uses git's built-in subtree split to create a new repository from the existing LogViewer files while preserving history.

```bash
# This is more complex and requires filtering the git history
# Only use this if you want to preserve the commit history of LogViewer files

# Step 1: Create a new branch with only LogViewer files
cd /c/Users/zuhai/code/Autopilot
git subtree split --prefix=AutopilotLogViewer --branch logviewer-standalone

# Step 2: Create a new repository directory
mkdir ../AutopilotLogViewer-standalone
cd ../AutopilotLogViewer-standalone
git init

# Step 3: Pull the split branch
git pull ../Autopilot logviewer-standalone

# Step 4: Push to GitHub (create repository first)
git remote add origin https://github.com/yourusername/AutopilotLogViewer.git
git branch -M main
git push -u origin main

# Step 5: Return to main repository and add subtree
cd /c/Users/zuhai/code/Autopilot
git subtree add --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash
```

## Verification

After setup, verify the integration:

```bash
# Check that AutopilotLogViewer directory exists
cd /c/Users/zuhai/code/Autopilot
ls AutopilotLogViewer/

# Expected output:
# Build-LogViewer.ps1
# README.md
# AutopilotLogViewer.sln
# LICENSE
# .gitignore
# src/
# docs/

# Verify the build works
cd AutopilotLogViewer
./Build-LogViewer.ps1 -Configuration Release

# Expected output: AutopilotLogViewer.exe in bin/Release/net9.0-windows/

# Test pull updates
cd /c/Users/zuhai/code/Autopilot
git subtree pull --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash

# Test push changes
git subtree push --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main
```

## Remote Alias Setup (Recommended)

Add a remote alias to avoid typing the full URL:

```bash
cd /c/Users/zuhai/code/Autopilot
git remote add logviewer https://github.com/yourusername/AutopilotLogViewer.git

# Now use shorter commands:
git subtree pull --prefix=AutopilotLogViewer logviewer main --squash
git subtree push --prefix=AutopilotLogViewer logviewer main
```

## Daily Workflow

### Pulling Updates from LogViewer Repository
```bash
cd /c/Users/zuhai/code/Autopilot
git subtree pull --prefix=AutopilotLogViewer logviewer main --squash
git push origin dotnet
```

### Pushing Changes to LogViewer Repository
```bash
cd /c/Users/zuhai/code/Autopilot
# Make changes to AutopilotLogViewer/
git add AutopilotLogViewer/
git commit -m "LogViewer: Description of changes"
git push origin dotnet
git subtree push --prefix=AutopilotLogViewer logviewer main
```

## Troubleshooting

### Issue: Build fails in AutopilotLogViewer/
**Solution**: Ensure all source files were copied correctly. Check that the `.csproj` files reference the correct dependencies.

### Issue: Subtree add fails with "refusing to merge unrelated histories"
**Solution**: Add `--allow-unrelated-histories` flag:
```bash
git subtree add --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash \
    --allow-unrelated-histories
```

### Issue: Cannot push to remote repository
**Solution**: Ensure you have write access to the GitHub repository and that it exists.

## Complete File Structure

After setup, the AutopilotLogViewer/ directory should contain:

```
AutopilotLogViewer/
├── src/
│   ├── Autopilot.LogCore/              # Logging infrastructure
│   │   ├── Logger.cs
│   │   └── Autopilot.LogCore.csproj
│   ├── Autopilot.LogViewer.Core/       # Core parsing logic
│   │   ├── Models/
│   │   ├── Parsers/
│   │   └── Autopilot.LogViewer.Core.csproj
│   └── Autopilot.LogViewer.UI/         # WPF application
│       ├── ViewModels/
│       ├── Views/
│       ├── Converters/
│       ├── App.xaml
│       ├── App.xaml.cs
│       └── Autopilot.LogViewer.UI.csproj
├── docs/
│   ├── LOG_VIEWER_USER_GUIDE.md
│   ├── LOG_VIEWER_IMPLEMENTATION_SUMMARY.md
│   └── SUBTREE_INTEGRATION.md
├── bin/                                # Build output (gitignored)
├── Build-LogViewer.ps1
├── AutopilotLogViewer.sln
├── README.md
├── LICENSE
└── .gitignore
```

## Need Help?

See the comprehensive documentation:
- [README.md](README.md) - Project overview and usage
- [docs/SUBTREE_INTEGRATION.md](docs/SUBTREE_INTEGRATION.md) - Detailed integration guide
- [docs/LOG_VIEWER_USER_GUIDE.md](docs/LOG_VIEWER_USER_GUIDE.md) - End-user documentation

---

**Last Updated**: October 30, 2025
