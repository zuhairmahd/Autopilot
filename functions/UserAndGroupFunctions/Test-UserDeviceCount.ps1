function Test-UserDeviceCount()
{
    <#
    .SYNOPSIS
        Validates that a user has not exceeded the maximum allowed device count.
    
    .DESCRIPTION
        Checks the number of devices registered to a user against the configured maximum.
        Returns detailed information about current device count and limit.
    
    .PARAMETER UserName
        The user principal name (email address) of the user to check.
    
    .PARAMETER AccessToken
        Microsoft Graph API access token for authentication.
    
    .PARAMETER Settings
        Hashtable containing application settings including maxNumberOfDevicesAllowed.
    
    .OUTPUTS
        Returns a PSCustomObject representing the check result with properties:
        - CheckName: Name of the check
        - Passed: Boolean indicating if check passed
        - Severity: "Error" or "Warning"
        - Message: Description of the result
        - Details: Additional information
        - SuggestedResolution: Steps to resolve if check failed
        - CurrentCount: Current number of devices
        - MaxAllowed: Maximum allowed devices
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking device count for user: $UserName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Checking device count for user: $UserName" -LogLevel Verbose
    
    # Initialize check result
    $checkResult = [PSCustomObject]@{
        CheckName           = "Device Count Limit"
        Passed              = $false
        Severity            = "Error"
        Message             = ""
        Details             = @()
        SuggestedResolution = ""
        CurrentCount        = 0
        MaxAllowed          = $Settings.maxNumberOfDevicesAllowed
    }
    
    try
    {
        # Get current device count
        $totalDevices = GetTotalRegisteredDevicesByUser -Username $UserName -AccessToken $AccessToken
        $checkResult.CurrentCount = $totalDevices
        
        Write-Verbose "[$functionName] User has $totalDevices devices, limit is $($Settings.maxNumberOfDevicesAllowed)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User $UserName has $totalDevices devices, limit is $($Settings.maxNumberOfDevicesAllowed)" -LogLevel Verbose
        
        if ($totalDevices -lt $Settings.maxNumberOfDevicesAllowed)
        {
            $checkResult.Passed = $true
            $checkResult.Message = "User is below device limit"
            $checkResult.Details += "Current devices: $totalDevices"
            $checkResult.Details += "Maximum allowed: $($Settings.maxNumberOfDevicesAllowed)"
            $checkResult.Details += "Available slots: $($Settings.maxNumberOfDevicesAllowed - $totalDevices)"
        }
        else
        {
            $checkResult.Passed = $false
            $checkResult.Message = "User has reached or exceeded device limit"
            $checkResult.Details += "Current devices: $totalDevices"
            $checkResult.Details += "Maximum allowed: $($Settings.maxNumberOfDevicesAllowed)"
            $checkResult.Details += "No additional devices can be assigned"
            $checkResult.SuggestedResolution = "Remove unused or old devices from the user's account, or request a device limit increase from an Intune administrator."
        }
    }
    catch
    {
        $checkResult.Passed = $false
        $checkResult.Message = "Error retrieving device count"
        $checkResult.Details += "Exception: $($_.Exception.Message)"
        $checkResult.SuggestedResolution = "Verify network connectivity and Graph API permissions. Contact support if issue persists."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error checking device count: $($_.Exception.Message)" -LogLevel Error
    }
    
    Write-Verbose "[$functionName] Device count check completed. Passed: $($checkResult.Passed)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Device count check completed for $UserName. Passed: $($checkResult.Passed)" -LogLevel Verbose
    
    return $checkResult
}
