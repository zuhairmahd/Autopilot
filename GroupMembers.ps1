[CmdletBinding()]
param (
    [string]$Endpoint,
    [string]$Version = 'v1.0'
)

# Define the Graph API endpoint
$graphApiUrl = "https://graph.microsoft.com/$Version/$endpoint"
Write-Host "The Graph API URL is $graphApiUrl"
$secretsFile = '..\.secrets\config.json'
Write-Verbose "Reading app registration details from $secretsFile"
$secrets = Get-Content $secretsFile | ConvertFrom-Json
$tenantId = $secrets.tenantId
$clientId = $secrets.clientId
$clientSecret = $secrets.clientSecret
$SecureClientSecret = ConvertTo-SecureString -String $clientSecret  -AsPlainText -Force
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $SecureClientSecret
Write-Verbose 'Connecting to Microsoft Graph with the following details:'
Write-Verbose "TenantId: $tenantId"
Write-Verbose "ClientId: $clientId"
Write-Verbose "ClientSecret: $clientSecret"

Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome
Write-Verbose 'Connected to Microsoft graph with the following scopes:'
$scopes = Get-MgContext | Select-Object -ExpandProperty Scopes
Write-Verbose "$scopes"
#Get a list of all device configurations.
Write-Verbose 'Calling Invoke-MgGraphRequest with the following parameters:'
Write-Verbose "Uri: $graphApiUrl"
Write-Verbose 'Method: Get'

$groups = Invoke-MgGraphRequest -Uri $graphApiUrl -Method Get
#print the members of each group.
foreach ($group in $groups.value)
{
    Write-Host "Getting membership for group: $($group.displayName)"
    Write-Verbose 'Calling Invoke-MgGraphRequest with the following parameters:'
    Write-Verbose "Uri: $($graphApiUrl)/$($group.id)/members"
    Write-Verbose 'Method: Get'
    $members = Invoke-MgGraphRequest -Uri "$($graphApiUrl)/$($group.id)/members" -Method Get
    if ($members.value.Count -eq 0)
    {
        Write-Host "Group: $($group.displayName) has no members."
    }
    else
    {
        Write-Output "Group $($group.displayName) has the following $($members.value.Count) members:"
        foreach ($member in $members.value)
        {
            Write-Host "Member: $($member.displayName)"
        }
    }
}
Disconnect-MgGraph