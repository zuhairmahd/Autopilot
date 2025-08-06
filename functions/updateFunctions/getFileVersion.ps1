function getFileVersion()
{
    [CmdletBinding()]    
    param(
        [string]$executableFileName
    )

    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{}
    Write-Verbose "[$functionName] Executable File Name: $executableFileName"
    if (-not $executableFileName -or -not (Test-Path $executableFileName) -or $executableFileName -match '.ps1')
    {
        Write-Verbose "[$functionName] Executable file name is not provided."
        return $null
    }
    Write-Verbose "[$functionName] Checking if the executable file exists in the current directory."
    if (Test-Path $executableFileName -PathType Leaf -ErrorAction SilentlyContinue)
    {
        Write-Verbose "[$functionName] Found the executable file '$executableFileName'."
        Write-Verbose "[$functionName] Getting the file version."
        $LocalVersion = (Get-Item $executableFileName).VersionInfo.ProductVersion
        $companyName = (Get-Item $executableFileName).VersionInfo.CompanyName
        Write-Verbose "[$functionName] Local version extracted: $LocalVersion"
        Write-Verbose "[$functionName] Parsing the local version string to System.Version object."
        $localVersion = [System.Version]::Parse($LocalVersion)
        Write-Verbose "[$functionName] Parsed local version: $localVersion"
        Write-Verbose "[$functionName] Returning local version: $localVersion"
        $returnObject = @{
            'major'       = $localVersion.Major
            'minor'       = $localVersion.Minor
            'build'       = $localVersion.Build
            'revision'    = $localVersion.Revision
            'version'     = $localVersion
            'companyName' = $companyName
        }
        return $returnObject
    }
    else
    {
        Write-Verbose "[$functionName] Executable file '$executableFileName' not found in the current directory."
        return $null
    }
}

