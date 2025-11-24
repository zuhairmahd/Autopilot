function Get-FileVersion()
{
    <#
    .SYNOPSIS
    Retrieves version information from an executable file.

    .DESCRIPTION
    This function extracts version information from a specified executable file including
    product version, company name, and SHA256 file hash. It validates the file exists
    and is not a PowerShell script, then returns detailed version metadata in a structured
    hashtable format.

    .PARAMETER executableFileName
    The name or path of the executable file to retrieve version information from.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with properties:
    - major: Major version number
    - minor: Minor version number
    - build: Build number
    - revision: Revision number
    - version: Complete System.Version object
    - companyName: Company name from file metadata
    - hash: SHA256 hash of the file
    
    Returns $null if file doesn't exist, is a .ps1 file, or no version info is available.

    .EXAMPLE
    $versionInfo = Get-FileVersion -executableFileName "main.exe"
    Write-Host "Version: $($versionInfo.version)"
    Write-Host "Hash: $($versionInfo.hash)"

    .NOTES
    Uses Get-Item to extract VersionInfo properties.
    Calculates SHA256 hash for file verification.
    Validates file existence and type before processing.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]    
    param(
        [string]$executableFileName
    )

    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{}
    Write-Log -LogFile $LogFile -Module $functionName -Message "Executable File Name: $executableFileName" -LogLevel "Verbose"
    if (-not $executableFileName -or -not (Test-Path $executableFileName) -or $executableFileName -match '.ps1')
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Executable file name is not provided." -LogLevel "Error"
        return $null
    }
    Write-Log -LogFile $LogFile -Module $functionName -Message "Checking if the executable file exists in the current directory." -LogLevel "Verbose"
    if (Test-Path $executableFileName -PathType Leaf -ErrorAction SilentlyContinue)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Found the executable file '$executableFileName'." -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Getting the file version." -LogLevel "Verbose"
        $LocalVersion = (Get-Item $executableFileName).VersionInfo.ProductVersion
        $companyName = (Get-Item $executableFileName).VersionInfo.CompanyName
        $hash = (Get-FileHash -Path $executableFileName -Algorithm SHA256).Hash
        Write-Log -LogFile $LogFile -Module $functionName -Message "Local version extracted: $LocalVersion" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Company Name: $companyName" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module $functionName -Message "File Hash: $hash" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Parsing the local version string to System.Version object." -LogLevel "Verbose"
        $localVersion = [System.Version]::Parse($LocalVersion)
        Write-Log -LogFile $LogFile -Module $functionName -Message "Parsed local version: $localVersion" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Returning local version: $localVersion" -LogLevel "Information"
        $returnObject = @{
            'major'       = $localVersion.Major
            'minor'       = $localVersion.Minor
            'build'       = $localVersion.Build
            'revision'    = $localVersion.Revision
            'version'     = $localVersion
            'companyName' = $companyName
            'hash'        = $hash
        }
        return $returnObject
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Executable file '$executableFileName' not found in the current directory." -LogLevel "Verbose"
        return $null
    }
}

