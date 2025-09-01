function CreateSecretsFile()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$SecretsFile = "$RootFolder\.secrets\secrets.json"
    )
    
    #region print verbose log of received parameters
    Write-Verbose "Root folder: $RootFolder"
Write-Log -LogFile $LogFile -Module "MiscFunctions" -Message "Processing with root folder: $RootFolder" -LogLevel "Verbose"
    Write-Verbose "SecretsFile: $SecretsFile"
    Write-Log -LogFile $LogFile -Module "MiscFunctions" -Message "Using secrets file: $SecretsFile" -LogLevel "Debug"
    #endregion
    
    if (-not(Test-Path $SecretsFile))
    {
        Write-Verbose "Creating secrets file at $SecretsFile."
        Write-Log -LogFile $LogFile -Module "MiscFunctions" -Message "Creating secrets file at $SecretsFile" -LogLevel "Information"
        $secrets = @{}
        $secrets | ConvertTo-Json -Depth $maxJSONDepth | Set-Content -Path $SecretsFile -Force
        Write-Host "Secrets file created successfully at $SecretsFile." -ForegroundColor Green
    }
    else
    {
        Write-Host "Secrets file already exists at $SecretsFile." -ForegroundColor Yellow
    }
}

