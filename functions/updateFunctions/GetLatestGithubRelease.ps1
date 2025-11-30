function GetLatestGithubRelease()
{
    <#
    .SYNOPSIS
    Retrieves the latest release tag from a GitHub repository.

    .DESCRIPTION
    This function queries the GitHub API to retrieve the latest release tag name from a
    specified repository. It uses the GitHub releases API endpoint and handles errors
    gracefully if the release information cannot be retrieved.

    .PARAMETER Repository
    The GitHub repository in format "owner/repo" (e.g., "microsoft/powershell").

    .OUTPUTS
    System.String
    Returns the latest release tag name (e.g., "v1.2.3"), or $null if retrieval fails.

    .EXAMPLE
    $latestTag = GetLatestGithubRelease -Repository "zuhairmahd/Autopilot"
    Write-Host "Latest release: $latestTag"

    .NOTES
    Uses GitHub API: https://api.github.com/repos/{owner}/{repo}/releases/latest
    Does not require authentication for public repositories.
    Returns only the tag_name property from the release object.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [string]$Repository
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking the latest release for Repository: $Repository"
    $url = "https://api.github.com/repos/$Repository/releases/latest"
    Write-Verbose "[$functionName] Requesting URL: $url"
    $response = Invoke-RestMethod -Uri $url -Method Get 
    Write-Verbose "[$functionName] Got response: $($response.tag_name)"
    if (($null -eq $response) -or ($null -eq $response.tag_name ))
    {
        Write-Host "Failed to retrieve the latest release information from GitHub." -ForegroundColor Red
        return $null
    }
    return $response.tag_name
}

