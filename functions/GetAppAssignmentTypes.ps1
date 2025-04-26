function GetAppAssignmentTypes()
{
    [cmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [switch]$Export
    )
    
    # Create a cache for group information to avoid repeated API calls
    $groupCache = @{}
    
    # Function to get group display name (uses cache when possible)
    function GetGroupDisplayName {
        param (
            [string]$groupId
        )
        
        # Return from cache if available
        if ($groupCache.ContainsKey($groupId)) {
            Write-Verbose "Using cached group info for ID: $groupId"
            return $groupCache[$groupId]
        }
        
        # Otherwise fetch from Graph API and add to cache
        $groupUri = "groups/$groupId"
        $extraparameters = "select=displayName"
        Write-Verbose "Fetching group info for ID: $groupId"
        $groupResult = CallGraphApi -ResourcePath $groupUri -accessToken $AccessToken -apiVersion 'v1.0' -extraparameters $extraparameters
        
        if ($groupResult.displayName) {
            # Store in cache for future use
            $groupCache[$groupId] = $groupResult.displayName
            return $groupResult.displayName
        }
        else {
            return 'unassigned'
        }
    }
    
    # Step 1: Get all mobile apps with $expand parameter to include assignments in the same call
    $managedAppUri = "deviceAppManagement/mobileApps"
    $extraParameters = "expand=assignments"
    Write-Verbose "Getting all apps with assignments in a single call: $($managedAppUri)"
    
    # Get all apps with their assignments in a single API call
    $apps = CallGraphApi -ResourcePath $managedAppUri -accessToken $AccessToken -apiVersion 'v1.0' -extraParameters $extraParameters
    Write-Verbose "Found $($apps.value.count) apps in Intune."
    
    # Track results
    $assignmentResults = @()
    $requiredApps = @()
    $availableApps = @()
    $unassignedApps = @()
    
    # Step 2: Create a list of all unique groupIds to fetch in batch
    $allGroupIds = @{}
    foreach ($app in $apps.value) {
        if ($app.assignments) {
            foreach ($assignment in $app.assignments) {
                if ($assignment.target.groupId) {
                    $allGroupIds[$assignment.target.groupId] = $true
                }
            }
        }
    }
    
    # Step 3: Prefetch group info for all groups in batch (if supported by your GraphAPI implementation)
    Write-Verbose "Pre-fetching information for ${$allGroupIds.Keys.Count} groups"
    foreach ($groupId in $allGroupIds.Keys) {
        # Populate cache - calls the inner function that handles caching
        GetGroupDisplayName -groupId $groupId | Out-Null
    }
    
    # Step 4: Process each app
    foreach ($app in $apps.value) {
        Write-Verbose "Processing app: $($app.displayName)"
        $assignedGroups = @()
        
        # Process app assignments (if any)
        $hasAssignments = $false
        if ($app.assignments -and $app.assignments.Count -gt 0) {
            $hasAssignments = $true
            
            foreach ($assignment in $app.assignments) {
                if ($assignment.target.groupId) {
                    $groupName = GetGroupDisplayName -groupId $assignment.target.groupId
                    $assignedGroups += $groupName
                }
                else {
                    $assignedGroups += 'unassigned'
                }
            }
        }
        else {
            $assignedGroups += 'unassigned'
        }
        
        # Create app object
        $appObject = [ordered] @{
            id                     = $app.id
            displayName            = $app.displayName
            AssignedGroups         = $assignedGroups | Out-String
            assignedGroupCount     = $assignedGroups.Count
            assignmentResultObject = if ($app.assignments) { $app.assignments | Out-String } else { "No assignments" }
        }
        
        # Categorize the app based on assignment intent
        if (-not $hasAssignments) {
            Write-Verbose "$($app.displayName) is unassigned."
            $unassignedApps += $appObject
        }
        elseif ($app.assignments.intent -contains 'required') {
            Write-Verbose "$($app.displayName) is a required app."
            $requiredApps += $appObject
        }
        elseif ($app.assignments.intent -match 'available') {
            Write-Verbose "$($app.displayName) is an available app."
            $availableApps += $appObject
        }
        else {
            Write-Verbose "$($app.displayName) has assignments but unclear intent."
            $unassignedApps += $appObject
        }
        
        $assignmentResults += $appObject
    }
    
    # Create the return object
    $returnedApps = [ordered] @{
        RequiredApps   = $requiredApps
        AvailableApps  = $availableApps
        UnassignedApps = $unassignedApps
        AllApps        = $assignmentResults
    }
    
    # Output stats
    Write-Host "Total number of apps: $($apps.value.count)" -ForegroundColor Green
    Write-Host "Total number of required apps: $($requiredApps.count)"
    Write-Host "Total number of available apps: $($availableApps.count)"
    Write-Host "Total number of unassigned apps: $($unassignedApps.count)"
    
    # Export if requested
    if ($export)
    {
        $date = Get-Date -Format "yyyyMMdd"
        $csvPath = "app-assignment-report-$date.csv"
        $requiredApps | Export-Csv -Path $csvPath -NoTypeInformation
        $availableApps | Export-Csv -Path $csvPath -NoTypeInformation -Append
        $unassignedApps | Export-Csv -Path $csvPath -NoTypeInformation -Append
        Write-Host "Exported the list of apps to $csvPath" -ForegroundColor Green
    }
    else
    {
        Write-Verbose "No export requested."
    }
    
    return $returnedApps
}