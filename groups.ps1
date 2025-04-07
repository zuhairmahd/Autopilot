
[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true
    )
    ]
    [string]$userName,
    [string]$configFile = '.\.secrets\config.json',
    [string]$functionsFolder = '.\functions',
    [switch]$noCertificate
)

$groupsToInclude = @('IOS-COMPANY-PORTAL')
$groupsToExclude = @('User elevation management')
$functions = @(
    'ConnectToTenant.ps1',
    'Get-decryptedObject.ps1'
)

if (Test-Path $functionsFolder)
{
    Write-Verbose "Loading functions from $functionsFolder."
    foreach ($function in $functions)
    {
        $functionPath = Join-Path -Path $functionsFolder -ChildPath $function
        if (Test-Path $functionPath)
        {
            Write-Verbose "Loading function $functionPath."
            . $functionPath
        }
        else
        {
            Write-Warning "The function $functionPath does not exist."
        }
    }
}
else
{
    Write-Warning "The functions folder $functionsFolder does not exist."
}

#read the configuration json file.
$config = ConnectToTenant -configFile $configFile
if (-not($config))
{
    Write-Host "Failed to connect"
    exit 1
}



$scopes = Get-MgContext | Select-Object -ExpandProperty Scopes
if ($scopes)
{
    Write-Verbose "The following $($scopes.Count) scopes are available:"
    $scopes | ForEach-Object { Write-Verbose $_ }
}
else
{
    Get-MgContext | Format-List
}


#Get the id for the user.
$userID = Get-MgUser -UserId $userName | Select-Object -ExpandProperty Id
Write-Output "Getting group membership for user $userName with id $userID"
$groupsAndRoles = Get-MgUserMemberOf -UserId $userName | ForEach-Object { $_ }
$groups = @()
$index = 0
foreach ($groupAndRole in $groupsAndRoles)
{
    $index ++
    if ($groupAndRole.AdditionalProperties -and $groupAndRole.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group')
    {
        $groups += $groupAndRole.AdditionalProperties
    }
}

if ($groups)
{
    Write-Verbose "The user $userName is a member of the following $($groups.Count) groups:"
    foreach ($group in $groups)
    {
        Write-Verbose "$($group.displayName)"
        #Check if the group is in the list of groups to include
        if ($groupsToInclude -contains $group.displayName)
        {
            Write-Host ' [✓] ' -NoNewline -ForegroundColor Green -BackgroundColor Yellow
            Write-Host "$($group.displayName)" -ForegroundColor Green -BackgroundColor Yellow
        }
        #Check if the group is in the list of groups to exclude
        elseif ($groupsToExclude -contains $group.displayName)
        {
            Write-Host ' [✗] ' -NoNewline -ForegroundColor Red -BackgroundColor Yellow
            Write-Host "$($group.displayName)" -ForegroundColor Red -BackgroundColor Yellow
            #remove the user from the group
            # Write-Output "Removing user $userName from the group $($group.displayName)"
            # $userID = Get-MgUser -UserId $userName | Select-Object -ExpandProperty Id
            # Invoke-MgGraphRequest -Method DELETE -Uri "/groups/$($groupAndRole.id)/members/$userName"
        }
        else
        {
            Write-Verbose "The group $($group.displayName) is not an exclusion or an inclusion group"
        }
    }
}
else
{
    Write-Output "The user $userName is not a member of any groups."
}
