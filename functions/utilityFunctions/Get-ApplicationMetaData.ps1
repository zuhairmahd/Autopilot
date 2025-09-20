function Get-ApplicationMetaData()
{
    [CmdletBinding()]
    param (
        [string]$GlobalSettingsFile = "$pwd\settings.psd1",
        [string]$domain
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
            $globalSettings = Import-PowerShellDataFile -Path $GlobalSettingsFile
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
    if (-not $globalSettings -and -not $domainSettings)
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
        else
        {
            $null 
        }
        version     = if ($domainSettings.version)
        {
            $domainSettings.version 
        }
        elseif ($globalSettings.version)
        {
            $globalSettings.version 
        }
        else
        {
            $null 
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
    }
    Write-Verbose "[$functionName] Application metadata for domain '$($domainSettings.domain)' retrieved successfully."
    Write-Log -logFile $logFile -module $functionName -Message "Application metadata for domain '$($domainSettings.domain)' retrieved successfully."
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