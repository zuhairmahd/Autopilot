# Multiple App Modes Configuration Guide

## Enhanced Role-Based Access Control and Menu Customization

The Windows Autopilot Management Tool now supports both **single app mode** (legacy) and **multiple app modes** (new) to provide flexible role-based access control and menu customization. This enhanced system allows users to combine permissions from different modes for greater functionality while maintaining security boundaries.

## Multiple App Modes Overview

The application now supports two configuration approaches:

1. **Single App Mode (Legacy)**: Traditional single mode configuration for backward compatibility
2. **Multiple App Modes (New)**: Combine multiple modes to create custom permission sets

### Benefits of Multiple App Modes
- **Flexibility**: Combine permissions from different modes (e.g., Help Desk + Registration)
- **Granular Control**: Fine-tune access based on specific organizational needs  
- **Reduced Redundancy**: Automatically resolves conflicts between overlapping modes
- **Backward Compatibility**: Existing single mode configurations continue to work unchanged

## App Mode Hierarchy System

The application uses a hierarchical permission system where higher-level modes include permissions from lower-level modes:

```
Full Mode (*)
├── Admin Mode
│   ├── Advanced Mode
│   │   ├── Help Desk Mode
│   │   └── Registration Mode
│   └── Advanced Registration Mode
└── Custom Mode (user-defined)
```

### Hierarchy Rules
- **Full Mode**: Grants all permissions, supersedes all other modes
- **Admin Mode**: Includes Advanced + Help Desk + Registration permissions
- **Advanced Mode**: Includes Help Desk + Registration permissions  
- **Advanced Registration**: Specialized registration with extended features
- **Help Desk**: Device troubleshooting and user management
- **Registration**: Device enrollment and basic operations
- **Custom**: User-defined permissions based on configuration

## Application Modes

### 🔑 Full Mode (`full`)
**Complete administrative access with all features enabled**
- All menu items and actions available
- Bypasses all access restrictions
- Recommended for system administrators
- **Hierarchy**: `*` (all permissions)

### 👨‍💼 Admin Mode (`admin`)  
**System administrator with full configuration and management capabilities**
- Administrative functions and system configuration
- Advanced user management and device operations
- Full export and reporting capabilities
- **Hierarchy**: `admin`, `advanced`, `helpdesk`, `registration`

### ⚙️ Advanced Mode (`advanced`)
**Advanced user with helpdesk and configuration capabilities**
- Advanced features for experienced users
- Device configuration and policy management
- Advanced troubleshooting tools
- **Hierarchy**: `advanced`, `helpdesk`, `registration`

### 🎧 Help Desk Mode (`helpdesk`)
**Streamlined interface for help desk operations and device troubleshooting**
- Device assignment and troubleshooting
- User management and device actions
- Basic exports and reporting
- **Hierarchy**: `helpdesk`

### 📝 Registration Mode (`registration`)
**Device registration specialist with Autopilot enrollment capabilities**
- Autopilot device registration and import
- Device status checking and basic operations
- Basic export functionality
- **Hierarchy**: `helpdesk`, `registration`

### 🔧 Advanced Registration Mode (`advancedRegistration`)
**Advanced registration specialist with administrative Autopilot capabilities**
- Advanced Autopilot features and custom imports
- Device preparation and advanced device actions
- Extended registration capabilities
- **Hierarchy**: `advancedRegistration`, `registration`

### 🎨 Custom Mode (`custom`)
**Customizable mode where users define their own access patterns**
- User-defined permissions and capabilities
- Flexible configuration for specialized deployments
- **Hierarchy**: Configurable (empty by default)

## Configuration and Customization

### Setting App Mode

App mode can be configured in multiple ways:

#### 1. Command Line Parameter (Single Mode)
```powershell
.\main.ps1 -appMode "helpdesk"
```

#### 2. Settings Configuration (Single Mode - Legacy)
```json
{
  "globalSettings": {
    "appMode": "helpdesk"
  }
}
```

#### 3. Settings Configuration (Multiple Modes - New)
```json
{
  "globalSettings": {
    "appMode": "helpdesk",
    "appModes": ["helpdesk", "registration"]
  }
}
```

#### 4. Domain-Specific Configuration
```json
{
  "domains": {
    "company.com": {
      "settings": {
        "appModes": ["advanced", "registration"]
      }
    }
  }
}
```

### Multiple App Modes Configuration

When using multiple app modes, the system combines permissions using **additive strategy** by default:

#### Example Configurations

**Help Desk + Registration Combination:**
```json
{
  "globalSettings": {
    "appModes": ["helpdesk", "registration"]
  }
}
```
*Result*: Access to help desk operations + device registration features

**Admin + Custom Combination:**  
```json
{
  "globalSettings": {
    "appModes": ["admin", "custom"]
  }
}
```
*Result*: Full admin permissions + any custom-defined permissions

### Conflict Resolution

When multiple modes are selected, the system automatically resolves conflicts:

#### Resolution Strategies

1. **Additive Strategy (Default)**
   - Combines permissions from all selected modes
   - Provides union of all allowed features
   - More permissive approach

2. **Precedence Strategy**
   - Uses permissions from highest precedence mode only
   - Follows hierarchy order (Full > Admin > Advanced > etc.)
   - More restrictive approach

#### Conflict Examples

**Redundant Modes:**
```json
{
  "appModes": ["admin", "helpdesk"]
}
```
→ *Warning*: `admin` already includes `helpdesk` permissions

**Full Mode Combination:**
```json
{
  "appModes": ["full", "helpdesk", "registration"]
}
```  
→ *Result*: `full` mode grants all permissions, other modes are redundant

### Menu Item Visibility Configuration

Individual menu items can specify which modes can access them:

```json
{
  "name": "Advanced Settings",
  "description": "Modify advanced configuration",
  "includeInDisplayModes": ["advanced", "admin", "full"]
}
```

#### Multiple Mode Menu Filtering

With multiple app modes, menu items are shown if **any** of the user's modes match the item's `includeInDisplayModes`:

```json
User modes: ["helpdesk", "registration"]
Menu item: {"includeInDisplayModes": ["registration", "admin"]}
```
→ *Result*: Menu item is **visible** (matches `registration`)

### Settings Editor Interface

The enhanced settings editor provides two configuration options:

#### Multiple App Mode Selection
- Interactive multi-selection interface
- Conflict detection and resolution warnings
- Hierarchy information and superseding notifications
- Real-time effective permissions display

#### Single App Mode Selection  
- Traditional single-mode selection
- Maintained for backward compatibility
- Simpler interface for basic deployments

### Interactive Mode Selection Features

**Conflict Detection:**
```
⚠ CONFLICT INFORMATION:
• Mode 'admin' already includes 'helpdesk' permissions
• Resolution: Using additive strategy - all permissions combined
```

**Superseding Notifications:**
```
ℹ NOTE: Some modes may be redundant due to hierarchy:
• 'admin' already includes 'helpdesk' permissions
• 'full' mode grants all permissions - other modes are redundant
```

**Effective Permissions Display:**
```
Selected modes: [admin, registration]  
Effective permissions: [admin, advanced, helpdesk, registration]
```

### Custom Mode Configuration

Organizations can create custom access patterns by:

#### 1. Defining Custom Hierarchy
```json
"appModeHierarchy": {
  "custom": ["registration", "helpdesk"]
}
```

#### 2. Setting Custom Menu Visibility
```json
{
  "name": "Special Function",
  "includeInDisplayModes": ["custom"]
}
```

#### 3. Custom Mode Combinations
```json
{
  "globalSettings": {
    "appModes": ["custom", "registration"]
  }
}
```

## Best Practices

### Choosing the Right Configuration

**Single Mode (Legacy)**
- Use for simple deployments with clear role separation
- Backward compatibility with existing configurations
- Simpler management and training

**Multiple Modes (Recommended)**  
- Use for complex organizations with overlapping responsibilities
- Fine-grained permission control
- Better alignment with real-world job functions

### Recommended Mode Combinations

**Support Operations:**
```json
{"appModes": ["helpdesk", "registration"]}
```
*Ideal for*: Support staff handling both troubleshooting and device enrollment

**Senior Technical Staff:**
```json  
{"appModes": ["advanced", "registration"]}
```
*Ideal for*: Technical leads with device management and enrollment responsibilities

**Device Specialists:**
```json
{"appModes": ["advancedRegistration"]}  
```
*Ideal for*: Dedicated device enrollment and preparation teams

**System Administrators:**
```json
{"appModes": ["admin"]}
```
*Ideal for*: Full administrative access with all permissions

### Security Considerations

- **Start with Minimum Access**: Begin with the least privileged mode combination
- **Regular Reviews**: Periodically review mode assignments and effective permissions
- **Conflict Resolution**: Understand how conflicts are resolved in your configuration
- **Testing**: Test mode combinations in development before production deployment
- **Documentation**: Document mode assignments and rationale for audit purposes

### Organizational Implementation

**Planning Phase:**
- Map organizational roles to app mode combinations
- Identify overlapping responsibilities and required permissions
- Plan for training on new multiple mode functionality

**Deployment Phase:**  
- Start with backward-compatible single modes
- Gradually migrate to multiple mode combinations
- Use settings editor for interactive configuration and validation

**Maintenance Phase:**
- Monitor effective permissions and usage patterns
- Adjust mode combinations based on user feedback
- Update documentation and training materials

## Troubleshooting

### Common Issues

1. **Missing Menu Items**: Check if current modes include required access level
2. **Unexpected Access**: Verify app mode hierarchy and conflict resolution
3. **Configuration Errors**: Validate menu.json and settings file syntax
4. **Mode Conflicts**: Review effective permissions and resolution strategy

### Debugging Mode Access

```powershell
# Check current mode configuration  
$appModeConfig = Get-AppModeSettingsFromFile -SettingsFile "settings.psd1"
Write-Host "Configuration Type: $($appModeConfig.ConfigurationType)"
Write-Host "Effective Modes: [$($appModeConfig.EffectiveModes -join ', ')]"

# Get combined hierarchy
$hierarchy = Get-MultipleAppModeHierarchy -AppModes $appModeConfig.EffectiveModes  
Write-Host "Available Permissions: [$($hierarchy -join ', ')]"
```

### Validation Commands

```powershell
# Test menu item visibility
$menuItems = @(@{name="Test Item"; includeInDisplayModes=@("helpdesk", "admin")})
$filtered = FilterMenuItemsByAppMode -MenuItems $menuItems -CurrentAppModes @("helpdesk", "registration")

# Validate app mode combination
$validation = Test-AppModeSelection -SelectedModes @("admin", "helpdesk")
Write-Host "Has Conflicts: $($validation.HasConflicts)"
Write-Host "Resolution: $($validation.Resolution)"
```

### Migration from Single to Multiple Modes

**Existing Configuration:**
```json
{
  "globalSettings": {
    "appMode": "helpdesk"
  }
}
```

**Migrated Configuration:**
```json  
{
  "globalSettings": {
    "appMode": "helpdesk",
    "appModes": ["helpdesk", "registration"]
  }
}
```

*Note*: The legacy `appMode` property is maintained for backward compatibility.

---

This enhanced configuration system provides a flexible, secure, and scalable approach to role-based access control within the Windows Autopilot Management Tool, ensuring users have appropriate access to the features they need while maintaining security boundaries and supporting complex organizational structures.