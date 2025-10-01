function Test-UserReadiness()
{
    <#
    .SYNOPSIS
        Performs comprehensive readiness checks on a user before assigning a Windows 11 device.
    
    .DESCRIPTION
        This function orchestrates multiple validation checks to determine if a user is ready to receive
        a Windows 11 device. It performs all checks regardless of individual failures and returns a 
        detailed report with all issues and suggested resolutions.
    
    .PARAMETER UserName
        The user principal name (email address) of the user to check.
    
    .PARAMETER AccessToken
        Microsoft Graph API access token for authentication.
    
    .PARAMETER GroupsToInclude
        Array of groups that the user must be a member of.
    
    .PARAMETER GroupsToExclude
        Array of groups that the user must not be a member of.
    
    .PARAMETER Settings
        Hashtable containing application settings including device limits and strong mapping options.
    
    .OUTPUTS
        Returns a PSCustomObject with the following properties:
        - IsReady: Boolean indicating if all checks passed
        - UserName: The user principal name that was checked
        - DisplayName: The user's display name
        - Checks: Array of check result objects
        - IssueCount: Total number of issues found
        - WarningCount: Total number of warnings
    
    .EXAMPLE
        $result = Test-UserReadiness -UserName "john.doe@contoso.com" -AccessToken $token -GroupsToInclude $groups -GroupsToExclude $excludedGroups -Settings $settings
        if ($result.IsReady) {
            Write-Host "User is ready to receive a device"
        } else {
            foreach ($check in $result.Checks | Where-Object { -not $_.Passed }) {
                Write-Host "Issue: $($check.Message)"
                Write-Host "Resolution: $($check.SuggestedResolution)"
            }
        }
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter()]
        $GroupsToInclude,
        
        [Parameter()]
        $GroupsToExclude,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting comprehensive user readiness check for: $UserName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting comprehensive user readiness check for: $UserName" -LogLevel Information
    
    # Initialize result object
    $result = [PSCustomObject]@{
        IsReady      = $false
        UserName     = $UserName
        DisplayName  = ""
        Checks       = @()
        IssueCount   = 0
        WarningCount = 0
    }
    
    # Track overall success
    $allChecksPassed = $true
    
    #region Check 1: Group Membership
    Write-Verbose "[$functionName] Performing group membership check..."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Performing group membership check for $UserName" -LogLevel Information
    
    $groupCheck = Test-UserGroupMembership -UserName $UserName -AccessToken $AccessToken -GroupsToInclude $GroupsToInclude -GroupsToExclude $GroupsToExclude
    $result.Checks += $groupCheck
    
    if (-not $groupCheck.Passed)
    {
        $allChecksPassed = $false
        if ($groupCheck.Severity -eq "Error")
        {
            $result.IssueCount++
        }
        else
        {
            $result.WarningCount++
        }
    }
    
    # Update display name from group check if available
    if ($groupCheck.UserDisplayName)
    {
        $result.DisplayName = $groupCheck.UserDisplayName
    }
    #endregion
    
    #region Check 2: Device Count
    Write-Verbose "[$functionName] Performing device count check..."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Performing device count check for $UserName" -LogLevel Information
    
    $deviceCountCheck = Test-UserDeviceCount -UserName $UserName -AccessToken $AccessToken -Settings $Settings
    $result.Checks += $deviceCountCheck
    
    if (-not $deviceCountCheck.Passed)
    {
        $allChecksPassed = $false
        if ($deviceCountCheck.Severity -eq "Error")
        {
            $result.IssueCount++
        }
        else
        {
            $result.WarningCount++
        }
    }
    #endregion
    
    #region Check 3: Strong Certificate Mapping (if enabled)
    if ($Settings.checkStrongMapping)
    {
        Write-Verbose "[$functionName] Performing strong certificate mapping check..."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Performing strong certificate mapping check for $UserName" -LogLevel Information
        
        $strongMappingCheck = Test-UserStrongMapping -UserName $UserName -AccessToken $AccessToken -Settings $Settings
        $result.Checks += $strongMappingCheck
        
        if (-not $strongMappingCheck.Passed)
        {
            $allChecksPassed = $false
            if ($strongMappingCheck.Severity -eq "Error")
            {
                $result.IssueCount++
            }
            else
            {
                $result.WarningCount++
            }
        }
    }
    else
    {
        Write-Verbose "[$functionName] Strong mapping check is disabled in settings"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Strong mapping check is disabled in settings" -LogLevel Verbose
    }
    #endregion
    
    # Set overall readiness status
    $result.IsReady = $allChecksPassed
    
    Write-Verbose "[$functionName] User readiness check completed. IsReady: $($result.IsReady), Issues: $($result.IssueCount), Warnings: $($result.WarningCount)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "User readiness check completed for $UserName. IsReady: $($result.IsReady), Issues: $($result.IssueCount), Warnings: $($result.WarningCount)" -LogLevel Information
    
    return $result
}
