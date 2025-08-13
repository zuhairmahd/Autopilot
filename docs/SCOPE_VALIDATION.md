# Microsoft Graph Scope Validation

This document describes the Microsoft Graph scope validation functionality implemented in the Windows Autopilot Management Tool.

## Overview

The scope validation system ensures that the application has the necessary Microsoft Graph API permissions to function correctly. It validates the scopes available in the access token against the required scopes defined in `settings.json`, and provides guidance on how to resolve any missing permissions.

## How It Works

### Validation Process

1. **Token Acquisition**: After successfully retrieving an access token via `GetGraphAccessToken`
2. **Scope Validation**: The system calls `Test-ScopeAvailability` to compare available scopes against requirements
3. **Missing Scope Handling**: If scopes are missing, `Request-AdditionalScopes` handles the appropriate response based on authentication type

### Authentication Types

#### Delegated Authentication (`delegated: true`)
- **Scope Source**: Uses the scopes that were requested during the authentication flow
- **Missing Scopes**: Offers to re-authenticate with additional scopes
- **User Experience**: Interactive prompt to grant additional permissions
- **Implementation**: Combines current scopes with missing scopes and requests new token

#### Application Authentication (`delegated: false`)
- **Scope Source**: Extracts scopes from the JWT token using `DecodeJwtToken`
- **Missing Scopes**: Provides administrator guidance for adding permissions
- **User Experience**: Clear instructions for adding permissions in Microsoft Entra admin center
- **Implementation**: Cannot request additional scopes at runtime

## Functions

### Test-ScopeAvailability

Validates whether all required scopes are available in the current access token.

**Parameters:**
- `AccessToken` (string): The access token to validate
- `RequiredScopes` (array): Array of scope objects from settings.json
- `AuthConfiguration` (hashtable): Authentication configuration object
- `RequestedScopes` (array): Scopes that were requested (delegated auth only)

**Returns:**
- `HasAllRequiredScopes` (boolean): Whether all required scopes are available
- `MissingScopes` (array): List of missing scope objects
- `AvailableScopes` (array): List of scopes available in the token
- `ScopeSource` (string): Description of where scopes were sourced from
- `UnavailableFunctionality` (array): List of features that will be unavailable
- `RecommendedAction` (string): Suggested next steps

**Example:**
```powershell
$validation = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes -AuthConfiguration $auth -RequestedScopes $requestedScopes

if (-not $validation.HasAllRequiredScopes) {
    Write-Host "Missing scopes: $($validation.MissingScopes.Count)"
    Write-Host "Recommended: $($validation.RecommendedAction)"
}
```

### Request-AdditionalScopes

Handles the process of requesting additional scopes when they are missing.

**Parameters:**
- `MissingScopes` (array): Array of missing scope objects
- `AuthConfiguration` (hashtable): Authentication configuration object
- `CurrentScopes` (array): Currently available scopes
- `AuthParams` (hashtable): Parameters used for authentication

**Returns:**
- `Success` (boolean): Whether additional scopes were successfully obtained
- `NewAccessToken` (string): New access token with additional scopes (delegated only)
- `ErrorMessage` (string): Error message if the operation failed
- `UserCancelled` (boolean): Whether the user cancelled the operation

**Example:**
```powershell
$scopeRequest = Request-AdditionalScopes -MissingScopes $missingScopes -AuthConfiguration $auth -CurrentScopes $currentScopes -AuthParams $authParams

if ($scopeRequest.Success) {
    $accessToken = $scopeRequest.NewAccessToken
    Write-Host "Successfully obtained additional permissions"
}
```

## Configuration

### Required Scopes in settings.json

The `requiredScopes` array in `settings.json` defines all the Microsoft Graph permissions that the application potentially needs:

```json
{
  "requiredScopes": [
    {
      "Scope": "User.Read.All",
      "Reason": "Required to read user profiles, group memberships, registered devices, and user directory information.",
      "Endpoints": [
        "users",
        "users/{id}",
        "users/{id}/memberOf",
        "users/{id}/registeredDevices"
      ]
    }
  ]
}
```

**Properties:**
- `Scope`: The exact Microsoft Graph permission name
- `Reason`: Description of why this permission is needed (based on Microsoft documentation)
- `Endpoints`: List of API endpoints that require this permission

### Scope Descriptions

All scope descriptions have been updated based on official Microsoft Graph documentation to ensure accuracy and compliance with Microsoft's guidance.

## Integration Points

### main.ps1 Integration

The scope validation is integrated into `main.ps1` immediately after successful token retrieval:

```powershell
if ($accessToken) {
    Write-Verbose "[$scriptName] Access token retrieved successfully."
    
    # Validate scope availability for the retrieved access token
    Write-Verbose "[$scriptName] Validating Microsoft Graph API scope availability..."
    # ... scope validation logic ...
}
```

### Error Handling

The system includes comprehensive error handling:
- Graceful fallback when dependencies are unavailable
- Clear error messages for different failure scenarios
- Continuation of application execution when scope validation fails
- Proper logging of all validation activities

## User Experience

### Successful Validation
```
✓ All required Microsoft Graph API scopes are available.
```

### Missing Scopes (Delegated)
```
⚠ Microsoft Graph Scope Validation Results:
Some required permissions are missing. This may limit functionality.

Missing permissions:
  • DeviceManagementManagedDevices.Read.All
    Impact: Required to read Intune managed device properties, device health status, and device compliance information.

Recommended action: Re-authenticate with additional scopes to enable full functionality.

Delegated authentication is being used.
Additional scopes can be requested by re-authenticating.
Would you like to re-authenticate to request these additional permissions?
```

### Missing Scopes (Application)
```
⚠ Microsoft Graph Scope Validation Results:
Some required permissions are missing. This may limit functionality.

Application authentication is being used.
Missing application permissions cannot be requested at runtime.

The following application permissions need to be added by an administrator:
  • DeviceManagementManagedDevices.Read.All
    Reason: Required to read Intune managed device properties, device health status, and device compliance information.
    Affects endpoints: deviceManagement/managedDevices, deviceManagement/managedDevices/{id}

To add these permissions:
1. Go to the Microsoft Entra admin center (https://entra.microsoft.com)
2. Navigate to 'Identity' > 'Applications' > 'App registrations'
3. Find and select your application
4. Go to 'API permissions'
5. Click 'Add a permission' > 'Microsoft Graph' > 'Application permissions'
6. Add the missing permissions listed above
7. Click 'Grant admin consent for [your organization]'
```

## Testing

### Test Coverage

The scope validation functionality includes comprehensive tests in `TestScripts/test-scope-validation.ps1`:

- Function existence validation
- Delegated authentication with all scopes available
- Delegated authentication with missing scopes
- Application authentication (JWT token decoding)
- Empty required scopes handling
- Invalid configuration handling
- Integration validation

### Running Tests

```powershell
# Run scope validation tests specifically
pwsh -File "./TestScripts/test-scope-validation.ps1"

# Run as part of enhanced test category
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory enhanced

# Run comprehensive tests including scope validation
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory all
```

## Best Practices

### For Developers

1. **Always validate scopes** after token acquisition
2. **Handle missing scopes gracefully** with clear user guidance
3. **Update scope descriptions** when adding new functionality
4. **Test both delegated and application authentication** scenarios

### For Administrators

1. **Review required permissions** in the Microsoft Entra admin center
2. **Grant admin consent** for application permissions when needed
3. **Monitor scope validation messages** in application logs
4. **Update application registrations** when new features require additional permissions

### For Users

1. **Grant consent** when prompted for additional delegated permissions
2. **Contact administrators** if application permissions are missing
3. **Review permission requests** carefully before granting consent

## Troubleshooting

### Common Issues

1. **JWT Token Decoding Fails**: Ensure the access token is a valid JWT format
2. **Write-Log Dependency**: The functions gracefully handle missing logging dependencies
3. **Empty Scope Arrays**: Functions properly handle empty arrays and null values
4. **Authentication Type Detection**: Ensure `AuthConfiguration.Delegated` is properly set

### Debug Information

Enable verbose logging to see detailed scope validation information:
```powershell
pwsh -File "main.ps1" -Verbose
```

## Microsoft Graph Documentation References

The scope descriptions and requirements are based on:
- [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)
- [Overview of Microsoft Graph permissions](https://learn.microsoft.com/en-us/graph/permissions-overview)
- [Authentication and authorization basics](https://learn.microsoft.com/en-us/graph/auth/auth-concepts)
- [Grant or revoke API permissions programmatically](https://learn.microsoft.com/en-us/graph/permissions-grant-via-msgraph)

## Future Enhancements

Potential improvements to the scope validation system:

1. **Incremental Consent**: Support for requesting only the minimum required scopes initially
2. **Scope Caching**: Cache scope validation results to reduce API calls
3. **Dynamic Scope Requirements**: Adjust required scopes based on selected application mode
4. **Permission Monitoring**: Alert administrators when permissions are revoked or expire
5. **Audit Logging**: Enhanced logging of permission grants and usage