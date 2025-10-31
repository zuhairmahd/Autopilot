# Git Subtree Integration Guide

## Overview

This guide explains how to integrate the **AutopilotLogViewer** repository as a git subtree into the main **Autopilot** repository. Git subtrees allow you to maintain the LogViewer as a separate, independent repository while embedding it as a subdirectory in the main Autopilot project.

## Why Git Subtree?

### Advantages
- **Independent Development**: The LogViewer can be developed, tested, and released independently
- **Reusability**: The LogViewer can be used by other projects without the full Autopilot codebase
- **Simplified Workflow**: No submodule complexity - files are part of the main repository
- **Separate History**: LogViewer has its own commit history and versioning
- **Easy Distribution**: Users cloning Autopilot get the LogViewer automatically (no submodule init required)

### Compared to Submodules
- **Subtree**: Files are copied into the parent repository (easier for end users)
- **Submodule**: Files are linked as references (requires `git submodule init` and `git submodule update`)

## Repository Setup

### 1. Create the Standalone LogViewer Repository

First, create a new repository for the LogViewer:

```bash
# Create a new directory for the standalone repository
mkdir AutopilotLogViewer
cd AutopilotLogViewer

# Initialize git repository
git init

# Copy files from the main Autopilot repository (initial setup)
# This is a one-time operation to extract the LogViewer files
# See "Initial Extraction" section below for details

# Add all files and commit
git add .
git commit -m "Initial commit: Autopilot Log Viewer v1.0.0"

# Create a GitHub repository and push
git remote add origin https://github.com/yourusername/AutopilotLogViewer.git
git branch -M main
git push -u origin main
```

### 2. Add Subtree to Main Autopilot Repository

Once the standalone LogViewer repository exists, add it as a subtree to the main Autopilot repository:

```bash
# Navigate to the main Autopilot repository
cd /c/Users/zuhai/code/Autopilot

# Add the LogViewer as a subtree in the AutopilotLogViewer/ directory
# --prefix: Where to place the subtree in the parent repository
# --squash: Combine all commits into one (cleaner history)
git subtree add --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash
```

**Expected Output**:
```
git fetch https://github.com/yourusername/AutopilotLogViewer.git main
From https://github.com/yourusername/AutopilotLogViewer
 * branch            main       -> FETCH_HEAD
Added dir 'AutopilotLogViewer'
```

### 3. Verify the Integration

```bash
# Check that the files are present
ls AutopilotLogViewer/

# Verify git status
git status

# The subtree files are now part of the main repository
# You should see AutopilotLogViewer/ in your working tree
```

## Daily Workflow

### Pulling Updates from LogViewer Repository

When the LogViewer repository is updated (bug fixes, new features, etc.), pull those changes into the main Autopilot repository:

```bash
# Navigate to the main Autopilot repository
cd /c/Users/zuhai/code/Autopilot

# Pull updates from the LogViewer repository
git subtree pull --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash

# Resolve any conflicts if they occur
# Commit the merge
git commit -m "Update LogViewer to latest version"

# Push to main Autopilot repository
git push origin dotnet
```

### Pushing Changes to LogViewer Repository

If you make changes to the LogViewer files in the main Autopilot repository and want to push them back to the standalone LogViewer repository:

```bash
# Navigate to the main Autopilot repository
cd /c/Users/zuhai/code/Autopilot

# Push changes from AutopilotLogViewer/ to the LogViewer repository
git subtree push --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main
```

**Important**: Only changes within the `AutopilotLogViewer/` directory will be pushed. Changes outside this directory are not included.

### Making Changes to LogViewer

#### Option A: Work in the Main Autopilot Repository
```bash
# Make changes to files in AutopilotLogViewer/
cd /c/Users/zuhai/code/Autopilot
code AutopilotLogViewer/src/Autopilot.LogViewer.UI/ViewModels/MainViewModel.cs

# Commit changes to main Autopilot repository
git add AutopilotLogViewer/
git commit -m "LogViewer: Add new filtering feature"
git push origin dotnet

# Push changes to standalone LogViewer repository
git subtree push --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main
```

#### Option B: Work in the Standalone LogViewer Repository
```bash
# Clone the standalone repository
git clone https://github.com/yourusername/AutopilotLogViewer.git
cd AutopilotLogViewer

# Make changes
code src/Autopilot.LogViewer.UI/ViewModels/MainViewModel.cs

# Commit and push to LogViewer repository
git add .
git commit -m "Add new filtering feature"
git push origin main

# Pull changes into main Autopilot repository
cd /c/Users/zuhai/code/Autopilot
git subtree pull --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash
```

**Recommendation**: For LogViewer-specific work, use Option B (work in the standalone repository). For integration testing with Autopilot, use Option A.

## Initial Extraction (One-Time Setup)

If you're setting up the subtree for the first time and need to extract existing LogViewer files from the main Autopilot repository, follow these steps:

### Step 1: Create the Standalone Repository Structure

```bash
# Create the standalone repository directory
mkdir AutopilotLogViewer
cd AutopilotLogViewer

# Initialize git
git init

# Create directory structure
mkdir -p src/Autopilot.LogCore
mkdir -p src/Autopilot.LogViewer.Core
mkdir -p src/Autopilot.LogViewer.UI
mkdir -p docs
```

### Step 2: Copy Files from Main Autopilot Repository

```bash
# Set path to main Autopilot repository
$AUTOPILOT_REPO = "/c/Users/zuhai/code/Autopilot"

# Copy LogCore (dependency)
cp -r "$AUTOPILOT_REPO/src/Autopilot.LogCore/"* src/Autopilot.LogCore/

# Copy LogViewer.Core
cp -r "$AUTOPILOT_REPO/src/Autopilot.LogViewer.Core/"* src/Autopilot.LogViewer.Core/

# Copy LogViewer.UI
cp -r "$AUTOPILOT_REPO/src/Autopilot.LogViewer.UI/"* src/Autopilot.LogViewer.UI/

# Copy documentation
cp "$AUTOPILOT_REPO/docs/LOG_VIEWER_USER_GUIDE.md" docs/
cp "$AUTOPILOT_REPO/docs/LOG_VIEWER_IMPLEMENTATION_SUMMARY.md" docs/
```

### Step 3: Create Standalone Files

```bash
# Copy the build script and README from the AutopilotLogViewer/ setup directory
# (These should already exist if you followed this guide)
cp "$AUTOPILOT_REPO/AutopilotLogViewer/build.bat" .
cp "$AUTOPILOT_REPO/AutopilotLogViewer/README.md" .
cp "$AUTOPILOT_REPO/AutopilotLogViewer/.gitignore" .

# Create the solution file (see below)
```

### Step 4: Create Solution File

Create `AutopilotLogViewer.sln`:

```xml
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Autopilot.LogCore", "src\Autopilot.LogCore\Autopilot.LogCore.csproj", "{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}"
EndProject
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Autopilot.LogViewer.Core", "src\Autopilot.LogViewer.Core\Autopilot.LogViewer.Core.csproj", "{9E0F3456-789A-12CD-EF01-3456789012CD}"
EndProject
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Autopilot.LogViewer.UI", "src\Autopilot.LogViewer.UI\Autopilot.LogViewer.UI.csproj", "{0F1F4567-890B-23DE-F012-4567890123DE}"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|Any CPU = Debug|Any CPU
		Release|Any CPU = Release|Any CPU
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}.Release|Any CPU.Build.0 = Release|Any CPU
		{9E0F3456-789A-12CD-EF01-3456789012CD}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{9E0F3456-789A-12CD-EF01-3456789012CD}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{9E0F3456-789A-12CD-EF01-3456789012CD}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{9E0F3456-789A-12CD-EF01-3456789012CD}.Release|Any CPU.Build.0 = Release|Any CPU
		{0F1F4567-890B-23DE-F012-4567890123DE}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{0F1F4567-890B-23DE-F012-4567890123DE}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{0F1F4567-890B-23DE-F012-4567890123DE}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{0F1F4567-890B-23DE-F012-4567890123DE}.Release|Any CPU.Build.0 = Release|Any CPU
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
EndGlobal
```

### Step 5: Initial Commit and Push

```bash
# Add all files
git add .

# Initial commit
git commit -m "Initial commit: Autopilot Log Viewer v1.0.0

- WPF application for viewing Autopilot log files
- Multi-format support (Standard + CMTrace)
- Advanced filtering (Level, Module, Search)
- Full accessibility (JAWS, NVDA)
- Standalone build script
- Extracted from main Autopilot repository"

# Create GitHub repository and push
git remote add origin https://github.com/yourusername/AutopilotLogViewer.git
git branch -M main
git push -u origin main
```

### Step 6: Remove Files from Main Autopilot Repository

Now that the LogViewer is in its own repository, remove the old files from the main Autopilot repository and add the subtree:

```bash
# Navigate to main Autopilot repository
cd /c/Users/zuhai/code/Autopilot

# Remove old files (DO NOT commit yet)
rm -rf AutopilotLogViewer/

# Add the LogViewer as a subtree
git subtree add --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash

# Commit the subtree
git commit -m "Replace LogViewer with git subtree

- Removed standalone LogViewer files
- Added AutopilotLogViewer repository as git subtree
- LogViewer can now be maintained independently
- See AutopilotLogViewer/docs/SUBTREE_INTEGRATION.md for details"

# Push to main repository
git push origin dotnet
```

## Build Integration

### Building from Main Autopilot Repository

The LogViewer build is integrated into the main Autopilot build process:

```bash
# Navigate to main Autopilot repository
cd /c/Users/zuhai/code/Autopilot

# Build all projects (includes LogViewer)
.\Build-NativeDlls.ps1 -Configuration Release

# Build only LogViewer (using subtree build script)
.\AutopilotLogViewer\build.bat
```

### Building from Standalone LogViewer Repository

```bash
# Clone the standalone repository
git clone https://github.com/yourusername/AutopilotLogViewer.git
cd AutopilotLogViewer

# Build
build.bat
```

Both methods produce the same output: `bin/Release/net9.0-windows/AutopilotLogViewer.exe`

## Troubleshooting

### Issue: Subtree Add Fails

**Error**: `fatal: refusing to merge unrelated histories`

**Solution**: Use the `--allow-unrelated-histories` flag:
```bash
git subtree add --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash \
    --allow-unrelated-histories
```

### Issue: Subtree Push Fails

**Error**: `Updates were rejected because the remote contains work that you do not have locally`

**Solution**: Pull first, then push:
```bash
git subtree pull --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash
git subtree push --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main
```

### Issue: Conflicts During Subtree Pull

**Solution**: Resolve conflicts manually:
```bash
# After subtree pull fails with conflicts
git status

# Edit conflicting files
code AutopilotLogViewer/src/...

# Mark conflicts as resolved
git add AutopilotLogViewer/

# Complete the merge
git commit -m "Resolve conflicts from LogViewer subtree update"
```

### Issue: Build Script Not Found

**Error**: `.\AutopilotLogViewer\Build-LogViewer.ps1: File not found`

**Solution**: Ensure the subtree is properly added:
```bash
# Check if directory exists
ls AutopilotLogViewer/

# If missing, add the subtree again
git subtree add --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash
```

## Using a Remote Alias (Recommended)

To avoid typing the full URL repeatedly, create a git remote alias:

```bash
# Navigate to main Autopilot repository
cd /c/Users/zuhai/code/Autopilot

# Add a remote for the LogViewer repository
git remote add logviewer https://github.com/yourusername/AutopilotLogViewer.git

# Now use the alias instead of the full URL
git subtree pull --prefix=AutopilotLogViewer logviewer main --squash
git subtree push --prefix=AutopilotLogViewer logviewer main
```

## Best Practices

### 1. Commit Message Convention
Use clear prefixes when making LogViewer changes:
```
LogViewer: Add support for new log format
LogViewer: Fix filtering bug in search box
Update LogViewer to v1.1.0
```

### 2. Versioning
Tag releases in the standalone LogViewer repository:
```bash
cd AutopilotLogViewer
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release"
git push origin v1.0.0
```

### 3. Testing Before Pushing
Always test changes before pushing to the standalone repository:
```bash
# Build and test in main Autopilot repository
cd /c/Users/zuhai/code/Autopilot
.\AutopilotLogViewer\build.bat
.\bin\Release\net9.0-windows\AutopilotLogViewer.exe

# If tests pass, push to standalone repository
git subtree push --prefix=AutopilotLogViewer logviewer main
```

### 4. Documentation
Keep documentation synchronized:
- Update `AutopilotLogViewer/README.md` for standalone users
- Update `docs/LOG_VIEWER_USER_GUIDE.md` for Autopilot users
- Both should reference each other for context

## Summary

### Key Commands

| Action | Command |
|--------|---------|
| Add subtree (first time) | `git subtree add --prefix=AutopilotLogViewer <URL> main --squash` |
| Pull updates | `git subtree pull --prefix=AutopilotLogViewer <URL> main --squash` |
| Push changes | `git subtree push --prefix=AutopilotLogViewer <URL> main` |
| Build LogViewer | `.\AutopilotLogViewer\build.bat` |
| Add remote alias | `git remote add logviewer <URL>` |

### Workflow Summary

1. **Develop** in either repository (standalone or main Autopilot)
2. **Build and test** using `build.bat`
3. **Commit** changes to the appropriate repository
4. **Sync** using `git subtree pull` or `git subtree push`
5. **Tag releases** in the standalone repository
6. **Update documentation** in both locations

---

**Last Updated**: October 30, 2025  
**Document Version**: 1.0.0
