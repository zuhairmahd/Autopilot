function Initialize-RepoInfo()
{
    <#
    .SYNOPSIS
        Processes repository information configuration from settings file.
    
    .DESCRIPTION
        Validates and processes repository information from the configuration file,
        merging with defaults from Get-ApplicationDefaults. Supports both top-level
        repoInfo and globalSettings.repoInfo locations for backward compatibility.
    
    .PARAMETER RepoInfoData
        Repository information hashtable from settings.psd1 (can be from top-level or globalSettings).
    
    .PARAMETER BoundParameters
        Hashtable of command-line parameters to preserve overrides.
    
    .OUTPUTS
        Hashtable containing:
        - RepoInfo: Merged repository information hashtable
        - Changed: Boolean indicating whether missing keys were merged from defaults
    
    .EXAMPLE
        $repoResult = Initialize-RepoInfo -RepoInfoData $initFileContent.repoInfo -BoundParameters $PSBoundParameters
        $repoInfo = $repoResult.RepoInfo
    #>
    [CmdletBinding()]
    param(
        $RepoInfoData,
        [hashtable]$BoundParameters = @{}
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $logFile -module $functionName -Message "Initializing repository information" -logLevel "Information"
    Write-Verbose "[$functionName] Initializing repository information"
    
    $repoInfo = @{}
    
    if ($null -eq $RepoInfoData)
    {
        Write-Log -logFile $logFile -module $functionName -Message "No repository information found in configuration, using defaults" -logLevel "Verbose"
        Write-Verbose "[$functionName] No repository information found in configuration, using defaults"
        
        # Get defaults and return
        try
        {
            $defaultRepoInfo = Get-ApplicationDefaults -DefaultType 'repoInfo'
            return @{ RepoInfo = $defaultRepoInfo; Changed = $true }
        }
        catch
        {
            Write-Warning "[$functionName] Error getting default repository information: $($_.Exception.Message)"
            Write-Log -logFile $logFile -module $functionName -Message "Error getting default repository information: $($_.Exception.Message)" -logLevel "Warning"
            return @{ RepoInfo = @{}; Changed = $false }
        }
    }
    
    Write-Verbose "[$functionName] Processing repository information configuration"
    Write-Log -logFile $logFile -module $functionName -Message "Processing repository information configuration" -logLevel "Verbose"
    
    # Get defaults for merging
    $repoDefaults = Get-ApplicationDefaults -DefaultType 'repoInfo'
    
    # Process each key from defaults, preferring loaded values
    foreach ($key in $repoDefaults.Keys)
    {
        # Command-line parameter takes highest priority
        if ($BoundParameters.ContainsKey($key))
        {
            $repoInfo[$key] = $BoundParameters[$key]
            Write-Verbose "[$functionName] Using command-line override for $key"
            Write-Log -logFile $logFile -module $functionName -Message "Using command-line override for $key" -logLevel "Verbose"
        }
        # Then loaded configuration value
        elseif ($null -ne $RepoInfoData -and $RepoInfoData -is [System.Collections.IDictionary])
        {
            if ($RepoInfoData.Contains($key) -and $null -ne $RepoInfoData[$key] -and $RepoInfoData[$key] -ne '')
            {
                $repoInfo[$key] = $RepoInfoData[$key]
                Write-Verbose "[$functionName] Using loaded value for $key"
                Write-Log -logFile $logFile -module $functionName -Message "Using loaded value for $key`: $($RepoInfoData[$key])" -logLevel "Verbose"
            }
            else
            {
                # Fall back to default
                $repoInfo[$key] = $repoDefaults[$key]
                Write-Verbose "[$functionName] Using default value for $key"
                Write-Log -logFile $logFile -module $functionName -Message "Using default value for $key`: $($repoDefaults[$key])" -logLevel "Verbose"
            }
        }
        else
        {
            # Fall back to default if RepoInfoData is not a dictionary
            $repoInfo[$key] = $repoDefaults[$key]
            Write-Verbose "[$functionName] Using default value for $key (RepoInfoData not a dictionary)"
            Write-Log -logFile $logFile -module $functionName -Message "Using default value for $key`: $($repoDefaults[$key])" -logLevel "Verbose"
        }
    }
    
    # Check if we added any missing keys (changed = true if any defaults were used)
    $changesMade = $false
    if ($null -ne $RepoInfoData -and $RepoInfoData -is [System.Collections.IDictionary])
    {
        foreach ($key in $repoDefaults.Keys)
        {
            if (-not $RepoInfoData.Contains($key) -or $null -eq $RepoInfoData[$key] -or $RepoInfoData[$key] -eq '')
            {
                $changesMade = $true
                break
            }
        }
    }
    else
    {
        $changesMade = $true
    }
    
    Write-Verbose "[$functionName] Repository information processed (Changed: $changesMade)"
    Write-Log -logFile $logFile -module $functionName -Message "Repository information processed: Path=$($repoInfo.repoPath), Name=$($repoInfo.repoName) (Changed: $changesMade)" -logLevel "Information"
    
    return @{ RepoInfo = $repoInfo; Changed = $changesMade }
}
