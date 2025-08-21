function Get-ApplicationMetaDataFromDomain()
{
    [CmdletBinding()]
    param (
        [string]$domain
    )

    $functionName = $MyInvocation.MyCommand.Name
    if (-not $domain)
    {
        Write-Verbose "[$functionName] No domain specified. Attempting to infer from context."
        Write-Log -logFile $logFile -module $functionName -Message "No domain specified. Attempting to infer from context." -logLevel 'Error'
        # Domain-like filename pattern: one or more labels separated by dots, ending with .json
        # Examples that match: contoso.com.json, sub.contoso.co.uk.json
        # Examples that do NOT match: config.json, contosojson, .json
        $domainPattern = '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+\.json$'
        #Look for a file in the current folder whose matches a domain name with a json extension
        Write-Verbose "[$functionName] Looking for domain settings file in: $pwd"
        Write-Log -logFile $logFile -module $functionName -Message "Looking for domain settings file in: $pwd"
        # Enumerate only JSON files in the current directory, then filter by the domain-like pattern
        # Use -ErrorAction SilentlyContinue to avoid errors if directory is inaccessible for any reason
        $domainsSettingsFiles = Get-ChildItem -Path $pwd -File -Filter *.json -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $domainPattern }
        Write-Verbose "[$functionName] Found $($domainsSettingsFiles.count) domain settings files."
        Write-Log -logFile $logFile -module $functionName -Message "Found $($domainsSettingsFiles.count) domain settings files."
        if ($domainsSettingsFiles -and $domainsSettingsFiles.count -eq 1)
        {
            Write-Verbose "[$functionName] Found domain settings file: $domainsSettingsFiles"
            Write-Log -logFile $logFile -module $functionName -Message "Found domain settings file: $domainsSettingsFiles"
            $domainSettingsFile = $domainsSettingsFiles 
        }
        elseif ($domainsSettingsFiles.count -gt 1)
        {
            Write-Verbose "[$functionName] Found multiple domain settings files."
            Write-Log -logFile $logFile -module $functionName -Message "Found multiple domain settings files."
            $domainSettingsFile = $null
        }
        else 
        {
            Write-Verbose "[$functionName] No domain settings files found."
            Write-Log -logFile $logFile -module $functionName -Message "No domain settings files found."
            return $null
        }
    }
    Write-Verbose "[$functionName] Domain settings file determined: $domainSettingsFile"
    if ($domainSettingsFile)
    {
        Write-Verbose "[$functionName] Loading domain settings from: $domainSettingsFile"
        Write-Log -logFile $logFile -module $functionName -Message "Loading domain settings from: $domainSettingsFile"
        try
        {
            $domainSettings = (Get-Content -Path $domainSettingsFile -Raw | ConvertFrom-Json).settings.appInfo
            Write-Verbose "[$functionName] Successfully loaded domain settings."
            Write-Log -logFile $logFile -module $functionName -Message "Successfully loaded domain settings."
        }
        catch
        {
            Write-Verbose "[$functionName] Error reading domain settings file: $domainSettingsFile"
            Write-Log -logFile $logFile -module $functionName -Message "Error reading domain settings file: $domainSettingsFile" -logLevel 'Error'
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] A domain settings file for domain '$domain' could not be determined."
        Write-Log -logFile $logFile -module $functionName -Message "A domain settings file for domain '$domain' could not be determined."
        return $null
    }
    $appMetaData = @{
        companyName = if ($domainSettings.companyName) { $domainSettings.companyName  } else { $null }
        version     = if ($domainSettings.version) { $domainSettings.version } else { $null }
    }
    Write-Verbose "[$functionName] Application metadata for domain '$($domainSettings.domain)' retrieved successfully."
    Write-Log -logFile $logFile -module $functionName -Message "Application metadata for domain '$($domainSettings.domain)' retrieved successfully."
    #print verbose all the values that are not null.
    foreach ($key in $appMetaData.Keys)
    {
        if ($appMetaData[$key] -ne $null)
        {
            Write-Verbose "[$functionName] $($key): $($appMetaData[$key])"
            Write-Log -logFile $logFile -module $functionName -Message "$($key): $($appMetaData[$key])"
        }
    }
    return $appMetaData
}