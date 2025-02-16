
####################################################################################################
# Autoupdate function

# URL to the version file on GitHub
$versionUrl = 'https://raw.githubusercontent.com/ugurkocde/IntuneAssignmentChecker/main/version_v2.txt'

# URL to the latest script on GitHub
$scriptUrl = 'https://raw.githubusercontent.com/ugurkocde/IntuneAssignmentChecker/main/IntuneAssignmentChecker_v2.ps1'

# Determine the script path based on whether it's run as a file or from an IDE
if ($PSScriptRoot)
{
    $newScriptPath = Join-Path $PSScriptRoot 'IntuneAssignmentChecker_v2.ps1'
}
else
{
    $currentDirectory = Get-Location
    $newScriptPath = Join-Path $currentDirectory 'IntuneAssignmentChecker_v2.ps1'
}

# Flag to control auto-update behavior
$autoUpdate = $true  # Set to $false to disable auto-update

try
{
    # Fetch the latest version number from GitHub
    $latestVersion = Invoke-RestMethod -Uri $versionUrl
    
    # Compare versions using System.Version for proper semantic versioning
    $local = [System.Version]::new($localVersion)
    $latest = [System.Version]::new($latestVersion)
    
    if ($local -lt $latest)
    {
        Write-Host "A new version is available: $latestVersion (you are running $localVersion)" -ForegroundColor Yellow
        if ($autoUpdate)
        {
            Write-Host 'AutoUpdate is enabled. Downloading the latest version...' -ForegroundColor Yellow
            try
            {
                # Download the latest version of the script
                Invoke-WebRequest -Uri $scriptUrl -OutFile $newScriptPath
                Write-Host "The latest version has been downloaded to $newScriptPath" -ForegroundColor Yellow
                Write-Host 'Please restart the script to use the updated version.' -ForegroundColor Yellow
            }
            catch
            {
                Write-Host 'An error occurred while downloading the latest version. Please download it manually from: https://github.com/ugurkocde/IntuneAssignmentChecker' -ForegroundColor Red
            }
        }
        else
        {
            Write-Host 'Auto-update is disabled. Get the latest version at:' -ForegroundColor Yellow
            Write-Host 'https://github.com/ugurkocde/IntuneAssignmentChecker' -ForegroundColor Cyan
            Write-Host '' 
        }
    }
    elseif ($local -gt $latest)
    {
        Write-Host "Note: You are running a pre-release version ($localVersion)" -ForegroundColor Magenta
        Write-Host ''
    }
}
catch
{
    Write-Host 'Unable to check for updates. Continue with current version...' -ForegroundColor Gray
}

