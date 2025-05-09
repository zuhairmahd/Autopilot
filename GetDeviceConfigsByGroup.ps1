[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [string]$GroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$GroupId,
    
    [Parameter(Mandatory = $false)]
    [string]$configFile = "$pwd\.secrets\config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$csvOutputPath = "$pwd\GroupDeviceConfigurations.csv"
)

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
Write-Verbose "Setting up variables and constants"

# Define required scopes for Microsoft Graph API
$scopes = "offline_access Device.ReadWrite.All DeviceManagementApps.Read.All DeviceManagementConfiguration.ReadWrite.All Group.Read.All"

# Define API endpoint URIs
$deviceConfigurationUri = "deviceManagement/deviceConfigurations"
$groupsUri = "groups"

Write-Verbose "Getting Graph API access token"
$accessToken = GetGraphAccessToken -configFile $configFile -deligated -scopes $scopes
if (-not $accessToken)
{
    Write-Error "Failed to get access token. Please check your credentials and try again."
    exit 1
}

Write-Verbose "Access token acquired successfully"
#endregion variables

#region Find Group
# If no Group Name or ID is provided, prompt for Group Name
if (-not $GroupName -and -not $GroupId)
{
    $GroupName = Read-Host -Prompt "Enter the name of the group to find device configurations for"
}

# Find the Group ID if we have a name but no ID
if ($GroupName -and -not $GroupId)
{
    Write-Verbose "Looking up Group ID for group name: $GroupName"
    Write-Host "Looking up Group ID for: $GroupName" -ForegroundColor Cyan
    
    try
    {
        # Filter to find the group by name (using startswith to make it easier to find)
        $groupFilter = "startswith(displayName,'$GroupName')"
        Write-Verbose "Group filter: $groupFilter"
        
        # Call Graph API to find the group
        $groupResult = CallGraphApi -ResourcePath $groupsUri -accessToken $accessToken -Method GET -Filter $groupFilter
        
        if ($groupResult -and $groupResult.value.Count -gt 0)
        {
            # If multiple groups match, let user select the correct one
            if ($groupResult.value.Count -gt 1)
            {
                Write-Host "Multiple groups found matching '$GroupName'. Please select one:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $groupResult.value.Count; $i++)
                {
                    Write-Host "[$i] $($groupResult.value[$i].displayName) (Type: $($groupResult.value[$i].groupTypes -join ', '))"
                }
                $selection = Read-Host "Enter the number of the group you want"
                $GroupId = $groupResult.value[$selection].id
                $GroupDisplayName = $groupResult.value[$selection].displayName
            }
            else
            {
                $GroupId = $groupResult.value[0].id
                $GroupDisplayName = $groupResult.value[0].displayName
            }
            
            Write-Verbose "Selected Group: $GroupDisplayName (ID: $GroupId)"
            Write-Host "Found Group: $GroupDisplayName" -ForegroundColor Green
        }
        else
        {
            Write-Error "No groups found matching name: $GroupName"
            exit 1
        }
    }
    catch
    {
        Write-Error "Error looking up group: $_"
        exit 1
    }
}
# If we have an ID but no name, get the name
elseif ($GroupId -and -not $GroupName)
{
    Write-Verbose "Looking up Group Name for ID: $GroupId"
    try
    {
        # Call Graph API to get the group by ID
        $group = CallGraphApi -ResourcePath "$groupsUri/$GroupId" -accessToken $accessToken -Method GET
        
        if ($group -and $group.displayName)
        {
            $GroupDisplayName = $group.displayName
            Write-Verbose "Found Group: $GroupDisplayName (ID: $GroupId)"
            Write-Host "Found Group: $GroupDisplayName" -ForegroundColor Green
        }
        else
        {
            Write-Error "No group found with ID: $GroupId"
            exit 1
        }
    }
    catch
    {
        Write-Error "Error looking up group ID: $_"
        exit 1
    }
}
#endregion

#region Get All Device Configurations
Write-Verbose "Getting all device configurations"
Write-Host "Fetching device configurations..." -ForegroundColor Cyan

# Call Graph API to get all device configurations
$deviceConfigurations = CallGraphApi -ResourcePath $deviceConfigurationUri -accessToken $accessToken -Method GET
if (-not $deviceConfigurations -or -not $deviceConfigurations.value)
{
    Write-Error "Failed to get device configurations."
    exit 1
}

Write-Verbose "Found $($deviceConfigurations.value.count) total device configurations"
Write-Host "Found $($deviceConfigurations.value.count) total device configurations" -ForegroundColor Green
#endregion

#region Find Device Configurations Assigned to the Group
Write-Verbose "Finding device configurations assigned to group: $GroupDisplayName (ID: $GroupId)"
Write-Host "Finding device configurations assigned to group: $GroupDisplayName..." -ForegroundColor Cyan

$results = @()
$assignedConfigurations = 0

# Process each device configuration to check if it's assigned to our target group
foreach ($config in $deviceConfigurations.value)
{
    Write-Verbose "Checking assignments for configuration: $($config.displayName) (ID: $($config.id))"
    
    # Construct assignment URI for this configuration
    $deviceConfigurationAssignmentUri = "deviceManagement/deviceConfigurations/$($config.id)/assignments"
    Write-Verbose "Assignment URI: $deviceConfigurationAssignmentUri"
    
    # Call Graph API to get assignments for this configuration
    try
    {
        $assignments = CallGraphApi -ResourcePath $deviceConfigurationAssignmentUri -accessToken $accessToken -Method GET
        
        if ($assignments -and $assignments.value)
        {
            # Check if any assignment targets our group
            $targetAssignment = $assignments.value | Where-Object { $_.target.groupId -eq $GroupId }
            
            if ($targetAssignment)
            {
                Write-Verbose "Found assignment to our target group for configuration: $($config.displayName)"
                $assignedConfigurations++
                
                # Create result object
                $resultObj = [PSCustomObject]@{
                    ConfigurationId   = $config.id
                    ConfigurationName = $config.displayName
                    ConfigurationType = $config.'@odata.type'
                    GroupName         = $GroupDisplayName
                    GroupId           = $GroupId
                    AssignmentType    = $targetAssignment.target.'@odata.type'
                }
                
                $results += $resultObj
                Write-Host "Found: $($config.displayName)" -ForegroundColor Yellow
            }
        }
    }
    catch
    {
        Write-Warning "Error checking assignments for configuration: $($config.displayName) - $_"
    }
}
#endregion

#region Export results to CSV
if ($results.Count -gt 0)
{
    Write-Verbose "Exporting results to CSV file: $csvOutputPath"
    Write-Host "Exporting results to: $csvOutputPath" -ForegroundColor Cyan
    
    try
    {
        $results | Export-Csv -Path $csvOutputPath -NoTypeInformation -Force
        Write-Host "Export completed successfully. Found $assignedConfigurations device configurations assigned to group: $GroupDisplayName" -ForegroundColor Green
    }
    catch
    {
        Write-Error "Failed to export results to CSV: $_"
        exit 1
    }
}
else
{
    Write-Host "No device configurations found assigned to group: $GroupDisplayName" -ForegroundColor Yellow
}
#endregion

Write-Verbose "Script completed successfully"
Write-Host "Process completed. CSV file available at: $csvOutputPath" -ForegroundColor Green
