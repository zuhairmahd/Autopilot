function Test-ResourcePlatformMatch()
{
    [CmdletBinding()                                        ]
    param(
        [Parameter(Mandatory = $true)]
        $Resource,
        [Parameter(Mandatory = $false)]
        [string]$TargetOS
    )
    $functionName = $MyInvocation.MyCommand.Name                                
    Write-Verbose "[$functionName] Target OS: $TargetOS"
    write-log -logFile $logFile -module $functionName -message "Target OS: $TargetOS"
    # If no target OS specified, include all resources
    if ([string]::IsNullOrWhiteSpace($TargetOS))
    {
        write-log -logFile $logFile -module $functionName -message "No Target OS specified, including all resources."                   
        return $true
    }
        
    # Get the @odata.type if available
    $odataType = if ($Resource.'@odata.type') { $Resource.'@odata.type'.ToLower() } else { '' }
    Write-Verbose "[$functionName] Resource @odata.type: $odataType"        
    write-log -logFile $logFile -module $functionName -message "Resource @odata.type: $odataType"                   
    # Platform matching logic based on @odata.type
    switch ($TargetOS.ToLower())
    {
        'windows'
        {
            # Match Windows-specific types
            write-log -logFile $logFile -module $functionName -message "Checking for Windows platform match."
            return ($odataType -match 'windows|win32|msi|intunewin|officeSuiteApp')
        }
        'ios'
        {
            # Match iOS-specific types
            write-log -logFile $logFile -module $functionName -message "Checking for iOS platform match."                                               
            return ($odataType -match 'ios(?!.*mac)')
        }
        'android'
        {
            # Match Android-specific types  
            write-log -logFile $logFile -module $functionName -message "Checking for Android platform match."                           
            return ($odataType -match 'android')
        }
        'macos'
        {
            # Match macOS-specific types
            write-log -logFile $logFile -module $functionName -message "Checking for macOS platform match."                                 
            return ($odataType -match 'macos|macOSLobApp|macOSOfficeApp')
        }
        'linux'
        {
            # Match Linux-specific types (rare but possible)
            write-log -logFile $logFile -module $functionName -message "Checking for Linux platform match."                                                 
            return ($odataType -match 'linux')
        }
        default
        {
            # Unknown OS - include all
            write-log -logFile $logFile -module $functionName -message "Unknown Target OS specified, including all resources."                                              
            return $true
        }
    }
}
