function getFileVersion()
{
    [CmdletBinding()]    
    param(
        [string]$executableFileName
    )

    $functionName = $MyInvocation.MyCommand.Name
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
        Write-Verbose "[$functionName] Local version extracted: $LocalVersion"
        Write-Verbose "[$functionName] Parsing the local version string to System.Version object."
        $localVersion = [System.Version]::Parse($LocalVersion)
        Write-Verbose "[$functionName] Parsed local version: $localVersion"
        Write-Verbose "[$functionName] Returning local version: $localVersion"
        return $localVersion
    }
    else
    {
        Write-Verbose "[$functionName] Executable file '$executableFileName' not found in the current directory."
        return $null
    }
}

