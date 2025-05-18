function GetLatestGitlabRelease()
{
    [CmdletBinding()]
    param (
        [string]$ProjectID
    )
    $gitlabURL = 'https://git.gao.gov'
    $gitlabAPIEndpoint = "$gitlabURL/api/v4"
    $gitlabAPIProjectEndpoint = "$gitlabAPIEndpoint/projects/$ProjectID"
    $gitlabAPILatestReleaseEndpoint = "$gitlabAPIProjectEndpoint/releases/permalink/latest"
    $returnValue = $null
    Write-Verbose "GitLab URL: $gitlabURL"
    Write-Verbose "GitLab API Endpoint: $gitlabAPIEndpoint"
    Write-Verbose "GitLab API Project Endpoint: $gitlabAPIProjectEndpoint"
    Write-Verbose "GitLab API Latest Release Endpoint: $gitlabAPILatestReleaseEndpoint"
    Write-Verbose "Project ID: $ProjectID"
    Write-Verbose 'Attempting to retrieve the latest release from GitLab...'
    Write-Verbose "getting latest release from $gitlabAPILatestReleaseEndpoint"
    $response = Invoke-RestMethod -Uri $gitlabAPILatestReleaseEndpoint -Method Get -ErrorAction SilentlyContinue
    if ($response)
    {
        Write-Verbose "Successfully retrieved the latest release. Tag Name: $($response.tag_name)"
        $returnValue = $response.tag_name
    }
    else 
    {
        Write-Verbose 'Failed to retrieve the latest release from GitLab. Trying to get the default branch instead.'
        Write-Verbose "Attempting to retrieve project details from: $gitlabAPIProjectEndpoint"
        $response = Invoke-RestMethod -Uri $gitlabAPIProjectEndpoint -Method Get -ErrorAction SilentlyContinue
        if ($response)
        {
            Write-Verbose "Successfully retrieved project details. Default Branch: $($response.default_branch)"
            $returnValue = $response.default_branch
        }
        else
        {
            Write-Verbose 'Failed to retrieve project details from GitLab.'
        }
    }
    Write-Verbose "Returning value: $returnValue"
    return $returnValue
}
