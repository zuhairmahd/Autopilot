# LogViewer Git Subtree Migration Summary

## Overview

The AutopilotLogViewer has been prepared for extraction into a separate git subtree repository. This allows the LogViewer to be maintained independently while still being embedded in the main Autopilot repository as a dependency.

## Changes Made

### 1. Created AutopilotLogViewer/ Directory Structure

```
AutopilotLogViewer/
├── src/                                # Will contain LogViewer source code
│   ├── Autopilot.LogCore/              # Logging infrastructure (dependency)
│   ├── Autopilot.LogViewer.Core/       # Core parsing logic
│   └── Autopilot.LogViewer.UI/         # WPF application
├── docs/                               # LogViewer documentation
│   ├── LOG_VIEWER_USER_GUIDE.md
│   ├── LOG_VIEWER_IMPLEMENTATION_SUMMARY.md
│   └── SUBTREE_INTEGRATION.md
├── Build-LogViewer.ps1                 # Standalone build script
├── AutopilotLogViewer.sln              # Solution file (LogViewer projects only)
├── README.md                           # Standalone repository README
├── SETUP.md                            # Quick start guide for subtree setup
├── LICENSE                             # MIT License
└── .gitignore                          # Build artifacts exclusions
```

### 2. Created Standalone Build Script

**File**: `AutopilotLogViewer/Build-LogViewer.ps1`

- Builds only LogViewer projects (LogCore, LogViewer.Core, LogViewer.UI)
- Independent of the main Autopilot build system
- Outputs to `bin/Release/net9.0-windows/AutopilotLogViewer.exe`
- Supports `-Clean`, `-Verbose`, `-Configuration` parameters

### 3. Created Solution File

**File**: `AutopilotLogViewer/AutopilotLogViewer.sln`

- Contains only LogViewer-related projects
- Can be opened independently in Visual Studio
- Separate from main `Autopilot.sln`

### 4. Created Comprehensive Documentation

**Files Created**:
- `README.md` - Standalone repository overview, features, usage, build instructions
- `SETUP.md` - Step-by-step quick start guide for subtree setup
- `docs/SUBTREE_INTEGRATION.md` - Detailed git subtree integration guide
- `docs/LOG_VIEWER_USER_GUIDE.md` - Copied from main repository
- `docs/LOG_VIEWER_IMPLEMENTATION_SUMMARY.md` - Copied from main repository

### 5. Created Supporting Files

- `.gitignore` - Excludes build artifacts (bin/, obj/, *.dll, *.exe, etc.)
- `LICENSE` - MIT License for standalone repository

## Why Git Subtree?

### Benefits

1. **Independent Development**: LogViewer can be developed, tested, and released separately
2. **Reusability**: Other projects can use the LogViewer without the full Autopilot codebase
3. **Simplified Workflow**: No submodule complexity - files are part of the main repository
4. **Separate History**: LogViewer has its own commit history and versioning
5. **Easy Distribution**: Users cloning Autopilot get the LogViewer automatically

### Compared to Submodules

| Feature | Subtree | Submodule |
|---------|---------|-----------|
| Files location | Copied into parent repo | Linked as reference |
| Clone experience | Automatic | Requires `git submodule init` |
| Update complexity | Moderate | Complex |
| Best for | Embedded dependencies | Independent modules |

## Next Steps to Complete Migration

Follow the instructions in `AutopilotLogViewer/SETUP.md` for two options:

### Option 1: Copy Files and Create Repository (Recommended)

1. Copy source files from `src/Autopilot.LogCore/`, `src/Autopilot.LogViewer.Core/`, `src/Autopilot.LogViewer.UI/` to `AutopilotLogViewer/src/`
2. Test the build: `cd AutopilotLogViewer && ./Build-LogViewer.ps1 -Configuration Release`
3. Initialize git in AutopilotLogViewer/: `git init`
4. Commit: `git add . && git commit -m "Initial commit"`
5. Create GitHub repository: `AutopilotLogViewer`
6. Push: `git remote add origin <URL> && git push -u origin main`
7. Remove local AutopilotLogViewer/ from main repo: `git rm -rf AutopilotLogViewer`
8. Add as subtree: `git subtree add --prefix=AutopilotLogViewer <URL> main --squash`

### Option 2: Use Git Subtree Split (Advanced)

Uses `git subtree split` to preserve commit history. See `SETUP.md` for details.

## Daily Workflow After Migration

### Pull Updates from LogViewer Repository
```bash
cd /c/Users/zuhai/code/Autopilot
git subtree pull --prefix=AutopilotLogViewer logviewer main --squash
```

### Push Changes to LogViewer Repository
```bash
cd /c/Users/zuhai/code/Autopilot
# Make changes to AutopilotLogViewer/
git add AutopilotLogViewer/
git commit -m "LogViewer: Description"
git subtree push --prefix=AutopilotLogViewer logviewer main
```

## Build Integration

### Building from Main Autopilot Repository

The LogViewer is now built separately:

```powershell
# Option 1: Use main build script (builds all projects including LogViewer)
.\Build-NativeDlls.ps1 -Configuration Release

# Option 2: Use LogViewer-specific build script
.\AutopilotLogViewer\Build-LogViewer.ps1 -Configuration Release
```

### Building from Standalone LogViewer Repository

```bash
git clone https://github.com/yourusername/AutopilotLogViewer.git
cd AutopilotLogViewer
./Build-LogViewer.ps1 -Configuration Release
```

## Impact on Existing Workflows

### For Developers

**Before**:
```powershell
# Build everything
.\Build-NativeDlls.ps1 -Configuration Release

# LogViewer built automatically with other projects
```

**After**:
```powershell
# Option 1: Build everything (including LogViewer via subtree)
.\Build-NativeDlls.ps1 -Configuration Release

# Option 2: Build only LogViewer
.\AutopilotLogViewer\Build-LogViewer.ps1 -Configuration Release
```

### For End Users

**No change** - The LogViewer is still launched from the main menu:
1. Run Autopilot application
2. Navigate to Main Menu
3. Select "View Logs"

The executable location remains the same: `bin/Release/net9.0-windows/AutopilotLogViewer.exe`

## Testing Checklist

After completing the migration, verify:

- [ ] Standalone repository created and pushed to GitHub
- [ ] Subtree added to main Autopilot repository
- [ ] LogViewer builds successfully: `.\AutopilotLogViewer\Build-LogViewer.ps1 -Configuration Release`
- [ ] Main Autopilot build still includes LogViewer: `.\Build-NativeDlls.ps1 -Configuration Release`
- [ ] LogViewer launches from Autopilot main menu
- [ ] Can pull updates: `git subtree pull --prefix=AutopilotLogViewer logviewer main --squash`
- [ ] Can push changes: `git subtree push --prefix=AutopilotLogViewer logviewer main`
- [ ] Documentation is accurate and up-to-date

## Rollback Plan

If issues arise, you can revert the subtree:

```bash
# Remove the subtree
git rm -rf AutopilotLogViewer

# Restore original files from git history
git checkout HEAD~1 -- src/Autopilot.LogViewer.Core
git checkout HEAD~1 -- src/Autopilot.LogViewer.UI
git checkout HEAD~1 -- docs/LOG_VIEWER*.md

# Commit the rollback
git commit -m "Rollback: Revert LogViewer subtree migration"
```

## Documentation References

### Main Autopilot Repository
- `docs/LOG_VIEWER_USER_GUIDE.md` - End-user documentation (original)
- `docs/LOG_VIEWER_IMPLEMENTATION_SUMMARY.md` - Implementation details (original)
- This file - Migration summary

### AutopilotLogViewer Repository
- `AutopilotLogViewer/README.md` - Standalone repository overview
- `AutopilotLogViewer/SETUP.md` - Quick start guide
- `AutopilotLogViewer/docs/SUBTREE_INTEGRATION.md` - Detailed integration guide
- `AutopilotLogViewer/docs/LOG_VIEWER_USER_GUIDE.md` - User guide (copy)
- `AutopilotLogViewer/docs/LOG_VIEWER_IMPLEMENTATION_SUMMARY.md` - Implementation details (copy)

## Questions?

For questions about:
- **Git subtree operations**: See `AutopilotLogViewer/docs/SUBTREE_INTEGRATION.md`
- **Build issues**: See `AutopilotLogViewer/README.md` - Troubleshooting section
- **Usage**: See `AutopilotLogViewer/docs/LOG_VIEWER_USER_GUIDE.md`

---

**Created**: October 30, 2025  
**Author**: GitHub Copilot  
**Status**: Ready for execution (follow SETUP.md for next steps)
