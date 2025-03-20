function GetLatestGitlabRelease()
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [string]$RepositoryUrl
    )
    $gitlabURL = 'https://git.gao.gov'
    $gitlabAPIEndpoint = "$gitlabURL/api/v4"
    $GitlabPrivateToken = 'nothing_to_see_here'
    # Extract the project ID from the repository URL
    $projectId = $RepositoryUrl -replace "$gitlabURL/", '' -replace '.git$', ''
    Write-Host $projectId
    exit 0
    # GitLab API endpoint for the latest release
    $apiUrl = "$gitlabAPIEndpoint/projects/$($projectId)/releases/latest"
    try
    {
        # Make a GET request to the GitLab API to fetch the latest release information
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
        # Return the response object containing release details
        return $response
    }
    catch
    {
        Write-Host "Failed to retrieve the latest release from GitLab: $_"
    }
}

# Example usage:
$latestRelease = GetLatestGitlabRelease -RepositoryUrl 'https://git.gao.gov/mahmoudz/intune-scripts.git'
Write-Host $latestRelease