function Get-UserSignInActivity
{
    <#
    .SYNOPSIS
    Retrieves recent sign-in activity for a user from Microsoft Graph audit logs.

    .DESCRIPTION
    This function queries the Microsoft Graph auditLogs/signIns endpoint to retrieve
    the most recent sign-in events for a specified user. It extracts key fields including
    IP address, location, success/failure status, failure reason, and conditional access
    policy results. Returns a structured object suitable for enriching device enrollment
    reports.

    Requires AuditLog.Read.All and Directory.Read.All permissions. Conditional access
    policy details require the caller to have permissions to read CA data (e.g., Security
    Reader role).

    .PARAMETER accessToken
    Microsoft Graph API access token for authentication. This parameter is mandatory.

    .PARAMETER userPrincipalName
    The user principal name (UPN) to look up sign-in activity for. This parameter is mandatory.

    .PARAMETER maxResults
    Maximum number of sign-in events to retrieve. Defaults to 5.

    .PARAMETER daysBack
    Number of days back to search for sign-in events. Defaults to 30.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with:
      - Success: Boolean indicating if the API call succeeded
      - SignIns: Array of sign-in event objects with extracted fields
      - LatestSignIn: The most recent sign-in event (or $null)
      - Message: Status message describing the result

    .EXAMPLE
    $signInData = Get-UserSignInActivity -accessToken $token -userPrincipalName "user@contoso.com"

    .EXAMPLE
    $signInData = Get-UserSignInActivity -accessToken $token -userPrincipalName "user@contoso.com" -maxResults 10 -daysBack 7

    .NOTES
    Requires Microsoft Entra ID P1 or P2 license on the tenant.
    Uses the v1.0 Graph API endpoint for stability.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$accessToken,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$userPrincipalName,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$maxResults = 5,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 365)]
        [int]$daysBack = 30
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting sign-in activity lookup for user: $userPrincipalName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Looking up sign-in activity for user: $userPrincipalName" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Parameters - maxResults: $maxResults, daysBack: $daysBack" -LogLevel "Verbose"

    $returnObject = @{
        Success      = $false
        SignIns      = @()
        LatestSignIn = $null
        Message      = ""
    }

    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($userPrincipalName))
    {
        $returnObject.Message = "User principal name is required to look up sign-in activity."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message $returnObject.Message -LogLevel "Warning"
        return $returnObject
    }

    # Build date filter for the query
    $startDate = (Get-Date).AddDays(-$daysBack).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Searching sign-ins from $startDate" -LogLevel "Verbose"

    # Build the filter for the signIns endpoint
    $escapedUserPrincipalName = $userPrincipalName -replace "'", "''"
    $filter = "userPrincipalName eq '$escapedUserPrincipalName' and createdDateTime ge $startDate"
    $extraParams = "top=$maxResults&orderby=createdDateTime desc"

    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Calling Graph API for sign-in logs with filter: $filter" -LogLevel "Information"

    try
    {
        $response = CallGraphAPI -accessToken $accessToken `
            -ResourcePath "auditLogs/signIns" `
            -APIVersion "v1.0" `
            -Filter $filter `
            -ExtraParameters $extraParams

        # Check for error responses (CallGraphAPI returns status code on error)
        if ($null -eq $response)
        {
            $returnObject.Message = "No response received from Graph API for sign-in logs."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message $returnObject.Message -LogLevel "Warning"
            return $returnObject
        }

        if ($response -is [int])
        {
            $returnObject.Message = "Graph API returned error status $response when fetching sign-in logs. This may indicate insufficient permissions (AuditLog.Read.All required) or the tenant may not have a Microsoft Entra ID P1/P2 license."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message $returnObject.Message -LogLevel "Warning"
            return $returnObject
        }

        # Extract sign-in events from response
        $signInEvents = @()
        if ($response.value)
        {
            $signInEvents = @($response.value)
        }
        elseif ($response -is [array])
        {
            $signInEvents = @($response)
        }
        elseif ($response.id)
        {
            # Single sign-in object returned
            $signInEvents = @($response)
        }

        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Retrieved $($signInEvents.Count) sign-in events for user $userPrincipalName" -LogLevel "Information"

        if ($signInEvents.Count -eq 0)
        {
            $returnObject.Success = $true
            $returnObject.Message = "No sign-in events found for user $userPrincipalName in the last $daysBack days."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message $returnObject.Message -LogLevel "Information"
            return $returnObject
        }

        # Process each sign-in event and extract relevant fields
        $processedSignIns = @()
        foreach ($signIn in $signInEvents)
        {
            $processed = @{
                SignInId                  = $signIn.id
                CreatedDateTime          = $signIn.createdDateTime
                UserDisplayName          = $signIn.userDisplayName
                UserPrincipalName        = $signIn.userPrincipalName
                AppDisplayName           = $signIn.appDisplayName
                IPAddress                = $signIn.ipAddress
                ClientAppUsed            = $signIn.clientAppUsed
                IsInteractive            = $signIn.isInteractive
                # Location fields
                LocationCity             = $null
                LocationState            = $null
                LocationCountryOrRegion  = $null
                # Status fields
                SignInSucceeded          = $false
                ErrorCode                = $null
                FailureReason            = $null
                AdditionalDetails        = $null
                # Conditional Access fields
                ConditionalAccessStatus  = $signIn.conditionalAccessStatus
                CABlockedByPolicy        = $false
                CAPoliciesApplied        = @()
            }

            # Extract location
            if ($signIn.location)
            {
                $processed.LocationCity = $signIn.location.city
                $processed.LocationState = $signIn.location.state
                $processed.LocationCountryOrRegion = $signIn.location.countryOrRegion
            }

            # Extract status
            if ($signIn.status)
            {
                $processed.ErrorCode = $signIn.status.errorCode
                $processed.FailureReason = $signIn.status.failureReason
                $processed.AdditionalDetails = $signIn.status.additionalDetails
                $processed.SignInSucceeded = ($signIn.status.errorCode -eq 0)
            }

            # Determine if blocked by conditional access
            if ($signIn.conditionalAccessStatus -eq 'failure')
            {
                $processed.CABlockedByPolicy = $true
            }

            # Extract applied conditional access policies
            if ($signIn.appliedConditionalAccessPolicies)
            {
                $caPolicies = @()
                foreach ($policy in $signIn.appliedConditionalAccessPolicies)
                {
                    $caPolicy = @{
                        PolicyName             = $policy.displayName
                        PolicyId               = $policy.id
                        Result                 = $policy.result
                        EnforcedGrantControls  = $policy.enforcedGrantControls
                        EnforcedSessionControls = $policy.enforcedSessionControls
                    }
                    $caPolicies += $caPolicy
                }
                $processed.CAPoliciesApplied = $caPolicies
            }

            $processedSignIns += $processed
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processed sign-in event $($signIn.id): Success=$($processed.SignInSucceeded), IP=$($processed.IPAddress), CA=$($processed.ConditionalAccessStatus)" -LogLevel "Verbose"
        }

        $returnObject.Success = $true
        $returnObject.SignIns = $processedSignIns
        $returnObject.LatestSignIn = $processedSignIns[0]
        $returnObject.Message = "Retrieved $($processedSignIns.Count) sign-in events for user $userPrincipalName."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message $returnObject.Message -LogLevel "Information"

        # Log analysis summary
        $successCount = ($processedSignIns | Where-Object { $_.SignInSucceeded -eq $true }).Count
        $failureCount = ($processedSignIns | Where-Object { $_.SignInSucceeded -eq $false }).Count
        $caBlockCount = ($processedSignIns | Where-Object { $_.CABlockedByPolicy -eq $true }).Count
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Sign-in summary: $successCount succeeded, $failureCount failed, $caBlockCount blocked by CA policy" -LogLevel "Information"
    }
    catch
    {
        $returnObject.Message = "Error retrieving sign-in activity: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message $returnObject.Message -LogLevel "Error"
        Write-Error "[$functionName] $($returnObject.Message)"
    }

    return $returnObject
}
