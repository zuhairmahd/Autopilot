function Test-UserGroupMembership()
{
    <#
    .SYNOPSIS
        Validates user group membership requirements.
    
    .DESCRIPTION
        Checks if a user is a member of all required groups and not a member of any forbidden groups.
        Returns detailed information about membership status with suggested resolutions.
    
    .PARAMETER UserName
        The user principal name (email address) of the user to check.
    
    .PARAMETER AccessToken
        Microsoft Graph API access token for authentication.
    
    .PARAMETER GroupsToInclude
        Array of groups that the user must be a member of.
    
    .PARAMETER GroupsToExclude
        Array of groups that the user must not be a member of.
    
    .OUTPUTS
        Returns a PSCustomObject representing the check result with properties:
        - CheckName: Name of the check
        - Passed: Boolean indicating if check passed
        - Severity: "Error" or "Warning"
        - Message: Description of the result
        - Details: Additional information
        - SuggestedResolution: Steps to resolve if check failed
        - UserDisplayName: User's display name (if available)
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
        $GroupsToExclude
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking group membership for user: $UserName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Checking group membership for user: $UserName" -LogLevel Verbose
    
    # Initialize check result
    $checkResult = [PSCustomObject]@{
        CheckName           = "Group Membership"
        Passed              = $false
        Severity            = "Error"
        Message             = ""
        Details             = @()
        SuggestedResolution = ""
        UserDisplayName     = ""
    }
    
    try
    {
        # Call the existing VerifyGroupMembership function
        $groups = VerifyGroupMembership -AccessToken $AccessToken -userName $UserName -groupsToInclude $GroupsToInclude -groupsToExclude $GroupsToExclude
        
        # Extract user display name if available
        if ($groups.UserInfo -and $groups.UserInfo.displayName)
        {
            $checkResult.UserDisplayName = $groups.UserInfo.displayName
        }
        
        if ($groups.success -eq $true)
        {
            $checkResult.Passed = $true
            $requiredCount = if ($GroupsToInclude)
            {
                $GroupsToInclude.Count 
            }
            else
            {
                0 
            }
            $forbiddenCount = if ($GroupsToExclude)
            {
                $GroupsToExclude.Count 
            }
            else
            {
                0 
            }
            $checkResult.Message = "User has correct group memberships"
            $checkResult.Details += "Member of all $requiredCount required groups"
            $checkResult.Details += "Not a member of any of the $forbiddenCount forbidden groups"
        }
        else
        {
            $checkResult.Passed = $false
            $issues = @()
            $resolutions = @()
            
            if ($groups.MissingGroups.Count -gt 0)
            {
                $checkResult.Message = "User is missing required group memberships"
                $checkResult.Details += "Missing groups:"
                foreach ($group in $groups.MissingGroups)
                {
                    $checkResult.Details += "  - $group"
                    $issues += "Missing membership in group: $group"
                }
                $resolutions += "Add user to the following groups: $($groups.MissingGroups -join ', ')"
            }
            
            if ($groups.ForbiddenGroups.Count -gt 0)
            {
                if (-not $checkResult.Message)
                {
                    $checkResult.Message = "User is a member of forbidden groups"
                }
                else
                {
                    $checkResult.Message = "User has missing and forbidden group memberships"
                }
                $checkResult.Details += "Forbidden group memberships:"
                foreach ($group in $groups.ForbiddenGroups)
                {
                    $checkResult.Details += "  - $group"
                    $issues += "Member of forbidden group: $group"
                }
                $resolutions += "Remove user from the following groups: $($groups.ForbiddenGroups -join ', ')"
            }
            
            $checkResult.SuggestedResolution = ($resolutions -join "; ") + ". Contact an Intune administrator for assistance."
        }
    }
    catch
    {
        $checkResult.Passed = $false
        $checkResult.Message = "Error checking group membership"
        $checkResult.Details += "Exception: $($_.Exception.Message)"
        $checkResult.SuggestedResolution = "Verify network connectivity and Graph API permissions. Contact support if issue persists."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error checking group membership: $($_.Exception.Message)" -LogLevel Error
    }
    
    Write-Verbose "[$functionName] Group membership check completed. Passed: $($checkResult.Passed)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Group membership check completed for $UserName. Passed: $($checkResult.Passed)" -LogLevel Verbose
    
    return $checkResult
}
