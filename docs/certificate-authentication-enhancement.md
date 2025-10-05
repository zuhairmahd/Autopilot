# Certificate Authentication Enhancement

## Overview
This document describes the certificate-based authentication enhancement implemented for the Autopilot tool, specifically for the client credentials (non-delegated) authentication flow.

## Changes Made

### 1. Get-ClientCredentialsToken.ps1
Enhanced to support certificate-based authentication with the following features:

#### New Parameters
- `certificateThumbprint` (optional): X.509 certificate thumbprint for certificate-based authentication

#### Authentication Modes
1. **Client Secret Only**: Traditional authentication using client secret
2. **Certificate Only**: Authentication using X.509 certificate with JWT client assertion
3. **Both Available**: Tries certificate first, falls back to client secret on failure

#### Certificate Authentication Flow
1. Retrieves certificate from Windows certificate store (CurrentUser\My or LocalMachine\My)
2. Validates certificate:
   - Exists in store
   - Has not expired
   - Has accessible private key
3. Creates JWT client assertion:
   - Header: `{alg: "RS256", typ: "JWT", x5t: "<base64url-encoded thumbprint>"}`
   - Payload: `{aud, iss, sub, jti, nbf, exp}`
   - Signs with certificate's private key using RS256
4. Sends token request with `client_assertion` and `client_assertion_type` parameters
5. Returns access token on success

#### Fallback Logic
When both certificate and client secret are provided:
- Certificate authentication is attempted first
- If certificate authentication fails for any reason (cert not found, expired, no private key, token endpoint error), the function automatically falls back to client secret authentication
- Comprehensive logging tracks which method was attempted and which succeeded

#### Error Handling
- Certificate not found in store
- Certificate expired
- Certificate has no private key
- Token endpoint errors (invalid certificate, signature validation failures)
- All errors logged with appropriate severity levels

### 2. GetGraphAccessToken.ps1
Enhanced to detect and pass certificate authentication parameters:

#### Configuration Detection
- Checks for `certificateThumbprint` in config file via `Get-DecryptedConfigValue`
- Validates that at least one authentication method is available (secret or certificate)
- Logs which authentication method(s) will be used

#### Parameter Passing
Passes appropriate parameters to `Get-ClientCredentialsToken` based on what's available in config:
```powershell
$params = @{
    tenantId       = $tenantId
    clientId       = $clientId
    domain         = $domain
    cacheType      = $CacheType
    cacheTokenFile = $cacheTokenFile
    cacheFolder    = $cacheFolder
}

if ($clientSecret) {
    $params['clientSecret'] = $clientSecret
}

if ($certificateThumbprint) {
    $params['certificateThumbprint'] = $certificateThumbprint
}
```

## Configuration

### Adding Certificate Thumbprint to Config
Add the certificate thumbprint to your configuration file:

```powershell
@{
    tenantId = "your-tenant-id"
    appId = "your-app-id"
    domain = "yourdomain.onmicrosoft.com"
    
    # Option 1: Use certificate only
    certificateThumbprint = "ABCD1234567890EFABCD1234567890EFABCD1234"
    
    # Option 2: Use client secret only
    AppSecret = "your-client-secret"
    
    # Option 3: Provide both for automatic fallback
    certificateThumbprint = "ABCD1234567890EFABCD1234567890EFABCD1234"
    AppSecret = "your-client-secret"  # Used as fallback if certificate fails
}
```

### Certificate Requirements
1. Certificate must be installed in Windows certificate store:
   - Current User Personal store (`Cert:\CurrentUser\My`), OR
   - Local Machine Personal store (`Cert:\LocalMachine\My`)
2. Certificate must have a private key accessible to the running process
3. Certificate must not be expired
4. Certificate must be registered with Azure AD application:
   - Go to Azure Portal → App Registrations → Your App → Certificates & Secrets
   - Upload the certificate's public key (.cer file)
   - Note the thumbprint for configuration

## Testing

### Unit Tests
`TestScripts\test-Get-ClientCredentialsToken.ps1` - 10 comprehensive tests:
1. Parameter validation (missing both secret and cert)
2. Client secret authentication success
3. Client secret authentication failure
4. Certificate not found in store
5. Certificate without private key
6. Certificate expired
7. Certificate authentication success
8. Fallback from certificate to secret (both provided)
9. Certificate-only mode with no fallback
10. SecureString output

### Integration Tests
`TestScripts\test-GetGraphAccessToken-Certificate.ps1` - 4 integration tests:
1. Certificate-only configuration
2. Client secret only configuration
3. Both available (certificate priority)
4. Neither available (graceful failure)

## Logging
All authentication attempts are logged with comprehensive detail:
- Authentication strategy selected (cert only / secret only / both with fallback)
- Certificate retrieval attempts and results
- JWT creation success/failure
- Token request attempts with method used
- Fallback trigger events
- All errors with appropriate severity levels

Example log output:
```
[Get-ClientCredentialsToken] Starting Get-ClientCredentialsToken - tenantId=..., clientId=..., domain=...
[Get-ClientCredentialsToken] Both certificate and client secret provided - will try certificate first with fallback to secret
[Get-ClientCredentialsToken] Attempting certificate-based authentication
[Get-ClientCredentialsToken] Retrieving certificate from store with thumbprint: ABCD1234...
[Get-ClientCredentialsToken] Certificate found: Subject=CN=MyApp, NotAfter=2026-01-01
[Get-ClientCredentialsToken] Creating JWT client assertion
[Get-ClientCredentialsToken] Signing JWT with certificate private key
[Get-ClientCredentialsToken] JWT client assertion created successfully
[Get-ClientCredentialsToken] Sending token request with certificate authentication
[Get-ClientCredentialsToken] Access token received successfully via certificate authentication. Expires in: 3600 seconds
[Get-ClientCredentialsToken] Token cached successfully (type: memory)
```

## Security Considerations

### Certificate Storage
- Certificates are stored in Windows certificate store, leveraging OS-level security
- Private keys are protected by Windows cryptographic providers
- Certificate thumbprints in config files are not sensitive (they're public identifiers)

### JWT Client Assertion
- Uses RS256 (RSA Signature with SHA-256) for signing
- JWTs are short-lived (10 minutes validity)
- Each token request uses a unique JWT identifier (jti claim)
- Token endpoint validates certificate registration with Azure AD

### Best Practices
1. Use certificate authentication for production environments (more secure than client secrets)
2. Implement certificate rotation procedures (update config when certificate is renewed)
3. Restrict private key access using certificate permissions
4. Monitor certificate expiration dates
5. Keep fallback client secret as a backup authentication method

## Backward Compatibility
All changes are fully backward compatible:
- Existing configurations using only client secret continue to work without modification
- New `certificateThumbprint` parameter is optional
- Function signatures preserve all existing parameters
- No breaking changes to calling code

## Related Files
- `functions/graphFunctions/Get-ClientCredentialsToken.ps1` - Core implementation
- `functions/graphFunctions/GetGraphAccessToken.ps1` - Integration point
- `TestScripts/test-Get-ClientCredentialsToken.ps1` - Unit tests
- `TestScripts/test-GetGraphAccessToken-Certificate.ps1` - Integration tests
- `docs/certificate-authentication-enhancement.md` - This document

## References
- [Microsoft Identity Platform - Certificate Credentials](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-certificate-credentials)
- [OAuth 2.0 Client Credentials Grant with Certificate](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-client-creds-grant-flow#second-case-access-token-request-with-a-certificate)
- [RFC 7523 - JSON Web Token (JWT) Profile for OAuth 2.0 Client Authentication](https://tools.ietf.org/html/rfc7523)
