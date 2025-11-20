function DecodeJwtToken()
{
    <#
    .SYNOPSIS
    Decodes and parses a JWT (JSON Web Token) into its component parts.

    .DESCRIPTION
    This function decodes a Base64-encoded JWT token and extracts its payload claims.
    It handles Base64 padding, provides human-readable claim names for common JWT properties,
    and supports both raw object output and formatted JSON output. The function validates
    token format and handles decoding errors gracefully.

    .PARAMETER Token
    The JWT token string to decode. This parameter is mandatory.

    .PARAMETER raw
    When specified, returns the raw decoded object without human-readable claim name mapping.

    .PARAMETER RawJSON
    When specified, returns the decoded payload as raw JSON string instead of PSObject.

    .OUTPUTS
    System.Management.Automation.PSCustomObject or System.String
    Returns decoded token claims as PSObject (default), raw object (if -raw), or JSON string (if -RawJSON).
    Returns error message from $returnValues if token is invalid.

    .EXAMPLE
    $claims = DecodeJwtToken -Token $accessToken
    Write-Host "User: $($claims.UserPrincipalName)"
    Write-Host "Expires: $($claims.ExpirationTime)"
    
    $rawClaims = DecodeJwtToken -Token $accessToken -raw

    .NOTES
    Maps common JWT claims to human-readable names:
    - aud → Audience
    - iss → Issuer
    - roles → Roles
    - exp → ExpirationTime
    - preferred_username → UserPrincipalName
    And many more...
    
    Handles Base64 padding automatically for URL-safe Base64 encoding.
    Validates token has at least 2 parts (header.payload).
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,
        [switch]$raw,
        [switch]$RawJSON
    )
    $functionName = $MyInvocation.MyCommand.Name
    $HRIdentifyers = @{
        aud                = 'Audience'
        iss                = 'Issuer'
        wids               = 'WindowsIdentifiers'
        roles              = 'Roles'
        sub                = 'Subject'
        oid                = 'Object Identifier'
        iat                = 'IssuedAt'
        nbf                = 'NotBefore'
        exp                = 'ExpirationTime'
        idp                = 'IdentityProvider'
        appidacr           = 'AuthenticationMechanism'
        idtyp              = 'IdentityType'
        tid                = 'TenantID'
        uti                = 'UniqueTokenIdentifier'
        ver                = 'Version'
        preferred_username = 'UserPrincipalName'
        email              = 'Email'
        upn                = 'UserPrincipalName'
        unique_name        = 'UniqueName'
        mail               = 'Email'
    }
    $parts = $Token -split '\.'
    Write-Verbose "[$functionName] Token parts: $($parts.Length)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing JWT token with $($parts.Length) parts" -LogLevel "Verbose"
    if ($parts.Length -lt 2)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Invalid JWT token format. Expected at least 2 parts." -LogLevel "Error"
        return $returnValues.invalidJWTTokenMessage
    }
    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    Write-Verbose "[$functionName] Payload part: $($payload.Length)"
    switch ($payload.Length % 4)
    {
        2
        {
            Write-Verbose "[$functionName] Adjusting payload length by adding two padding characters."; $payload += '==' 
        }
        3
        {
            Write-Verbose "[$functionName] Adjusting payload length by adding one padding character."; $payload += '=' 
        }
    }
    Write-Verbose "[$functionName] Adjusted payload for Base64 decoding: $($payload.Length)"
    $bytes = [System.Convert]::FromBase64String($payload)
    Write-Verbose "[$functionName] Decoded bytes length: $($bytes.Length)"
    if ($bytes.Length -eq 0)
    {
        Write-Verbose "[$functionName] Decoded bytes are empty. Invalid JWT payload."
        return $returnValues.invalidJWTPayloadMessage
    }
    Write-Verbose "[$functionName] Decoding payload to JSON string."
    $json = [System.Text.Encoding]::UTF8.GetString($bytes)
    $claims = $json | ConvertFrom-Json
    if (-not $raw)
    {
        # Convert all claims to human readable if possible
        Write-Verbose "[$functionName] Converting JWT claims to human readable format."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Converting JWT claims to human readable format" -LogLevel "Debug"
        $humanClaims = [ordered]@{}
        foreach ($key in $claims.PSObject.Properties.Name)
        {
            Write-Verbose "[$functionName] Processing claim: $key"
            $value = $claims.$key
            Write-Verbose "[$functionName] Claim value: $value"
            Write-Verbose "[$functionName] Claim value type: $($value.GetType().Name)"
            # Check if the key is a known identifier and convert it to human readable format
            Write-Verbose "[$functionName] Checking if claim key $key is a known identifier."
            if ($HRIdentifyers.ContainsKey($key))
            {
                Write-Verbose "[$functionName] Claim key $key is a known identifier, converting to human readable format."
                $key = $HRIdentifyers[$key]
            }
            else
            {
                Write-Verbose "[$functionName] Claim key $key is not a known identifier, Skipping."
                continue
            }
            # Try to convert unix time fields
            if ($value -is [int] -or $value -is [long])
            {
                # Heuristic: treat as unix time if key is a known time claim or value is in a reasonable unix time range
                Write-Verbose "[$functionName] Claim is a number, checking if it is a unix time."
                if ($value -gt 1000000000 -and $value -lt 3000000000)
                {
                    Write-Verbose "[$functionName] Claim $key is a unix time, converting to human readable format."
                    $dt = [DateTimeOffset]::FromUnixTimeSeconds([long]$value).UtcDateTime
                    $humanClaims[$key] = FormatDateWithTimeZone -DateTime $dt
                    continue
                }
            }
            # Try to convert arrays to comma-separated string
            Write-Verbose "[$functionName] Checking if claim value is an array."
            if ($value -is [array])
            {
                Write-Verbose "[$functionName] Claim value is an array, converting to comma-separated string."
                $humanClaims[$key] = $value -join ', '
                continue
            }
            else
            {
                Write-Verbose "[$functionName] Claim value is not an array."    
            }
            if ($key -eq 'AuthenticationMechanism')
            {
                switch ($value)
                {
                    0
                    { 
                        $value = 'Public'
                        Write-Verbose "[$functionName] AuthenticationMechanism is 0, setting value to $value"
                    }
                    1 
                    { 
                        $value = 'App Secret'
                        Write-Verbose "[$functionName] AuthenticationMechanism is 1, setting value to $value"
                    }
                    2 
                    { 
                        $value = 'Certificate'
                        Write-Verbose "[$functionName] AuthenticationMechanism is 2, setting value to $value"
                    }
                    default 
                    { 
                        $value = $value
                        Write-Verbose "[$functionName] AuthenticationMechanism is unknown, keeping value as $value"
                    }
                }
                $humanClaims[$key] = $value
                continue
            }
            # Otherwise, just copy
            $humanClaims[$key] = $value
        }
        if ($RawJSON)
        {
            Write-Verbose "[$functionName] Returning all decoded JWT claims as raw JSON."
            return $humanClaims | ConvertTo-Json -Depth $maxJSONDepth
        }
        else
        {
            Write-Verbose "[$functionName] Returning all decoded JWT claims as object."
            return $humanClaims
        }
    }
    else
    {
        # Raw mode: Return unfiltered JWT claims
        Write-Verbose "[$functionName] Raw mode: Returning unfiltered JWT claims"
        if ($RawJSON)
        {
            Write-Verbose "[$functionName] Returning raw decoded JWT payload as raw JSON."
            return $json 
        }
        else
        {
            Write-Verbose "[$functionName] Returning raw decoded JWT payload as object."
            return $claims
        }
    }
}

