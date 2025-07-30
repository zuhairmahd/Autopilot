function GetAppAssignmentTypes()
{
    [cmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(ParameterSetName = 'Export')]
        [switch]$Export,
        [Parameter(Mandatory = $true, ParameterSetName = 'Export')]
        [string]$outputPath,
        [Parameter(ParameterSetName = 'Export')]
        [ValidateSet('Append', 'Overwrite')]
        [string]$fileMode = 'overwrite'
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #write a verbose log of received parameters
    Write-Verbose "[$functionName] Starting function with parameters: AccessToken, Export: $Export, outputPath: $outputPath, fileMode: $fileMode"
    Write-Log -logFile $logFile -Module $functionName -Message "Starting function with parameters: AccessToken, Export: $Export, outputPath: $outputPath, fileMode: $fileMode." -LogLevel "Information"
    # Create a cache for group information to avoid repeated API calls
    $groupCache = @{}
    Write-Verbose "[$functionName] Initialized group cache."
    Write-Log -logFile $logFile -Module $functionName -Message "Initialized group cache." -LogLevel "Debug"
    
    # Function to get group display name (uses cache when possible)
    function GetGroupDisplayName
    {
        param (
            [string]$groupId
        )
        $functionName = $MyInvocation.MyCommand.Name    
        Write-Verbose "[$functionName] Called with groupId: $groupId"
        Write-Log -logFile $logFile -Module $functionName -Message "Called GetGroupDisplayName with groupId: $groupId" -LogLevel "Debug"
        # Return from cache if available
        if ($groupCache.ContainsKey($groupId))
        {
            Write-Verbose "[$functionName] Using cached group info for ID: $groupId"
            Write-Log -logFile $logFile -Module $functionName -Message "Using cached group info for ID: $groupId" -LogLevel "Debug"
            return $groupCache[$groupId]
        }
        
        # Otherwise fetch from Graph API and add to cache
        $groupUri = "groups/$groupId"
        $extraparameters = "select=displayName"
        Write-Verbose "[$functionName] Fetching group info for ID: $groupId"
        Write-Log -logFile $logFile -Module $functionName -Message "Fetching group info for ID: $groupId" -LogLevel "Debug"
        $groupResult = CallGraphApi -ResourcePath $groupUri -accessToken $AccessToken -apiVersion 'v1.0' -extraparameters $extraparameters
        Write-Verbose "[$functionName] Group result: $($groupResult | Out-String)"
        Write-Log -logFile $logFile -Module $functionName -Message "Group result: $($groupResult | Out-String)" -LogLevel "Debug"
        
        if ($groupResult.displayName)
        {
            Write-Verbose "[$functionName] Caching displayName: $($groupResult.displayName) for groupId: $groupId"
            Write-Log -logFile $logFile -Module $functionName -Message "Caching displayName: $($groupResult.displayName) for groupId: $groupId" -LogLevel "Debug"
            # Store in cache for future use
            $groupCache[$groupId] = $groupResult.displayName
            return $groupResult.displayName
        }
        else
        {
            Write-Verbose "[$functionName] No displayName found for groupId: $groupId, returning 'unassigned'"
            Write-Log -logFile $logFile -Module $functionName -Message "No displayName found for groupId: $groupId, returning 'unassigned'" -LogLevel "Warning"
            return 'unassigned'
        }
    }
    
    # Step 1: Get all mobile apps with $expand parameter to include assignments in the same call
    $managedAppUri = "deviceAppManagement/mobileApps"
    $extraParameters = "expand=assignments"
    Write-Verbose "[$functionName] Getting all apps with assignments in a single call: $($managedAppUri)"
    Write-Log -logFile $logFile -Module $functionName -Message "Getting all apps with assignments in a single call: $managedAppUri" -LogLevel "Information"
    
    # Get all apps with their assignments in a single API call
    $apps = CallGraphApi -ResourcePath $managedAppUri -accessToken $AccessToken -apiVersion 'v1.0' -extraParameters $extraParameters
    Write-Verbose "[$functionName] Found $($apps.value.count) apps in Intune."
    Write-Log -logFile $logFile -Module $functionName -Message "Found $($apps.value.count) apps in Intune." -LogLevel "Information"
    
    # Track results
    $assignmentResults = @()
    $requiredApps = @()
    $availableApps = @()
    $unassignedApps = @()
    Write-Verbose "[$functionName] Initialized result arrays."
    Write-Log -logFile $logFile -Module $functionName -Message "Initialized result arrays for assignments." -LogLevel "Debug"
    
    # Step 2: Create a list of all unique groupIds to fetch in batch
    $allGroupIds = @{}
    Write-Verbose "[$functionName] Collecting all unique groupIds from app assignments."
    Write-Log -logFile $logFile -Module $functionName -Message "Collecting all unique groupIds from app assignments." -LogLevel "Debug"
    foreach ($app in $apps.value)
    {
        if ($app.assignments)
        {
            foreach ($assignment in $app.assignments)
            {
                if ($assignment.target.groupId)
                {
                    Write-Verbose "[$functionName] Found groupId: $($assignment.target.groupId) for app: $($app.displayName)"
                    Write-Log -logFile $logFile -Module $functionName -Message "Found groupId: $($assignment.target.groupId) for app: $($app.displayName)" -LogLevel "Debug"
                    $allGroupIds[$assignment.target.groupId] = $true
                }
            }
        }
    }
    Write-Verbose "[$functionName] Total unique groupIds collected: $($allGroupIds.Keys.Count)"
    Write-Log -logFile $logFile -Module $functionName -Message "Total unique groupIds collected: $($allGroupIds.Keys.Count)" -LogLevel "Debug"
    
    # Step 3: Prefetch group info for all groups in batch (if supported by your GraphAPI implementation)
    Write-Verbose "[$functionName] Pre-fetching information for $($allGroupIds.Keys.Count) groups"
    Write-Log -logFile $logFile -Module $functionName -Message "Pre-fetching information for $($allGroupIds.Keys.Count) groups" -LogLevel "Debug"
    foreach ($groupId in $allGroupIds.Keys)
    {
        Write-Verbose "[$functionName] Pre-fetching groupId: $groupId"
        Write-Log -logFile $logFile -Module $functionName -Message "Pre-fetching groupId: $groupId" -LogLevel "Debug"
        # Populate cache - calls the inner function that handles caching
        GetGroupDisplayName -groupId $groupId | Out-Null
    }
    
    # Step 4: Process each app
    foreach ($app in $apps.value)
    {
        Write-Verbose "[$functionName] Processing app: $($app.displayName) (id: $($app.id))"
        Write-Log -logFile $logFile -Module $functionName -Message "Processing app: $($app.displayName) (id: $($app.id))" -LogLevel "Debug"
        $assignedGroups = @()
        
        # Process app assignments (if any)
        $hasAssignments = $false
        if ($app.assignments -and $app.assignments.Count -gt 0)
        {
            $hasAssignments = $true
            Write-Verbose "[$functionName] App has $($app.assignments.Count) assignments."
            Write-Log -logFile $logFile -Module $functionName -Message "App has $($app.assignments.Count) assignments." -LogLevel "Debug"
            foreach ($assignment in $app.assignments)
            {
                if ($assignment.target.groupId)
                {
                    $groupName = GetGroupDisplayName -groupId $assignment.target.groupId
                    Write-Verbose "[$functionName] Assignment groupId: $($assignment.target.groupId), groupName: $groupName"
                    Write-Log -logFile $logFile -Module $functionName -Message "Assignment groupId: $($assignment.target.groupId), groupName: $groupName" -LogLevel "Debug"
                    $assignedGroups += $groupName
                }
                else
                {
                    Write-Verbose "[$functionName] Assignment has no groupId, marking as 'unassigned'"
                    Write-Log -logFile $logFile -Module $functionName -Message "Assignment has no groupId, marking as 'unassigned'" -LogLevel "Warning"
                    $assignedGroups += 'unassigned'
                }
            }
        }
        else
        {
            Write-Verbose "[$functionName] App has no assignments, marking as 'unassigned'"
            Write-Log -logFile $logFile -Module $functionName -Message "App has no assignments, marking as 'unassigned'" -LogLevel "Warning"
            $assignedGroups += 'unassigned'
        }
        # Create app object
        $appObject = [PSCustomObject]@{
            id                     = $app.id
            type                   = ($app."@odata.type" -replace '#Microsoft.Graph.', '')
            displayName            = $app.displayName
            AssignedGroups         = $assignedGroups | Out-String
            assignedGroupCount     = $assignedGroups.Count
            assignmentResultObject = if ($app.assignments) { $app.assignments | Out-String } else { "No assignments" }
            applicableDeviceType   = if ($app.applicableDeviceType.iPhoneAndIPod -and $app.applicableDeviceType.iPad) { 'iPad and iPhone' } elseif ($app.applicableDeviceType.iPad) { 'iPad' } elseif ($app.applicableDeviceType.iPhoneAndIPod) { 'iPhone' } else { "" }
        }
        Write-Verbose "[$functionName] App object created: $($appObject | Out-String)"
        Write-Log -logFile $logFile -Module $functionName -Message "App object created: $($appObject | Out-String)" -LogLevel "Debug"
        
        # Categorize the app based on assignment intent
        if (-not $hasAssignments)
        {
            Write-Verbose "[$functionName] $($app.displayName) is unassigned."
            Write-Log -logFile $logFile -Module $functionName -Message "$($app.displayName) is unassigned." -LogLevel "Information"
            $unassignedApps += $appObject
        }
        elseif ($app.assignments.intent -contains 'required')
        {
            Write-Verbose "[$functionName] $($app.displayName) is a required app."
            Write-Log -logFile $logFile -Module $functionName -Message "$($app.displayName) is a required app." -LogLevel "Information"
            $requiredApps += $appObject
        }
        elseif ($app.assignments.intent -match 'available')
        {
            Write-Verbose "[$functionName] $($app.displayName) is an available app."
            Write-Log -logFile $logFile -Module $functionName -Message "$($app.displayName) is an available app." -LogLevel "Information"
            $availableApps += $appObject
        }
        else
        {
            Write-Verbose "[$functionName] $($app.displayName) has assignments but unclear intent."
            Write-Log -logFile $logFile -Module $functionName -Message "$($app.displayName) has assignments but unclear intent." -LogLevel "Warning"
            $unassignedApps += $appObject
        }
        
        $assignmentResults += $appObject
    }
    
    # Create the return object
    $returnedApps = [PSCustomObject]@{
        RequiredApps   = $requiredApps
        AvailableApps  = $availableApps
        UnassignedApps = $unassignedApps
        AllApps        = $assignmentResults
    }
    Write-Verbose "[$functionName] Created return object."
    Write-Log -logFile $logFile -Module $functionName -Message "Created return object for app assignments." -LogLevel "Debug"
    
    # Output stats
    Write-Host "Total number of apps: $($apps.value.count)" -ForegroundColor Green
    Write-Host "Total number of required apps: $($requiredApps.count)"
    Write-Host "Total number of available apps: $($availableApps.count)"
    Write-Host "Total number of unassigned apps: $($unassignedApps.count)"
    Write-Verbose "[$functionName] Output stats displayed."
    Write-Log -logFile $logFile -Module $functionName -Message "Output stats displayed." -LogLevel "Debug"
    
    # Export if requested
    if ($export)
    {
        Write-Verbose "[$functionName] Export requested."
        Write-Log -logFile $logFile -Module $functionName -Message "Export requested." -LogLevel "Information"
        $date = (Get-Date -Format "yyyyMMdd-HHmmss")
        $exportSuccessful = $false
        $csvPath = "$outputPath\$appReport-$date.csv"
        Write-Verbose "[$functionName] Preparing export data."
        Write-Log -logFile $logFile -Module $functionName -Message "Preparing export data for required, available, and unassigned apps." -LogLevel "Debug"

        # Combine all apps for export and add a category column
        $allAppsForExport = @()
        
        # Add required apps with category
        foreach ($app in $requiredApps)
        {
            $exportApp = [PSCustomObject]@{
                Intent               = "Required"
                id                   = $app.id
                type                 = $app.type
                displayName          = $app.displayName
                applicableDeviceType = $app.applicableDeviceType
                AssignedGroups       = $app.AssignedGroups
                assignedGroupCount   = $app.assignedGroupCount
            }
            $allAppsForExport += $exportApp
        }
        
        # Add available apps with category
        foreach ($app in $availableApps)
        {
            $exportApp = [PSCustomObject]@{
                Intent               = "Available"
                id                   = $app.id
                type                 = $app.type
                displayName          = $app.displayName
                applicableDeviceType = $app.applicableDeviceType
                AssignedGroups       = $app.AssignedGroups
                assignedGroupCount   = $app.assignedGroupCount
            }
            $allAppsForExport += $exportApp
        }
        
        # Add unassigned apps with category
        foreach ($app in $unassignedApps)
        {
            $exportApp = [PSCustomObject]@{
                Intent               = "Unassigned"
                id                   = $app.id
                type                 = $app.type
                displayName          = $app.displayName
                applicableDeviceType = $app.applicableDeviceType
                AssignedGroups       = $app.AssignedGroups
                assignedGroupCount   = $app.assignedGroupCount
            }
            $allAppsForExport += $exportApp
        }
        
        # Export all apps to CSV
        if ($allAppsForExport.Count -gt 0)
        {
            Write-Verbose "[$functionName] Exporting $($allAppsForExport.Count) total apps to $csvPath"
            Write-Log -logFile $logFile -Module $functionName -Message "Exporting $($allAppsForExport.Count) total apps to $csvPath" -LogLevel "Information"
            if ($fileMode -eq 'Append' -and (Test-Path $csvPath))
            {
                Write-Verbose "[$functionName] Appending to existing CSV file."
                Write-Log -logFile $logFile -Module $functionName -Message "Appending to existing CSV file." -LogLevel "Debug"
                $allAppsForExport | Export-Csv -Path $csvPath -NoTypeInformation -Append
            }
            else
            {
                Write-Verbose "[$functionName] Overwriting existing CSV file."
                Write-Log -logFile $logFile -Module $functionName -Message "Overwriting existing CSV file." -LogLevel "Debug"
                $allAppsForExport | Export-Csv -Path $csvPath -NoTypeInformation
            }
            Write-Host "Exported $($allAppsForExport.Count) apps to $csvPath" -ForegroundColor Green
            if (Test-Path $csvPath)
            {
                Write-Verbose "[$functionName] CSV file created successfully."
                Write-Log -logFile $logFile -Module $functionName -Message "CSV file created successfully at $csvPath." -LogLevel "Information"
                $exportSuccessful = $true
            }
        }
        else
        {
            Write-Verbose "[$functionName] No apps to export"
            Write-Log -logFile $logFile -Module $functionName -Message "No apps to export" -LogLevel "Warning"
            Write-Host "No apps found to export" -ForegroundColor Yellow
            $exportSuccessful = $false
        }
        
        Write-Verbose "[$functionName] Export complete."
        Write-Log -logFile $logFile -Module $functionName -Message "Export complete to $csvPath" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] No export requested."
        Write-Log -logFile $logFile -Module $functionName -Message "No export requested." -LogLevel "Debug"
    }
    
    Write-Verbose "[$functionName] Returning result object."
    Write-Log -logFile $logFile -Module $functionName -Message "Returning result object from GetAppAssignmentTypes." -LogLevel "Debug"
    return $exportSuccessful, $returnedApps
}
