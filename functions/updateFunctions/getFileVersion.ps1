function getFileVersion()
{
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

