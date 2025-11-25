# Settings Reference

Complete reference for all configuration settings in the Windows Autopilot Management Tool.

## Table of Contents

- [Overview](#overview)
- [Configuration Files](#configuration-files)
- [Global Settings](#global-settings)
- [Domain Settings](#domain-settings)
- [Authentication Settings](#authentication-settings)
- [Cache Settings](#cache-settings)
- [App Mode Configuration](#app-mode-configuration)
- [Required Scopes](#required-scopes)

## Overview

Settings are organized in a hierarchical structure with three priority levels:

1. **Runtime Parameters** (highest priority) - Command-line arguments
2. **Domain Settings** - Organization-specific overrides
3. **Global Settings** - Application-wide defaults

Settings in `settings.psd1` use PowerShell Data File format for native integration and improved performance.

## Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `settings.psd1` | Main application settings | Root directory |
| `config.psd1` | Encrypted authentication credentials | `.secrets/` |
| `strings.psd1` | UI text and messages | Root directory |
| `menu.psd1` | Menu structure definitions | Root directory |

## Global Settings

Located in `settings.psd1` under `globalSettings`:

### Core Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `operatingSystem` | String | `"Windows"` | Target operating system |
| `timeInSeconds` | Integer | `60` | Default timeout for operations |
| `maxWaitTime` | Integer | `30` | Maximum API wait time in seconds |
| `autoUpdate` | Boolean | `$true` | Enable automatic updates |
| `privateSession` | Boolean | `$false` | Enable private session mode |

### Display Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `maxMenuItemsPerPage` | Integer | `15` | Items per menu page |
| `maxUserMatchDisplay` | Integer | `10` | Maximum user matches to display |
| `maxGroupMatchDisplay` | Integer | `10` | Maximum group matches to display |
| `showLicenseBanner` | Boolean | `$true` | Show license information at startup |
| `useGridForLogDisplay` | Boolean | `$true` | Use grid format for log display |
| `hideEmptyMenus` | Boolean | `$true` | Hide menus with no items |

### App Mode Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `appModes` | Array | `@('full')` | Active app mode(s) |
| `DisplayManualFilterSelection` | Boolean | `$false` | Show manual filter options |

### Device Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `deviceContactThresholdInDays` | Integer | `30` | Days before device considered stale |
| `includeEnrolledDevicesInNextUserReadiness` | Boolean | `$true` | Include enrolled devices in readiness check |
| `checkStrongMapping` | Boolean | `$false` | Validate certificate strong mapping |
| `strongMappingOptional` | Boolean | `$true` | Allow operations without strong mapping |

### Validation Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `validateScopes` | Boolean | `$true` | Validate API scopes at startup |
| `migrateLegacyConfiguration` | Boolean | `$true` | Auto-migrate old config formats |

### External Configuration

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `documentationURL` | String | GitHub URL | Link to documentation |
| `licenseURL` | String | GitHub URL | Link to license |
| `release` | String | `"auto"` | Release channel |
| `preferredBrowser` | String | `"Chrome"` | Preferred browser for auth |
| `configFile` | String | `.\.secrets\config.json` | Path to config file |

## Domain Settings

Domain-specific settings override global settings for each organization.

### Domain Structure

```powershell
domains = @{
    "contoso.com" = @{
        # Group filtering
        groupsToInclude = @(
            @{ name = "GroupName"; id = "guid" }
        )
        groupsToExclude = @(
            @{ name = "GroupName"; id = "guid" }
        )
        
        # Autopilot profiles
        autopilotProfilesToInclude = @(
            @{ name = "ProfileName"; id = "guid" }
        )
        
        # Domain-specific settings
        settings = @{
            # Override any global setting here
        }
    }
}
```

### Common Domain Settings

| Setting | Type | Description |
|---------|------|-------------|
| `deviceNamePrefix` | String | Prefix for device names |
| `maxNumberOfDevicesAllowed` | Integer | Max devices per user |
| `GroupTag` | String | Autopilot group tag |
| `operatingSystem` | String | Target OS for domain |
| `domain` | String | Domain name |
| `companyName` | String | Organization display name |

### Group Configuration

Groups can be specified in two formats:

**Enhanced Format (Recommended):**
```powershell
groupsToInclude = @(
    @{
        name = "IT-Users"
        id = "12345678-1234-1234-1234-123456789abc"
    }
)
```

**Legacy Format (Backward Compatible):**
```powershell
groupsToInclude = @("IT-Users", "Device-Users")
```

The enhanced format is recommended as it improves API performance by using group IDs directly.

### Pattern Exclusions

| Setting | Type | Description |
|---------|------|-------------|
| `userPatternsToExclude` | Array | User patterns to exclude (e.g., `@('-test', 'onmicrosoft.com')`) |
| `groupPatternsToExclude` | Array | Group patterns to exclude |

## Authentication Settings

Located in `settings.psd1` under `auth`:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `authType` | String | `"PublicAuthFlow"` | Authentication type |
| `delegated` | Boolean | `$true` | Use delegated permissions |
| `cacheType` | String | `"File"` | Token cache type (File/Memory) |
| `renewalLeadTime` | Integer | `5` | Minutes before token expiry to renew |
| `noSaveRefreshToken` | Boolean | `$false` | Disable refresh token storage |
| `forceNewToken` | Boolean | `$false` | Force new token on each request |
| `changePwOnNextStart` | Boolean | `$false` | Require password change |
| `secureString` | Boolean | `$false` | Use SecureString for credentials |
| `scope` | Array | (see below) | API scopes to request |

### Authentication Types

| Type | Description | Use Case |
|------|-------------|----------|
| `PublicAuthFlow` | Public client MSAL (recommended) | Standard deployments |
| `Interactive` | Browser-based user auth | Interactive scenarios |
| `PrivateAuthFlow` | Confidential client | Service accounts |

### Default Scopes

```powershell
scope = @(
    'Device.ReadWrite.All'
    'DeviceManagementApps.Read.All'
    'DeviceManagementConfiguration.ReadWrite.All'
    'DeviceManagementScripts.Read.All'
    'Mail.Send'
    'DeviceManagementManagedDevices.PrivilegedOperations.All'
    'DeviceManagementManagedDevices.ReadWrite.All'
    'DeviceManagementServiceConfig.ReadWrite.All'
)
```

## Cache Settings

Located in `settings.psd1` under `cacheSettings`:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `enabled` | Boolean | `$true` | Enable caching system |
| `maxCacheSize` | Integer | `1000` | Maximum cache entries |
| `defaultExpirationMinutes` | Integer | `15` | Default cache expiration |

### Cache Types

```powershell
cacheTypes = @{
    Configuration = @{
        enabled = $true
        expirationMinutes = 60
    }
    DirectoryObjects = @{
        enabled = $true
        expirationMinutes = 15
    }
    Devices = @{
        enabled = $true
        expirationMinutes = 15
    }
}
```

### Managing Cache

```powershell
# View cache statistics
Invoke-CacheManagement -Action GetStatistics

# Clear all caches
Invoke-CacheManagement -Action Clear

# Monitor cache performance
Invoke-CacheManagement -Action Monitor -ShowDetails
```

## App Mode Configuration

Located in `menu.psd1` under `appModeHierarchy`:

### Mode Hierarchy

Each mode includes permissions from lower-level modes:

```
full (*)
├── admin
│   ├── advanced
│   │   ├── helpdesk
│   │   └── registration
│   └── advancedRegistration
└── custom (user-defined)
```

### Mode Definitions

| Mode | Hierarchy Includes | Description |
|------|-------------------|-------------|
| `full` | `*` (all) | Complete access |
| `admin` | admin, advanced, helpdesk, registration | Administrative access |
| `advanced` | advanced, helpdesk, registration | Technical staff |
| `helpdesk` | helpdesk | Support operations |
| `registration` | helpdesk, registration | Device enrollment |
| `advancedRegistration` | advancedRegistration, registration | Extended enrollment |
| `custom` | (user-defined) | Custom access patterns |

### Configuring Multiple Modes

```powershell
# In settings.psd1
globalSettings = @{
    appModes = @("helpdesk", "registration")  # Combine modes
}

# Or domain-specific
domains = @{
    "contoso.com" = @{
        settings = @{
            appModes = @("advanced")
        }
    }
}
```

## Required Scopes

Located in `settings.psd1` under `requiredScopes`:

| Scope | Endpoints | Purpose |
|-------|-----------|---------|
| `User.Read.All` | /users | Read user profiles |
| `Device.Read.All` | /devices | Read device objects |
| `DeviceManagementApps.ReadWrite.All` | /deviceAppManagement | Manage apps |
| `DeviceManagementConfiguration.Read.All` | /deviceManagement/deviceConfigurations | Read device config |
| `DeviceManagementManagedDevices.Read.All` | /deviceManagement/managedDevices | Read managed devices |
| `BitlockerKey.Read.All` | /informationProtection/bitlocker | Read BitLocker keys |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` | /directory/deviceLocalCredentials | Read LAPS passwords |
| `DeviceManagementServiceConfig.ReadWrite.All` | /deviceManagement/windowsAutopilotDeviceIdentities | Manage Autopilot |
| `Mail.Send` | /me/sendMail | Send notification emails |

## Corporate Settings

For organizations with centralized configuration:

```powershell
corporateSettings = @{
    useCorporateSettings = $true
    corporateDomain = "corp.contoso.com"
    corporateSettingsFilePaths = @(
        "\\\\fileserver\\share\\autopilot-settings.psd1"
    )
}
```

## Repository Information

Located in `settings.psd1` under `repoInfo`:

```powershell
repoInfo = @{
    repoPath = "zuhairmahd"
    repoName = "Autopilot"
    baseURL = "https://www.github.com"
    baseSourceURL = "https://raw.githubusercontent.com"
}
```

---

*For additional information, see [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md) or return to the [main README](../readme.md).*
