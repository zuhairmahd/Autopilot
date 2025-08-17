# Application Mode Configuration Guide
## Role-Based Access Control and Menu Customization

### Overview
The Windows Autopilot Management Tool provides multiple application modes designed for different organizational roles and responsibilities. Each mode provides a customized interface with specific capabilities tailored to the user's needs while maintaining security and operational boundaries.

---

## App Mode Hierarchy System

### Hierarchical Privilege Model
The application uses a **hierarchical privilege system** where higher-level modes automatically inherit capabilities from lower-level modes:

```
full (All Features)
├── admin (System Administration)
├── advanced (Advanced Operations)
│   ├── helpdesk (Help Desk Operations)
│   │   └── registration (Device Registration)
│   └── advancedRegistration (Advanced Registration)
│       └── registration (Device Registration)
└── custom (User-Defined)
```

### How Hierarchy Works
- **full**: Can access ALL features and menus (wildcard access)
- **admin**: Gets admin + advanced + helpdesk + registration features
- **advanced**: Gets advanced + helpdesk + registration features  
- **helpdesk**: Gets helpdesk + registration features
- **registration**: Gets only registration features
- **advancedRegistration**: Gets advancedRegistration + registration features
- **custom**: User-defined access patterns

---

## Application Modes

### 🔑 Full Mode (`full`)
**Target Users**: System Administrators, IT Directors  
**Description**: Complete administrative access with all features enabled

**Capabilities**:
- All menu items and actions available
- Complete system configuration access
- Advanced diagnostic and troubleshooting tools
- All export and reporting functions
- Device management and administrative actions
- Settings and environment configuration

**Menu Access**: Unlimited - sees every menu item

**Use Cases**:
- System administration and configuration
- Advanced troubleshooting and diagnostics
- Policy management and system oversight
- Initial system setup and maintenance

---

### 👨‍💼 Admin Mode (`admin`)
**Target Users**: IT Administrators, System Managers  
**Description**: System administrator with full configuration and management capabilities

**Capabilities**:
- System administration and configuration
- Advanced features and diagnostics
- Helpdesk and user management operations
- Device registration and enrollment
- Full configuration access
- Advanced reporting and exports

**Menu Access**: All features except full-mode-specific administrative tools

**Use Cases**:
- Day-to-day system administration
- User and device management
- Configuration management
- Advanced troubleshooting

---

### ⚙️ Advanced Mode (`advanced`)
**Target Users**: Senior IT Staff, Team Leads  
**Description**: Advanced user with helpdesk and configuration capabilities

**Capabilities**:
- Advanced device management features
- Helpdesk operations and user support
- Device registration and enrollment
- Settings viewing and some configuration
- Advanced export and reporting functions
- Complex device troubleshooting

**Menu Access**: Advanced features + all helpdesk and registration capabilities

**Use Cases**:
- Advanced device troubleshooting
- Complex user assignment scenarios
- Detailed reporting and analysis
- Senior helpdesk operations

---

### 🎧 Help Desk Mode (`helpdesk`)
**Target Users**: Help Desk Technicians, Support Staff  
**Description**: Helpdesk operator with device troubleshooting and user assignment capabilities

**Capabilities**:
- User-to-device assignment workflows
- Device troubleshooting and status checking
- Basic export and reporting functions
- Device actions (wipe, sync, restart)
- User management and device lookup
- Basic registration operations

**Menu Access**: Helpdesk-specific features + all registration capabilities

**Use Cases**:
- Daily help desk operations
- User support and device assignment
- Basic device troubleshooting
- Device management tasks

---

### 📝 Registration Mode (`registration`)
**Target Users**: Device Registration Specialists, Deployment Teams  
**Description**: Device registration specialist with Autopilot enrollment capabilities

**Capabilities**:
- Autopilot device registration and import
- Basic device exports and reporting
- Device status checking and monitoring
- Device hash generation and management
- Basic device actions and operations

**Menu Access**: Registration-specific features only

**Use Cases**:
- Device enrollment and registration
- Autopilot device management
- Basic device monitoring
- Device preparation workflows

---

### 🔧 Advanced Registration Mode (`advancedRegistration`)
**Target Users**: Senior Registration Specialists, Deployment Engineers  
**Description**: Advanced registration specialist with administrative Autopilot capabilities

**Capabilities**:
- Advanced Autopilot device operations
- Custom device import and configuration
- Corporate Device Identifier management
- Device Preparation workflows
- Advanced device hash operations
- All basic registration functions

**Menu Access**: Advanced registration features + all basic registration capabilities

**Use Cases**:
- Complex device enrollment scenarios
- Corporate device preparation
- Advanced Autopilot configuration
- Specialized deployment workflows

---

### 🎨 Custom Mode (`custom`)
**Target Users**: Specialized Roles, Custom Implementations  
**Description**: Customizable mode where organizations define their own access patterns

**Capabilities**: User-defined based on organizational requirements

**Menu Access**: Configured by organization based on specific needs

**Configuration**: Organizations can define custom menu visibility and feature access patterns in the configuration files.

**Use Cases**:
- Specialized organizational roles
- Custom workflow requirements
- Temporary or project-specific access
- Testing and development scenarios

---

## Default Configuration

### App Mode Defaults in menu.json
The application includes pre-configured defaults for each mode in `menu.json`:

```json
"appModeDefaults": {
  "full": {
    "description": "Full administrative access with all features enabled",
    "capabilities": ["all_menus", "all_actions", "settings_management", "advanced_diagnostics", "export_all", "device_management"]
  },
  "advanced": {
    "description": "Advanced user with helpdesk and configuration capabilities", 
    "capabilities": ["advanced_features", "helpdesk_operations", "device_registration", "settings_view", "advanced_exports"]
  },
  "helpdesk": {
    "description": "Helpdesk operator with device troubleshooting and user assignment capabilities",
    "capabilities": ["device_assignment", "device_troubleshooting", "basic_exports", "device_actions", "user_management"]
  },
  "registration": {
    "description": "Device registration specialist with Autopilot enrollment capabilities",
    "capabilities": ["autopilot_registration", "device_import", "basic_exports", "device_status_check"]
  },
  "advancedRegistration": {
    "description": "Advanced registration specialist with administrative Autopilot capabilities",
    "capabilities": ["advanced_autopilot", "custom_import", "device_preparation", "advanced_device_actions"]
  },
  "admin": {
    "description": "System administrator with full configuration and management capabilities",
    "capabilities": ["system_administration", "advanced_features", "helpdesk_operations", "device_registration", "full_configuration"]
  },
  "custom": {
    "description": "Customizable mode where users define their own access patterns",
    "capabilities": ["user_defined"]
  }
}
```

---

## Configuration and Customization

### Setting App Mode
App mode can be configured in multiple ways:

1. **Command Line Parameter**:
   ```powershell
   .\main.ps1 -appMode "helpdesk"
   ```

2. **Settings Configuration**:
   ```json
   {
     "globalSettings": {
       "appMode": "helpdesk"
     }
   }
   ```

3. **Domain-Specific Configuration**:
   ```json
   {
     "domains": {
       "company.com": {
         "settings": {
           "appMode": "registration"
         }
       }
     }
   }
   ```

### Menu Item Visibility Configuration
Individual menu items can specify which modes can access them:

```json
{
  "name": "Advanced Settings",
  "description": "Modify advanced configuration",
  "includeInDisplayModes": ["advanced", "admin"]
}
```

### Custom Mode Configuration
Organizations can create custom access patterns by:

1. **Defining Custom Hierarchy**:
   ```json
   "appModeHierarchy": {
     "custom": ["registration", "helpdesk"]
   }
   ```

2. **Setting Custom Menu Visibility**:
   ```json
   {
     "name": "Special Function",
     "includeInDisplayModes": ["custom"]
   }
   ```

---

## Best Practices

### Choosing the Right Mode
- **Start with the minimum required access** for security
- **Use registration mode** for dedicated enrollment teams
- **Use helpdesk mode** for general support operations  
- **Use advanced mode** for senior technical staff
- **Reserve full/admin modes** for system administrators

### Security Considerations
- **Regular Access Review**: Periodically review who has access to each mode
- **Principle of Least Privilege**: Grant only the minimum access required
- **Role Separation**: Use different modes for different organizational functions
- **Audit Trail**: Monitor mode usage and feature access

### Organizational Implementation
- **Document Role Mappings**: Clearly define which roles use which modes
- **Training Programs**: Ensure users understand their mode capabilities
- **Configuration Management**: Use domain-specific settings for different environments
- **Change Control**: Implement proper processes for mode configuration changes

---

## Troubleshooting

### Common Issues
1. **Missing Menu Items**: Check if current mode includes required access level
2. **Unexpected Access**: Verify app mode hierarchy configuration
3. **Configuration Errors**: Validate menu.json syntax and structure

### Debugging Mode Access
```powershell
# Check current mode and hierarchy
Write-Host "Current App Mode: $($settings.appMode)"
$hierarchy = Get-AppModeHierarchy -CurrentAppMode $settings.appMode
Write-Host "Available Access Levels: [$($hierarchy -join ', ')]"
```

### Validation Commands
```powershell
# Test menu item visibility
Test-MenuItemIncluded -MenuItemName "Advanced Settings" -Menus $menuConfig

# Validate app mode configuration
Test-AppModeConfiguration -Mode "helpdesk"
```

---

This configuration provides a flexible, secure, and scalable approach to role-based access control within the Windows Autopilot Management Tool, ensuring users have appropriate access to the features they need while maintaining security boundaries.