function Get-SignInActivity()
{
    <#
    .SYNOPSIS
    Retrieves and formats user sign-in activity from Microsoft Graph audit logs for enrollment reports.

    .DESCRIPTION
    Queries the Microsoft Graph auditLogs/signIns endpoint to retrieve recent sign-in events
    for a specified user. Extracts and formats key fields including IP address, location,
    success/failure status, failure reasons, and conditional access policy results.
    Returns enriched data suitable for inclusion in autopilot enrollment reports.

    Requires AuditLog.Read.All and Directory.Read.All permissions. Conditional access
    policy details require appropriate permissions (e.g., Security Reader role).

    .PARAMETER UserPrincipalName
    The user principal name (UPN) to look up sign-in activity for.

    .PARAMETER AccessToken
    Microsoft Graph API access token for authentication. If not provided, uses $global:accessToken.

    .PARAMETER MaxResults
    Maximum number of sign-in events to retrieve. Defaults to 5.

    .PARAMETER DaysBack
    Number of days back to search for sign-in events. Defaults to 30.

    .PARAMETER EnrichmentOnly
    When specified, returns enrichment data in a hashtable format suitable for adding
    to existing report objects. When not specified, returns the full sign-in data structure.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with either:
    - Full data mode: Success, SignIns, LatestSignIn, Message properties
    - Enrichment mode: Formatted properties for report inclusion (SignInLatest*, SignInConditionalAccess*, SignInRecent*)

    .EXAMPLE
    $signInData = Get-SignInActivity -UserPrincipalName "user@contoso.com"

    .EXAMPLE
    $enrichmentData = Get-SignInActivity -UserPrincipalName "user@contoso.com" -EnrichmentOnly

    .EXAMPLE
    $signInData = Get-SignInActivity -UserPrincipalName "user@contoso.com" -MaxResults 10 -DaysBack 7 -AccessToken $token

    .NOTES
    Requires Microsoft Entra ID P1 or P2 license on the tenant.
    Uses the v1.0 Graph API endpoint for stability.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $false)]
        [string]$AccessToken,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$MaxResults = 5,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 365)]
        [int]$DaysBack = 30,

        [Parameter(Mandatory = $false)]
        [switch]$EnrichmentOnly
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting sign-in activity lookup for user: $UserPrincipalName" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Parameters - MaxResults: $MaxResults, DaysBack: $DaysBack, EnrichmentOnly: $EnrichmentOnly" -LogLevel "Verbose"

    # Use provided token or fall back to global token
    $token = if ($AccessToken)
    {
        $AccessToken
    }
    elseif ($global:accessToken)
    {
        $global:accessToken
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No access token available" -LogLevel "Error"
        throw "Access token is required. Provide AccessToken parameter or ensure `$global:accessToken is set."
    }

    # Initialize return object
    $returnObject = @{
        Success      = $false
        SignIns      = @()
        LatestSignIn = $null
        Message      = ""
    }

    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($UserPrincipalName))
    {
        $returnObject.Message = "User principal name is required to look up sign-in activity."
        Write-Log -LogFile $LogFile -Module $functionName -Message $returnObject.Message -LogLevel "Warning"
        if ($EnrichmentOnly)
        {
            return @{ SignInLatestStatus = "No user principal name provided" }
        }
        return $returnObject
    }

    # Build date filter for the query
    $startDate = (Get-Date).AddDays(-$DaysBack).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Log -LogFile $LogFile -Module $functionName -Message "Searching sign-ins from $startDate" -LogLevel "Verbose"

    # Build the filter for the signIns endpoint
    $escapedUserPrincipalName = $UserPrincipalName -replace "'", "''"
    $filter = "userPrincipalName eq '$escapedUserPrincipalName' and createdDateTime ge $startDate"
    $extraParams = "top=$MaxResults&orderby=createdDateTime desc"

    Write-Log -LogFile $LogFile -Module $functionName -Message "Calling Graph API for sign-in logs" -LogLevel "Verbose"

    try
    {
        $response = CallGraphAPI -accessToken $token `
            -ResourcePath "auditLogs/signIns" `
            -APIVersion "v1.0" `
            -Filter $filter `
            -ExtraParameters $extraParams

        # Check for error responses
        if ($null -eq $response)
        {
            $returnObject.Message = "No response received from Graph API for sign-in logs."
            Write-Log -LogFile $LogFile -Module $functionName -Message $returnObject.Message -LogLevel "Warning"
            if ($EnrichmentOnly)
            {
                return @{ SignInLatestStatus = "No API response" }
            }
            return $returnObject
        }

        if ($response -is [int])
        {
            $returnObject.Message = "Graph API returned error status $response when fetching sign-in logs. This may indicate insufficient permissions (AuditLog.Read.All required) or the tenant may not have a Microsoft Entra ID P1/P2 license."
            Write-Log -LogFile $LogFile -Module $functionName -Message $returnObject.Message -LogLevel "Warning"
            if ($EnrichmentOnly)
            {
                return @{ SignInLatestStatus = "API error: $response" }
            }
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
            $signInEvents = @($response)
        }

        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieved $($signInEvents.Count) sign-in events for user $UserPrincipalName" -LogLevel "Information"

        if ($signInEvents.Count -eq 0)
        {
            $returnObject.Success = $true
            $returnObject.Message = "No sign-in events found for user $UserPrincipalName in the last $DaysBack days."
            Write-Log -LogFile $LogFile -Module $functionName -Message $returnObject.Message -LogLevel "Information"
            if ($EnrichmentOnly)
            {
                return @{
                    SignInLatestStatus      = "No sign-in data available"
                    SignInRecentPattern     = $returnObject.Message
                    SignInLatestDateTime    = "N/A"
                    SignInLatestIPAddress   = "N/A"
                    SignInLatestLocation    = "N/A"
                    SignInLatestAppUsed     = "N/A"
                    SignInLatestFailureReason = "N/A"
                    SignInConditionalAccessStatus = "N/A"
                    SignInConditionalAccessPolicies = "None"
                    SignInRecentFailureReasons = "N/A"
                }
            }
            return $returnObject
        }

        # Process each sign-in event and extract relevant fields
        $processedSignIns = @()
        foreach ($signIn in $signInEvents)
        {
            $processed = @{
                SignInId                = $signIn.id
                CreatedDateTime         = $signIn.createdDateTime
                UserDisplayName         = $signIn.userDisplayName
                UserPrincipalName       = $signIn.userPrincipalName
                AppDisplayName          = $signIn.appDisplayName
                IPAddress               = $signIn.ipAddress
                ClientAppUsed           = $signIn.clientAppUsed
                IsInteractive           = $signIn.isInteractive
                LocationCity            = $null
                LocationState           = $null
                LocationCountryOrRegion = $null
                SignInSucceeded         = $false
                ErrorCode               = $null
                FailureReason           = $null
                AdditionalDetails       = $null
                ConditionalAccessStatus = $signIn.conditionalAccessStatus
                CABlockedByPolicy       = $false
                CAPoliciesApplied       = @()
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
                        PolicyName              = $policy.displayName
                        PolicyId                = $policy.id
                        Result                  = $policy.result
                        EnforcedGrantControls   = $policy.enforcedGrantControls
                        EnforcedSessionControls = $policy.enforcedSessionControls
                    }
                    $caPolicies += $caPolicy
                }
                $processed.CAPoliciesApplied = $caPolicies
            }

            $processedSignIns += $processed
            Write-Log -LogFile $LogFile -Module $functionName -Message "Processed sign-in event: Success=$($processed.SignInSucceeded), IP=$($processed.IPAddress), CA=$($processed.ConditionalAccessStatus)" -LogLevel "Verbose"
        }

        $returnObject.Success = $true
        $returnObject.SignIns = $processedSignIns
        $returnObject.LatestSignIn = $processedSignIns[0]
        $returnObject.Message = "Retrieved $($processedSignIns.Count) sign-in events for user $UserPrincipalName."

        # Log analysis summary
        $successCount = @($processedSignIns | Where-Object { $_.SignInSucceeded -eq $true }).Count
        $failureCount = @($processedSignIns | Where-Object { $_.SignInSucceeded -eq $false }).Count
        $caBlockCount = @($processedSignIns | Where-Object { $_.CABlockedByPolicy -eq $true }).Count
        Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in summary: $successCount succeeded, $failureCount failed, $caBlockCount blocked by CA policy" -LogLevel "Information"

        # If enrichment mode, format for report inclusion
        if ($EnrichmentOnly)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Generating enrichment data for report" -LogLevel "Verbose"
            $enrichmentData = ConvertTo-SignInEnrichmentData -SignInData $returnObject
            Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in enrichment data generated successfully" -LogLevel "Information"
            return $enrichmentData
        }

        Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in activity retrieval completed successfully" -LogLevel "Information"
        return $returnObject
    }
    catch
    {
        $returnObject.Message = "Error retrieving sign-in activity: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message $returnObject.Message -LogLevel "Error"

        if ($EnrichmentOnly)
        {
            return @{ SignInLatestStatus = "Error retrieving sign-in data" }
        }
        return $returnObject
    }
}

function ConvertTo-SignInEnrichmentData()
{
    <#
    .SYNOPSIS
    Converts sign-in data into formatted enrichment properties for reports.

    .DESCRIPTION
    Helper function that transforms the structured sign-in data from Get-SignInActivity
    into a flat hashtable of formatted properties suitable for inclusion in
    autopilot enrollment reports.

    .PARAMETER SignInData
    The sign-in data object returned from Get-SignInActivity (full mode).

    .OUTPUTS
    System.Collections.Hashtable
    Returns enrichment properties: SignInLatest*, SignInConditionalAccess*, SignInRecent*

    .NOTES
    Internal helper function used by Get-SignInActivity.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SignInData
    )

    $functionName = $MyInvocation.MyCommand.Name
    $enrichmentData = @{}

    if ($SignInData.Success -and $SignInData.LatestSignIn)
    {
        $latest = $SignInData.LatestSignIn

        # Build location string
        $locationParts = @()
        if ($latest.LocationCity)
        {
            $locationParts += $latest.LocationCity
        }
        if ($latest.LocationState)
        {
            $locationParts += $latest.LocationState
        }
        if ($latest.LocationCountryOrRegion)
        {
            $locationParts += $latest.LocationCountryOrRegion
        }
        $locationStr = if ($locationParts.Count -gt 0)
        {
            $locationParts -join ", "
        }
        else
        {
            "N/A"
        }

        # Build conditional access summary
        $caStatus = if ($latest.ConditionalAccessStatus)
        {
            $latest.ConditionalAccessStatus
        }
        else
        {
            "N/A"
        }

        $caPolicySummary = "None"
        if ($latest.CAPoliciesApplied -and $latest.CAPoliciesApplied.Count -gt 0)
        {
            $policyNames = @()
            foreach ($policy in $latest.CAPoliciesApplied)
            {
                $policyEntry = "$($policy.PolicyName) ($($policy.Result))"
                $policyNames += $policyEntry
            }
            $caPolicySummary = $policyNames -join "; "
        }

        # Build sign-in pattern summary
        $totalSignIns = $SignInData.SignIns.Count
        $successCount = @($SignInData.SignIns | Where-Object { $_.SignInSucceeded -eq $true }).Count
        $failureCount = @($SignInData.SignIns | Where-Object { $_.SignInSucceeded -eq $false }).Count
        $caBlockCount = @($SignInData.SignIns | Where-Object { $_.CABlockedByPolicy -eq $true }).Count

        $analysisSummary = "$successCount of $totalSignIns succeeded"
        if ($failureCount -gt 0)
        {
            $analysisSummary += ", $failureCount failed"
        }
        if ($caBlockCount -gt 0)
        {
            $analysisSummary += ", $caBlockCount blocked by CA"
        }

        # Collect unique failure reasons
        $failureReasons = @()
        foreach ($signIn in $SignInData.SignIns)
        {
            if ($signIn.SignInSucceeded -eq $false -and $signIn.FailureReason)
            {
                if ($failureReasons -notcontains $signIn.FailureReason)
                {
                    $failureReasons += $signIn.FailureReason
                }
            }
        }
        $failureReasonSummary = if ($failureReasons.Count -gt 0)
        {
            $failureReasons -join "; "
        }
        else
        {
            "N/A"
        }

        # Populate enrichment data
        $enrichmentData['SignInLatestDateTime'] = if ($latest.CreatedDateTime)
        {
            $latest.CreatedDateTime | FormatDateWithTimeZone
        }
        else
        {
            "N/A"
        }
        $enrichmentData['SignInLatestStatus'] = if ($latest.SignInSucceeded)
        {
            "Success"
        }
        else
        {
            "Failed"
        }
        $enrichmentData['SignInLatestIPAddress'] = if ($latest.IPAddress)
        {
            $latest.IPAddress
        }
        else
        {
            "N/A"
        }
        $enrichmentData['SignInLatestLocation'] = $locationStr
        $enrichmentData['SignInLatestAppUsed'] = if ($latest.AppDisplayName)
        {
            $latest.AppDisplayName
        }
        else
        {
            "N/A"
        }
        $enrichmentData['SignInLatestFailureReason'] = if (-not $latest.SignInSucceeded -and $latest.FailureReason)
        {
            $latest.FailureReason
        }
        else
        {
            "N/A"
        }
        $enrichmentData['SignInConditionalAccessStatus'] = $caStatus
        $enrichmentData['SignInConditionalAccessPolicies'] = $caPolicySummary
        $enrichmentData['SignInRecentPattern'] = $analysisSummary
        $enrichmentData['SignInRecentFailureReasons'] = $failureReasonSummary

        Write-Log -LogFile $LogFile -Module $functionName -Message "Enrichment data created. Pattern: $analysisSummary" -LogLevel "Verbose"
    }
    else
    {
        # No sign-in data available
        $enrichmentData['SignInLatestStatus'] = "No sign-in data available"
        $enrichmentData['SignInRecentPattern'] = $SignInData.Message
        $enrichmentData['SignInLatestDateTime'] = "N/A"
        $enrichmentData['SignInLatestIPAddress'] = "N/A"
        $enrichmentData['SignInLatestLocation'] = "N/A"
        $enrichmentData['SignInLatestAppUsed'] = "N/A"
        $enrichmentData['SignInLatestFailureReason'] = "N/A"
        $enrichmentData['SignInConditionalAccessStatus'] = "N/A"
        $enrichmentData['SignInConditionalAccessPolicies'] = "None"
        $enrichmentData['SignInRecentFailureReasons'] = "N/A"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No sign-in data available: $($SignInData.Message)" -LogLevel "Information"
    }

    return $enrichmentData
}

# Legacy wrapper for backward compatibility (deprecated)
function Get-UserSignInActivity()
{
    <#
    .SYNOPSIS
    [DEPRECATED] Legacy wrapper for Get-SignInActivity.

    .DESCRIPTION
    This function is deprecated and maintained only for backward compatibility.
    Use Get-SignInActivity instead.

    .NOTES
    This function will be removed in a future version.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,

        [Parameter(Mandatory = $true)]
        [string]$userPrincipalName,

        [Parameter(Mandatory = $false)]
        [int]$maxResults = 5,

        [Parameter(Mandatory = $false)]
        [int]$daysBack = 30
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "DEPRECATED: Get-UserSignInActivity called. Use Get-SignInActivity instead." -LogLevel "Warning"

    return Get-SignInActivity -UserPrincipalName $userPrincipalName `
        -AccessToken $accessToken `
        -MaxResults $maxResults `
        -DaysBack $daysBack
}

