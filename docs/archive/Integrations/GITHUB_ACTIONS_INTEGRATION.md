# GitHub Actions Integration with Target-Based Builds

## Overview

The Windows Autopilot Management Tool now integrates the target-based build system with GitHub Actions workflows, enabling automated, configuration-driven builds from development to production.

## Workflow Structure

### 1. Automatic Branch-Based Builds (`publish.yml`)

**Triggers**: Push to `dev` or `lhm` branches

- **`dev` branch** → Uses `development` target
  - Test mode enabled
  - Signing disabled for faster builds
  - Output: `bin/main.exe`
  
- **`lhm` branch** → Uses `government` target  
  - Government-specific settings (GAO)
  - Production build with signing
  - Output: `lhm/main.exe`

### 2. Release Builds (`release.yml`)

**Triggers**: GitHub release publication

- Uses `production` target
- Full signing and production settings
- Uploads signed artifacts to release

### 3. Manual Target Builds (`target-build.yml`)

**Triggers**: Manual workflow dispatch

- Choose any target: `development`, `production`, `arabictutor`, `government`, `ci_test`
- Optional signing control
- Flexible artifact naming

## Target-to-Workflow Mapping

| Branch/Trigger | Target | Output Directory | Settings Applied |
|----------------|--------|------------------|------------------|
| `dev` branch | `development` | `bin/` | Test mode, no signing |
| `lhm` branch | `government` | `lhm/` | GAO settings, signed |
| GitHub Release | `production` | `bin/` | Production settings, signed |
| Manual (any target) | User choice | Per target config | Per target settings |

## Benefits

### 1. Configuration-Driven Builds
- No more hardcoded parameters in workflows
- Centralized build configuration in `targets.psd1`
- Consistent builds across environments

### 2. Environment-Specific Settings
Each target automatically applies appropriate settings:
- **Development**: Test mode, local logging, no validation
- **Production**: Auto-updates, strict validation, no test mode
- **Government**: Compliance settings, enhanced security
- **Customer**: Brand-specific configurations

### 3. Simplified CI/CD Pipeline
```
Push to dev → Test → Build (development target) → Sign → Deploy
Push to lhm → Test → Build (government target) → Sign → Deploy  
Create Release → Test → Build (production target) → Sign → Publish
Manual → Choose Target → Build → Optional Sign → Download
```

## Usage Examples

### Automatic Builds
```bash
# Development build (triggered by push to dev)
git push origin dev

# Government build (triggered by push to lhm)  
git push origin lhm

# Production release (triggered by creating GitHub release)
gh release create v1.3.1 --title "Release 1.3.1" --notes "Release notes"
```

### Manual Builds
1. Go to Actions tab in GitHub
2. Select "Target-based Build" workflow
3. Click "Run workflow"
4. Choose target and signing options
5. Download artifacts when complete

## Target Configuration

All targets are defined in `targets.psd1`:

```powershell
targets = @{
    development = @{
        buildParameters = @{
            Version = '1.3.0.0-dev'
            OutputPath = 'bin'
            SkipSigning = $true
            Overwrite = $true
        }
        globalSettings = @{
            testMode = $true
            autoUpdate = $false
        }
        # ... additional settings
    }
    # ... other targets
}
```

## Artifact Outputs

### Branch Builds
- **Artifact Name**: `autopilot-build-dev` or `autopilot-build-lhm`
- **Contents**: `main.exe`, `lastrun.json`, configuration files
- **Signed**: Yes (if secrets available)

### Release Builds  
- **Artifact Name**: `signed-artifacts`
- **Contents**: `main.exe`, `lastrun.json`
- **Release Assets**: Automatically attached to GitHub release
- **Signed**: Yes

### Manual Builds
- **Artifact Name**: `autopilot-build-{target}`
- **Contents**: Per target configuration
- **Signed**: Optional (user choice)

## Integration Points

### CreateRelease.ps1 Parameters
The workflows now use target-based parameters:
```powershell
# Old approach (hardcoded)
.\CreateRelease.ps1 -InputFile .\main.ps1 -outputPath bin -CompanyName 'GAO' -Overwrite

# New approach (target-based)  
.\CreateRelease.ps1 -TargetsFile .\targets.psd1 -TargetName government -Overwrite
```

### Settings Application
Targets automatically apply settings to:
- `settings.psd1` (global settings)
- Domain-specific `.psd1` files (e.g., `gao.gov.psd1`)
- Authentication configuration
- Build parameters

## Troubleshooting

### Build Failures
1. Check target configuration in `targets.psd1`
2. Verify required secrets are configured
3. Review workflow logs for specific errors

### Missing Artifacts
1. Ensure target `OutputPath` matches workflow expectations
2. Check if signing step completed successfully
3. Verify artifact upload step ran

### Configuration Issues
1. Validate `targets.psd1` syntax
2. Test target locally: `.\CreateRelease.ps1 -TargetsFile .\targets.psd1 -TargetName development`
3. Check target-specific settings application

## Future Enhancements

1. **Multi-Environment Deployments**: Extend targets for staging, UAT environments
2. **Customer-Specific Branches**: Create dedicated branches for major customers
3. **Automated Testing**: Add target-specific test suites
4. **Deployment Automation**: Auto-deploy to customer environments
5. **Version Management**: Automatic version incrementing based on target type