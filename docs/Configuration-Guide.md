# Advanced Configuration Guide

This guide provides detailed information on configuring the Windows Autopilot Management Tool for various enterprise scenarios.

## Table of Contents

- [Configuration File Structure](#configuration-file-structure)
- [Authentication Configuration](#authentication-configuration)
- [Menu Customization](#menu-customization)
- [Domain-Specific Settings](#domain-specific-settings)
- [Security Configuration](#security-configuration)
- [Application Modes](#application-modes)
- [Command Line Parameters](#command-line-parameters)

## Configuration File Structure

The tool uses a hierarchical configuration system with multiple files:

### Primary Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `settings.json` | Main application configuration | Root directory |
| `config.json` | Authentication credentials (encrypted) | `.secrets/` directory |
| `strings.json` | Localized messages and UI text | Root directory |

### Configuration Hierarchy

The application resolves configuration using a three-tier priority system:

1. **Runtime Parameters** (Highest Priority)
   - Command-line arguments passed to `main.ps1`
   - Override all other settings

2. **Domain-Specific Settings** (Medium Priority)
   - Settings defined in `settings.json` → `domains[domain].settings`
   - Override global settings for specific domains

3. **Global Settings** (Lowest Priority)
   - Settings defined in `settings.json` → `globalSettings`
   - Default values used when no override exists

## Authentication Configuration

### Authentication Types

The tool supports multiple authentication flows, each with different security characteristics:

#### PublicAuthFlow (Recommended)
**Best for**: Standard deployments where app secrets are not desired

```json
{
  "auth": {
    "Delegated": true,
    "authType": "PublicAuthFlow",
    "CacheType": "Memory",
    "NoSaveRefreshToken": false
  }
}
```

**Benefits:**
- No app secrets required
- Enhanced security through MSAL public client
- Supports multi-factor authentication
- Recommended by Microsoft for desktop applications

#### Interactive Flow
**Best for**: Interactive scenarios requiring full user consent

```json
{
  "auth": {
    "Delegated": true,
    "authType": "Interactive",
    "CacheType": "Memory",
    "privateSession": true
  }
}
```

**Benefits:**
- Full browser-based authentication
- Supports all Azure AD features (MFA, conditional access)
- Interactive consent for permissions
- Can use private/incognito browser sessions

#### Private Flow
**Best for**: Automated scenarios and background services

```json
{
  "auth": {
    "Delegated": false,
    "authType": "Private",
    "CacheType": "File"
  }
}
```

**Requirements:**
- App secret or certificate configured in Azure AD
- Either `AppSecret` or `Thumbprint` in encrypted config.json
- Application permissions granted in Azure AD

### Authentication Settings Reference

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `Delegated` | Boolean | true | Use delegated permissions vs application permissions |
| `authType` | String | "PublicAuthFlow" | Authentication flow type |
| `renewalLeadTime` | Integer | 5 | Minutes before expiration to renew tokens |
| `NoSaveRefreshToken` | Boolean | false | Don't save refresh tokens (for USB deployments) |
| `SecureString` | Boolean | false | Use SecureString for sensitive inputs |
| `ForceNewToken` | Boolean | false | Force new token generation on each run |
| `CacheType` | String | "Memory" | Token cache type ("Memory" or "File") |
| `changePWOnNextStart` | Boolean | false | Force password change on next startup |
| `privateSession` | Boolean | false | Use private/incognito browser sessions |
| `preferredBrowser` | String | "Default" | Browser for authentication ("Chrome", "Firefox", "Edge", "Default") |

### Encrypted Configuration File

The `.secrets/config.json` file contains sensitive authentication information:

```json
{
  "domain": "your-domain.com",
  "TenantId": "your-tenant-id",
  "AppId": "your-app-id",
  "AppSecret": "your-app-secret",
  "Thumbprint": "your-cert-thumbprint",
  "Subject": "your-certificate-subject"
}
```

**Security Notes:**
- This file is automatically encrypted with AES-256 encryption
- Password required to decrypt on each application run
- File automatically deleted after 3 failed password attempts
- Only `AppId` and `TenantId` are required for PublicAuthFlow

## Menu Customization

### Menu Inclusion System

The application uses a menu **inclusion** system (not exclusion) to control which menu items are visible:

```json
{
  "appMode": "helpDesk",
  "menuItemsToInclude": [
    "Give a device to a user",
    "Check device status",
    "About"
  ]
}
```

**Important**: 
- When `appMode` is set to "full", all menu items are shown regardless of the inclusion list
- For other app modes, only items in `menuItemsToInclude` are displayed
- Menu item names must match exactly (case-insensitive)

### Available Menu Items

#### Main Menu Items
- "Give a device to a user"
- "Check device status"
- "Autopilot menu"
- "Change application settings"
- "Check for script updates"
- "Restart the device"
- "Export Menu"
- "About"

#### Autopilot Submenu Items
- "Quick Import device into Autopilot (requires admin rights)"
- "Custom import device into Autopilot (requires admin rights)"
- "Import Corporate Device Identifier for Device Preparation (requires admin rights)"
- "Delete Corporate Device Identifier from Device Preparation (requires admin rights)"
- "Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)"
- "Get device hash for manual upload to Autopilot (requires admin rights)"
- "Download and install latest Windows updates(requires admin rights)"
- "Check device Autopilot status"
- "Delete device from Autopilot"

#### Settings Submenu Items
- "Change application settings"
- "Change password and authentication information"
- "Change Auto Update setting"
- "Restore defaults"

#### Export Submenu Items
- "Export Autopilot Devices"
- "Export Imported Autopilot Devices"
- "Export Managed Windows Devices"

### Menu Customization Examples

#### Help Desk Configuration
Limit access to basic device management functions:

```json
{
  "appMode": "helpDesk",
  "menuItemsToInclude": [
    "Give a device to a user",
    "Check device status",
    "Export Menu",
    "About"
  ]
}
```

#### Registration-Only Configuration
Focus on device registration tasks:

```json
{
  "appMode": "registration",
  "menuItemsToInclude": [
    "Autopilot menu",
    "Check device status",
    "About"
  ]
}
```

#### Full Administrator Access
Allow access to all features:

```json
{
  "appMode": "full"
}
```

## Domain-Specific Settings

### Multi-Domain Support

The application supports different configurations for different domains:

```json
{
  "globalSettings": {
    "maxWaitTime": 300,
    "autoUpdate": true
  },
  "domains": {
    "contoso.com": {
      "groupsToInclude": ["Contoso-Users", "Device-Recipients"],
      "groupsToExclude": ["Contractors", "Temporary-Staff"],
      "settings": {
        "deviceNamePrefix": "CONTOSO-",
        "GroupTag": "Contoso-Autopilot",
        "maxNumberOfDevicesAllowed": 2
      }
    },
    "fabrikam.com": {
      "groupsToInclude": ["Fabrikam-Employees"],
      "groupsToExclude": ["External-Users"],
      "settings": {
        "deviceNamePrefix": "FAB-",
        "GroupTag": "Fabrikam-Devices",
        "maxNumberOfDevicesAllowed": 1
      }
    }
  }
}
```

### Domain Settings Reference

| Setting | Type | Description |
|---------|------|-------------|
| `groupsToInclude` | Array | Required user groups for device eligibility |
| `groupsToExclude` | Array | Groups that disqualify users from device assignment |
| `settings` | Object | Domain-specific overrides for global settings |

### Domain-Specific Overrides

Any global setting can be overridden at the domain level:

```json
{
  "domains": {
    "secure-domain.com": {
      "settings": {
        "privateSession": true,
        "MaxUserNameLength": 20,
        "MinimumDevicePhysicalMemoryInGB": 16,
        "DesiredAutopilotProfiles": ["Secure-Profile", "Compliance-Profile"]
      }
    }
  }
}
```

## Security Configuration

### Password Security Settings

#### Maximum Password Attempts
The application enforces a security policy of maximum 3 password attempts:

- **Behavior**: After 3 failed attempts, the encrypted configuration file is deleted
- **Reason**: Prevents brute force attacks on encrypted credentials
- **Recovery**: User must re-run First Run Wizard to recreate configuration

#### Administrative Password Control

Force users to change their encryption password:

```json
{
  "auth": {
    "changePWOnNextStart": true
  }
}
```

**Use Cases:**
- Regular password rotation policies
- Security incident response
- New employee onboarding
- Compliance requirements

**Process:**
1. User successfully decrypts configuration with existing password
2. Application detects `changePWOnNextStart: true`
3. Prompts user for new password with confirmation
4. Re-encrypts configuration file with new password
5. Automatically sets `changePWOnNextStart: false`

### Secure Browser Sessions

For organizations requiring additional security:

```json
{
  "auth": {
    "privateSession": true,
    "preferredBrowser": "Edge"
  }
}
```

**Benefits:**
- Authentication occurs in private/incognito browser sessions
- Prevents credential caching in browser history
- Reduces risk of session hijacking

### Token Security Settings

```json
{
  "auth": {
    "CacheType": "Memory",
    "NoSaveRefreshToken": true,
    "renewalLeadTime": 10
  }
}
```

**Security Options:**
- `CacheType: "Memory"`: Tokens stored in memory only (more secure)
- `CacheType: "File"`: Tokens cached to disk (persistent across sessions)
- `NoSaveRefreshToken: true`: Don't save refresh tokens (for USB/portable deployments)
- Higher `renewalLeadTime`: More frequent token refresh for enhanced security

## Application Modes

### Full Mode
**Purpose**: Complete administrative access
**Configuration**: `"appMode": "full"`
**Features**: All menu items available, no restrictions

### Help Desk Mode  
**Purpose**: Limited access for help desk personnel
**Configuration**: `"appMode": "helpDesk"`
**Typical Menu Items**:
- Give a device to a user
- Check device status
- Export functions
- About

### Registration Mode
**Purpose**: Device registration and enrollment tasks
**Configuration**: `"appMode": "registration"`
**Typical Menu Items**:
- Autopilot menu (device registration functions)
- Check device status
- Device identifier management

### Custom Modes
Create custom modes by combining `appMode` with `menuItemsToInclude`:

```json
{
  "appMode": "compliance",
  "menuItemsToInclude": [
    "Check device status",
    "Export Menu",
    "About"
  ]
}
```

## Command Line Parameters

### Authentication Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-configFile` | String | Path to authentication config file |
| `-Delegated` | Switch | Use delegated authentication |
| `-AuthType` | String | Authentication type |
| `-Scope` | String | Custom authentication scope |
| `-ForceNewToken` | Switch | Force new access token |
| `-ForceNewRefreshToken` | Switch | Force new refresh token |
| `-NoSaveRefreshToken` | Switch | Don't save refresh tokens |

### Configuration Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-InitFile` | String | Path to settings.json file |
| `-appMode` | String | Application mode |
| `-GroupTag` | String | Autopilot group tag |
| `-maxWaitTime` | Integer | Maximum wait time (seconds) |
| `-timeInSeconds` | Integer | Retry interval (seconds) |

### Logging Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-LogFile` | String | Custom log file path |
| `-LogLevel` | String | Logging verbosity level |

### Example Command Lines

```powershell
# Run in help desk mode with verbose logging
.\main.ps1 -appMode "helpDesk" -Verbose -LogLevel "Debug"

# Force new authentication token
.\main.ps1 -ForceNewToken -Delegated

# Use custom configuration files
.\main.ps1 -InitFile "custom-settings.json" -configFile ".secrets\custom-config.json"

# Run with specific group tag and wait time
.\main.ps1 -GroupTag "Custom-Autopilot" -maxWaitTime 600
```

## Configuration Validation

### Automatic Validation

The application automatically validates configuration:

- JSON syntax checking
- Required field validation
- Type checking for settings
- Fallback to default values for missing settings

### Manual Validation

Test configuration without running the full application:

```powershell
# Display current authentication settings
.\main.ps1 -showAuth

# Display current application settings  
.\main.ps1 -showSettings
```

### Configuration Troubleshooting

Common configuration issues and solutions:

1. **Invalid JSON Syntax**
   - Use JSON validator to check syntax
   - Check for missing commas, brackets, or quotes

2. **Missing Required Fields**
   - Ensure `AppId` and `TenantId` are present
   - Verify domain configuration matches your environment

3. **Permission Issues**
   - Check Azure AD app registration permissions
   - Verify user has appropriate roles in Azure AD

4. **Authentication Failures**
   - Verify app secret/certificate if using Private flow
   - Check network connectivity to Microsoft Graph API
   - Ensure correct tenant ID and app ID

---

*This configuration guide provides comprehensive information for customizing the Windows Autopilot Management Tool for your enterprise environment. For additional technical details, refer to the Technical-Reference.md file.*