# Common functions and utilities for GetGroupDirectAssignments and GetGroupIndirectAssignments
# This module contains shared code to reduce duplication and improve maintainability

function Initialize-AssignmentResultObject()
{
    <#
    .SYNOPSIS
    Creates a standardized assignment result object structure.
    
    .DESCRIPTION
    Initializes a PSCustomObject with all assignment category arrays and metadata.
    This ensures consistent structure across both direct and indirect assignment functions.
    
    .PARAMETER GroupName
    Optional group display name for direct assignments.
    
    .PARAMETER GroupId
    Optional group ID for direct assignments.
    
    .EXAMPLE
    $result = Initialize-AssignmentResultObject -GroupName "IT Admins" -GroupId "abc-123"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GroupName,
        [Parameter(Mandatory = $false)]
        [string]$GroupId
    )
    
    $resultObject = [PSCustomObject]@{
        AppAssignments                          = @()
        ConfigurationAssignments                = @()
        ComplianceAssignments                   = @()
        AutopilotAssignments                    = @()
        ScriptAssignments                       = @()
        HealthScriptAssignments                 = @()
        AppProtectionAssignments                = @()
        IntentAssignments                       = @()
        ResourceAccessAssignments               = @()
        ConfigurationPolicyAssignments          = @()
        GroupPolicyAssignments                  = @()
        WindowsInformationProtectionAssignments = @()
        PolicySetAssignments                    = @()
        AllAssignments                          = @()
        FailedResources                         = @()
    }
    
    # Add group-specific properties if provided
    if ($GroupName)
    {
        $resultObject | Add-Member -NotePropertyName 'GroupName' -NotePropertyValue $GroupName -Force
    }
    if ($GroupId)
    {
        $resultObject | Add-Member -NotePropertyName 'GroupId' -NotePropertyValue $GroupId -Force
    }
    
    return $resultObject
}

function Test-IsAllUsersAllDevicesAssignment()
{
    <#
    .SYNOPSIS
    Tests if an assignment targets All Users or All Devices virtual groups.
    
    .DESCRIPTION
    Checks if the assignment target is either allLicensedUsersAssignmentTarget or allDevicesAssignmentTarget.
    
    .PARAMETER Assignment
    The assignment object to test.
    
    .RETURNS
    Boolean - $true if the assignment targets All Users or All Devices, $false otherwise.
    
    .EXAMPLE
    if (Test-IsAllUsersAllDevicesAssignment -Assignment $assignment) { ... }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Assignment
    )
    
    $targetType = $Assignment.target.'@odata.type'
    return ($targetType -eq '#microsoft.graph.allDevicesAssignmentTarget' -or 
        $targetType -eq '#microsoft.graph.allLicensedUsersAssignmentTarget')
}

function Test-IsGroupAssignment()
{
    <#
    .SYNOPSIS
    Tests if an assignment targets a specific group (not All Users/All Devices).
    
    .DESCRIPTION
    Checks if the assignment target is groupAssignmentTarget.
    
    .PARAMETER Assignment
    The assignment object to test.
    
    .RETURNS
    Boolean - $true if the assignment targets a specific group, $false otherwise.
    
    .EXAMPLE
    if (Test-IsGroupAssignment -Assignment $assignment) { ... }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Assignment
    )
    
    return ($Assignment.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget')
}

function Test-HasRealAssignment()
{
    <#
    .SYNOPSIS
    Tests if a resource has any real assignment (group, All Users, or All Devices).
    
    .DESCRIPTION
    According to requirements:
    - A resource is "assigned" if it has ANY of the following:
      * Direct group assignment
      * All Users assignment
      * All Devices assignment
    - For apps, any intent (Required, Available, Uninstall) counts as assigned
    
    .PARAMETER Assignments
    Array of assignment objects for the resource.
    
    .PARAMETER ResourceName
    Optional resource name for detailed logging.
    
    .PARAMETER ResourceCategory
    Optional resource category for detailed logging.
    
    .RETURNS
    Boolean - $true if the resource has at least one real assignment, $false otherwise.
    
    .EXAMPLE
    if (Test-HasRealAssignment -Assignments $assignmentData.value -ResourceName "MyApp" -ResourceCategory "Application") { ... }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Assignments,
        [Parameter(Mandatory = $false)]
        [string]$ResourceName,
        [Parameter(Mandatory = $false)]
        [string]$ResourceCategory
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $logPrefix = if ($ResourceName) { "[$ResourceName]" } else { "" }
    
    if (-not $Assignments -or $Assignments.Count -eq 0)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "$logPrefix No assignments provided (empty or null)" -logLevel "Debug"
        return $false
    }
    
    Write-Log -logFile $LogFile -module $functionName -Message "$logPrefix Checking $($Assignments.Count) assignment(s) for real assignments (Category: $ResourceCategory)" -logLevel "Debug"
    
    # Check if any assignment is a group, All Users, or All Devices
    $assignmentIndex = 0
    foreach ($assignment in $Assignments)
    {
        $assignmentIndex++
        $targetType = $assignment.target.'@odata.type'
        $intent = $assignment.intent
        
        Write-Log -logFile $LogFile -module $functionName -Message "$logPrefix Assignment #$assignmentIndex - TargetType: '$targetType', Intent: '$intent'" -logLevel "Debug"
        
        # Check for group assignment
        if (Test-IsGroupAssignment -Assignment $assignment)
        {
            $groupId = $assignment.target.groupId
            Write-Log -logFile $LogFile -module $functionName -Message "$logPrefix FOUND real assignment - Group assignment (GroupId: $groupId)" -logLevel "Information"
            return $true
        }
        
        # Check for All Users/All Devices
        if (Test-IsAllUsersAllDevicesAssignment -Assignment $assignment)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "$logPrefix FOUND real assignment - All Users/All Devices (TargetType: $targetType)" -logLevel "Information"
            return $true
        }
        
        Write-Log -logFile $LogFile -module $functionName -Message "$logPrefix Assignment #$assignmentIndex is NOT a real assignment (unknown target type: $targetType)" -logLevel "Debug"
    }
    
    Write-Log -logFile $LogFile -module $functionName -Message "$logPrefix NO real assignments found after checking all $($Assignments.Count) assignment(s)" -logLevel "Information"
    return $false
}

function Test-HasGroupAndIndirectAssignment()
{
    <#
    .SYNOPSIS
    Tests if a resource has both a specific group assignment AND All Users/All Devices assignment.
    
    .DESCRIPTION
    Used for indirect assignment filtering when a group name is specified.
    Returns true only if the resource has assignments to BOTH:
    - The specified group (by groupId)
    - All Users or All Devices
    
    .PARAMETER Assignments
    Array of assignment objects for the resource.
    
    .PARAMETER GroupId
    The group ID to check for.
    
    .RETURNS
    Boolean - $true if resource has both group and All Users/All Devices assignments, $false otherwise.
    
    .EXAMPLE
    if (Test-HasGroupAndIndirectAssignment -Assignments $assignmentData.value -GroupId $groupId) { ... }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Assignments,
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )
    
    if (-not $Assignments -or $Assignments.Count -eq 0)
    {
        return $false
    }
    
    $hasGroupAssignment = $false
    $hasAllUsersOrAllDevices = $false
    
    foreach ($assignment in $Assignments)
    {
        # Check for the specific group
        if (Test-IsGroupAssignment -Assignment $assignment)
        {
            if ($assignment.target.groupId -eq $GroupId)
            {
                $hasGroupAssignment = $true
            }
        }
        
        # Check for All Users/All Devices
        if (Test-IsAllUsersAllDevicesAssignment -Assignment $assignment)
        {
            $hasAllUsersOrAllDevices = $true
        }
        
        # Early exit if we found both
        if ($hasGroupAssignment -and $hasAllUsersOrAllDevices)
        {
            return $true
        }
    }
    
    return ($hasGroupAssignment -and $hasAllUsersOrAllDevices)
}

function Get-ResourceListEndpoints()
{
    <#
    .SYNOPSIS
    Defines the standard resource list endpoints for batch API calls.
    
    .DESCRIPTION
    Returns an array of endpoint definitions including v1.0 and optional beta endpoints.
    Ensures consistency between direct and indirect assignment functions.
    
    .PARAMETER IncludeBeta
    Switch to include beta API endpoints.
    
    .EXAMPLE
    $endpoints = Get-ResourceListEndpoints -IncludeBeta
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeBeta
    )
    
    # Standard v1.0 endpoints
    $resourceEndpoints = @(
        @{ id = "mobileApps"; url = "deviceAppManagement/mobileApps"; extraParams = "`$select=id,displayName,description" }
        @{ id = "deviceConfigs"; url = "deviceManagement/deviceConfigurations"; extraParams = "`$select=id,displayName,description" }
        @{ id = "compliancePolicies"; url = "deviceManagement/deviceCompliancePolicies"; extraParams = "`$select=id,displayName,description" }
        @{ id = "deviceScripts"; url = "deviceManagement/deviceManagementScripts"; extraParams = "`$select=id,displayName,description" }
        @{ id = "appProtectionPolicies"; url = "deviceAppManagement/managedAppPolicies"; extraParams = "`$select=id,displayName,description" }
        @{ id = "intents"; url = "deviceManagement/intents"; extraParams = "`$select=id,displayName,description" }
        @{ id = "resourceAccessProfiles"; url = "deviceManagement/resourceAccessProfiles"; extraParams = "`$select=id,displayName,description" }
        @{ id = "policySets"; url = "deviceAppManagement/policySets"; extraParams = "`$select=id,displayName,description" }
    )

    # Add beta endpoints if requested
    if ($IncludeBeta.IsPresent)
    {
        $resourceEndpoints += @(
            @{ id = "autopilotProfiles"; url = "deviceManagement/windowsAutopilotDeploymentProfiles"; extraParams = "`$select=id,displayName,description" }
            @{ id = "healthScripts"; url = "deviceManagement/deviceHealthScripts"; extraParams = "`$select=id,displayName,description" }
            @{ id = "configurationPolicies"; url = "deviceManagement/configurationPolicies"; extraParams = "`$select=id,name,description" }
            @{ id = "groupPolicyConfigs"; url = "deviceManagement/groupPolicyConfigurations"; extraParams = "`$select=id,displayName,description" }
            @{ id = "wipPolicies"; url = "deviceAppManagement/windowsInformationProtectionPolicies"; extraParams = "`$select=id,displayName,description" }
            @{ id = "mdmWipPolicies"; url = "deviceAppManagement/mdmWindowsInformationProtectionPolicies"; extraParams = "`$select=id,displayName,description" }
            @{ id = "windowsFeatureUpdates"; url = "deviceManagement/windowsFeatureUpdateProfiles"; extraParams = "`$select=id,displayName,description" }
            @{ id = "windowsQualityUpdates"; url = "deviceManagement/windowsQualityUpdateProfiles"; extraParams = "`$select=id,displayName,description" }
            @{ id = "windowsDriverUpdates"; url = "deviceManagement/windowsDriverUpdateProfiles"; extraParams = "`$select=id,displayName,description" }
        )
    }
    
    # Windows Update for Business configurations (Update Rings) - available in both v1.0 and beta
    # These are under deviceConfigurations but have @odata.type = windowsUpdateForBusinessConfiguration
    # They are already included in deviceConfigs endpoint above
    
    return $resourceEndpoints
}

function Add-FailedResourceError()
{
    <#
    .SYNOPSIS
    Adds a failed resource error to the result object.
    
    .DESCRIPTION
    Creates a standardized error object and adds it to the FailedResources array.
    This ensures consistent error tracking across all assignment functions.
    
    .PARAMETER ResultObject
    The result object to update with the error.
    
    .PARAMETER ResourceType
    The type of resource that failed (e.g., "resourceAccessProfiles").
    
    .PARAMETER ErrorMessage
    The error message describing the failure.
    
    .PARAMETER StatusCode
    HTTP status code or "N/A" for non-HTTP errors.
    
    .PARAMETER ApiVersion
    API version used (v1.0 or beta).
    
    .EXAMPLE
    Add-FailedResourceError -ResultObject $assignments -ResourceType "resourceAccessProfiles" -ErrorMessage "HTTP 400 error" -StatusCode 400 -ApiVersion "v1.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ResultObject,
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,
        [Parameter(Mandatory = $true)]
        $StatusCode,
        [Parameter(Mandatory = $true)]
        [string]$ApiVersion
    )
    
    $errorObject = [PSCustomObject]@{
        ResourceType = $ResourceType
        ErrorMessage = $ErrorMessage
        StatusCode   = $StatusCode
        ApiVersion   = $ApiVersion
    }
    
    $ResultObject.FailedResources += $errorObject
}

function Apply-PlatformFilter()
{
    <#
    .SYNOPSIS
    Applies platform filtering to resource collections.
    
    .DESCRIPTION
    Filters all resource types based on the target operating system using Test-ResourcePlatformMatch.
    Returns a hashtable with filtered resource collections.
    
    .PARAMETER Resources
    Hashtable containing all resource collections to filter.
    
    .PARAMETER TargetOS
    Target operating system (windows, ios, android, macos, linux).
    
    .EXAMPLE
    $filtered = Apply-PlatformFilter -Resources $allResources -TargetOS "windows"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Resources,
        [Parameter(Mandatory = $true)]
        [string]$TargetOS
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Applying platform filter for OS: $TargetOS" -logLevel "Information"
    
    # Filter each resource type
    $filtered = @{}
    foreach ($key in $Resources.Keys)
    {
        if ($Resources[$key] -and $Resources[$key].Count -gt 0)
        {
            $originalCount = $Resources[$key].Count
            $filtered[$key] = @($Resources[$key] | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $TargetOS })
            $filteredCount = $filtered[$key].Count
            
            if ($filteredCount -lt $originalCount)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Filtered $key from $originalCount to $filteredCount resources for OS: $TargetOS" -logLevel "Verbose"
            }
        }
        else
        {
            $filtered[$key] = @()
        }
    }
    
    return $filtered
}

function New-AssignmentObject()
{
    <#
    .SYNOPSIS
    Creates a standardized assignment object.
    
    .DESCRIPTION
    Constructs a PSCustomObject with consistent property structure for an assignment.
    Used by both direct and indirect assignment processing functions.
    
    .PARAMETER Type
    Assignment category type (Application, Configuration, etc.).
    
    .PARAMETER Name
    Display name of the resource.
    
    .PARAMETER Description
    Description of the resource.
    
    .PARAMETER Id
    Resource ID.
    
    .PARAMETER Intent
    Assignment intent.
    
    .PARAMETER Target
    Assignment target object.
    
    .PARAMETER Settings
    Assignment settings object.
    
    .PARAMETER AssignmentScope
    Assignment scope (Direct, All Users, All Devices, or array).
    
    .EXAMPLE
    $assignment = New-AssignmentObject -Type "Application" -Name "Office 36`5" -Id "abc-123" -Intent "required" -Target $targetObj -AssignmentScope "Direct"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [string]$Description = "",
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $false)]
        $Intent,
        [Parameter(Mandatory = $false)]
        $Target,
        [Parameter(Mandatory = $false)]
        $Settings,
        [Parameter(Mandatory = $true)]
        $AssignmentScope
    )
    
    return [PSCustomObject]@{
        Type            = $Type
        Name            = $Name
        Description     = $Description
        Id              = $Id
        Intent          = $Intent
        Target          = $Target
        Settings        = $Settings
        AssignmentScope = $AssignmentScope
    }
}

function Add-AssignmentToCategory()
{
    <#
    .SYNOPSIS
    Adds an assignment object to the appropriate category in the result object.
    
    .DESCRIPTION
    Routes the assignment to the correct category array based on AssignmentCategory parameter.
    Also adds to AllAssignments array. Ensures consistent categorization logic.
    
    .PARAMETER ResultObject
    The result object containing assignment category arrays.
    
    .PARAMETER Assignment
    The assignment object to add.
    
    .PARAMETER AssignmentCategory
    The category to add the assignment to.
    
    .EXAMPLE
    Add-AssignmentToCategory -ResultObject $assignments -Assignment $assignmentObj -AssignmentCategory "Application"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ResultObject,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Assignment,
        [Parameter(Mandatory = $true)]
        [string]$AssignmentCategory
    )
    
    switch ($AssignmentCategory)
    {
        "Application" { $ResultObject.AppAssignments += $Assignment }
        "Configuration" { $ResultObject.ConfigurationAssignments += $Assignment }
        "Compliance" { $ResultObject.ComplianceAssignments += $Assignment }
        "AutopilotProfile" { $ResultObject.AutopilotAssignments += $Assignment }
        "Script" { $ResultObject.ScriptAssignments += $Assignment }
        "HealthScript" { $ResultObject.HealthScriptAssignments += $Assignment }
        "AppProtection" { $ResultObject.AppProtectionAssignments += $Assignment }
        "Intent" { $ResultObject.IntentAssignments += $Assignment }
        "ResourceAccess" { $ResultObject.ResourceAccessAssignments += $Assignment }
        "ConfigurationPolicy" { $ResultObject.ConfigurationPolicyAssignments += $Assignment }
        "GroupPolicy" { $ResultObject.GroupPolicyAssignments += $Assignment }
        "WindowsInformationProtection" { $ResultObject.WindowsInformationProtectionAssignments += $Assignment }
        "PolicySet" { $ResultObject.PolicySetAssignments += $Assignment }
    }
    
    $ResultObject.AllAssignments += $Assignment
}

function Get-IndirectResourceAssignments()
{
    <#
    .SYNOPSIS
    Processes a set of resources to retrieve their indirect assignments via virtual groups.
    
    .DESCRIPTION
    This helper function iterates over a collection of resources (such as apps, configurations, etc.)
    and retrieves assignments that are indirectly assigned through the "All Users" or "All Devices" virtual groups.
    It is called by the parent function for each resource type and assignment category.
    
    Unlike the parent function, which orchestrates the overall retrieval and aggregation of indirect assignments,
    this helper focuses on processing a specific resource type and category, making API calls and updating the result object.
    
    .PARAMETER ResultObject
    The result object to update with assignments and errors. This ensures proper pass-by-reference behavior.
    
    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.
    
    .PARAMETER ApiVersion
    API version to use (v1.0 or beta).
    
    .PARAMETER Resources
    The array of resources to process for indirect assignments.
    
    .PARAMETER ResourceType
    The type of resource being processed (e.g., App, Configuration).
    
    .PARAMETER BaseUri
    The base URI for the Microsoft Graph API endpoint for the resource type.
    
    .PARAMETER EndpointId
    The endpoint identifier used for dynamic categorization via Get-ResourceCategory.
    
    .PARAMETER GroupId
    Optional. When specified, only returns resources that have assignments to BOTH this group
    AND All Users/All Devices (requirement #2). When not specified, returns ALL resources with
    All Users/All Devices assignments (requirement #3).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ResultObject,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,
        [array]$Resources,
        [string]$ResourceType,
        [string]$BaseUri,
        [string]$EndpointId,
        [Parameter(Mandatory = $false)]
        [string]$GroupId
    )
        
    $functionName = $MyInvocation.MyCommand.Name
    if (-not $Resources -or $Resources.Count -eq 0)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "No ${ResourceType} resources to process" -logLevel "Verbose"
        return
    }
        
    Write-Log -logFile $LogFile -module $functionName -Message "Processing $($Resources.Count) ${ResourceType} resources for indirect assignments" -LogLevel "Verbose"
    # Build array of assignment endpoint paths
    $assignmentPaths = @()
    foreach ($resource in $Resources)
    {
        $assignmentPaths += "$BaseUri/$($resource.id)/assignments"
    }
        
    # Use CallGraphAPI's native batch support with error handling
    try
    {
        $batchResult = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentPaths -APIVersion $apiVersion -Method "GET"
    }
    catch
    {
        $errorMessage = $_.Exception.Message
        Write-Log -logFile $LogFile -module $functionName -Message "Error calling batch API for ${ResourceType}: $errorMessage" -LogLevel "Error"
        
        # Add to failed resources
        Add-FailedResourceError -ResultObject $ResultObject -ResourceType $ResourceType -ErrorMessage $errorMessage -StatusCode "N/A" -ApiVersion $ApiVersion
        return
    }
        
    if ($batchResult -and $batchResult.value)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Processing $($batchResult.value.Count) batch responses for ${ResourceType}" -LogLevel "Verbose"
        for ($i = 0; $i -lt $batchResult.value.Count; $i++)
        {
            $responseData = $batchResult.value[$i]
            $resource = $Resources[$i]
                
            if ($responseData -and $responseData.value)
            {
                $assignmentCount = $responseData.value.Count
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.displayName)' has $assignmentCount assignment(s)" -logLevel "Debug"
                
                # Log all assignment target types for diagnostics
                for ($j = 0; $j -lt $responseData.value.Count; $j++)
                {
                    $assign = $responseData.value[$j]
                    Write-Log -logFile $LogFile -module $functionName -Message "  Assignment #$($j+1) for '$($resource.displayName)': TargetType='$($assign.target.'@odata.type')', Intent='$($assign.intent)'" -logLevel "Debug"
                }
                
                # Check if GroupId filtering is required (requirement #2)
                if ($GroupId)
                {
                    # Mode: Show only resources with BOTH group assignment AND All Users/All Devices
                    Write-Log -logFile $LogFile -module $functionName -Message "Checking if '$($resource.displayName)' has BOTH GroupId '$GroupId' AND All Users/All Devices" -logLevel "Debug"
                    $hasGroupAndIndirect = Test-HasGroupAndIndirectAssignment -Assignments $responseData.value -GroupId $GroupId
                    
                    if (-not $hasGroupAndIndirect)
                    {
                        # Skip this resource - it doesn't have both
                        Write-Log -logFile $LogFile -module $functionName -Message "Skipping '$($resource.displayName)' - does NOT have both GroupId and All Users/All Devices" -logLevel "Debug"
                        continue
                    }
                    Write-Log -logFile $LogFile -module $functionName -Message "Including '$($resource.displayName)' - HAS both GroupId and All Users/All Devices" -logLevel "Information"
                }
                
                # Filter for All Users and All Devices assignments
                $indirectAssignmentTargets = $responseData.value | Where-Object { 
                    $_.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget' -or 
                    $_.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget'
                }
                
                # Log the count of indirect assignments found
                Write-Log -logFile $LogFile -module $functionName -Message "Found $($indirectAssignmentTargets.Count) All Users/All Devices assignment(s) for '$($resource.displayName)'" -logLevel "Debug"
                
                # Skip if no indirect assignments found (shouldn't happen, but defensive)
                if (-not $indirectAssignmentTargets -or $indirectAssignmentTargets.Count -eq 0)
                {
                    continue
                }
                    
                foreach ($assignment in $indirectAssignmentTargets)
                {
                    # Determine assignment scope
                    $assignmentScope = switch ($assignment.target.'@odata.type')
                    {
                        '#microsoft.graph.allLicensedUsersAssignmentTarget' { 'All Users' }
                        '#microsoft.graph.allDevicesAssignmentTarget' { 'All Devices' }
                        default { 'Unknown' }
                    }
                    
                    # Use Get-ResourceCategory to determine the correct category based on @odata.type
                    $category = Get-ResourceCategory -Resource $resource -EndpointId $EndpointId
                        
                    $assignmentObject = New-AssignmentObject -Type $category `
                        -Name $resource.displayName `
                        -Description $(if ($resource.description) { $resource.description } else { "" }) `
                        -Id $resource.id `
                        -Intent $assignment.intent `
                        -Target $assignment.target `
                        -Settings $assignment.settings `
                        -AssignmentScope $assignmentScope
                        
                    Add-AssignmentToCategory -ResultObject $ResultObject -Assignment $assignmentObject -AssignmentCategory $category
                }
            }
        }
    }
}
    
function Get-ResourceCategory()
{
    <#
    .SYNOPSIS
    Determines the correct category for a resource based on its @odata.type.
    
    .DESCRIPTION
    Uses the resource's @odata.type to accurately categorize it, ensuring Windows Update
    configurations, custom configurations, and other special types are correctly identified.
    This function provides consistent categorization across all assignment functions.
    
    .PARAMETER Resource
    The resource object containing @odata.type and other properties.
    
    .PARAMETER EndpointId
    The endpoint ID as a fallback (e.g., 'mobileApps', 'deviceConfigs').
    
    .EXAMPLE
    $category = Get-ResourceCategory -Resource $resourceObj -EndpointId 'deviceConfigs'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Resource,
        [Parameter(Mandatory = $true)]
        [string]$EndpointId
    )
    
    $odataType = if ($Resource.'@odata.type') { $Resource.'@odata.type'.ToLower() } else { '' }
    
    # First, check @odata.type for specific categorization
    if ($odataType)
    {
        # Windows Update configurations
        if ($odataType -match 'windowsupdateforbusinessconfiguration')
        {
            return 'Configuration'  # Update Ring
        }
        elseif ($odataType -match 'windowsfeatureupdateprofile')
        {
            return 'WindowsFeatureUpdate'
        }
        elseif ($odataType -match 'windowsqualityupdateprofile')
        {
            return 'WindowsQualityUpdate'
        }
        elseif ($odataType -match 'windowsdriverupdateprofile')
        {
            return 'WindowsDriverUpdate'
        }
        # Device configurations (various types)
        elseif ($odataType -match 'windows10generalconfiguration|windowscustomconfiguration|windows10customconfiguration|ioscompliancepolicy|androidcompliancepolicy')
        {
            return 'Configuration'
        }
        # Mobile apps
        elseif ($odataType -match 'win32lobapp|ioslobapp|androidlobapp|webapp|managedapp|officeSuiteApp')
        {
            return 'Application'
        }
        # Compliance policies
        elseif ($odataType -match 'compliancepolicy')
        {
            return 'Compliance'
        }
        # Scripts
        elseif ($odataType -match 'devicemanagementscript|devicehealthscript')
        {
            return if ($odataType -match 'health') { 'HealthScript' } else { 'Script' }
        }
        # App protection
        elseif ($odataType -match 'managedapppolicy|managedappprotection')
        {
            return 'AppProtection'
        }
        # Security baselines/intents
        elseif ($odataType -match 'intent')
        {
            return 'Intent'
        }
        # Configuration policies (Settings Catalog)
        elseif ($odataType -match 'configurationpolicy')
        {
            return 'ConfigurationPolicy'
        }
        # Group Policy
        elseif ($odataType -match 'grouppolicyconfiguration')
        {
            return 'GroupPolicy'
        }
        # Windows Information Protection
        elseif ($odataType -match 'windowsinformationprotection|mdmwindowsinformationprotection')
        {
            return 'WindowsInformationProtection'
        }
        # Autopilot
        elseif ($odataType -match 'windowsautopilotdeploymentprofile')
        {
            return 'AutopilotProfile'
        }
        # Resource Access
        elseif ($odataType -match 'resourceaccessprofile')
        {
            return 'ResourceAccess'
        }
        # Policy Sets
        elseif ($odataType -match 'policyset')
        {
            return 'PolicySet'
        }
    }
    
    # Fallback to endpoint-based categorization
    switch ($EndpointId)
    {
        'mobileApps' { return 'Application' }
        'deviceConfigs' { return 'Configuration' }
        'compliancePolicies' { return 'Compliance' }
        'deviceScripts' { return 'Script' }
        'appProtectionPolicies' { return 'AppProtection' }
        'intents' { return 'Intent' }
        'resourceAccessProfiles' { return 'ResourceAccess' }
        'autopilotProfiles' { return 'AutopilotProfile' }
        'healthScripts' { return 'HealthScript' }
        'configurationPolicies' { return 'ConfigurationPolicy' }
        'groupPolicyConfigs' { return 'GroupPolicy' }
        'wipPolicies' { return 'WindowsInformationProtection' }
        'mdmWipPolicies' { return 'WindowsInformationProtection' }
        'policySets' { return 'PolicySet' }
        'windowsFeatureUpdates' { return 'WindowsFeatureUpdate' }
        'windowsQualityUpdates' { return 'WindowsQualityUpdate' }
        'windowsDriverUpdates' { return 'WindowsDriverUpdate' }
        default { return 'Unknown' }
    }
}

function Test-ResourcePlatformMatch()
{
    [CmdletBinding()                                        ]
    param(
        [Parameter(Mandatory = $true)]
        $Resource,
        [Parameter(Mandatory = $false)]
        [string]$TargetOS
    )
    $functionName = $MyInvocation.MyCommand.Name                                
    Write-Verbose "[$functionName] Target OS: $TargetOS"
    write-log -logFile $logFile -module $functionName -message "Target OS: $TargetOS"
    # If no target OS specified, include all resources
    if ([string]::IsNullOrWhiteSpace($TargetOS))
    {
        write-log -logFile $logFile -module $functionName -message "No Target OS specified, including all resources."                   
        return $true
    }
        
    # Get the @odata.type if available
    $odataType = if ($Resource.'@odata.type') { $Resource.'@odata.type'.ToLower() } else { '' }
    Write-Verbose "[$functionName] Resource @odata.type: $odataType"        
    write-log -logFile $logFile -module $functionName -message "Resource @odata.type: $odataType"                   
    # Platform matching logic based on @odata.type
    switch ($TargetOS.ToLower())
    {
        'windows'
        {
            # Match Windows-specific types
            write-log -logFile $logFile -module $functionName -message "Checking for Windows platform match."
            return ($odataType -match 'windows|win32|msi|intunewin|officeSuiteApp')
        }
        'ios'
        {
            # Match iOS-specific types
            write-log -logFile $logFile -module $functionName -message "Checking for iOS platform match."                                               
            return ($odataType -match 'ios(?!.*mac)')
        }
        'android'
        {
            # Match Android-specific types  
            write-log -logFile $logFile -module $functionName -message "Checking for Android platform match."                           
            return ($odataType -match 'android')
        }
        'macos'
        {
            # Match macOS-specific types
            write-log -logFile $logFile -module $functionName -message "Checking for macOS platform match."                                 
            return ($odataType -match 'macos|macOSLobApp|macOSOfficeApp')
        }
        'linux'
        {
            # Match Linux-specific types (rare but possible)
            write-log -logFile $logFile -module $functionName -message "Checking for Linux platform match."                                                 
            return ($odataType -match 'linux')
        }
        default
        {
            # Unknown OS - include all
            write-log -logFile $logFile -module $functionName -message "Unknown Target OS specified, including all resources."                                              
            return $true
        }
    }
}

function Get-UnassignedResources()
{
    <#
    .SYNOPSIS
    Retrieves all Intune resources and identifies those without any assignments.
    
    .DESCRIPTION
    This function fetches ALL resources from Intune (apps, configurations, policies, etc.)
    and checks each one to determine if it has any assignments. Resources with zero assignments
    are returned as unassigned.
    
    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.
    
    .PARAMETER IncludeBeta
    Switch to include beta API endpoints for additional resource types.
    
    .PARAMETER Settings
    Optional settings hashtable for platform filtering.
    
    .EXAMPLE
    $unassigned = Get-UnassignedResources -AccessToken $token -IncludeBeta
    
    .OUTPUTS
    PSCustomObject with properties:
    - UnassignedResources: Array of resources with no assignments
    - TotalResourcesChecked: Total number of resources examined
    - FailedChecks: Array of resources that failed assignment check
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeBeta,
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Starting unassigned resources check" -logLevel "Information"
    
    # Determine API version
    $apiVersion = if ($IncludeBeta.IsPresent) { 'beta' } else { 'v1.0' }
    
    # Get all resource endpoints
    $resourceEndpoints = Get-ResourceListEndpoints -IncludeBeta:$IncludeBeta
    
    Write-Log -logFile $LogFile -module $functionName -Message "Fetching all resources from $($resourceEndpoints.Count) endpoint types" -logLevel "Information"
    
    # Fetch all resources using batch API
    $allResourcePaths = $resourceEndpoints | ForEach-Object { $_.url }
    
    try
    {
        $resourceResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $allResourcePaths -APIVersion $apiVersion -Method "GET"
    }
    catch
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Error fetching resources: $($_.Exception.Message)" -logLevel "Error"
        return $null
    }
    
    # Collect all resources
    $allResources = @()
    $resourceTypeMap = @{}
    
    for ($i = 0; $i -lt $resourceResults.value.Count; $i++)
    {
        $endpointInfo = $resourceEndpoints[$i]
        $resources = $resourceResults.value[$i].value
        
        if ($resources -and $resources.Count -gt 0)
        {
            foreach ($resource in $resources)
            {
                # Determine resource type and category using unified function
                $resourceType = $endpointInfo.id
                $category = Get-ResourceCategory -Resource $resource -EndpointId $resourceType
                
                $allResources += [PSCustomObject]@{
                    Id            = $resource.id
                    Name          = if ($resource.displayName) { $resource.displayName } elseif ($resource.name) { $resource.name } else { "Unknown" }
                    Description   = if ($resource.description) { $resource.description } else { "" }
                    ResourceType  = $resourceType
                    Category      = $category
                    BaseUri       = $endpointInfo.url
                    '@odata.type' = $resource.'@odata.type'
                    Resource      = $resource
                }
                
                $resourceTypeMap[$resource.id] = $category
            }
        }
    }
    
    Write-Log -logFile $LogFile -module $functionName -Message "Retrieved $($allResources.Count) total resources across all types" -logLevel "Information"
    
    # Apply platform filtering if specified
    if ($Settings -and $Settings.operatingSystem)
    {
        $targetOS = $Settings.operatingSystem
        Write-Log -logFile $LogFile -module $functionName -Message "Applying platform filter for OS: $targetOS" -logLevel "Information"
        
        $originalCount = $allResources.Count
        $allResources = @($allResources | Where-Object { Test-ResourcePlatformMatch -Resource $_.Resource -TargetOS $targetOS })
        $filteredCount = $allResources.Count
        
        Write-Log -logFile $LogFile -module $functionName -Message "Platform filter applied: reduced from $originalCount to $filteredCount resources for OS: $targetOS" -logLevel "Information"
    }
    else
    {
        Write-Log -logFile $LogFile -module $functionName -Message "No platform filter specified, checking all $($allResources.Count) resources" -logLevel "Information"
    }
    
    # Now check each resource for assignments
    $assignmentPaths = $allResources | ForEach-Object { "$($_.BaseUri)/$($_.Id)/assignments" }
    
    Write-Log -logFile $LogFile -module $functionName -Message "Checking assignments for $($allResources.Count) resources" -logLevel "Information"
    
    try
    {
        $assignmentResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentPaths -APIVersion $apiVersion -Method "GET"
    }
    catch
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Error fetching assignments: $($_.Exception.Message)" -logLevel "Error"
        return $null
    }
    
    # Identify unassigned resources
    $unassignedResources = @()
    $failedChecks = @()
    
    for ($i = 0; $i -lt $assignmentResults.value.Count; $i++)
    {
        $assignmentData = $assignmentResults.value[$i]
        $resource = $allResources[$i]
        
        # Check if we got a successful response (not null and has value property)
        if ($null -ne $assignmentData -and $assignmentData.PSObject.Properties['value'])
        {
            $assignmentCount = if ($assignmentData.value) { $assignmentData.value.Count } else { 0 }
            
            if ($assignmentCount -eq 0)
            {
                # No assignments - this is an unassigned resource
                $unassignedResources += New-AssignmentObject `
                    -Type $resource.Category `
                    -Name $resource.Name `
                    -Description $resource.Description `
                    -Id $resource.Id `
                    -Intent $null `
                    -Target $null `
                    -Settings $resource.Resource `
                    -AssignmentScope "None"
                
                Write-Verbose "[$functionName] Unassigned: $($resource.Category) - $($resource.Name) [@odata.type: $($resource.'@odata.type')]"
                Write-Log -logFile $LogFile -module $functionName -Message "Found unassigned resource: $($resource.Category) - $($resource.Name) [@odata.type: $($resource.'@odata.type')]" -logLevel "Verbose"
            }
            else
            {
                # Log detailed assignment information for this resource
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)' (Category: $($resource.Category), @odata.type: $($resource.Resource.'@odata.type')) has $assignmentCount assignment(s)" -logLevel "Information"
                
                # Log each assignment's target type for diagnostics
                for ($j = 0; $j -lt $assignmentData.value.Count; $j++)
                {
                    $assign = $assignmentData.value[$j]
                    $targetTypeDetail = $assign.target.'@odata.type'
                    $intentDetail = $assign.intent
                    Write-Log -logFile $LogFile -module $functionName -Message "  Assignment #$($j+1) for '$($resource.Name)': TargetType='$targetTypeDetail', Intent='$intentDetail'" -logLevel "Debug"
                }
                
                # Use centralized helper to determine if resource has real assignments
                # Per requirements: Any group assignment, All Users, or All Devices counts as "assigned"
                # For apps, any intent (Required, Available, Uninstall) counts
                $hasRealAssignment = Test-HasRealAssignment -Assignments $assignmentData.value -ResourceName $resource.Name -ResourceCategory $resource.Category
                
                if (-not $hasRealAssignment)
                {
                    # No real assignments found - treat as unassigned
                    $unassignedResources += New-AssignmentObject `
                        -Type $resource.Category `
                        -Name $resource.Name `
                        -Description $resource.Description `
                        -Id $resource.Id `
                        -Intent $null `
                        -Target $null `
                        -Settings $resource.Resource `
                        -AssignmentScope "None"
                    
                    Write-Verbose "[$functionName] Unassigned (no group/All Users/All Devices assignments): $($resource.Category) - $($resource.Name)"
                    Write-Log -logFile $LogFile -module $functionName -Message "UNASSIGNED: '$($resource.Name)' has $assignmentCount assignment(s) but NONE are real assignments (no groups, All Users, or All Devices)" -logLevel "Warning"
                }
                else
                {
                    Write-Verbose "[$functionName] Resource has $assignmentCount assignment(s): $($resource.Category) - $($resource.Name)"
                    Write-Log -logFile $LogFile -module $functionName -Message "ASSIGNED: '$($resource.Name)' has real assignment(s)" -logLevel "Information"
                }
            }
        }
        else
        {
            # Failed to get assignments or error occurred (404, 400, etc.)
            $failedChecks += $resource
            Write-Log -logFile $LogFile -module $functionName -Message "Failed to check assignments for $($resource.Name) (likely deleted or inaccessible)" -logLevel "Warning"
        }
    }
    
    Write-Log -logFile $LogFile -module $functionName -Message "Found $($unassignedResources.Count) unassigned resources out of $($allResources.Count) total ($($failedChecks.Count) failed)" -logLevel "Information"
    
    # Build FailedResources array in the same format as other assignment functions
    $failedResourcesArray = @()
    foreach ($failed in $failedChecks)
    {
        # Try to extract error details from the batch response if available
        $errorMsg = "Failed to check assignments (likely deleted or inaccessible)"
        $statusCode = "N/A"
        
        $failedResourcesArray += [PSCustomObject]@{
            ResourceType = $failed.ResourceType
            ErrorMessage = $errorMsg
            StatusCode   = $statusCode
            ApiVersion   = $apiVersion
        }
    }
    
    return [PSCustomObject]@{
        UnassignedResources   = $unassignedResources
        TotalResourcesChecked = $allResources.Count
        FailedChecks          = $failedChecks
        FailedResources       = $failedResourcesArray
    }
}
