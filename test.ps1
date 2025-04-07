[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]$userName
)


$groupsToInclude = @('IOS-COMPANY-PORTAL')
$groupsToExclude = @('User elevation management')
$configFile = "$pwd\.secrets\config.json"
# $serialNumber = 'VMware-564d734181a15091-8cab81424cc39146'

#region import functions.
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder)
{
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose "Importing function $function"
        . $function.FullName
    }
}
else
{
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}
#endregion

if (connectToTenant -configFile '.\.secrets\config.json')
{
    Write-Verbose 'Connected to tenant'
}
else
{
    Write-Host 'Failed to connect to tenant' -ForegroundColor Red
    exit 1
}


# $accessToken = GetGraphAccessToken -configFile $configFile
# $global:device1 = GetDeviceBySerial -serialNumber $serialNumber  -Access_Token $accessToken
# $global:device2 = GetDeviceBySerialNumber -serialNumber $serialNumber
VerifyGroupMembership -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude -verbose