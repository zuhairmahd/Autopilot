function GetLatestGithubRelease()
{
    [CmdletBinding()]
    param (
        [string]$Repository
    )
    Write-Verbose "Checking the latest release for Repository: $Repository"
    $url = "https://api.github.com/repos/$Repository/releases/latest"
    Write-Verbose "Requesting URL: $url"
    $response = Invoke-RestMethod -Uri $url -Method Get 
    Write-Verbose "Got response: $($response.tag_name)"
    if (($null -eq $response) -or ($null -eq $response.tag_name ))
    {
        Write-Host "Failed to retrieve the latest release information from GitHub."
        return $null
    }
    return $response.tag_name
}
