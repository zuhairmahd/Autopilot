function getFileVersion()
{
    [CmdletBinding()]    
    param(
        [string]$executableFileName
    )

    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{}
    
    # NOTE: Reduced logging verbosity for PowerShell 5.1 compatibility
    # Excessive Write-Log calls in deeply nested functions can cause stack overflow on PS 5.1
    
    if (-not $executableFileName -or -not (Test-Path $executableFileName) -or $executableFileName -match '.ps1')
    {
        Write-Verbose "[$functionName] Executable file name is not provided or does not exist."
        return $null
    }
    
    if (Test-Path $executableFileName -PathType Leaf -ErrorAction SilentlyContinue)
    {
        $LocalVersion = (Get-Item $executableFileName).VersionInfo.ProductVersion
        $companyName = (Get-Item $executableFileName).VersionInfo.CompanyName
        $hash = (Get-FileHash -Path $executableFileName -Algorithm SHA256).Hash
        
        Write-Verbose "[$functionName] Version: $LocalVersion, Company: $companyName"
        
        # Only log the final result, not every intermediate step
        $localVersion = [System.Version]::Parse($LocalVersion)
        
        # TEMP: Comment out Write-Log to test if it's causing stack overflow on PS 5.1
        # Write-Log -LogFile $LogFile -Module $functionName -Message "File version retrieved: $localVersion ($companyName)" -LogLevel "Information"
        
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
        Write-Verbose "[$functionName] Executable file '$executableFileName' not found."
        return $null
    }
}

