#requires -module Microsoft.Graph.Authentication

[CmdletBinding()]
param(
    [string]$configFilesPath = ".secrets",
    [switch]$useDelegatedAuthentication,
    [switch]$useDeviceCode,
    [switch]$disconnect
)

$scopes = @(
    'Device.ReadWrite.All',
    'DeviceManagementApps.Read.All',
    'DeviceManagementConfiguration.ReadWrite.All',
    'DeviceManagementScripts.Read.All',
    'Mail.Send',
    'DeviceManagementManagedDevices.PrivilegedOperations.All',
    'DeviceManagementManagedDevices.ReadWrite.All',
    'DeviceManagementServiceConfig.ReadWrite.All'
)

if ($disconnect)
{
    Write-Host "Disconnecting from Microsoft Graph SDK..."
    Disconnect-MgGraph
    Write-Host "Disconnected."
    exit 0
}
#Get all .json files in the folder.
$configFiles = Get-ChildItem -Path $configFilesPath -Filter config-*.json -Force -ErrorAction SilentlyContinue
if ($configFiles.count -eq 0)
{
    Write-Host "No configuration files found in the specified path: $configFilesPath"
    exit 1
}
foreach ($file in $configFiles)
{
    #read the name content property from each file and display in a menu along with the file name.
    $configContent = Get-Content -Path $file.FullName | ConvertFrom-Json
    $menuItems += @(
        @{
            FileName    = $file.Name
            DisplayName = $configContent.name
        }
    )
}
#Display menu to select a configuration file.
$menuIndex = 1
Write-Host "Select a configuration file to connect with Microsoft Graph SDK:`n"
foreach ($item in $menuItems)
{
    Write-Host "[$menuIndex] $($item.DisplayName) - $($item.FileName)"
    $menuIndex++
}
$selection = Read-Host "Enter the number corresponding to your choice"
while (-not ($selection -match '^[0-' + $menuItems.count + ']$'))
{
    $selection = Read-Host "Invalid selection. Please enter a number between 1 and $($menuItems.count)"
    [console]::beep(500, 300)
}
#exit if the user selects 0
if ($selection -eq 0)
{
    Write-Host "Exiting without making a connection."
    exit 0
}
#print the name of the selected file.
$selectedItem = $menuItems[$selection - 1]
Write-Host "You selected: $($selectedItem.DisplayName) - $($selectedItem.FileName)"
$config = Get-Content -Path (Join-Path -Path $configFilesPath -ChildPath $selectedItem.FileName) | ConvertFrom-Json
if ([string]::IsNullOrEmpty($config.appId) -or [string]::IsNullOrEmpty($config.tenantId))
{
    Write-Host "The selected configuration file is missing required properties (appId or tenantId)."
    exit 1
}

if ($useDelegatedAuthentication)
{
    Write-Host "Using Delegated Authentication method."
    $connectParams = @{
        noWelcome = $true
        TenantId  = $config.tenantId
        Scopes    = $scopes | ForEach-Object { $_.Trim() }
    }
    if ($useDeviceCode)
    {
        Write-Host "Using Device Code flow for authentication."
        $connectParams.useDeviceCode = $true
    }
}
else
{
    #we also need either a client secret or a certificate thumbprint to proceed.
    if ([string]::IsNullOrEmpty($config.AppSecret) -and [string]::IsNullOrEmpty($config.thumbprint))
    {
        Write-Host "The selected configuration file must contain either a clientSecret or a certificateThumbprint."
        exit 1
    }
    if (-not [string]::IsNullOrEmpty($config.AppSecret))
    {
        Write-Host "Using Client Secret authentication method."
        $secureSecret = ConvertTo-SecureString -String $config.AppSecret -AsPlainText -Force
        $credentials = New-Object -TypeName Microsoft.Graph.Auth.ClientSecretCredential -ArgumentList $config.appId, $secureSecret
        $connectParams = @{
            noWelcome              = $true
            TenantId               = $config.tenantId
            ClientSecretCredential = $credentials
            Scopes                 = "https://graph.microsoft.com/.default"
        }
    }
    elseif (-not [string]::IsNullOrEmpty($config.Thumbprint))
    {
        Write-Host "Using Certificate Thumbprint authentication method."
        $connectParams = @{
            noWelcome             = $true
            TenantId              = $config.tenantId
            clientId              = $config.appId
            CertificateThumbprint = $config.Thumbprint
        }
    }
    else
    {
        Write-Host "No valid authentication method found in the configuration file."
        exit 1
    }
}
#Connect to Microsoft Graph using the selected configuration.
try
{
    Connect-MgGraph @connectParams
    Write-Host "Successfully connected to Microsoft Graph SDK using the selected configuration."
}
catch
{
    Write-Host "Failed to connect to Microsoft Graph SDK. Error: $_"
    exit 1
}
