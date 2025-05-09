[CmdletBinding()]
param
(
    $configFile = "$pwd\.secrets\config.json",
    $csvOutputPath = "$pwd\DeviceConfigurationAssignments.csv"
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
$scopes = "offline_access Device.ReadWrite.All DeviceManagementApps.Read.All DeviceManagementConfiguration.ReadWrite.All"

# Define API endpoint URIs
$deviceConfigurationUri = "deviceManagement/deviceConfigurations"

Write-Verbose "Getting Graph API access token"
$accessToken = GetGraphAccessToken -configFile $configFile -deligated -scopes $scopes
if (-not $accessToken)
{
    Write-Error "Failed to get access token. Please check your credentials and try again."
    exit 1
}

Write-Verbose "Access token acquired successfully"
#endregion variables

#region Get Windows Device Configurations
Write-Verbose "Getting all device configurations and filtering for Windows types client-side"
Write-Host "Fetching device configurations..." -ForegroundColor Cyan

# Call Graph API to get all device configurations without filtering
$deviceConfigurations = CallGraphApi -ResourcePath $deviceConfigurationUri -accessToken $accessToken -Method GET
if (-not $deviceConfigurations)
{
    Write-Error "Failed to get device configurations."
    exit 1
}

# Filter for Windows configurations client-side
$filteredConfigurations = @{
    value = $deviceConfigurations.value | Where-Object { 
        $_.'@odata.type' -like "*windows*" 
    }
}
$deviceConfigurations = $filteredConfigurations

if ($deviceConfigurations.value.Count -eq 0)
{
    Write-Error "No Windows device configurations found."
    exit 1
}

Write-Verbose "Found $($deviceConfigurations.value.count) Windows device configurations"
Write-Host "Found $($deviceConfigurations.value.count) Windows device configurations" -ForegroundColor Green
#endregion

#region Get Assignments for Each Configuration
Write-Verbose "Getting assignments for each device configuration"
Write-Host "Fetching assignments for each device configuration..." -ForegroundColor Cyan

$results = @()
$uniqueGroupIds = [System.Collections.Generic.HashSet[string]]::new()
$configAssignments = @{}

# First, collect all assignments and unique group IDs
Write-Verbose "Collecting all assignments and unique group IDs..."
foreach ($config in $deviceConfigurations.value)
{
    Write-Verbose "Processing device configuration: $($config.displayName) (ID: $($config.id))"
    Write-Host "Processing: $($config.displayName)" -ForegroundColor Yellow

    # Construct assignment URI for this configuration
    $deviceConfigurationAssignmentUri = "deviceManagement/deviceConfigurations/$($config.id)/assignments"
    Write-Verbose "Assignment URI: $deviceConfigurationAssignmentUri"    # Call Graph API to get assignments
    try
    {
        $assignments = CallGraphApi -ResourcePath $deviceConfigurationAssignmentUri -accessToken $accessToken -Method GET
        
        if ($assignments)
        {
            # Store assignments for this configuration
            $configAssignments[$config.id] = @{
                Config      = $config
                Assignments = $assignments.value
            }
            
            Write-Verbose "Retrieved $($assignments.value.count) assignments for this configuration"
        }
        else
        {
            Write-Warning "Unable to retrieve assignments for configuration: $($config.displayName) (ID: $($config.id))"
            $configAssignments[$config.id] = @{
                Config      = $config
                Assignments = @()
            }
        }
    }
    catch
    {
        Write-Warning "Error retrieving assignments for configuration: $($config.displayName) (ID: $($config.id)) - $_"
        $configAssignments[$config.id] = @{
            Config      = $config
            Assignments = @()
        }
    }

    # Collect unique group IDs
    foreach ($assignment in $assignments.value)
    {
        if ($assignment.target.groupId)
        {
            [void]$uniqueGroupIds.Add($assignment.target.groupId)
        }
    }
}

# Get group details in bulk if there are group IDs to lookup
$groupLookup = @{}
if ($uniqueGroupIds.Count -gt 0)
{
    Write-Verbose "Found $($uniqueGroupIds.Count) unique group IDs to look up"
    Write-Host "Looking up information for $($uniqueGroupIds.Count) groups..." -ForegroundColor Cyan
    # Fetch group details in batches to avoid URL length limitations
    $batchSize = 15  # Reduced batch size for safety with URL length limits
    $groupIdList = $uniqueGroupIds | ForEach-Object { $_ }
    
    for ($i = 0; $i -lt $groupIdList.Count; $i += $batchSize)
    {
        $batchIds = $groupIdList[$i..([Math]::Min($i + $batchSize - 1, $groupIdList.Count - 1))]
        Write-Verbose "Processing batch of $($batchIds.Count) groups (batch $(($i/$batchSize) + 1))"
        
        # Create filter to get multiple groups in one call - properly format and escape each ID
        $filterParts = @()
        foreach ($id in $batchIds)
        {
            $escapedId = $id.Replace("'", "''")  # Escape single quotes in IDs if any
            $filterParts += "id eq '$escapedId'"
        }
        $groupFilter = $filterParts -join " or "
        Write-Verbose "Group filter: $groupFilter"
        try
        {
            $groups = CallGraphApi -ResourcePath "groups" -accessToken $accessToken -Method GET -Filter $groupFilter
            
            if ($groups -and $groups.value)
            {
                foreach ($group in $groups.value)
                {
                    $groupLookup[$group.id] = $group.displayName
                    Write-Verbose "Cached group: $($group.id) = $($group.displayName)"
                }
                
                # Check if we might have missed any groups in this batch
                $missingGroups = $batchIds | Where-Object { -not $groupLookup.ContainsKey($_) }
                if ($missingGroups.Count -gt 0)
                {
                    Write-Warning "Some groups were not found in the API response: $($missingGroups.Count) missing"
                    foreach ($missingId in $missingGroups)
                    {
                        Write-Verbose "Missing group ID: $missingId"
                        $groupLookup[$missingId] = "Group Not Found"
                    }
                }
            }
            else
            {
                Write-Warning "No groups returned for batch $(($i/$batchSize) + 1). Check filter syntax or permissions."
                # Add placeholder entries for this batch
                foreach ($id in $batchIds)
                {
                    $groupLookup[$id] = "Group Lookup Failed"
                }
            }
        }
        catch
        {
            Write-Warning "Error looking up groups in batch $(($i/$batchSize) + 1): $_"
            # Add placeholder entries for this batch
            foreach ($id in $batchIds)
            {
                $groupLookup[$id] = "Error Looking Up Group"
            }
        }
    }
    
    Write-Verbose "Successfully cached display names for $($groupLookup.Count) groups"
}

# Now process all configurations and their assignments using the cached group information
Write-Verbose "Processing all configuration assignments with cached group information"
foreach ($configId in $configAssignments.Keys)
{
    $config = $configAssignments[$configId].Config
    $assignments = $configAssignments[$configId].Assignments
    
    if ($assignments -and $assignments.Count -gt 0)
    {
        foreach ($assignment in $assignments)
        {
            $targetGroupId = $assignment.target.groupId
            $targetGroupDisplayName = "Not found"
            
            if ($targetGroupId)
            {
                # Look up group name from our cached information
                if ($groupLookup.ContainsKey($targetGroupId))
                {
                    $targetGroupDisplayName = $groupLookup[$targetGroupId]
                    Write-Verbose "Found group display name in cache: $targetGroupDisplayName"
                }
                
                # Create result object
                $resultObj = [PSCustomObject]@{
                    ConfigurationId   = $config.id
                    ConfigurationName = $config.displayName
                    ConfigurationType = $config.'@odata.type'
                    GroupId           = $targetGroupId
                    GroupName         = $targetGroupDisplayName
                    AssignmentType    = $assignment.target.'@odata.type'
                }
                
                $results += $resultObj
                Write-Verbose "Added assignment to results: $($config.displayName) -> $targetGroupDisplayName"
            }
            else
            {
                # Handle assignments without a group ID (like AllDevices or AllUsers)
                $targetType = $assignment.target.'@odata.type' -replace '#microsoft.graph.', ''
                
                $resultObj = [PSCustomObject]@{
                    ConfigurationId   = $config.id
                    ConfigurationName = $config.displayName
                    ConfigurationType = $config.'@odata.type'
                    GroupId           = "N/A"
                    GroupName         = $targetType
                    AssignmentType    = $assignment.target.'@odata.type'
                }
                
                $results += $resultObj
                Write-Verbose "Added assignment to results: $($config.displayName) -> $targetType"
            }
        }
    }
    else
    {
        # Add entry for configurations with no assignments
        $resultObj = [PSCustomObject]@{
            ConfigurationId   = $config.id
            ConfigurationName = $config.displayName
            ConfigurationType = $config.'@odata.type'
            GroupId           = "None"
            GroupName         = "No assignments"
            AssignmentType    = "None"
        }
        
        $results += $resultObj
        Write-Verbose "Added configuration with no assignments to results: $($config.displayName)"
    }
}
#endregion

#region Export results to CSV
Write-Verbose "Exporting results to CSV file: $csvOutputPath"
Write-Host "Exporting results to: $csvOutputPath" -ForegroundColor Cyan

try
{
    $results | Export-Csv -Path $csvOutputPath -NoTypeInformation -Force
    Write-Host "Export completed successfully. Found $($results.Count) total assignments." -ForegroundColor Green
}
catch
{
    Write-Error "Failed to export results to CSV: $_"
    exit 1
}
#endregion

Write-Verbose "Script completed successfully"
Write-Host "Process completed. CSV file available at: $csvOutputPath" -ForegroundColor Green
