function CreateSecretsFile()
{
    <#
    .SYNOPSIS
    Creates a secrets JSON file for storing sensitive configuration data.

    .DESCRIPTION
    This function creates an empty secrets.json file in the .secrets subdirectory if it
    doesn't already exist. The file is initialized as an empty JSON object and is used to
    store sensitive configuration values like API keys, client secrets, and passwords that
    should not be committed to source control.

    .PARAMETER RootFolder
    The root folder path where the .secrets subdirectory should be created. This parameter is mandatory.

    .PARAMETER SecretsFile
    The full path to the secrets file. Defaults to "$RootFolder\.secrets\secrets.json".

    .OUTPUTS
    None. Creates the secrets file if it doesn't exist.

    .EXAMPLE
    CreateSecretsFile -RootFolder "C:\MyApp"
    CreateSecretsFile -RootFolder $PSScriptRoot -SecretsFile "C:\MyApp\custom-secrets.json"

    .NOTES
    The .secrets directory should be added to .gitignore to prevent committing sensitive data.
    Creates an empty JSON object {} as the initial file content.
    Compatible with PowerShell 5.1.
    #>
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

