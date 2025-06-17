# Strings Configuration

This document explains how to manage the strings used throughout the Autopilot script.

## Overview

The script now loads strings from `strings.json` instead of having them hardcoded. This makes it easier to:
- Modify messages without editing the main script
- Maintain consistency across the application
- Support future localization efforts
- Version control string changes separately

## File Structure

The `strings.json` file contains three main sections:

### returnValues
Contains all return messages used throughout the script for various operations and states.

### deviceStates
Contains messages related to device readiness states.

### deviceActions
Contains messages for various device actions that can be performed.

## Example Structure

```json
{
  "returnValues": {
    "EnrolledMessage": "The device is enrolled.",
    "ImportSuccessMessage": "The device was imported successfully.",
    "UpdateFailedMessage": "Could not download update."
  },
  "deviceStates": {
    "Ready": "The device is ready for the next user",
    "NotReady": "The device is not ready for the next user"
  },
  "deviceActions": {
    "none": "No action",
    "contactAdmin": "Contact an Intune administrator"
  }
}
```

## Adding New Strings

To add new strings:

1. Open `strings.json`
2. Add the new key-value pair to the appropriate section
3. Save the file
4. The script will automatically pick up the new strings on next run

## Fallback Behavior

If the `strings.json` file:
- Doesn't exist
- Is corrupted/invalid JSON
- Is missing specific keys

The script will automatically fall back to built-in default values, ensuring the script continues to work without interruption.

## Best Practices

1. **Keep keys descriptive**: Use clear, descriptive key names
2. **Maintain consistency**: Use consistent naming patterns
3. **Test changes**: Always test after modifying strings
4. **Backup**: Keep backups of working configurations
5. **Version control**: Track changes to the strings file

## Migration Notes

- The original hardcoded values are preserved as fallback defaults
- All existing functionality remains unchanged
- The script maintains backward compatibility even without the JSON file
