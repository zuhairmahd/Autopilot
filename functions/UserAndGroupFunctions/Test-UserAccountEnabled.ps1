function Test-UserAccountEnabled()
{
    <#
    .SYNOPSIS
        Validates that a user account is enabled in Entra ID.
    
    .DESCRIPTION
        Checks if a user's account is enabled in Entra ID. A disabled account will fail
        the user readiness check and prevent device assignment. Returns detailed information
        about the account status.
    
    .PARAMETER UserName
        The user principal name (email address) of the user to check.
    
    .PARAMETER AccessToken
        Microsoft Graph API access token for authentication.
    
    .OUTPUTS
        Returns a PSCustomObject representing the check result with properties:
        - CheckName: Name of the check
        - Passed: Boolean indicating if check passed
        - Severity: "Error", "Warning", or "Information"
        - Message: Description of the result
        - Details: Additional information
        - SuggestedResolution: Steps to resolve if check failed
        - AccountEnabled: Boolean indicating if account is enabled
    
    .EXAMPLE
        $result = Test-UserAccountEnabled -UserName "john.doe@contoso.com" -AccessToken $token
        if ($result.Passed) {
            Write-Host "User account is enabled"
        } else {
            Write-Host "User account is disabled: $($result.Message)"
        }
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking account status for user: $UserName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Checking account status for user: $UserName" -LogLevel Verbose
    
    # Initialize check result
    $checkResult = [PSCustomObject]@{
        CheckName           = "Account Status"
        Passed              = $false
        Severity            = "Error"
        Message             = ""
        Details             = @()
        SuggestedResolution = ""
        AccountEnabled      = $false
    }
    
    try
    {
        # Query user account status
        $userUri = "users/$UserName"
        Write-Verbose "[$functionName] Querying user account status from Graph API"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Querying user account status from Graph API" -LogLevel Verbose
        
        $user = CallGraphApi -AccessToken $AccessToken -ResourcePath $userUri -extraparameters "select=accountEnabled,displayName,userPrincipalName"
        
        if ($null -eq $user)
        {
            $checkResult.Passed = $false
            $checkResult.Message = "Unable to retrieve user account information"
            $checkResult.Details += "User query returned null"
            $checkResult.SuggestedResolution = "Verify the user principal name is correct and that the Graph API token has User.Read.All permissions."
            Write-Log -LogFile $LogFile -Module $functionName -Message "User query returned null for $UserName" -LogLevel Error
            return $checkResult
        }
        
        # Check if accountEnabled property exists
        if ($null -eq $user.accountEnabled)
        {
            # If accountEnabled is null, treat as enabled (default behavior)
            Write-Verbose "[$functionName] accountEnabled property is null, treating as enabled"
            Write-Log -LogFile $LogFile -Module $functionName -Message "accountEnabled property is null for $UserName, treating as enabled" -LogLevel Warning
            $checkResult.Passed = $true
            $checkResult.AccountEnabled = $true
            $checkResult.Message = "User account status could not be determined (assumed enabled)"
            $checkResult.Details += "The accountEnabled property was not returned by Graph API"
            $checkResult.Details += "This may indicate insufficient permissions"
            $checkResult.Severity = "Warning"
        }
        elseif ($user.accountEnabled -eq $true)
        {
            $checkResult.Passed = $true
            $checkResult.AccountEnabled = $true
            $checkResult.Severity = "Information"
            $checkResult.Message = "User account is enabled"
            $checkResult.Details += "Account status: Enabled"
            $checkResult.Details += "User can be assigned a device"
            Write-Verbose "[$functionName] User account is enabled"
            Write-Log -LogFile $LogFile -Module $functionName -Message "User account $UserName is enabled" -LogLevel Verbose
        }
        else
        {
            $checkResult.Passed = $false
            $checkResult.AccountEnabled = $false
            $checkResult.Message = "User account is disabled"
            $checkResult.Details += "Account status: Disabled"
            $checkResult.Details += "Disabled accounts cannot be assigned devices"
            $checkResult.SuggestedResolution = "Enable the user account in Entra ID before assigning a device. Contact an Entra ID administrator for assistance."
            Write-Verbose "[$functionName] User account is disabled"
            Write-Log -LogFile $LogFile -Module $functionName -Message "User account $UserName is disabled" -LogLevel Warning
        }
    }
    catch
    {
        $checkResult.Passed = $false
        $checkResult.Message = "Error checking account status"
        $checkResult.Details += "Exception: $($_.Exception.Message)"
        $checkResult.SuggestedResolution = "Verify network connectivity and Graph API permissions. Contact support if issue persists."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error checking account status for $UserName : $($_.Exception.Message)" -LogLevel Error
    }
    
    Write-Verbose "[$functionName] Account status check completed. Passed: $($checkResult.Passed)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Account status check completed for $UserName. Passed: $($checkResult.Passed)" -LogLevel Verbose
    
    return $checkResult
}
