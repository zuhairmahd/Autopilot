function GetLatestGithubRelease()
{
    [CmdletBinding()]
    param (
        [string]$Repository
    )
    $url = "https://api.github.com/repos/$Repository/releases/latest"
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{ 'User-Agent' = 'PowerShell' }
    return $response.tag_name
}
