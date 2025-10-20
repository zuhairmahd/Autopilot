function Get-ApplicationMetaData()
{
    [CmdletBinding()]
    param (
        [string]$GlobalSettingsFile = "$pwd\settings.psd1",
        [string]$scriptPath,
        $scriptName,
        [string]$domain,
        [switch]$Silent
    )

    $functionName = $MyInvocation.MyCommand.Name
    if (-not $domain)
    {
        Write-Verbose "[$functionName] No domain specified. Attempting to infer from context."
        Write-Log -logFile $logFile -module $functionName -Message "No domain specified. Attempting to infer from context." -logLevel 'Error'
        $domainPattern = '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+\.psd1$'
        Write-Verbose "[$functionName] Looking for domain settings file in: $pwd"
        Write-Log -logFile $logFile -module $functionName -Message "Looking for domain settings file in: $pwd"
        # Use -ErrorAction SilentlyContinue to avoid errors if directory is inaccessible for any reason
        $domainsSettingsFiles = Get-ChildItem -Path $pwd -File -Filter *.psd1 -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $domainPattern }
        Write-Verbose "[$functionName] Found $($domainsSettingsFiles.count) domain settings files."
        Write-Log -logFile $logFile -module $functionName -Message "Found $($domainsSettingsFiles.count) domain settings files."
        if ($domainsSettingsFiles -and $domainsSettingsFiles.count -eq 1)
        {
            Write-Verbose "[$functionName] Found $($domainsSettingsFiles.count) domain settings files."
            Write-Log -logFile $logFile -module $functionName -Message "Found $($domainsSettingsFiles.count) domain settings files"
            $domainSettingsFile = $domainsSettingsFiles | Select-Object -First 1
        }
        elseif ($domainsSettingsFiles -and $domainsSettingsFiles.count -gt 1)
        {
            Write-Verbose "[$functionName] Found multiple domain settings files."
            Write-Log -logFile $logFile -module $functionName -Message "Found multiple domain settings files."
            if (-not $Silent)
            {
                Write-Host "Multiple domain settings files found."
                for ($i = 0; $i -lt $domainsSettingsFiles.Count; $i++)
                {
                    $list += @( ($domainsSettingsFiles[$i].Name) -replace '.psd1', '' )
                    Write-Verbose "[$functionName] $($domainsSettingsFiles[$i].Name)"
                }
                $result = DisplayNumericMenu -choices $list -banner "Please choose a domain" -Prompt "Choose the correct number and press enter" -RequireEnter
                Write-Verbose "[$functionName] User selected domain settings file: $($domainSettingsFile.Name)"
                if ($result -eq 0)
                {
                    Write-Verbose "[$functionName] User cancelled the selection."
                    Write-Log -logFile $logFile -module $functionName -Message "User cancelled the selection."
                    return $null
                }
                else
                {
                    $domainSettingsFile = "$result.psd1"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Silent mode enabled. Choosing the first found domain."
                Write-Log -logFile $logFile -module $functionName -Message "Silent mode enabled. Choosing the first found domain."  
                $domainSettingsFile = $domainsSettingsFiles | Select-Object -First 1    
            }
        }
        else 
        {
            Write-Verbose "[$functionName] No domain settings files found."
            Write-Log -logFile $logFile -module $functionName -Message "No domain settings files found."
        }
    }
    Write-Verbose "[$functionName] Domain settings file determined: $domainSettingsFile"
    if ($domainSettingsFile)
    {
        Write-Verbose "[$functionName] Loading domain settings from: $domainSettingsFile"
        Write-Log -logFile $logFile -module $functionName -Message "Loading domain settings from: $domainSettingsFile"
        try
        {
            $domainSettings = Import-PowerShellDataFile -Path $domainSettingsFile
            Write-Verbose "[$functionName] Successfully loaded domain settings."
            Write-Log -logFile $logFile -module $functionName -Message "Successfully loaded domain settings."
        }
        catch
        {
            Write-Verbose "[$functionName] Error reading domain settings file: $domainSettingsFile"
            Write-Log -logFile $logFile -module $functionName -Message "Error reading domain settings file: $domainSettingsFile" -logLevel 'Error'
        }
    }
    else
    {
        Write-Verbose "[$functionName] A domain settings file for domain '$domain' could not be determined."
        Write-Log -logFile $logFile -module $functionName -Message "A domain settings file for domain '$domain' could not be determined."
    }
    if ($GlobalSettingsFile)
    {
        Write-Verbose "[$functionName] Loading global settings from: $GlobalSettingsFile"
        Write-Log -logFile $logFile -module $functionName -Message "Loading global settings from: $GlobalSettingsFile"
        try
        {
            $globalSettings = Import-PowerShellDataFile -Path $GlobalSettingsFile -ErrorAction SilentlyContinue
            Write-Verbose "[$functionName] Successfully loaded global settings."
            Write-Log -logFile $logFile -module $functionName -Message "Successfully loaded global settings."
        }
        catch
        {
            Write-Verbose "[$functionName] Error reading global settings file: $GlobalSettingsFile"
            Write-Log -logFile $logFile -module $functionName -Message "Error reading global settings file: $GlobalSettingsFile" -logLevel 'Error'
        }
    }
    else
    {
        Write-Verbose "[$functionName] No global settings file specified."
        Write-Log -logFile $logFile -module $functionName -Message "No global settings file specified."
    }
    
    #Get the version.  Check if the script name exists
    if ($scriptName -and $scriptName.endswith('.ps1'))
    {
        $scriptName = $scriptName -replace '\.ps1$', '.exe'
    }
    Write-Verbose "[$functionName] Retrieving file version for script: $scriptName"
    Write-Log -logFile $logFile -module $functionName -Message "Retrieving file version for script: $scriptName"
    if ($scriptName -and (Test-Path $scriptName))
    {
        Write-Verbose "[$functionName] Executable file exists: $scriptName. Getting version."
        Write-Log -logFile $logFile -module $functionName -Message "Script file exists: $scriptName. Getting version."
        $fileVersionInfo = getFileVersion -executableFileName $scriptName
    }    
    if ($null -eq $fileVersionInfo)
    {
        Write-Verbose "[$functionName] Could not retrieve version information for script: $scriptName.  Let us check lastrun.json"
        Write-Log -logFile $logFile -module $functionName -Message "Could not retrieve version information for script: $scriptName" -logLevel 'Error'
        if (Test-Path "$scriptPath\lastrun.json")
        {
            Write-Verbose "[$functionName] lastrun.json found. Attempting to read version from it."
            Write-Log -logFile $logFile -module $functionName -Message "lastrun.json found. Attempting to read version from it."
            try
            {
                $lastrunData = Get-Content "$pwd\lastrun.json" | ConvertFrom-Json
                if ($lastrunData.version)
                {
                    $fileVersionInfo = @{
                        version     = $lastrunData.version
                        companyName = $null
                    }
                    Write-Verbose "[$functionName] Successfully retrieved version information from lastrun.json."
                    Write-Log -logFile $logFile -module $functionName -Message "Successfully retrieved version information from lastrun.json."
                }
                else
                {
                    Write-Verbose "[$functionName] No version information found in lastrun.json."
                    Write-Log -logFile $logFile -module $functionName -Message "No version information found in lastrun.json." -logLevel 'Error'
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Error reading lastrun.json: $($_.Exception.Message)"
                Write-Log -logFile $logFile -module $functionName -Message "Error reading lastrun.json: $($_.Exception.Message)" -logLevel 'Error'
            }
        }                           
    }
    
    if (-not $globalSettings -and -not $domainSettings -and -not $fileVersionInfo)
    {
        Write-Verbose "[$functionName] No settings files could be loaded. Cannot retrieve application metadata."
        Write-Log -logFile $logFile -module $functionName -Message "No settings files could be loaded. Cannot retrieve application metadata." -logLevel "Error"
        return $null
    }
    
    $appMetaData = @{
        companyName = if ($domainSettings.companyName)
        {
            $domainSettings.companyName  
        }
        elseif ($globalSettings.companyName)
        {
            $globalSettings.companyName 
        }
        elseif ($fileVersionInfo.companyName)
        {
            $fileVersionInfo.companyName
        }
        else
        {
            'Zuhair Mahmoud'
        }
        version     = if ($fileVersionInfo.version)
        {
            [version]$fileVersionInfo.version
        }
        elseif ($domainSettings.version)
        {
            [version]$domainSettings.version 
        }
        elseif ($globalSettings.version)
        {
            [version]$globalSettings.version 
        }
        else
        {
            [version]"1.0.0.0"
        }
        release     = if ($domainSettings.release)
        {
            $domainSettings.release 
        }
        elseif ($globalSettings.release)
        {
            $globalSettings.release 
        }
        else
        {
            $null 
        }
        domain      = if ($domainSettings.domain)
        {
            $domainSettings.domain 
        }
    }
    #print verbose all the values that are not null.
    foreach ($key in $appMetaData.Keys)
    {
        if ($null -ne $appMetaData[$key])
        {
            Write-Verbose "[$functionName] $($key): $($appMetaData[$key])"
            Write-Log -logFile $logFile -module $functionName -Message "$($key): $($appMetaData[$key])"
        }
    }
    return $appMetaData
}