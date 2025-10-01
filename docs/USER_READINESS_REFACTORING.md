# User Readiness Check Refactoring

## Summary
This document describes the refactoring of the "Give a device to a user" action in main.ps1 to improve user experience and code maintainability.

## Changes Overview

### 1. Comprehensive Check Execution
**Previous Behavior:** The action would stop at the first failure (e.g., missing group membership) and not perform subsequent checks.

**New Behavior:** All checks are now performed regardless of individual failures, and a comprehensive report is displayed showing all issues before prompting for the device serial number.

### 2. Code Modularization
**Previous Behavior:** All validation logic was embedded directly in the main.ps1 action block (~170 lines).

**New Behavior:** Validation logic has been extracted into reusable functions in the `UserAndGroupFunctions` folder, with main.ps1 now orchestrating the checks (~50 lines in action block).

## New Functions Created

### Test-UserReadiness.ps1
**Location:** `functions/UserAndGroupFunctions/Test-UserReadiness.ps1`

**Purpose:** Main orchestration function that coordinates all user readiness checks.

**Parameters:**
- `UserName` - User principal name to check
- `AccessToken` - Graph API access token
- `GroupsToInclude` - Required group memberships
- `GroupsToExclude` - Forbidden group memberships
- `Settings` - Application settings hashtable

**Returns:** PSCustomObject with:
- `IsReady` - Boolean overall status
- `UserName` - User being checked
- `DisplayName` - User's display name
- `Checks` - Array of individual check results
- `IssueCount` - Number of errors found
- `WarningCount` - Number of warnings found

### Test-UserGroupMembership.ps1
**Location:** `functions/UserAndGroupFunctions/Test-UserGroupMembership.ps1`

**Purpose:** Validates user group membership requirements by checking both required and forbidden groups.

**Leverages:** Existing `VerifyGroupMembership` function to perform the actual checks.

**Returns:** Check result object with:
- `CheckName` - "Group Membership"
- `Passed` - Boolean status
- `Severity` - "Error" or "Warning"
- `Message` - Summary message
- `Details` - Array of detailed information
- `SuggestedResolution` - Steps to fix issues
- `UserDisplayName` - User's display name

### Test-UserDeviceCount.ps1
**Location:** `functions/UserAndGroupFunctions/Test-UserDeviceCount.ps1`

**Purpose:** Validates that user has not exceeded maximum allowed device count.

**Leverages:** Existing `GetTotalRegisteredDevicesByUser` function.

**Returns:** Check result object with:
- `CheckName` - "Device Count Limit"
- `Passed` - Boolean status
- `Severity` - "Error" or "Warning"
- `Message` - Summary message
- `Details` - Array of detailed information
- `SuggestedResolution` - Steps to fix issues
- `CurrentCount` - Current device count
- `MaxAllowed` - Maximum allowed devices

### Test-UserStrongMapping.ps1
**Location:** `functions/UserAndGroupFunctions/Test-UserStrongMapping.ps1`

**Purpose:** Validates strong certificate mapping configuration for the user.

**Leverages:** Existing `Get-UserStrongMapping` function.

**Respects:** The `strongMappingOptional` setting to determine if this is an error or warning.

**Returns:** Check result object with:
- `CheckName` - "Strong Certificate Mapping"
- `Passed` - Boolean status
- `Severity` - "Error" or "Warning" (based on strongMappingOptional)
- `Message` - Summary message
- `Details` - Array of detailed information including certificate info
- `SuggestedResolution` - Steps to fix issues
- `CertificateCount` - Number of certificates found

### Show-UserReadinessReport.ps1
**Location:** `functions/UserAndGroupFunctions/Show-UserReadinessReport.ps1`

**Purpose:** Displays a formatted, user-friendly report of all readiness check results.

**Features:**
- ASCII-only characters (PowerShell 5.1 compatible)
- Color-coded results ([PASS] green, [FAIL] red, [WARN] yellow)
- Detailed issue descriptions
- Suggested resolutions for each failure
- Clear next steps guidance

**Output Format:**
```
============================================================
  User Readiness Report
============================================================

User: john.doe@contoso.com
Name: John Doe

[FAIL] User is NOT ready to receive a Windows 11 device

Issues found: 2
Warnings: 1

------------------------------------------------------------
  Check Results
------------------------------------------------------------

[FAIL] Group Membership
       User is missing required group memberships
       Missing groups:
         - Windows 11 Users
         - Corporate Network Access

       Resolution:
       Add user to the following groups: Windows 11 Users, Corporate Network Access. Contact an Intune administrator for assistance.

[PASS] Device Count Limit
       User is below device limit
       Current devices: 2
       Maximum allowed: 5
       Available slots: 3

[WARN] Strong Certificate Mapping
       User does not have strong certificate mapping (optional)
       Strong mapping is recommended but not required
       User may experience issues connecting to network resources

       Resolution:
       Open a ticket to enable strong certificate mapping for this user to improve security and network connectivity.

------------------------------------------------------------
Next Steps:
  1. Review the issues and warnings above
  2. Apply the suggested resolutions
  3. Run the readiness check again after making changes
============================================================
```

## Benefits of Refactoring

### 1. Improved User Experience
- **Complete visibility:** Users now see ALL issues at once instead of discovering them one at a time
- **Actionable guidance:** Each issue includes specific resolution steps
- **Better decision making:** Users can prioritize which issues to address first

### 2. Better Code Maintainability
- **Separation of concerns:** Each check is isolated in its own function
- **Reusability:** Check functions can be called independently or from other contexts
- **Testability:** Individual functions can be unit tested in isolation
- **Readability:** main.ps1 action is now clean orchestration code

### 3. Consistency
- **Standardized output:** All checks return the same structured object format
- **Uniform reporting:** Show-UserReadinessReport handles all display logic
- **Logging:** All functions include comprehensive logging

### 4. Extensibility
- **Easy to add checks:** New checks follow the same pattern (Test-UserXXX functions)
- **Flexible reporting:** The report function can be enhanced without touching check logic
- **Configuration-driven:** Severity levels and optional checks are settings-based

## Backward Compatibility

### Existing Functions Preserved
All existing functions used by the original implementation are still used:
- `VerifyGroupMembership` - Still performs the actual group membership validation
- `GetTotalRegisteredDevicesByUser` - Still retrieves device counts
- `Get-UserStrongMapping` - Still retrieves certificate mapping information
- `ProcessSerialNumber` - Still handles device serial number processing

### Settings Honored
All existing settings are respected:
- `maxNumberOfDevicesAllowed` - Device limit threshold
- `checkStrongMapping` - Whether to perform strong mapping check
- `strongMappingOptional` - Whether strong mapping is optional or required
- `groupsToInclude` - Required group memberships
- `groupsToExclude` - Forbidden group memberships

### Navigation Flow Unchanged
The menu navigation and user interaction patterns remain the same:
- User lookup and selection
- Back/exit navigation options
- Serial number input flow

## Testing Recommendations

### Unit Testing
Test individual check functions with various scenarios:
1. `Test-UserGroupMembership`: Missing groups, forbidden groups, all correct
2. `Test-UserDeviceCount`: Below limit, at limit, over limit
3. `Test-UserStrongMapping`: Has certificates, no certificates, optional vs required

### Integration Testing
Test the complete flow:
1. User with all checks passing
2. User with one failing check
3. User with multiple failing checks
4. User with warnings (optional checks)
5. User with mix of errors and warnings

### Edge Cases
1. User not found in directory
2. Network/API failures during checks
3. Empty group configurations
4. Missing settings values

## Migration Path

No migration is required. The refactored code:
- Uses the same settings structure
- Requires no configuration changes
- Maintains the same external interface
- Is automatically loaded with other functions on startup

## Future Enhancements

Potential improvements that are now easier with this architecture:

1. **Configurable checks:** Define which checks to run via settings
2. **Custom check plugins:** Allow admins to add domain-specific checks
3. **Parallel execution:** Run independent checks concurrently
4. **Report export:** Save readiness reports to files or tickets
5. **Bulk checking:** Check multiple users at once
6. **Automated remediation:** Trigger fixes for certain issue types
7. **Check history:** Track readiness status changes over time
