# App Assignment Export & Reporting: Technical Usage

This document describes how to use the advanced app assignment reporting and export features provided by the `GetAppAssignmentTypes` function.

## Function Usage

### Export All App Assignments to CSV (Overwrite Mode)
```powershell
$token = Get-IntuneAuthToken # (your authentication method)
GetAppAssignmentTypes -AccessToken $token -Export -outputPath $pwd -fileMode Overwrite
```

### Append to an Existing CSV File
```powershell
GetAppAssignmentTypes -AccessToken $token -Export -outputPath $pwd -fileMode Append
```

### Retrieve Assignment Data as an Object (No Export)
```powershell
$result = GetAppAssignmentTypes -AccessToken $token
$result.RequiredApps   # All required apps
$result.AvailableApps  # All available apps
$result.UnassignedApps # All unassigned apps
```

## Parameters

- `-AccessToken` (required): Microsoft Graph API access token
- `-Export`: Switch to enable CSV export
- `-outputPath`: Path to the folder where the output CSV file will be created (required if `-Export` is used)
- `-fileMode`: 'Append' or 'Overwrite' (default: 'Overwrite')

## CSV Output

The exported CSV includes columns for:
- Intent (Required, Available, Unassigned)
- App ID, Type, Display Name
- Assigned Groups (resolved names)
- Assignment group count
- Assignment metadata

## Logging

All operations are logged with both `Write-Verbose` and `Write-Log` (CMTrace-compatible) for full traceability. Verbose logging can be enabled for troubleshooting.
