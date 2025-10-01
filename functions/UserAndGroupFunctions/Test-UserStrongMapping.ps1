function Test-UserStrongMapping()
{
    <#
    .SYNOPSIS
        Validates that a user has strong certificate mapping enabled.
    
    .DESCRIPTION
        Checks if a user has strong certificate mapping configured with valid certificates.
        Respects the strongMappingOptional setting to determine if this is a warning or error.
    
    .PARAMETER UserName
        The user principal name (email address) of the user to check.
    
    .PARAMETER AccessToken
        Microsoft Graph API access token for authentication.
    
    .PARAMETER Settings
        Hashtable containing application settings including strongMappingOptional.
    
    .OUTPUTS
        Returns a PSCustomObject representing the check result with properties:
        - CheckName: Name of the check
        - Passed: Boolean indicating if check passed
        - Severity: "Error" or "Warning"
        - Message: Description of the result
        - Details: Additional information
        - SuggestedResolution: Steps to resolve if check failed
        - CertificateCount: Number of certificates found
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
    Write-Verbose "[$functionName] Checking strong certificate mapping for user: $UserName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Checking strong certificate mapping for user: $UserName" -LogLevel Verbose
    
    # Initialize check result
    $checkResult = [PSCustomObject]@{
        CheckName           = "Strong Certificate Mapping"
        Passed              = $false
        Severity            = if ($Settings.strongMappingOptional)
        {
            "Warning" 
        }
        else
        {
            "Error" 
        }
        Message             = ""
        Details             = @()
        SuggestedResolution = ""
        CertificateCount    = 0
    }
    
    try
    {
        # Get strong mapping information
        $strongMappingInfo = Get-UserStrongMapping -accessToken $AccessToken -UserName $UserName
        
        $mappingStatus = $strongMappingInfo.StrongMapping
        $certCount = $strongMappingInfo.CertificateCount
        Write-Verbose "[$functionName] Strong mapping info - StrongMapping=$mappingStatus, CertCount=$certCount"
        $logMessage = "Strong mapping check for user $UserName - StrongMapping=$mappingStatus, CertCount=$certCount"
        Write-Log -LogFile $LogFile -Module $functionName -Message $logMessage -LogLevel Verbose
        
        $checkResult.CertificateCount = $strongMappingInfo.CertificateCount
        
        if ($strongMappingInfo.StrongMapping)
        {
            $checkResult.Passed = $true
            $checkResult.Message = "User has strong certificate mapping enabled"
            $checkResult.Details += "Certificates configured: $($strongMappingInfo.CertificateCount)"
            
            foreach ($cert in $strongMappingInfo.Certificates)
            {
                $checkResult.Details += "Certificate: $cert"
            }
        }
        else
        {
            # User does not have strong mapping
            if ($Settings.strongMappingOptional)
            {
                # Optional - treat as warning but allow to proceed
                $checkResult.Passed = $true
                $checkResult.Severity = "Warning"
                $checkResult.Message = "User does not have strong certificate mapping (optional)"
                $checkResult.Details += "Strong mapping is recommended but not required"
                $checkResult.Details += "User may experience issues connecting to network resources"
                $checkResult.SuggestedResolution = "Open a ticket to enable strong certificate mapping for this user to improve security and network connectivity."
            }
            else
            {
                # Required - treat as error and block
                $checkResult.Passed = $false
                $checkResult.Severity = "Error"
                $checkResult.Message = "User does not have strong certificate mapping (required)"
                $checkResult.Details += "Strong mapping is required by organization policy"
                $checkResult.Details += "No certificates found for user"
                $checkResult.SuggestedResolution = "Enable strong certificate mapping for this user before assigning a device. Contact an Intune administrator for assistance."
            }
        }
    }
    catch
    {
        $checkResult.Passed = $false
        $checkResult.Severity = "Error"
        $checkResult.Message = "Error checking strong certificate mapping"
        $checkResult.Details += "Exception: $($_.Exception.Message)"
        $checkResult.SuggestedResolution = "Verify network connectivity and Graph API permissions. Contact support if issue persists."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error checking strong mapping: $($_.Exception.Message)" -LogLevel Error
    }
    
    Write-Verbose "[$functionName] Strong mapping check completed. Passed: $($checkResult.Passed), Severity: $($checkResult.Severity)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Strong mapping check completed for $UserName. Passed: $($checkResult.Passed), Severity: $($checkResult.Severity)" -LogLevel Verbose
    
    return $checkResult
}
