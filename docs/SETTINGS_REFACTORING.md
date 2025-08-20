# Settings Functions Refactoring Documentation

## Overview
This document describes the refactoring changes made to consolidate settings functions and add force overwrite capability as specified in issue #111.

## Changes Made

### 1. Consolidated ConvertFrom-JsonToHashtable and ConvertTo-FlatHashtable

**Previous State:**
- `ConvertFrom-JsonToHashtable`: Converted PSCustomObject to hashtable while preserving structure
- `ConvertTo-FlatHashtable`: Helper function inside MergeSettings.ps1 that flattened nested structures

**New State:**
- `ConvertFrom-JsonToHashtable`: Enhanced to support both structured and flattened conversion
- `ConvertTo-FlatHashtable`: Removed from MergeSettings.ps1

**Enhanced Function Signature:**
```powershell
ConvertFrom-JsonToHashtable -JsonObject $object [-Flatten] [-Prefix $prefix]
```

**Parameters:**
- `JsonObject`: The object to convert (PSCustomObject, hashtable, etc.)
- `Flatten`: Optional switch to flatten nested structures with dot notation
- `Prefix`: Internal parameter for recursion when flattening

**Backward Compatibility:**
- All existing calls to `ConvertFrom-JsonToHashtable` continue to work unchanged
- Function now handles hashtables, PSCustomObjects, and arrays
- Default behavior preserves original functionality

### 2. Enhanced Merge-ConfigurationDefaults with Overwrite Capability

**Previous State:**
- Only supported preserving existing values or overwriting all values
- No granular control over specific settings

**New State:**
- Added `OverwriteSettings` parameter for granular force overwrite control
- Maintains all existing behavior while adding new functionality

**Enhanced Function Signature:**
```powershell
Merge-ConfigurationDefaults -ExistingConfig $existing -DefaultConfig $defaults [-PreserveExisting $true] [-OverwriteSettings $overwrite]
```

**New Parameter:**
- `OverwriteSettings`: Optional PSCustomObject containing settings to forcibly overwrite

**Usage Examples:**
```powershell
# Force overwrite specific settings
$overwrite = [PSCustomObject]@{
    CheckForUpdates = $true
    "nested.setting" = "forced-value"
}
$merged = Merge-ConfigurationDefaults -ExistingConfig $config -DefaultConfig $defaults -OverwriteSettings $overwrite
```

### 3. Updated MergeSettings.ps1

**Changes:**
- Removed internal `ConvertTo-FlatHashtable` helper function
- Updated to use `ConvertFrom-JsonToHashtable -Flatten` for flattening operations
- Maintained all existing functionality and performance

## Validation and Testing

### Tests Passed
- **Syntax validation**: All PowerShell syntax checks pass ✓
- **Core tests**: All 3 core validation tests pass ✓
- **Unit tests**: All 47 unit tests pass (100% success rate) ✓
- **JSON merge tests**: All merge functionality tests pass ✓
- **Application loading**: Main application loads successfully with changes ✓

## Files Modified
1. `functions/setupFunctions/FirstRunWizardFunctions/ConvertFrom-JsonToHashtable.ps1`
2. `functions/setupFunctions/FirstRunWizardFunctions/Merge-ConfigurationDefaults.ps1`
3. `functions/setupFunctions/MergeSettings.ps1`

## Summary
The refactoring successfully consolidates duplicate functionality while adding the requested force overwrite capability. All changes maintain backward compatibility and pass comprehensive testing.