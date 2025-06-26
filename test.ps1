[CmdletBinding()]
param
(
    $userName,
    $repo = 'Github', # Options: Github, gitlab
    $release = 'auto',
    $configFile = "$pwd\.secrets\config.json",
    $outputFile = "$pwd\deviceMemory-export.csv",
    [switch]$forceNewToken
)

#region Load parameters from the configuration file if it exists
$scriptName = $MyInvocation.MyCommand.Name
$initFile = "$pwd\settings.json"
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
Write-Verbose "[$scriptName] Domain: $domain"
if (Test-Path -Path $InitFile)
{
    Write-Host " Loading configuration values from $(Split-Path -Path $initFile -Leaf)"
    $global:globalSettings = @{}
    $global:localSettings = @{}
    $globalConfigData = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty 'globalSettings'
    Write-Verbose "[$scriptName] Reading global settings..."
    Write-Verbose "[$scriptName] Found $($globalConfigData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $globalConfigData.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $globalConfigData.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($globalConfigData.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($globalConfigData.$key)"
            if ($globalConfigData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($globalConfigData.$key)
                $globalSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
                # Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($globalConfigData.$key))."
                # Set-Variable -Name $key -Value $globalConfigData.$key
                $globalSettings.add($key, $globalConfigData.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Got parameter $key from the commandline as $($PSBoundParameters[$key])"
            #add it to the global settings hashtable.
            $globalSettings.add($key, $PSBoundParameters[$key])
        }
    }
    $localConfigData = (Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty "domains").$domain
    Write-Verbose "[$scriptName] Reading local settings for domain $domain..."
    Write-Verbose "[$scriptName] Found $($localConfigData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $localConfigData.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $localConfigData.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($localConfigData.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($localConfigData.$key)"
            if ($localConfigData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($localConfigData.$key)
                $localSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
                # Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($localConfigData.$key))."
                # Set-Variable -Name $key -Value $localConfigData.$key
                $localSettings.add($key, $localConfigData.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Read parameter $key from the commandline as $($PSBoundParameters[$key])"
            #add it to the local settings hashtable.
            $localSettings.add($key, $PSBoundParameters[$key])
        }
    }   
}
else
{
    Write-Host "Configuration file $initFile not found. Using default values."
}
#endregion Load parameters from the configuration file if it exists

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

#region variables
# $auth = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty auth
# $scope = $auth.scope
# $logfile = "mylog.log"
# $settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
# $serialNumber = '0F3CFP724223KV'
# $serialNumber = 'BTSB25000BCR'
# $serialNumber = '5R3SBZ3'
# $userUri = "users"
# $managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $importedAutopilotDeviceExtraParameters = "select=serialNumber,importId,groupTag,state"
# $unmanagedDeviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $autopilotExtraParameters = "select=serialNumber,groupTag,manufacturer,model,systemFamily,enrollmentState,deploymentProfileAssignmentStatus&top=9999&skip=0&count=true"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $managedDeviceFilter = "startswith(deviceName,'w11-')"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $deviceConfigurationUri = "deviceManagement/deviceConfigurations"
# $autopilotCsv = [System.Collections.ArrayList]@()
# $importedCsv = [System.Collections.ArrayList]@()
# $accessToken = GetGraphAccessToken -configFile $configFile -deligated -scope $scope -AuthType 'PublicAuthFlow'
# $accessToken = GetGraphAccessToken -configFile $configFile
# $autopilotDevices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken -extraParameters $autopilotExtraParameters -consistencyLevel -verbose
# $importedDevices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -consistencyLevel -extraParameters $importedAutopilotDeviceExtraParameters -verbose
# $unmanagedDevices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken
# $global:enrollments = [ordered] @{
# "autopilot" = $autopilotDevices
# "managed" = $managedDevices
# "imported"  = $importedDevices
# "unmanaged" = $unmanagedDevices
# }
#endregion variables


# Define required permissions with reasons
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profile information and check group memberships"
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Needed to perform privileged operations on managed devices, such as wiping or retiring devices and reading LAPS passwords"
    },
    @{
        Permission = "DeviceManagementManagedDevices.ReadWrite.All"
        Reason     = "Required to read and write managed device information, including compliance policies and device configurations"
    },
    @{
        Permission = "DeviceManagementConfiguration.ReadWrite.All"
        Reason     = "Needed to read and write Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Needed to read and write Intune service configuration settings"
    },
    @{
        Permission = "offline_access"
        Reason     = "Needed to maintain access to resources when the user is not actively using the application"
    },
    @{ 
        Permission = "openid"
        Reason     = "Needed for OpenID Connect authentication to verify user identity"
    },
    @{
        Permission = "Device.ReadWrite.All"
        Reason     = "Needed to import devices into Autopilot"
    },    
    @{
        Permission = "Group.Read.All"
        Reason     = "Needed to read group information and memberships"
    },
    @{
        Permission = "DeviceManagementConfiguration.Read.All"
        Reason     = "Allows reading Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementApps.Read.All"
        Reason     = "Necessary to read mobile app management policies and app configurations"
    },
    @{
        Permission = "DeviceManagementManagedDevices.Read.All"
        Reason     = "Required to read managed device information and compliance policies"
    },
    @{
        Permission = "Device.Read.All"
        Reason     = "Needed to read device information from Entra ID"
    }
)

# Required permissions based on specific API endpoint access, following the principle of least privilege.
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profiles, group memberships, and registered devices. (Covers: /users, /users/{id}, /users/{id}/memberOf, /users/{id}/registeredDevices)"
    },
    @{
        Permission = "Device.Read.All"
        Reason     = "Required to read Microsoft Entra ID device objects. (Covers: /devices)"
    },
    @{
        Permission = "DeviceManagementApps.ReadWrite.All"
        Reason     = "Required to read application information and manage app assignments. (Covers: /deviceAppManagement/mobileApps and .../assignments)"
    },
    @{
        Permission = "DeviceManagementConfiguration.Read.All"
        Reason     = "Required to read Intune device configuration policies. (Covers: /deviceManagement/deviceConfigurations)"
    },
    @{
        Permission = "DeviceManagementManagedDevices.Read.All"
        Reason     = "Required to read Intune managed device properties. (Covers: /deviceManagement/managedDevices and /deviceManagement/managedDevices/{id})"
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Required for highly privileged operations, specifically to read local admin (LAPS) passwords. (Covers: /directory/deviceLocalCredentials)"
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Required to read Autopilot events and to read and manage Autopilot device identities. (Covers: /deviceManagement/autopilotEvents, .../importedWindowsAutopilotDeviceIdentities, .../windowsAutopilotDeviceIdentities)"
    },
    @{
        Permission = "BitlockerKey.Read.All"
        Reason     = "Required to read BitLocker recovery keys for all devices. (Covers: /informationProtection/bitlocker/recoveryKeys)"
    },
    @{
        Permission = "openid"
        Reason     = "Standard scope required for user sign-in with OpenID Connect."
    },
    @{
        Permission = "profile"
        Reason     = "Standard scope to get basic user profile information during sign-in."
    },
    @{
        Permission = "offline_access"
        Reason     = "Standard scope that provides refresh tokens to maintain access when the user is not active."
    }
)

# You can now use this array to construct your authentication request.
# For example, with MSAL.PS:
# $scopes = $requiredPermissions.Permission
# Get-MsalToken -ClientId "your-client-id" -TenantId "your-tenant-id" -Scope $scopes

# Define revised required permissions with reasons
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profile information and check group memberships"
    },
    @{
        Permission = "Group.Read.All"
        Reason     = "Needed to read group information and memberships"
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Needed to perform privileged operations on managed devices, such as wiping or retiring devices and reading LAPS passwords"
    },
    @{
        Permission = "DeviceManagementManagedDevices.ReadWrite.All"
        Reason     = "Required to read and write managed device information and compliance policies"
    },
    @{
        Permission = "DeviceManagementConfiguration.ReadWrite.All"
        Reason     = "Needed to read and write Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementApps.Read.All"
        Reason     = "Necessary to read mobile app management policies and app configurations"
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Needed to read/write Intune service configuration settings and to import devices into Autopilot"
    },
    @{
        Permission = "openid"
        Reason     = "Needed for OpenID Connect authentication to verify user identity"
    },
    @{
        Permission = "offline_access"
        Reason     = "Needed to maintain access to resources when the user is not actively using the application"
    }
)
exit 0
$uris = @()
# Regex pattern to find variables ending with 'uri' (case-insensitive) whose assignment doesn't start with $ or http
$queryPattern = '\$\w*uri\s*=\s*(?!\$|(?i:http))'
$filesToSearch = Get-ChildItem "$pwd\*.ps1" -Recurse 
Write-Host "Found $($filesToSearch.count) files."
#Search each file for variables ending with 'uri' and extract their assigned values
foreach ($file in $filesToSearch)
{
    Write-Host "Searching in $($file.Name)"
    $lines = Select-String -Path $file.FullName -Pattern $queryPattern -AllMatches
    if ($lines)
    {
        Write-Host "Found $($lines.count) lines in $($file.Name)" 
        foreach ($line in $lines)
        {
            # Extract the value after the = sign, handling quoted and unquoted strings
            $match = $line.Line -match '\$\w*uri\s*=\s*([\x27\x22]?)([^\x27\x22#\r\n]+)\1'
            if ($match)
            {
                $extractedUri = $matches[2].Trim()
                if ($extractedUri -and $extractedUri -notmatch '^(\$|(?i:http))')
                {
                    $uris += $extractedUri
                    Write-Verbose "Found URI: $extractedUri in $($file.Name) at line $($line.LineNumber)"
                }
            }
        }
    }
    else
    {
        Write-Host "No matches found in $($file.Name)"
    }
}
#sort uris and remove dupicates
Write-Host "Found $($uris.count) URIs."
if ($uris.count -eq 0)
{
    Write-Host "No URIs found. Exiting script." -ForegroundColor Red
    exit 1
}
else
{
    Write-Host "Found $($uris.count) unique URIs."
}
# Remove duplicates and sort the URIs
Write-Host "Sorting and removing duplicates from URIs..."
$uris = $uris | Sort-Object -Unique
Write-Host "Found $($uris.count) unique URIs after sorting."
Set-Content -Path 'uris.txt' -Value $uris -Force


