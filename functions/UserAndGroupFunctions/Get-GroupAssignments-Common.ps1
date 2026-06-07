# Common functions and utilities for Get-GroupDirectAssignments and Get-GroupIndirectAssignments
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

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Initializing assignment result object (GroupName: '$GroupName', GroupId: '$GroupId')" -logLevel "Verbose"

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
        WindowsFeatureUpdateAssignments         = @()
        WindowsQualityUpdateAssignments         = @()
        WindowsDriverUpdateAssignments          = @()
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

    Write-Log -logFile $LogFile -module $functionName -Message "Assignment result object initialized successfully with 17 category arrays" -logLevel "Verbose"
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

    $functionName = $MyInvocation.MyCommand.Name
    $targetType = $Assignment.target.'@odata.type'
    $isAllUsersOrDevices = ($targetType -eq '#microsoft.graph.allDevicesAssignmentTarget' -or
        $targetType -eq '#microsoft.graph.allLicensedUsersAssignmentTarget')

    Write-Log -logFile $LogFile -module $functionName -Message "Testing assignment target type: '$targetType' - IsAllUsersOrDevices: $isAllUsersOrDevices" -logLevel "Debug"
    return $isAllUsersOrDevices
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

    $functionName = $MyInvocation.MyCommand.Name
    $targetType = $Assignment.target.'@odata.type'
    $isGroup = ($targetType -eq '#microsoft.graph.groupAssignmentTarget')

    Write-Log -logFile $LogFile -module $functionName -Message "Testing assignment target type: '$targetType' - IsGroup: $isGroup" -logLevel "Debug"
    return $isGroup
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

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Testing for BOTH group '$GroupId' AND All Users/All Devices assignments (Total assignments: $($Assignments.Count))" -logLevel "Verbose"

    if (-not $Assignments -or $Assignments.Count -eq 0)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "No assignments provided, returning false" -logLevel "Debug"
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
            Write-Log -logFile $LogFile -module $functionName -Message "Found BOTH group assignment AND All Users/All Devices - returning true" -logLevel "Information"
            return $true
        }
    }

    $result = ($hasGroupAssignment -and $hasAllUsersOrAllDevices)
    Write-Log -logFile $LogFile -module $functionName -Message "Result: HasGroup=$hasGroupAssignment, HasIndirect=$hasAllUsersOrAllDevices, Final=$result" -logLevel "Verbose"
    return $result
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

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Getting resource list endpoints (IncludeBeta: $($IncludeBeta.IsPresent))" -logLevel "Verbose"

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

    Write-Log -logFile $LogFile -module $functionName -Message "Returning $($resourceEndpoints.Count) resource endpoints" -logLevel "Verbose"
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

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Adding failed resource error: Type='$ResourceType', Status=$StatusCode, API=$ApiVersion" -logLevel "Warning"
    Write-Log -logFile $LogFile -module $functionName -Message "Error message: $ErrorMessage" -logLevel "Verbose"

    $errorObject = [PSCustomObject]@{
        ResourceType = $ResourceType
        ErrorMessage = $ErrorMessage
        StatusCode   = $StatusCode
        ApiVersion   = $ApiVersion
    }

    $ResultObject.FailedResources += $errorObject
    Write-Log -logFile $LogFile -module $functionName -Message "Failed resource added to result object. Total failed resources: $($ResultObject.FailedResources.Count)" -logLevel "Verbose"
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
            else
            {
                Write-Log -logFile $LogFile -module $functionName -Message "$($key): All $originalCount resources match OS: $TargetOS" -logLevel "Debug"
            }
        }
        else
        {
            $filtered[$key] = @()
            Write-Log -logFile $LogFile -module $functionName -Message "$($key): No resources to filter" -logLevel "Debug"
        }
    }

    Write-Log -logFile $LogFile -module $functionName -Message "Platform filtering complete for OS: $TargetOS" -logLevel "Verbose"
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

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Creating assignment object: Type='$Type', Name='$Name', Scope='$AssignmentScope', Intent='$Intent'" -logLevel "Debug"

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

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Adding assignment to category '$AssignmentCategory': Name='$($Assignment.Name)', Type='$($Assignment.Type)'" -logLevel "Debug"

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
        "WindowsFeatureUpdate" { $ResultObject.WindowsFeatureUpdateAssignments += $Assignment }
        "WindowsQualityUpdate" { $ResultObject.WindowsQualityUpdateAssignments += $Assignment }
        "WindowsDriverUpdate" { $ResultObject.WindowsDriverUpdateAssignments += $Assignment }
    }

    $ResultObject.AllAssignments += $Assignment
    Write-Log -logFile $LogFile -module $functionName -Message "Assignment added successfully. Total assignments in AllAssignments: $($ResultObject.AllAssignments.Count)" -logLevel "Debug"
}

function Invoke-GraphNextLinkRequest()
{
    <#
    .SYNOPSIS
    Executes a GET request against a Microsoft Graph @odata.nextLink URL.

    .DESCRIPTION
    Used by pagination helpers to retrieve additional pages when the initial response
    returned a nextLink reference. Keeps authorization/header handling consistent.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$NextLink,
        [Parameter(Mandatory = $false)]
        [string]$ResourceDescription = "resource page"
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Retrieving nextLink for ${ResourceDescription}: $NextLink" -logLevel "Verbose"

    $headers = @{
        Authorization  = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
    }

    try
    {
        return Invoke-RestMethod -Method Get -Uri $NextLink -Headers $headers -UseBasicParsing
    }
    catch
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Failed to retrieve nextLink for ${ResourceDescription}: $($_.Exception.Message)" -logLevel "Warning"
        throw
    }
}

function Get-PagedCollectionItems()
{
    <#
    .SYNOPSIS
    Aggregates all items from a potentially paged Graph response.

    .DESCRIPTION
    Takes the initial response body from a batch request and follows any @odata.nextLink
    references until all pages are collected.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$InitialResponse,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [string]$ResourceDescription = "resource collection"
    )

    $functionName = $MyInvocation.MyCommand.Name
    $items = @()
    $pageCount = 0

    if ($null -eq $InitialResponse)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "No initial response provided for $ResourceDescription" -logLevel "Verbose"
        return @{
            Items     = $items
            PageCount = 0
        }
    }

    if ($InitialResponse.value)
    {
        $items += $InitialResponse.value
    }
    $pageCount = 1

    $nextLink = $InitialResponse.'@odata.nextLink'
    while ($nextLink)
    {
        $pageCount++
        $nextResponse = Invoke-GraphNextLinkRequest -AccessToken $AccessToken -NextLink $nextLink -ResourceDescription $ResourceDescription
        if ($nextResponse -and $nextResponse.value)
        {
            $items += $nextResponse.value
        }
        $nextLink = $nextResponse.'@odata.nextLink'
    }

    Write-Log -logFile $LogFile -module $functionName -Message "$ResourceDescription pagination complete - Pages: $pageCount, Items: $($items.Count)" -logLevel "Verbose"
    return @{
        Items     = $items
        PageCount = $pageCount
    }
}

function Invoke-AssignmentBatchRequest()
{
    <#
    .SYNOPSIS
    Executes a batch API request for assignments with standardized error handling.

    .DESCRIPTION
    Centralized function for making batch API calls to retrieve resource assignments.
    Provides consistent error handling, logging, and error categorization across all assignment functions.

    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.

    .PARAMETER AssignmentPaths
    Array of assignment endpoint paths to request.

    .PARAMETER ApiVersion
    API version to use (v1.0 or beta).

    .PARAMETER ResourceType
    The type of resource being processed (for logging/error reporting).

    .RETURNS
    Hashtable with Success (bool), Result (API response), and ErrorInfo (if failed).

    .EXAMPLE
    $batchResult = Invoke-AssignmentBatchRequest -AccessToken $token -AssignmentPaths $paths -ApiVersion 'v1.0' -ResourceType 'Mobile Apps'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [array]$AssignmentPaths,
        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,
        [Parameter(Mandatory = $true)]
        [string]$ResourceType
    )

    $functionName = $MyInvocation.MyCommand.Name

    try
    {
        Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: Batch request for $($AssignmentPaths.Count) assignment path(s)" -logLevel "Debug"
        $batchResult = CallGraphAPI -accessToken $AccessToken -ResourcePath $AssignmentPaths -APIVersion $ApiVersion -Method "GET"
        Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: Batch result structure - Has value: $(if ($batchResult.value) { "Yes ($($batchResult.value.Count) responses)" } else { 'No' })" -logLevel "Debug"

        return @{
            Success = $true
            Result  = $batchResult
        }
    }
    catch
    {
        $errorMessage = "Failed to fetch assignments for ${ResourceType}: $($_.Exception.Message)"
        $errorCode = $_.Exception.GetType().Name

        # Categorize error using common helper
        $errorCategory = Get-ErrorCategory -ErrorCode $errorCode -ErrorMessage $errorMessage -ResourceType $ResourceType -ODataType ""
        $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorCode -ResourceType $ResourceType -ODataType ""

        Write-Log -logFile $LogFile -module $functionName -Message "$errorMessage (Category: $errorCategory)" -LogLevel "Error"
        Write-Log -logFile $LogFile -module $functionName -Message "Remediation guidance: $remediationGuidance" -logLevel "Information"

        return @{
            Success   = $false
            ErrorInfo = @{
                Message     = $errorMessage
                Code        = $errorCode
                Category    = $errorCategory
                Remediation = $remediationGuidance
            }
        }
    }
}

function Get-ResourceAssignments()
{
    <#
    .SYNOPSIS
    Unified function to retrieve and process resource assignments for both direct and indirect assignments.

    .DESCRIPTION
    This function processes a set of resources to retrieve their assignments using batch API calls.
    It supports three modes:
    - Direct: Retrieves assignments for a specific group
    - Indirect: Retrieves All Users/All Devices assignments
    - IndirectFiltered: Retrieves resources with BOTH specific group AND All Users/All Devices assignments

    .PARAMETER ResultObject
    The result object to update with assignments and errors.

    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.

    .PARAMETER ApiVersion
    API version to use (v1.0 or beta).

    .PARAMETER Resources
    The array of resources to process for assignments.

    .PARAMETER ResourceType
    The type of resource being processed (e.g., "Mobile Apps", "Device Configurations").

    .PARAMETER BaseUri
    The base URI for the Microsoft Graph API endpoint for the resource type.

    .PARAMETER EndpointId
    The endpoint identifier used for dynamic categorization via Get-ResourceCategory.

    .PARAMETER AssignmentMode
    The assignment mode: 'Direct', 'Indirect', or 'IndirectFiltered'.

    .PARAMETER GroupIdValue
    Required for Direct and IndirectFiltered modes. The group ID to filter assignments.

    .EXAMPLE
    # Direct assignments for a specific group
    Get-ResourceAssignments -ResultObject $assignments -AccessToken $token -ApiVersion 'v1.0' `
        -Resources $apps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" `
        -EndpointId "mobileApps" -AssignmentMode "Direct" -GroupIdValue "abc-123"

    .EXAMPLE
    # All Users/All Devices assignments (no group filter)
    Get-ResourceAssignments -ResultObject $assignments -AccessToken $token -ApiVersion 'v1.0' `
        -Resources $apps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" `
        -EndpointId "mobileApps" -AssignmentMode "Indirect"

    .EXAMPLE
    # Resources with BOTH group and All Users/All Devices assignments
    Get-ResourceAssignments -ResultObject $assignments -AccessToken $token -ApiVersion 'v1.0' `
        -Resources $apps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" `
        -EndpointId "mobileApps" -AssignmentMode "IndirectFiltered" -GroupIdValue "abc-123"
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
        [Parameter(Mandatory = $true)]
        [ValidateSet('Direct', 'Indirect', 'IndirectFiltered')]
        [string]$AssignmentMode,
        [Parameter(Mandatory = $false)]
        [string]$GroupIdValue
    )

    $functionName = $MyInvocation.MyCommand.Name

    # Validate parameters based on mode
    if ($AssignmentMode -eq 'Direct' -and -not $GroupIdValue)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "AssignmentMode 'Direct' requires GroupIdValue parameter" -LogLevel "Error"
        return
    }

    if ($AssignmentMode -eq 'IndirectFiltered' -and -not $GroupIdValue)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "AssignmentMode 'IndirectFiltered' requires GroupIdValue parameter" -LogLevel "Error"
        return
    }

    if (-not $Resources -or $Resources.Count -eq 0)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "No ${ResourceType} resources to process" -logLevel "Verbose"
        return
    }

    $modeDescription = switch ($AssignmentMode)
    {
        'Direct' { "direct assignments for group '$GroupIdValue'" }
        'Indirect' { "All Users/All Devices assignments" }
        'IndirectFiltered' { "resources with BOTH group '$GroupIdValue' AND All Users/All Devices" }
    }

    Write-Log -logFile $LogFile -module $functionName -Message "Processing $($Resources.Count) ${ResourceType} resources for ${modeDescription}" -LogLevel "Verbose"

    # Build array of assignment endpoint paths
    $assignmentPaths = @()
    foreach ($resource in $Resources)
    {
        $assignmentPaths += "$BaseUri/$($resource.id)/assignments"
    }

    # Use centralized batch request function with error handling
    $batchResponse = Invoke-AssignmentBatchRequest -AccessToken $AccessToken -AssignmentPaths $assignmentPaths -ApiVersion $ApiVersion -ResourceType $ResourceType

    if (-not $batchResponse.Success)
    {
        # Add to failed resources using error info from batch request
        Add-FailedResourceError -ResultObject $ResultObject -ResourceType $ResourceType `
            -ErrorMessage $batchResponse.ErrorInfo.Message -StatusCode "N/A" -ApiVersion $ApiVersion
        return
    }

    $batchResult = $batchResponse.Result

    # CRITICAL FIX: CallGraphAPI returns a hashtable, not PSCustomObject
    # Check for hashtable keys OR PSCustomObject properties to handle both cases
    $hasValueProperty = $false
    if ($batchResult)
    {
        if ($batchResult -is [hashtable])
        {
            $hasValueProperty = $batchResult.ContainsKey('value')
            Write-Log -logFile $LogFile -module $functionName -Message "Batch result is hashtable, has 'value' key: $hasValueProperty (Count: $($batchResult.value.Count))" -logLevel "Verbose"
        }
        elseif ($batchResult.PSObject.Properties['value'])
        {
            $hasValueProperty = $true
            Write-Log -logFile $LogFile -module $functionName -Message "Batch result is PSCustomObject, has 'value' property (Count: $($batchResult.value.Count))" -logLevel "Verbose"
        }
    }

    if ($batchResult -and $hasValueProperty -and $batchResult.value)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Processing $($batchResult.value.Count) batch responses for ${ResourceType}" -LogLevel "Verbose"

        $responseLookup = Build-BatchResponseLookup -BatchResponses $batchResult.value
        for ($i = 0; $i -lt $Resources.Count; $i++)
        {
            $expectedResponseId = ($i + 1).ToString()
            $batchResponse = $responseLookup[$expectedResponseId]
            $resource = $Resources[$i]
            if (-not $batchResponse)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "No batch response for resource '$($resource.displayName)' (expected ID '$expectedResponseId')" -logLevel "Warning"
                continue
            }

            # CRITICAL FIX: CallGraphAPI batch responses have structure: { id, status, body }
            # The actual assignment data is in the 'body' property, not directly in 'value'
            $responseData = if ($batchResponse -and $batchResponse.body) { $batchResponse.body } else { $null }

            # Check for batch request failures (non-2xx status codes)
            $batchRequestFailed = $batchResponse -and $batchResponse.status -and ($batchResponse.status -lt 200 -or $batchResponse.status -ge 300)

            if ($batchRequestFailed)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Batch request failed for '$($resource.displayName)' - Status: $($batchResponse.status)" -logLevel "Warning"
                continue
            }

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

                # Filter assignments based on mode
                $relevantAssignments = @()

                switch ($AssignmentMode)
                {
                    'Direct'
                    {
                        # Filter for specific group assignments (included and excluded)
                        $relevantAssignments = $responseData.value | Where-Object {
                            ($_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -or
                             $_.target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget') -and
                            $_.target.groupId -eq $GroupIdValue
                        }
                        Write-Log -logFile $LogFile -module $functionName -Message "Found $($relevantAssignments.Count) direct group assignment(s) for '$($resource.displayName)'" -logLevel "Debug"
                    }

                    'IndirectFiltered'
                    {
                        # Check if resource has BOTH group assignment AND All Users/All Devices
                        Write-Log -logFile $LogFile -module $functionName -Message "Checking if '$($resource.displayName)' has BOTH GroupId '$GroupIdValue' AND All Users/All Devices" -logLevel "Debug"
                        $hasGroupAndIndirect = Test-HasGroupAndIndirectAssignment -Assignments $responseData.value -GroupId $GroupIdValue

                        if (-not $hasGroupAndIndirect)
                        {
                            Write-Log -logFile $LogFile -module $functionName -Message "Skipping '$($resource.displayName)' - does NOT have both GroupId and All Users/All Devices" -logLevel "Debug"
                            continue
                        }

                        Write-Log -logFile $LogFile -module $functionName -Message "Including '$($resource.displayName)' - HAS both GroupId and All Users/All Devices" -logLevel "Information"

                        # Get the All Users/All Devices assignments
                        $relevantAssignments = $responseData.value | Where-Object {
                            $_.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget' -or
                            $_.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget'
                        }
                        Write-Log -logFile $LogFile -module $functionName -Message "Found $($relevantAssignments.Count) All Users/All Devices assignment(s) for '$($resource.displayName)'" -logLevel "Debug"
                    }

                    'Indirect'
                    {
                        # Get all All Users/All Devices assignments (no group filtering)
                        $relevantAssignments = $responseData.value | Where-Object {
                            $_.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget' -or
                            $_.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget'
                        }
                        Write-Log -logFile $LogFile -module $functionName -Message "Found $($relevantAssignments.Count) All Users/All Devices assignment(s) for '$($resource.displayName)'" -logLevel "Debug"
                    }
                }

                # Process relevant assignments
                foreach ($assignment in $relevantAssignments)
                {
                    # Determine assignment scope based on mode and target type
                    $assignmentScope = if ($AssignmentMode -eq 'Direct')
                    {
                        if ($assignment.target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget')
                        {
                            'Excluded'
                        }
                        else
                        {
                            'Direct'
                        }
                    }
                    else
                    {
                        switch ($assignment.target.'@odata.type')
                        {
                            '#microsoft.graph.allLicensedUsersAssignmentTarget' { 'All Users' }
                            '#microsoft.graph.allDevicesAssignmentTarget' { 'All Devices' }
                            default { 'Unknown' }
                        }
                    }

                    # Use Get-ResourceCategory to determine the correct category
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

# Legacy function - kept for backward compatibility, redirects to unified Get-ResourceAssignments
function Get-IndirectResourceAssignments()
{
    <#
    .SYNOPSIS
    [DEPRECATED] Legacy function for backward compatibility. Use Get-ResourceAssignments instead.

    .DESCRIPTION
    This function is maintained for backward compatibility but redirects to the unified
    Get-ResourceAssignments function. New code should call Get-ResourceAssignments directly.
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
    Write-Log -logFile $LogFile -module $functionName -Message "[DEPRECATED] Legacy wrapper called - redirecting to Get-ResourceAssignments" -logLevel "Warning"
    Write-Log -logFile $LogFile -module $functionName -Message "Parameters: ResourceType='$ResourceType', EndpointId='$EndpointId', GroupId='$GroupId', Resources=$($Resources.Count)" -logLevel "Verbose"

    # Redirect to unified function
    $assignmentMode = if ($GroupId) { 'IndirectFiltered' } else { 'Indirect' }
    Write-Log -logFile $LogFile -module $functionName -Message "Using assignment mode: $assignmentMode" -logLevel "Verbose"

    Get-ResourceAssignments -ResultObject $ResultObject -AccessToken $AccessToken -ApiVersion $ApiVersion `
        -Resources $Resources -ResourceType $ResourceType -BaseUri $BaseUri -EndpointId $EndpointId `
        -AssignmentMode $assignmentMode -GroupIdValue $GroupId

    Write-Log -logFile $LogFile -module $functionName -Message "Completed redirect to Get-ResourceAssignments" -logLevel "Verbose"
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

    $functionName = $MyInvocation.MyCommand.Name
    $odataType = if ($Resource.'@odata.type') { $Resource.'@odata.type'.ToLower() } else { '' }
    Write-Log -logFile $LogFile -module $functionName -Message "Determining category for resource (ODataType: '$odataType', EndpointId: '$EndpointId')" -logLevel "Debug"

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
            $scriptReturnValue = if ($odataType -match 'health') { 'HealthScript' } else { 'Script' }
            return $scriptReturnValue
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
    Write-Log -logFile $LogFile -module $functionName -Message "No ODataType match found, using EndpointId fallback for: '$EndpointId'" -logLevel "Debug"

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
        default
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Unknown EndpointId '$EndpointId' - returning 'Unknown'" -logLevel "Warning"
            return 'Unknown'
        }
    }
}

function Get-DefaultODataTypeForEndpoint()
{
    <#
    .SYNOPSIS
    Provides a best-effort default @odata.type string for known endpoint identifiers.

    .DESCRIPTION
    Some Graph responses omit @odata.type when minimal metadata is returned. This helper
    returns a representative type name so downstream logic (platform filtering, base URI
    resolution, metadata lookups) can continue operating without warnings.

    .PARAMETER EndpointId
    Endpoint identifier such as 'deviceScripts', 'windowsFeatureUpdates', etc.

    .EXAMPLE
    $odataType = Get-DefaultODataTypeForEndpoint -EndpointId 'windowsFeatureUpdates'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EndpointId
    )

    $functionName = $MyInvocation.MyCommand.Name
    if ([string]::IsNullOrWhiteSpace($EndpointId))
    {
        Write-Log -logFile $LogFile -module $functionName -Message "EndpointId not provided, cannot derive default ODataType." -logLevel "Verbose"
        return $null
    }

    $originalId = $EndpointId
    $normalizedId = $EndpointId.Trim().ToLowerInvariant()
    $defaultTypes = @{
        mobileapps             = '#microsoft.graph.mobileApp'
        deviceconfigs          = '#microsoft.graph.deviceConfiguration'
        compliancepolicies     = '#microsoft.graph.deviceCompliancePolicy'
        devicescripts          = '#microsoft.graph.deviceManagementScript'
        appprotectionpolicies  = '#microsoft.graph.managedAppPolicy'
        intents                = '#microsoft.graph.deviceManagementIntent'
        resourceaccessprofiles = '#microsoft.graph.deviceManagementResourceAccessProfile'
        policysets             = '#microsoft.graph.policySet'
        autopilotprofiles      = '#microsoft.graph.windowsAutopilotDeploymentProfile'
        healthscripts          = '#microsoft.graph.deviceHealthScript'
        configurationpolicies  = '#microsoft.graph.configurationPolicy'
        grouppolicyconfigs     = '#microsoft.graph.groupPolicyConfiguration'
        wippolicies            = '#microsoft.graph.windowsInformationProtectionPolicy'
        mdmwippolicies         = '#microsoft.graph.mdmWindowsInformationProtectionPolicy'
        windowsfeatureupdates  = '#microsoft.graph.windowsFeatureUpdateProfile'
        windowsqualityupdates  = '#microsoft.graph.windowsQualityUpdateProfile'
        windowsdriverupdates   = '#microsoft.graph.windowsDriverUpdateProfile'
    }

    if ($defaultTypes.ContainsKey($normalizedId))
    {
        $inferredType = $defaultTypes[$normalizedId]
        Write-Log -logFile $LogFile -module $functionName -Message "Derived default ODataType '$inferredType' for EndpointId '$originalId'." -logLevel "Verbose"
        return $inferredType
    }

    Write-Log -logFile $LogFile -module $functionName -Message "No default ODataType mapping for EndpointId '$originalId'." -logLevel "Verbose"
    return $null
}

function Test-ResourcePlatformMatch()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Resource,
        [Parameter(Mandatory = $false)]
        [string]$TargetOS
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Target OS: $TargetOS"
    Write-Log -logFile $logFile -module $functionName -message "=== START Platform Match Check ===" -logLevel "Debug"
    Write-Log -logFile $logFile -module $functionName -message "Target OS: $TargetOS" -logLevel "Information"

    # Log resource identification details
    $resourceId = if ($Resource.id) { $Resource.id } else { "Unknown" }
    $resourceName = if ($Resource.displayName) { $Resource.displayName } elseif ($Resource.name) { $Resource.name } else { "Unnamed" }
    Write-Log -logFile $logFile -module $functionName -message "Resource: ID='$resourceId', Name='$resourceName'" -logLevel "Debug"

    if ([string]::IsNullOrWhiteSpace($TargetOS))
    {
        Write-Log -logFile $logFile -module $functionName -message "DECISION: No Target OS specified, including all resources." -logLevel "Verbose"
        Write-Log -logFile $logFile -module $functionName -message "=== END Platform Match Check === RESULT: TRUE (no filter)" -logLevel "Debug"
        return $true
    }

    $targetOSLower = $TargetOS.ToLowerInvariant()
    Write-Log -logFile $logFile -module $functionName -message "Target OS (normalized): '$targetOSLower'" -logLevel "Debug"

    $platformHints = New-Object System.Collections.ArrayList
    $addPlatformHint = {
        param(
            [string]$Hint,
            [System.Collections.ArrayList]$HintCollection
        )

        if (-not [string]::IsNullOrWhiteSpace($Hint) -and -not $HintCollection.Contains($Hint))
        {
            [void]$HintCollection.Add($Hint)
            Write-Log -logFile $logFile -module $functionName -message "HINT ADDED: '$Hint' to platform hints collection" -logLevel "Debug"
        }
        else
        {
            $reason = if ([string]::IsNullOrWhiteSpace($Hint)) { "empty/null" } else { "duplicate" }
            Write-Log -logFile $logFile -module $functionName -message "HINT SKIPPED: '$Hint' ($reason)" -logLevel "Debug"
        }
    }

    $odataType = if ($Resource.'@odata.type') { $Resource.'@odata.type'.ToLower() } else { '' }
    Write-Verbose "[$functionName] Resource @odata.type: $odataType"
    Write-Log -logFile $logFile -module $functionName -message "Resource @odata.type: '$odataType'" -logLevel "Debug"

    if ($odataType)
    {
        Write-Log -logFile $logFile -module $functionName -message "PHASE 1: Analyzing @odata.type for platform hints" -logLevel "Debug"

        if ($odataType -match 'windows|win32|intunewin|msi|officesuiteapp|desktop')
        {
            Write-Log -logFile $logFile -module $functionName -message "MATCH: @odata.type contains Windows indicators (pattern: 'windows|win32|intunewin|msi|officesuiteapp|desktop')" -logLevel "Debug"
            &$addPlatformHint -Hint 'windows' -HintCollection $platformHints
        }
        if ($odataType -match 'android')
        {
            Write-Log -logFile $logFile -module $functionName -message "MATCH: @odata.type contains Android indicators (pattern: 'android')" -logLevel "Debug"
            &$addPlatformHint -Hint 'android' -HintCollection $platformHints
        }
        if ($odataType -match 'ios' -and $odataType -notmatch 'windows')
        {
            Write-Log -logFile $logFile -module $functionName -message "MATCH: @odata.type contains iOS indicators (pattern: 'ios', excluding 'windows')" -logLevel "Debug"
            &$addPlatformHint -Hint 'ios' -HintCollection $platformHints
        }
        if ($odataType -match 'macos')
        {
            Write-Log -logFile $logFile -module $functionName -message "MATCH: @odata.type contains macOS indicators (pattern: 'macos')" -logLevel "Debug"
            &$addPlatformHint -Hint 'macos' -HintCollection $platformHints
        }
        if ($odataType -match 'linux')
        {
            Write-Log -logFile $logFile -module $functionName -message "MATCH: @odata.type contains Linux indicators (pattern: 'linux')" -logLevel "Debug"
            &$addPlatformHint -Hint 'linux' -HintCollection $platformHints
        }

        Write-Log -logFile $logFile -module $functionName -message "PHASE 1 COMPLETE: Platform hints after @odata.type analysis: $($platformHints.Count) hint(s)" -logLevel "Debug"
    }
    else
    {
        Write-Log -logFile $logFile -module $functionName -message "PHASE 1 SKIPPED: No @odata.type property found" -logLevel "Debug"
    }

    $platformPropertyNames = @(
        'platforms',
        'platform',
        'platformType',
        'devicePlatformType',
        'applicablePlatforms',
        'targetedPlatforms',
        'supportedPlatforms'
    )

    Write-Log -logFile $logFile -module $functionName -message "PHASE 2: Analyzing platform-specific properties (checking $($platformPropertyNames.Count) property names)" -logLevel "Debug"

    foreach ($propertyName in $platformPropertyNames)
    {
        if (-not $Resource.PSObject.Properties[$propertyName])
        {
            Write-Log -logFile $logFile -module $functionName -message "Property '$propertyName': NOT FOUND on resource" -logLevel "Debug"
            continue
        }

        $propertyValue = $Resource.$propertyName
        if ($null -eq $propertyValue)
        {
            Write-Log -logFile $logFile -module $functionName -message "Property '$propertyName': EXISTS but value is NULL" -logLevel "Debug"
            continue
        }

        Write-Log -logFile $logFile -module $functionName -message "Property '$propertyName': FOUND with value type '$($propertyValue.GetType().Name)'" -logLevel "Debug"

        $values = @()
        if ($propertyValue -is [System.Collections.IEnumerable] -and -not ($propertyValue -is [string]))
        {
            foreach ($entry in $propertyValue)
            {
                if (-not [string]::IsNullOrWhiteSpace($entry))
                {
                    $values += $entry
                }
            }
            Write-Log -logFile $logFile -module $functionName -message "Property '$propertyName': Collection contains $($values.Count) non-empty entries" -logLevel "Debug"
        }
        else
        {
            $values += $propertyValue
            Write-Log -logFile $logFile -module $functionName -message "Property '$propertyName': Single value = '$propertyValue'" -logLevel "Debug"
        }

        foreach ($value in $values)
        {
            $valueText = $value.ToString().ToLower()
            Write-Log -logFile $logFile -module $functionName -message "Analyzing value: '$valueText' from property '$propertyName'" -logLevel "Debug"

            if ($valueText -match 'windows')
            {
                Write-Log -logFile $logFile -module $functionName -message "MATCH: Value '$valueText' contains 'windows'" -logLevel "Debug"
                &$addPlatformHint -Hint 'windows' -HintCollection $platformHints
            }
            elseif ($valueText -match 'android')
            {
                Write-Log -logFile $logFile -module $functionName -message "MATCH: Value '$valueText' contains 'android'" -logLevel "Debug"
                &$addPlatformHint -Hint 'android' -HintCollection $platformHints
            }
            elseif (($valueText -match 'ios') -or ($valueText -match 'ipad') -or ($valueText -match 'iphone'))
            {
                Write-Log -logFile $logFile -module $functionName -message "MATCH: Value '$valueText' contains iOS indicators (ios/ipad/iphone)" -logLevel "Debug"
                &$addPlatformHint -Hint 'ios' -HintCollection $platformHints
            }
            elseif ($valueText -match 'macos')
            {
                Write-Log -logFile $logFile -module $functionName -message "MATCH: Value '$valueText' contains 'macos'" -logLevel "Debug"
                &$addPlatformHint -Hint 'macos' -HintCollection $platformHints
            }
            elseif ($valueText -match 'linux')
            {
                Write-Log -logFile $logFile -module $functionName -message "MATCH: Value '$valueText' contains 'linux'" -logLevel "Debug"
                &$addPlatformHint -Hint 'linux' -HintCollection $platformHints
            }
            else
            {
                Write-Log -logFile $logFile -module $functionName -message "NO MATCH: Value '$valueText' does not match any known platform pattern" -logLevel "Debug"
            }
        }
    }

    Write-Log -logFile $logFile -module $functionName -message "PHASE 2 COMPLETE: Platform hints after property analysis: $($platformHints.Count) hint(s)" -logLevel "Debug"

    $hintSummary = if ($platformHints.Count -gt 0) { ($platformHints -join ', ') } else { 'None' }
    Write-Log -logFile $logFile -module $functionName -message "SUMMARY: Derived platform hints: $hintSummary (Total: $($platformHints.Count))" -logLevel "Debug"

    if ($platformHints.Count -eq 0)
    {
        $defaultInclude = ($targetOSLower -eq 'windows')
        Write-Log -logFile $logFile -module $functionName -message "DECISION PATH: No platform hints found" -logLevel "Debug"
        Write-Log -logFile $logFile -module $functionName -message "DECISION LOGIC: When no hints exist, default behavior is Include=TRUE for Windows, Include=FALSE for others" -logLevel "Debug"
        Write-Log -logFile $logFile -module $functionName -message "DECISION: TargetOS='$TargetOS', DefaultInclude=$defaultInclude" -logLevel "Verbose"
        Write-Log -logFile $logFile -module $functionName -message "=== END Platform Match Check === RESULT: $defaultInclude (no hints found)" -logLevel "Debug"
        return $defaultInclude
    }

    $hasTargetHint = $platformHints -contains $targetOSLower
    Write-Log -logFile $logFile -module $functionName -message "DECISION PATH: Platform hints found, checking for target OS match" -logLevel "Debug"
    Write-Log -logFile $logFile -module $functionName -message "TARGET CHECK: Looking for '$targetOSLower' in hints [$hintSummary] = $hasTargetHint" -logLevel "Debug"

    switch ($targetOSLower)
    {
        'windows'
        {
            Write-Log -logFile $logFile -module $functionName -message "DECISION PATH: Windows-specific filtering logic" -logLevel "Debug"
            Write-Log -logFile $logFile -module $functionName -message "CRITICAL LOGIC: Windows filtering ONLY includes resources with explicit Windows hints" -logLevel "Debug"

            # CRITICAL: For Windows filtering, ONLY include resources that explicitly have Windows hints
            # Resources with no hints or conflicting hints should be EXCLUDED
            if ($hasTargetHint)
            {
                Write-Log -logFile $logFile -module $functionName -message "DECISION: Resource HAS Windows hint - INCLUDING" -logLevel "Verbose"
                Write-Log -logFile $logFile -module $functionName -message "=== END Platform Match Check === RESULT: TRUE (Windows hint found)" -logLevel "Debug"
                return $true
            }

            # If no Windows hint found, exclude the resource
            Write-Log -logFile $logFile -module $functionName -message "DECISION: Resource does NOT have Windows hint (hints: $hintSummary) - EXCLUDING" -logLevel "Verbose"
            Write-Log -logFile $logFile -module $functionName -message "RATIONALE: Windows filter requires explicit Windows platform indicator" -logLevel "Debug"
            Write-Log -logFile $logFile -module $functionName -message "=== END Platform Match Check === RESULT: FALSE (no Windows hint)" -logLevel "Debug"
            return $false
        }
        default
        {
            Write-Log -logFile $logFile -module $functionName -message "DECISION PATH: Default filtering logic for TargetOS='$TargetOS'" -logLevel "Debug"
            Write-Log -logFile $logFile -module $functionName -message "DECISION LOGIC: Include resource if target OS hint exists in platform hints" -logLevel "Debug"
            Write-Log -logFile $logFile -module $functionName -message "DECISION: Returning $hasTargetHint for TargetOS '$TargetOS' based on hints." -logLevel "Verbose"
            Write-Log -logFile $logFile -module $functionName -message "=== END Platform Match Check === RESULT: $hasTargetHint" -logLevel "Debug"
            return $hasTargetHint
        }
    }
}

function Get-CorrectBaseUriForResource()
{
    <#
    .SYNOPSIS
    Determines the correct Graph API base URI for a resource based on its @odata.type.

    .DESCRIPTION
    Maps resource OData types to their corresponding Microsoft Graph API endpoint base URIs.
    This ensures consistent endpoint usage across all assignment functions, especially important
    for resources that may be returned from batch endpoints with incorrect base URIs.

    Special handling includes:
    - Managed app protection policies with T_ or A_ prefixes
    - All mobile app types (win32, iOS, Android, etc.)
    - Compliance policies
    - Device configurations including Update rings
    - Configuration policies (Settings Catalog)
    - Scripts (standard and health)
    - App protection/managed app policies
    - Windows Information Protection policies
    - Security intents/baselines
    - Policy sets
    - Autopilot profiles
    - Windows Update profiles (Feature, Quality, Driver)
    - Resource access profiles

    .PARAMETER Resource
    The resource object containing the id and @odata.type properties.

    .PARAMETER ODataType
    Optional explicit OData type string. If not provided, uses Resource.@odata.type.

    .RETURNS
    String containing the correct base URI path, or $null if unable to determine.

    .EXAMPLE
    $baseUri = Get-CorrectBaseUriForResource -Resource $myResource

    .EXAMPLE
    $baseUri = Get-CorrectBaseUriForResource -Resource $resource -ODataType "#microsoft.graph.win32LobApp"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Resource,
        [Parameter(Mandatory = $false)]
        [string]$ODataType
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Determining base URI for resource (ResourceId: $($Resource.id))" -logLevel "Debug"

    # Special handling for managed app protection IDs with T_ or A_ prefixes
    # These are targetedManagedAppConfiguration and managed app protection policies
    if ($Resource.id -and ($Resource.id -match '^[TA]_'))
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Detected managed app protection ID prefix: $($Resource.id), using deviceAppManagement/managedAppPolicies" -logLevel "Verbose"
        return "deviceAppManagement/managedAppPolicies"
    }

    $odataType = if ([string]::IsNullOrWhiteSpace($ODataType) -and $Resource.'@odata.type')
    {
        $Resource.'@odata.type'.ToLower()
    }
    elseif (-not [string]::IsNullOrWhiteSpace($ODataType))
    {
        $ODataType.ToLower()
    }
    else
    {
        Write-Log -logFile $LogFile -module $functionName -Message "No @odata.type found for resource $($Resource.id)" -logLevel "Warning"
        return $null
    }

    Write-Log -logFile $LogFile -module $functionName -Message "OData type: $odataType" -logLevel "Debug"

    # Mobile Apps - all app types go to deviceAppManagement/mobileApps
    if ($odataType -match 'win32lobapp|ioslobapp|androidlobapp|iosvppapp|androidmanagedstoreapp|managediosstore|' +
        'webapp|microsoftstoreforbusinessapp|wingetapp|macoslobapp|macosvppapp|macospkgapp|windowsmobilemsi|' +
        'iosstoreapp|officesuiteapp|managedapp')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched mobile app type, using deviceAppManagement/mobileApps" -logLevel "Verbose"
        return "deviceAppManagement/mobileApps"
    }

    # Compliance Policies
    if ($odataType -match 'compliancepolicy')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched compliance policy type, using deviceManagement/deviceCompliancePolicies" -logLevel "Verbose"
        return "deviceManagement/deviceCompliancePolicies"
    }

    # Device Configurations
    if ($odataType -match 'windows10generalconfiguration|windowscustomconfiguration|windows10customconfiguration|' +
        'iosgeneraldeviceconfiguration|ioscustomconfiguration|androidgeneraldeviceconfiguration|androidcustomconfiguration|' +
        'macosgeneraldeviceconfiguration|macoscustomconfiguration|windowsupdateforbusinessconfiguration')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched device configuration type, using deviceManagement/deviceConfigurations" -logLevel "Verbose"
        return "deviceManagement/deviceConfigurations"
    }

    # Configuration Policies (Settings Catalog)
    if ($odataType -match '#microsoft\.graph\.configurationpolicy')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched configuration policy (Settings Catalog) type, using deviceManagement/configurationPolicies" -logLevel "Verbose"
        return "deviceManagement/configurationPolicies"
    }

    # Group Policy Configurations
    if ($odataType -match 'grouppolicyconfiguration')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched group policy configuration type, using deviceManagement/groupPolicyConfigurations" -logLevel "Verbose"
        return "deviceManagement/groupPolicyConfigurations"
    }

    # Scripts
    if ($odataType -match 'devicemanagementscript' -and $odataType -notmatch 'health')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched device management script type, using deviceManagement/deviceManagementScripts" -logLevel "Verbose"
        return "deviceManagement/deviceManagementScripts"
    }

    # Health Scripts
    if ($odataType -match 'devicehealthscript')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched health script type, using deviceManagement/deviceHealthScripts" -logLevel "Verbose"
        return "deviceManagement/deviceHealthScripts"
    }

    # App Protection/Managed App Policies
    if ($odataType -match 'managedapppolicy|managedappprotection|iosmanagedappprotection|androidmanagedappprotection|' +
        'targetedmanagedappconfiguration|windowsinformationprotectionpolicy|mdmwindowsinformationprotectionpolicy')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched managed app policy type, using deviceAppManagement/managedAppPolicies" -logLevel "Verbose"
        return "deviceAppManagement/managedAppPolicies"
    }

    # Windows Information Protection (specific endpoints)
    if ($odataType -match '#microsoft\.graph\.windowsinformationprotectionpolicy$')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched Windows Information Protection policy type, using deviceAppManagement/windowsInformationProtectionPolicies" -logLevel "Verbose"
        return "deviceAppManagement/windowsInformationProtectionPolicies"
    }
    if ($odataType -match '#microsoft\.graph\.mdmwindowsinformationprotectionpolicy')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched MDM Windows Information Protection policy type, using deviceAppManagement/mdmWindowsInformationProtectionPolicies" -logLevel "Verbose"
        return "deviceAppManagement/mdmWindowsInformationProtectionPolicies"
    }

    # Intents (Security Baselines)
    if ($odataType -match 'intent')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched security intent type, using deviceManagement/intents" -logLevel "Verbose"
        return "deviceManagement/intents"
    }

    # Policy Sets
    if ($odataType -match 'policyset')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched policy set type, using deviceAppManagement/policySets" -logLevel "Verbose"
        return "deviceAppManagement/policySets"
    }

    # Autopilot Profiles
    if ($odataType -match 'windowsautopilotdeploymentprofile')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched Autopilot profile type, using deviceManagement/windowsAutopilotDeploymentProfiles" -logLevel "Verbose"
        return "deviceManagement/windowsAutopilotDeploymentProfiles"
    }

    # Windows Feature Update Profiles
    if ($odataType -match 'windowsfeatureupdateprofile')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched Windows Feature Update profile type, using deviceManagement/windowsFeatureUpdateProfiles" -logLevel "Verbose"
        return "deviceManagement/windowsFeatureUpdateProfiles"
    }

    # Windows Quality Update Profiles
    if ($odataType -match 'windowsqualityupdateprofile')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched Windows Quality Update profile type, using deviceManagement/windowsQualityUpdateProfiles" -logLevel "Verbose"
        return "deviceManagement/windowsQualityUpdateProfiles"
    }

    # Windows Driver Update Profiles
    if ($odataType -match 'windowsdriverupdateprofile')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched Windows Driver Update profile type, using deviceManagement/windowsDriverUpdateProfiles" -logLevel "Verbose"
        return "deviceManagement/windowsDriverUpdateProfiles"
    }

    # Resource Access Profiles
    if ($odataType -match 'resourceaccessprofile')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Matched resource access profile type, using deviceManagement/resourceAccessProfiles" -logLevel "Verbose"
        return "deviceManagement/resourceAccessProfiles"
    }

    # If we can't determine, return null
    Write-Log -logFile $LogFile -module $functionName -Message "Unable to determine base URI for OData type: $odataType" -logLevel "Warning"
    return $null
}

function Get-AppProtectionPolicyAssignments()
{
    <#
    .SYNOPSIS
    Retrieves assignments for app protection policies using resource-type-specific endpoints.

    .DESCRIPTION
    App protection policies (iOS/Android Managed App Protection and Targeted Managed App Configuration)
    require resource-type-specific endpoints instead of the standard /assignments pattern.

    This function determines the correct endpoint based on the OData type and retrieves the assignments.

    Supported types:
    - androidManagedAppProtection → /deviceAppManagement/androidManagedAppProtections/{id}/assignments
    - iosManagedAppProtection → /deviceAppManagement/iosManagedAppProtections/{id}/assignments
    - targetedManagedAppConfiguration → /deviceAppManagement/targetedManagedAppConfigurations/{id}/assignments

    .PARAMETER ResourceId
    The ID of the app protection policy resource.

    .PARAMETER ODataType
    The @odata.type of the resource (determines which endpoint to use).

    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.

    .PARAMETER APIVersion
    The API version to use (v1.0 or beta).

    .RETURNS
    Assignment response object with value property containing assignments, or $null if error.

    .EXAMPLE
    $assignments = Get-AppProtectionPolicyAssignments -ResourceId "abc-123" -ODataType "#microsoft.graph.androidManagedAppProtection" -AccessToken $token -APIVersion "v1.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceId,
        [Parameter(Mandatory = $true)]
        [string]$ODataType,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$APIVersion
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Retrieving app protection policy assignments (ResourceId: '$ResourceId', ODataType: '$ODataType', API: $APIVersion)" -logLevel "Verbose"

    # Determine the correct endpoint based on OData type
    $endpoint = $null
    switch -Regex ($ODataType)
    {
        'androidManagedAppProtection'
        {
            $endpoint = "deviceAppManagement/androidManagedAppProtections/$ResourceId/assignments"
            Write-Log -logFile $LogFile -module $functionName -Message "Using Android managed app protection endpoint: $endpoint" -logLevel "Verbose"
        }
        'iosManagedAppProtection'
        {
            $endpoint = "deviceAppManagement/iosManagedAppProtections/$ResourceId/assignments"
            Write-Log -logFile $LogFile -module $functionName -Message "Using iOS managed app protection endpoint: $endpoint" -logLevel "Verbose"
        }
        'targetedManagedAppConfiguration'
        {
            $endpoint = "deviceAppManagement/targetedManagedAppConfigurations/$ResourceId/assignments"
            Write-Log -logFile $LogFile -module $functionName -Message "Using targeted managed app configuration endpoint: $endpoint" -logLevel "Verbose"
        }
        default
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Unknown app protection type: $ODataType, cannot determine endpoint" -logLevel "Warning"
            return $null
        }
    }

    try
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Fetching app protection assignments using endpoint: $endpoint" -logLevel "Verbose"
        $result = CallGraphAPI -accessToken $AccessToken -ResourcePath $endpoint -APIVersion $APIVersion -Method "GET"
        Write-Log -logFile $LogFile -module $functionName -Message "Successfully retrieved assignments for ResourceId: $ResourceId" -logLevel "Verbose"
        return $result
    }
    catch
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Error fetching app protection assignments: $($_.Exception.Message)" -logLevel "Warning"
        return $null
    }
}

function Test-ResourceSupportsAssignments()
{
    <#
    .SYNOPSIS
    Tests if a resource supports assignments using metadata analysis.

    .DESCRIPTION
    Uses Graph API metadata to determine if a resource type supports assignments navigation property.
    Caches results per entity type to avoid redundant API calls.

    Special cases handled:
    - PolicySets: Known API design limitation, standard assignment endpoint not supported
    - App Protection Policies: Require alternative resource-type-specific endpoints (returns special flag)

    .PARAMETER Resource
    The resource object to test (must include @odata.type).

    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.

    .RETURNS
    - $true: Resource supports standard /assignments endpoint
    - $false: Resource does not support assignments or has known limitations
    - 'ALTERNATIVE_ENDPOINT_REQUIRED': Resource requires special endpoint pattern (app protection policies)

    .EXAMPLE
    $supportsAssignments = Test-ResourceSupportsAssignments -Resource $myResource -AccessToken $token
    if ($supportsAssignments -eq $true) { # Standard assignment retrieval }
    elseif ($supportsAssignments -eq 'ALTERNATIVE_ENDPOINT_REQUIRED') { # Use alternative endpoint }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Resource,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    $functionName = $MyInvocation.MyCommand.Name

    # Cache metadata results per entity type to avoid redundant API calls
    if (-not $script:MetadataCache)
    {
        $script:MetadataCache = @{}
        Write-Log -logFile $LogFile -module $functionName -Message "Initialized metadata cache for assignment support validation" -logLevel "Verbose"
    }

    # Get entity type from @odata.type
    $odataType = $Resource.'@odata.type'
    if ([string]::IsNullOrWhiteSpace($odataType))
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Resource missing @odata.type, cannot validate assignment support - assuming supported" -logLevel "Verbose"
        return $true  # Assume supported if we can't determine
    }

    Write-Log -logFile $LogFile -module $functionName -Message "Testing assignment support for ODataType: '$odataType'" -logLevel "Verbose"

    # Known Graph metadata gaps for Windows Update profiles – treat as supported
    if ($odataType -match 'windowsfeatureupdateprofile|windowsqualityupdateprofile|windowsdriverupdateprofile')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Bypassing metadata check for Windows Update profile type '$odataType' (known Graph limitation)" -logLevel "Verbose"
        $script:MetadataCache[$odataType] = $true
        return $true
    }

    # Exception list for known API design limitations that require alternative handling
    # PolicySets: Use non-standard OData routing, assignments exist but GET endpoint differs
    if ($Resource.ResourceType -eq 'policySets' -or $odataType -match 'policySet')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "PolicySet detected ($odataType): Known API design limitation, standard assignment endpoint not supported" -logLevel "Verbose"
        $script:MetadataCache[$odataType] = $false
        return $false
    }

    # App Protection Policies: Use targetedManagedAppPolicyAssignment, require resource-type-specific endpoints
    if ($odataType -match 'ManagedAppProtection|targetedManagedAppConfiguration')
    {
        Write-Log -logFile $LogFile -module $functionName -Message "App Protection Policy detected ($odataType): Requires alternative endpoint pattern" -logLevel "Verbose"
        # Return special value to flag for alternative handling (will be processed separately)
        $script:MetadataCache[$odataType] = 'ALTERNATIVE_ENDPOINT_REQUIRED'
        return 'ALTERNATIVE_ENDPOINT_REQUIRED'
    }

    # Check cache first
    if ($script:MetadataCache.ContainsKey($odataType))
    {
        $supportsAssignments = $script:MetadataCache[$odataType]
        Write-Log -logFile $LogFile -module $functionName -Message "Metadata cache hit for $($odataType): SupportsAssignments=$supportsAssignments" -logLevel "Verbose"
        return $supportsAssignments
    }

    try
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Fetching metadata for $odataType to validate assignment support" -logLevel "Verbose"

        # Determine API version from script scope or default to v1.0
        $apiVersion = if ($script:APIVersion) { $script:APIVersion } else { 'v1.0' }
        Write-Log -logFile $LogFile -module $functionName -Message "Using API version: $apiVersion for metadata query" -logLevel "Debug"

        # Create a minimal response object with @odata.context for GetGraphObjectMetadata
        $fakeResponse = [PSCustomObject]@{
            '@odata.context' = "https://graph.microsoft.com/$apiVersion/`$metadata#$odataType"
            value            = @($Resource)
        }

        # Call GetGraphObjectMetadata to analyze the entity type
        $metadata = GetGraphObjectMetadata -ApiResponse $fakeResponse -AccessToken $AccessToken -IncludeSampleQueries $false

        if ($metadata -and $metadata.NavigationProperties)
        {
            # Look for any navigation property that references assignments (exact or variant names)
            $assignmentNav = $metadata.NavigationProperties | Where-Object { $_.Name -match 'assignment' }

            if ($assignmentNav)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Metadata analysis for $($odataType): assignment navigation detected ($($assignmentNav.Name -join ', '))" -logLevel "Verbose"
                $script:MetadataCache[$odataType] = $true
                return $true
            }

            Write-Log -logFile $LogFile -module $functionName -Message "Metadata for $($odataType) contains navigation properties but none named like 'assignment'. Defaulting to supported." -logLevel "Verbose"
            $script:MetadataCache[$odataType] = $true
            return $true
        }
        else
        {
            Write-Log -logFile $LogFile -module $functionName -Message "No navigation properties found in metadata for $odataType, assuming assignment support" -logLevel "Verbose"
            $script:MetadataCache[$odataType] = $true
            return $true
        }
    }
    catch
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Error fetching metadata for $($odataType): $($_.Exception.Message). Assuming assignment support." -logLevel "Warning"
        # On error, assume supported to avoid false negatives
        $script:MetadataCache[$odataType] = $true
        return $true
    }
}

function Get-ErrorCategory()
{
    <#
    .SYNOPSIS
    Categorizes errors based on error codes, messages, and resource context.

    .DESCRIPTION
    Analyzes error information to classify errors into standard categories for consistent
    error handling and reporting across all assignment functions.

    Categories:
    - API_DESIGN_LIMITATION: Known API design patterns requiring alternative approaches (e.g., PolicySets)
    - UNSUPPORTED_ENDPOINT: Resource requires alternative endpoint pattern
    - PERMISSION_DENIED: Insufficient API permissions (403)
    - RESOURCE_NOT_FOUND: Resource not found (404)
    - RATE_LIMIT: API rate limit exceeded (429)
    - SERVER_ERROR: Microsoft Graph server error (5xx)
    - INVALID_REQUEST: Bad request (400)
    - NO_RESPONSE: No response from API
    - MALFORMED_RESPONSE: Unexpected response structure
    - UNKNOWN: Unclassified error

    .PARAMETER ErrorCode
    The error code from the API response or exception.

    .PARAMETER ErrorMessage
    The error message text.

    .PARAMETER ResourceType
    The type of resource being accessed (e.g., 'policySets').

    .PARAMETER ODataType
    The @odata.type of the resource.

    .RETURNS
    String containing the error category.

    .EXAMPLE
    $category = Get-ErrorCategory -ErrorCode "403" -ErrorMessage "Forbidden" -ResourceType "mobileApps" -ODataType "#microsoft.graph.win32LobApp"
    #>
    [CmdletBinding()]
    param(
        [string]$ErrorCode,
        [string]$ErrorMessage,
        [string]$ResourceType,
        [string]$ODataType
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Categorizing error: Code='$ErrorCode', ResourceType='$ResourceType', ODataType='$ODataType'" -logLevel "Verbose"

    # PolicySets OData routing limitation
    if ($ResourceType -eq 'policySets' -and $ErrorCode -like '*No method match route template*')
    {
        return 'API_DESIGN_LIMITATION'
    }

    # App Protection Policies different assignment model
    if ($ErrorCode -eq 'BadRequest' -and $ErrorMessage -like '*Resource not found for the segment*assignments*')
    {
        if ($ODataType -match 'ManagedAppProtection|targetedManagedAppConfiguration')
        {
            return 'UNSUPPORTED_ENDPOINT'
        }
    }

    # Standard error codes
    switch -Regex ($ErrorCode)
    {
        '^403$|Forbidden'
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Categorized as PERMISSION_DENIED" -logLevel "Verbose"
            return 'PERMISSION_DENIED'
        }
        '^404$|NotFound'
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Categorized as RESOURCE_NOT_FOUND" -logLevel "Verbose"
            return 'RESOURCE_NOT_FOUND'
        }
        '^429$|TooManyRequests'
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Categorized as RATE_LIMIT" -logLevel "Verbose"
            return 'RATE_LIMIT'
        }
        '^5\d{2}$|ServerError'
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Categorized as SERVER_ERROR" -logLevel "Verbose"
            return 'SERVER_ERROR'
        }
        'BadRequest'
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Categorized as INVALID_REQUEST" -logLevel "Verbose"
            return 'INVALID_REQUEST'
        }
        'NULL'
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Categorized as NO_RESPONSE" -logLevel "Verbose"
            return 'NO_RESPONSE'
        }
        'MALFORMED'
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Categorized as MALFORMED_RESPONSE" -logLevel "Verbose"
            return 'MALFORMED_RESPONSE'
        }
        default
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Categorized as UNKNOWN (unmatched error code)" -logLevel "Verbose"
            return 'UNKNOWN'
        }
    }
}

function Get-RemediationGuidance()
{
    <#
    .SYNOPSIS
    Provides remediation guidance based on error category.

    .DESCRIPTION
    Returns actionable guidance text for remediating errors based on the error category
    and resource context. Helps users understand what to do when errors occur.

    .PARAMETER ErrorCategory
    The categorized error type from Get-ErrorCategory.

    .PARAMETER ErrorCode
    The original error code.

    .PARAMETER ResourceType
    The type of resource being accessed.

    .PARAMETER ODataType
    The @odata.type of the resource.

    .RETURNS
    String containing remediation guidance.

    .EXAMPLE
    $guidance = Get-RemediationGuidance -ErrorCategory "PERMISSION_DENIED" -ErrorCode "403" -ResourceType "mobileApps" -ODataType "#microsoft.graph.win32LobApp"
    #>
    [CmdletBinding()]
    param(
        [string]$ErrorCategory,
        [string]$ErrorCode,
        [string]$ResourceType,
        [string]$ODataType
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Providing remediation guidance for error category: '$ErrorCategory'" -logLevel "Verbose"

    switch ($ErrorCategory)
    {
        'API_DESIGN_LIMITATION'
        {
            return "PolicySets use non-standard OData routing. Consider implementing alternative query method or skipping assignment retrieval for this resource type."
        }
        'UNSUPPORTED_ENDPOINT'
        {
            if ($ODataType -match 'androidManagedAppProtection')
            {
                return "Use /deviceAppManagement/androidManagedAppProtections/{id}/assignments endpoint instead."
            }
            elseif ($ODataType -match 'iosManagedAppProtection')
            {
                return "Use /deviceAppManagement/iosManagedAppProtections/{id}/assignments endpoint instead."
            }
            elseif ($ODataType -match 'targetedManagedAppConfiguration')
            {
                return "Use /deviceAppManagement/targetedManagedAppConfigurations/{id}/assignments endpoint instead."
            }
            else
            {
                return "App Protection Policies require resource-type-specific endpoints. Check Microsoft Graph API documentation."
            }
        }
        'PERMISSION_DENIED'
        {
            return "Insufficient permissions. Verify API permissions include DeviceManagementApps.Read.All and DeviceManagementConfiguration.Read.All."
        }
        'RESOURCE_NOT_FOUND'
        {
            return "Resource may have been deleted or ID is invalid. Verify resource exists in Intune portal."
        }
        'RATE_LIMIT'
        {
            return "API rate limit exceeded. Implement retry logic with exponential backoff or reduce request frequency."
        }
        'SERVER_ERROR'
        {
            return "Microsoft Graph API server error. Retry the operation after a brief delay."
        }
        'NO_RESPONSE'
        {
            return "No response from API. Check network connectivity and API availability."
        }
        'MALFORMED_RESPONSE'
        {
            return "Response structure unexpected. May indicate API version mismatch or schema change."
        }
        default
        {
            return "Review error details and check Microsoft Graph API documentation for this resource type."
        }
    }
}

function Build-BatchResponseLookup()
{
    <#
    .SYNOPSIS
    Builds an efficient lookup dictionary for batch API responses.

    .DESCRIPTION
    Creates a hashtable that maps batch response IDs to their response objects for efficient lookup.
    CallGraphAPI batch responses include an 'id' field matching the request order (1, 2, 3...).

    This function ensures consistent ID handling (converts to strings for hashtable keys) and
    provides logging for troubleshooting batch response matching issues.

    .PARAMETER BatchResponses
    Array of batch response objects from CallGraphAPI (must have 'id' property).

    .RETURNS
    Hashtable with string keys (response IDs) and response objects as values.

    .EXAMPLE
    $lookup = Build-BatchResponseLookup -BatchResponses $batchResult.value
    $response = $lookup["5"]  # Get response for request ID 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$BatchResponses
    )

    $functionName = $MyInvocation.MyCommand.Name
    $lookup = @{}

    foreach ($response in $BatchResponses)
    {
        if ($response.id)
        {
            # Convert ID to string for consistent hashtable lookup
            $lookup[$response.id.ToString()] = $response
        }
    }

    Write-Log -logFile $LogFile -module $functionName -Message "Built response lookup with $($lookup.Count) entries from $($BatchResponses.Count) batch responses" -logLevel "Verbose"

    return $lookup
}

function Get-IntuneResourceLists()
{
    <#
    .SYNOPSIS
    Fetches all Intune resource lists using batch API with caching and platform filtering support.

    .DESCRIPTION
    Retrieves all Intune resource types (apps, configurations, policies, scripts, etc.) via Microsoft Graph API.
    Implements intelligent caching per API version with per-resource retry logic for failed endpoints.
    Supports platform filtering when Settings.operatingSystem is specified.

    This function consolidates duplicate resource fetching logic previously present in:
    - Get-GroupDirectAssignments
    - Get-GroupIndirectAssignments
    - Export-ConfigurationAssignments

    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.

    .PARAMETER IncludeBeta
    Switch to include beta API endpoints for additional resource types.

    .PARAMETER Settings
    Optional settings hashtable for platform filtering (Settings.operatingSystem).

    .PARAMETER CacheKey
    Optional cache key prefix. If not specified, uses default based on API version.
    Useful for separating caches for different operational contexts (e.g., 'Direct', 'Indirect', 'Export').

    .PARAMETER SkipCache
    Switch to bypass cache and always fetch fresh data. Useful for export scenarios requiring complete data.

    .PARAMETER ResultObject
    Optional assignment result object to track failed resources. If provided, failures will be added to ResultObject.FailedResources.

    .RETURNS
    Hashtable with the following structure:
    @{
        mobileApps             = @(...)
        deviceConfigs          = @(...)
        compliancePolicies     = @(...)
        autopilotProfiles      = @(...)
        deviceScripts          = @(...)
        healthScripts          = @(...)
        appProtectionPolicies  = @(...)
        intents                = @(...)
        resourceAccessProfiles = @(...)
        configurationPolicies  = @(...)
        groupPolicyConfigs     = @(...)
        policySets             = @(...)
        wipPolicies            = @(...)
        mdmWipPolicies         = @(...)
        FailedResourceIds      = @(...)  # IDs of resources that failed to fetch
    }

    .EXAMPLE
    # Fetch with caching and platform filtering
    $resources = Get-IntuneResourceLists -AccessToken $token -IncludeBeta -Settings $settings

    .EXAMPLE
    # Fetch without cache for export
    $resources = Get-IntuneResourceLists -AccessToken $token -IncludeBeta -Settings $settings -SkipCache

    .EXAMPLE
    # Fetch with custom cache key and track failures
    $assignments = Initialize-AssignmentResultObject
    $resources = Get-IntuneResourceLists -AccessToken $token -IncludeBeta -CacheKey "MyCustomCache" -ResultObject $assignments
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeBeta,
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings,
        [Parameter(Mandatory = $false)]
        [string]$CacheKey,
        [Parameter(Mandatory = $false)]
        [switch]$SkipCache,
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$ResultObject
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -module $functionName -Message "Starting Intune resource list retrieval" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "Parameters: IncludeBeta=$($IncludeBeta.IsPresent), SkipCache=$($SkipCache.IsPresent), CacheKey='$CacheKey', HasSettings=$($null -ne $Settings)" -logLevel "Verbose"

    if ($Settings -and $Settings.operatingSystem)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Platform filtering enabled for OS: $($Settings.operatingSystem)" -logLevel "Information"
    }

    # Determine API version
    $apiVersion = if ($IncludeBeta.IsPresent) { 'beta' } else { 'v1.0' }
    $apiVersionKey = $apiVersion

    # Determine cache key
    if (-not $CacheKey)
    {
        $CacheKey = "ResourceLists_${apiVersionKey}"
    }
    else
    {
        $CacheKey = "${CacheKey}_${apiVersionKey}"
    }

    Write-Log -logFile $LogFile -module $functionName -Message "Fetching Intune resource lists (API: $apiVersion, CacheKey: $CacheKey, SkipCache: $($SkipCache.IsPresent))" -logLevel "Information"
    Write-Verbose "[$functionName] API: $apiVersion, CacheKey: $CacheKey, SkipCache: $($SkipCache.IsPresent)"

    # Check cache unless SkipCache is specified
    $cachedResourceLists = $null
    if (-not $SkipCache.IsPresent)
    {
        $cachedResourceLists = Get-CachedData -CacheType 'Configuration' -Key $CacheKey
    }

    # Initialize result variables
    $mobileApps = @()
    $deviceConfigs = @()
    $compliancePolicies = @()
    $autopilotProfiles = @()
    $deviceScripts = @()
    $healthScripts = @()
    $appProtectionPolicies = @()
    $intents = @()
    $resourceAccessProfiles = @()
    $configurationPolicies = @()
    $groupPolicyConfigs = @()
    $policySets = @()
    $wipPolicies = @()
    $mdmWipPolicies = @()
    $windowsFeatureUpdates = @()
    $windowsQualityUpdates = @()
    $windowsDriverUpdates = @()
    $failedResourceIds = @()
    $resourceListsToCache = $null

    if ($cachedResourceLists)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Using cached resource lists (CacheKey: $CacheKey)" -logLevel "Verbose"
        Write-Verbose "[$functionName] Cache hit for resource lists"

        # Extract cached resources
        $mobileApps = $cachedResourceLists.mobileApps
        $deviceConfigs = $cachedResourceLists.deviceConfigs
        $compliancePolicies = $cachedResourceLists.compliancePolicies
        $autopilotProfiles = $cachedResourceLists.autopilotProfiles
        $deviceScripts = $cachedResourceLists.deviceScripts
        $healthScripts = $cachedResourceLists.healthScripts
        $appProtectionPolicies = $cachedResourceLists.appProtectionPolicies
        $intents = $cachedResourceLists.intents
        $resourceAccessProfiles = $cachedResourceLists.resourceAccessProfiles
        $configurationPolicies = $cachedResourceLists.configurationPolicies
        $groupPolicyConfigs = $cachedResourceLists.groupPolicyConfigs
        $policySets = $cachedResourceLists.policySets
        $wipPolicies = $cachedResourceLists.wipPolicies
        $mdmWipPolicies = $cachedResourceLists.mdmWipPolicies
        if ($cachedResourceLists.PSObject.Properties['windowsFeatureUpdates'])
        {
            $windowsFeatureUpdates = $cachedResourceLists.windowsFeatureUpdates
        }
        if ($cachedResourceLists.PSObject.Properties['windowsQualityUpdates'])
        {
            $windowsQualityUpdates = $cachedResourceLists.windowsQualityUpdates
        }
        if ($cachedResourceLists.PSObject.Properties['windowsDriverUpdates'])
        {
            $windowsDriverUpdates = $cachedResourceLists.windowsDriverUpdates
        }

        # Check for resources marked as $null (previously failed) and retry them
        $resourcesToRetry = @()
        $resourceRetryMap = @{
            'mobileApps'             = @{ endpoint = "deviceAppManagement/mobileApps?`$select=id,displayName,description"; variable = 'mobileApps' }
            'deviceConfigs'          = @{ endpoint = "deviceManagement/deviceConfigurations?`$select=id,displayName,description"; variable = 'deviceConfigs' }
            'compliancePolicies'     = @{ endpoint = "deviceManagement/deviceCompliancePolicies?`$select=id,displayName,description"; variable = 'compliancePolicies' }
            'autopilotProfiles'      = @{ endpoint = "deviceManagement/windowsAutopilotDeploymentProfiles?`$select=id,displayName,description"; variable = 'autopilotProfiles' }
            'deviceScripts'          = @{ endpoint = "deviceManagement/deviceManagementScripts?`$select=id,displayName,description"; variable = 'deviceScripts' }
            'healthScripts'          = @{ endpoint = "deviceManagement/deviceHealthScripts?`$select=id,displayName,description"; variable = 'healthScripts' }
            'appProtectionPolicies'  = @{ endpoint = "deviceAppManagement/managedAppPolicies?`$select=id,displayName,description"; variable = 'appProtectionPolicies' }
            'intents'                = @{ endpoint = "deviceManagement/intents?`$select=id,displayName,description"; variable = 'intents' }
            'resourceAccessProfiles' = @{ endpoint = "deviceManagement/resourceAccessProfiles?`$select=id,displayName,description"; variable = 'resourceAccessProfiles' }
            'configurationPolicies'  = @{ endpoint = "deviceManagement/configurationPolicies?`$select=id,name,description"; variable = 'configurationPolicies' }
            'groupPolicyConfigs'     = @{ endpoint = "deviceManagement/groupPolicyConfigurations?`$select=id,displayName,description"; variable = 'groupPolicyConfigs' }
            'policySets'             = @{ endpoint = "deviceAppManagement/policySets?`$select=id,displayName,description"; variable = 'policySets' }
            'wipPolicies'            = @{ endpoint = "deviceAppManagement/windowsInformationProtectionPolicies?`$select=id,displayName,description"; variable = 'wipPolicies' }
            'mdmWipPolicies'         = @{ endpoint = "deviceAppManagement/mdmWindowsInformationProtectionPolicies?`$select=id,displayName,description"; variable = 'mdmWipPolicies' }
        }

        if ($IncludeBeta.IsPresent)
        {
            $resourceRetryMap['windowsFeatureUpdates'] = @{ endpoint = "deviceManagement/windowsFeatureUpdateProfiles?`$select=id,displayName,description"; variable = 'windowsFeatureUpdates' }
            $resourceRetryMap['windowsQualityUpdates'] = @{ endpoint = "deviceManagement/windowsQualityUpdateProfiles?`$select=id,displayName,description"; variable = 'windowsQualityUpdates' }
            $resourceRetryMap['windowsDriverUpdates'] = @{ endpoint = "deviceManagement/windowsDriverUpdateProfiles?`$select=id,displayName,description"; variable = 'windowsDriverUpdates' }
        }

        foreach ($resourceId in $resourceRetryMap.Keys)
        {
            if ($null -eq $cachedResourceLists[$resourceId])
            {
                $resourcesToRetry += $resourceId
            }
        }

        if ($resourcesToRetry.Count -gt 0)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Retrying $($resourcesToRetry.Count) previously failed resources" -logLevel "Information"
            Write-Verbose "[$functionName] Retrying failed resources: $($resourcesToRetry -join ', ')"

            # Build batch request for retry
            $retryBatchBody = @{
                requests = @()
            }

            foreach ($resourceId in $resourcesToRetry)
            {
                $retryBatchBody.requests += @{
                    id     = $resourceId
                    method = "GET"
                    url    = $resourceRetryMap[$resourceId].endpoint
                }
            }

            # Send retry batch request
            try
            {
                $retryBatchResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath "`$batch" -APIVersion $apiVersion -Method "POST" -Body ($retryBatchBody | ConvertTo-Json -Depth $global:maxJSONDepth)

                if ($retryBatchResponse -and $retryBatchResponse.responses)
                {
                    foreach ($response in $retryBatchResponse.responses)
                    {
                        if ($response.status -eq 200 -and $response.body.value)
                        {
                            # Retry successful - update the variable
                            $varName = $resourceRetryMap[$response.id].variable
                            Set-Variable -Name $varName -Value $response.body.value -Scope Local
                            Write-Log -logFile $LogFile -module $functionName -Message "Retry successful for '$($response.id)' - retrieved $($response.body.value.Count) items" -logLevel "Verbose"
                        }
                        else
                        {
                            # Retry failed - track error again
                            $failedResourceIds += $response.id
                            $errorMsg = if ($response.body.error.message) { $response.body.error.message } else { "Unknown error (Status: $($response.status))" }

                            if ($ResultObject)
                            {
                                Add-FailedResourceError -ResultObject $ResultObject -ResourceType $response.id -ErrorMessage $errorMsg -StatusCode $response.status -ApiVersion $apiVersionKey
                            }

                            Write-Log -logFile $LogFile -module $functionName -Message "Retry failed for '$($response.id)': $errorMsg" -logLevel "Warning"
                        }
                    }
                }
            }
            catch
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Error during retry batch request: $($_.Exception.Message)" -LogLevel "Error"
            }
        }
    }
    else
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Cache miss - fetching resource lists from Graph API" -logLevel "Verbose"
        Write-Verbose "[$functionName] No cached resource lists found, fetching from API"

        # Create batch request for all resource lists
        $batchRequestBody = @{
            requests = @()
        }

        # Define resource endpoints
        $resourceEndpoints = @(
            @{ id = "mobileApps"; url = "deviceAppManagement/mobileApps"; extraParams = "select=id,displayName,description" }
            @{ id = "deviceConfigs"; url = "deviceManagement/deviceConfigurations"; extraParams = "select=id,displayName,description" }
            @{ id = "compliancePolicies"; url = "deviceManagement/deviceCompliancePolicies"; extraParams = "select=id,displayName,description" }
            @{ id = "deviceScripts"; url = "deviceManagement/deviceManagementScripts"; extraParams = "select=id,displayName,description" }
            @{ id = "appProtectionPolicies"; url = "deviceAppManagement/managedAppPolicies"; extraParams = "select=id,displayName,description" }
            @{ id = "intents"; url = "deviceManagement/intents"; extraParams = "select=id,displayName,description" }
            @{ id = "policySets"; url = "deviceAppManagement/policySets"; extraParams = "select=id,displayName,description" }
        )

        # Add beta endpoints if IncludeBeta is specified
        if ($IncludeBeta.IsPresent)
        {
            $resourceEndpoints += @(
                @{ id = "autopilotProfiles"; url = "deviceManagement/windowsAutopilotDeploymentProfiles"; extraParams = "select=id,displayName,description" }
                @{ id = "healthScripts"; url = "deviceManagement/deviceHealthScripts"; extraParams = "select=id,displayName,description" }
                @{ id = "configurationPolicies"; url = "deviceManagement/configurationPolicies"; extraParams = "select=id,name,description" }
                @{ id = "groupPolicyConfigs"; url = "deviceManagement/groupPolicyConfigurations"; extraParams = "select=id,displayName,description" }
                @{ id = "resourceAccessProfiles"; url = "deviceManagement/resourceAccessProfiles"; extraParams = "select=id,displayName,description" }
                @{ id = "wipPolicies"; url = "deviceAppManagement/windowsInformationProtectionPolicies"; extraParams = "select=id,displayName,description" }
                @{ id = "mdmWipPolicies"; url = "deviceAppManagement/mdmWindowsInformationProtectionPolicies"; extraParams = "select=id,displayName,description" }
                @{ id = "windowsFeatureUpdates"; url = "deviceManagement/windowsFeatureUpdateProfiles"; extraParams = "select=id,displayName,description" }
                @{ id = "windowsQualityUpdates"; url = "deviceManagement/windowsQualityUpdateProfiles"; extraParams = "select=id,displayName,description" }
                @{ id = "windowsDriverUpdates"; url = "deviceManagement/windowsDriverUpdateProfiles"; extraParams = "select=id,displayName,description" }
            )
        }

        # Build batch request
        foreach ($endpoint in $resourceEndpoints)
        {
            $requestUrl = "$($endpoint.url)?`$$($endpoint.extraParams)"
            $batchRequestBody.requests += @{
                id     = $endpoint.id
                method = "GET"
                url    = $requestUrl
            }
        }

        Write-Log -logFile $LogFile -module $functionName -Message "Sending batch request for $($resourceEndpoints.Count) resource lists" -logLevel "Information"

        # Send batch request
        try
        {
            Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: Sending batch request with $($batchRequestBody.requests.Count) resource list request(s)" -logLevel "Debug"
            $batchResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath "`$batch" -APIVersion $apiVersion -Method "POST" -Body ($batchRequestBody | ConvertTo-Json -Depth $global:maxJSONDepth)
            Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: Batch response received - Structure: $(if ($batchResponse.responses) { "Has 'responses' array with $($batchResponse.responses.Count) item(s)" } else { 'Missing responses array' })" -logLevel "Debug"

            # Process batch response
            if ($batchResponse -and $batchResponse.responses)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Processing batch response for resource lists ($($batchResponse.responses.Count) response(s))" -LogLevel "Verbose"

                foreach ($response in $batchResponse.responses)
                {
                    if ($response.status -eq 200 -and $response.body)
                    {
                        $pagedResult = Get-PagedCollectionItems -InitialResponse $response.body -AccessToken $AccessToken -ResourceDescription $response.id
                        $items = $pagedResult.Items
                        Write-Log -logFile $LogFile -module $functionName -Message "Endpoint '$($response.id)' fetched $($items.Count) item(s) across $($pagedResult.PageCount) page(s)" -logLevel "Verbose"

                        switch ($response.id)
                        {
                            "mobileApps" { $mobileApps = $items }
                            "deviceConfigs" { $deviceConfigs = $items }
                            "compliancePolicies" { $compliancePolicies = $items }
                            "deviceScripts" { $deviceScripts = $items }
                            "appProtectionPolicies" { $appProtectionPolicies = $items }
                            "intents" { $intents = $items }
                            "resourceAccessProfiles" { $resourceAccessProfiles = $items }
                            "autopilotProfiles" { $autopilotProfiles = $items }
                            "healthScripts" { $healthScripts = $items }
                            "configurationPolicies"
                            {
                                # Configuration policies use 'name' instead of 'displayName', so we normalize it
                                $configurationPolicies = $items | ForEach-Object {
                                    $_ | Add-Member -NotePropertyName 'displayName' -NotePropertyValue $_.name -Force -PassThru
                                }
                            }
                            "groupPolicyConfigs" { $groupPolicyConfigs = $items }
                            "policySets" { $policySets = $items }
                            "wipPolicies" { $wipPolicies = $items }
                            "mdmWipPolicies" { $mdmWipPolicies = $items }
                            "windowsFeatureUpdates" { $windowsFeatureUpdates = $items }
                            "windowsQualityUpdates" { $windowsQualityUpdates = $items }
                            "windowsDriverUpdates" { $windowsDriverUpdates = $items }
                        }
                    }
                    elseif ($response.status -ne 200)
                    {
                        $errorMessage = "API returned status $($response.status)"
                        $errorCode = $response.status.ToString()

                        if ($response.body -and $response.body.error)
                        {
                            $errorMessage += ": $($response.body.error.message)"
                            if ($response.body.error.code)
                            {
                                $errorCode = $response.body.error.code
                            }
                        }

                        # Categorize error using common helper
                        $errorCategory = Get-ErrorCategory -ErrorCode $errorCode -ErrorMessage $errorMessage -ResourceType $response.id -ODataType ""
                        $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorCode -ResourceType $response.id -ODataType ""

                        Write-Log -logFile $LogFile -module $functionName -Message "Failed to get resource list for $($response.id). Category: $errorCategory, Error: $errorMessage" -logLevel "Warning"
                        Write-Log -logFile $LogFile -module $functionName -Message "Remediation guidance: $remediationGuidance" -logLevel "Information"

                        if ($ResultObject)
                        {
                            Add-FailedResourceError -ResultObject $ResultObject -ResourceType $response.id -ErrorMessage $errorMessage -StatusCode $response.status -ApiVersion $apiVersion
                        }

                        # Track this resource ID so it's NOT cached and will be retried next time
                        $failedResourceIds += $response.id
                    }
                }
            }
        }
        catch
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Error fetching resource lists: $($_.Exception.Message)" -LogLevel "Error"
            throw
        }

        Write-Log -logFile $LogFile -module $functionName -Message "Retrieved resource counts via batch - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count), Scripts: $($deviceScripts.Count), HealthScripts: $($healthScripts.Count), AppProtection: $($appProtectionPolicies.Count), Intents: $($intents.Count), ResourceAccess: $($resourceAccessProfiles.Count), ConfigPolicies: $($configurationPolicies.Count), GroupPolicy: $($groupPolicyConfigs.Count), PolicySets: $($policySets.Count), WIP: $($wipPolicies.Count), MDMWIP: $($mdmWipPolicies.Count)" -logLevel "Information"

        # Prepare resource lists for caching (actual cache write occurs after metadata sanitation)
        if (-not $SkipCache.IsPresent)
        {
            $resourceListsToCache = @{
                mobileApps             = $mobileApps
                deviceConfigs          = $deviceConfigs
                compliancePolicies     = $compliancePolicies
                autopilotProfiles      = $autopilotProfiles
                deviceScripts          = $deviceScripts
                healthScripts          = $healthScripts
                appProtectionPolicies  = $appProtectionPolicies
                intents                = $intents
                resourceAccessProfiles = $resourceAccessProfiles
                configurationPolicies  = $configurationPolicies
                groupPolicyConfigs     = $groupPolicyConfigs
                policySets             = $policySets
                wipPolicies            = $wipPolicies
                mdmWipPolicies         = $mdmWipPolicies
                windowsFeatureUpdates  = $windowsFeatureUpdates
                windowsQualityUpdates  = $windowsQualityUpdates
                windowsDriverUpdates   = $windowsDriverUpdates
            }
        }
    }

    # Ensure @odata.type exists for all resources (Graph may omit for minimal metadata responses)
    $resourceCollections = @{
        mobileApps             = $mobileApps
        deviceConfigs          = $deviceConfigs
        compliancePolicies     = $compliancePolicies
        autopilotProfiles      = $autopilotProfiles
        deviceScripts          = $deviceScripts
        healthScripts          = $healthScripts
        appProtectionPolicies  = $appProtectionPolicies
        intents                = $intents
        resourceAccessProfiles = $resourceAccessProfiles
        configurationPolicies  = $configurationPolicies
        groupPolicyConfigs     = $groupPolicyConfigs
        policySets             = $policySets
        wipPolicies            = $wipPolicies
        mdmWipPolicies         = $mdmWipPolicies
        windowsFeatureUpdates  = $windowsFeatureUpdates
        windowsQualityUpdates  = $windowsQualityUpdates
        windowsDriverUpdates   = $windowsDriverUpdates
    }

    foreach ($endpointKey in $resourceCollections.Keys)
    {
        $resourcesForEndpoint = $resourceCollections[$endpointKey]
        if (-not $resourcesForEndpoint -or $resourcesForEndpoint.Count -eq 0)
        {
            continue
        }

        $fallbackType = Get-DefaultODataTypeForEndpoint -EndpointId $endpointKey
        if ([string]::IsNullOrWhiteSpace($fallbackType))
        {
            continue
        }

        foreach ($resource in $resourcesForEndpoint)
        {
            if ([string]::IsNullOrWhiteSpace($resource.'@odata.type'))
            {
                $resource | Add-Member -NotePropertyName '@odata.type' -NotePropertyValue $fallbackType -Force
                Write-Log -logFile $LogFile -module $functionName -Message "Populated missing ODataType '$fallbackType' for resource '$($resource.displayName)' (ID: $($resource.id)) via endpoint '$endpointKey'." -logLevel "Verbose"
            }
        }
    }

    # Persist sanitized resource lists to cache if we fetched fresh data this run
    if ($resourceListsToCache)
    {
        foreach ($failedId in $failedResourceIds)
        {
            if ($resourceListsToCache.ContainsKey($failedId))
            {
                $resourceListsToCache[$failedId] = $null
                Write-Log -logFile $LogFile -module $functionName -Message "Excluding failed resource '$failedId' from cache (will retry next time)" -logLevel "Verbose"
            }
        }

        $cacheMetadata = @{
            ApiVersion      = $apiVersionKey
            FetchedAt       = Get-Date
            FailedResources = $failedResourceIds
        }
        $cached = Set-CachedData -CacheType 'Configuration' -Key $CacheKey -Data $resourceListsToCache -Metadata $cacheMetadata
        if ($cached)
        {
            $successCount = ($resourceListsToCache.Keys | Where-Object { $resourceListsToCache[$_] -ne $null }).Count
            Write-Log -logFile $LogFile -module $functionName -Message "Successfully cached $successCount resource lists (CacheKey: $CacheKey, excluded $($failedResourceIds.Count) failed)" -logLevel "Verbose"
        }
    }

    # Apply platform filtering if Settings.operatingSystem is specified
    if ($Settings -and $Settings.operatingSystem)
    {
        $targetOS = $Settings.operatingSystem
        Write-Log -logFile $LogFile -module $functionName -Message "Filtering resources for operating system: $targetOS" -logLevel "Information"

        $mobileApps = @($mobileApps | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $deviceConfigs = @($deviceConfigs | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $compliancePolicies = @($compliancePolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $autopilotProfiles = @($autopilotProfiles | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $deviceScripts = @($deviceScripts | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $healthScripts = @($healthScripts | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $appProtectionPolicies = @($appProtectionPolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $intents = @($intents | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $resourceAccessProfiles = @($resourceAccessProfiles | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $configurationPolicies = @($configurationPolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $groupPolicyConfigs = @($groupPolicyConfigs | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $policySets = @($policySets | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $wipPolicies = @($wipPolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $mdmWipPolicies = @($mdmWipPolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $windowsFeatureUpdates = @($windowsFeatureUpdates | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $windowsQualityUpdates = @($windowsQualityUpdates | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
        $windowsDriverUpdates = @($windowsDriverUpdates | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })

        Write-Log -logFile $LogFile -module $functionName -Message "After filtering for $targetOS - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count), Scripts: $($deviceScripts.Count), HealthScripts: $($healthScripts.Count), AppProtection: $($appProtectionPolicies.Count), Intents: $($intents.Count), ResourceAccess: $($resourceAccessProfiles.Count), ConfigPolicies: $($configurationPolicies.Count), GroupPolicy: $($groupPolicyConfigs.Count), PolicySets: $($policySets.Count), WIP: $($wipPolicies.Count), MDMWIP: $($mdmWipPolicies.Count), FeatureUpdates: $($windowsFeatureUpdates.Count), QualityUpdates: $($windowsQualityUpdates.Count), DriverUpdates: $($windowsDriverUpdates.Count)" -logLevel "Information"
    }

    # Return hashtable with all resource lists
    return @{
        mobileApps             = $mobileApps
        deviceConfigs          = $deviceConfigs
        compliancePolicies     = $compliancePolicies
        autopilotProfiles      = $autopilotProfiles
        deviceScripts          = $deviceScripts
        healthScripts          = $healthScripts
        appProtectionPolicies  = $appProtectionPolicies
        intents                = $intents
        resourceAccessProfiles = $resourceAccessProfiles
        configurationPolicies  = $configurationPolicies
        groupPolicyConfigs     = $groupPolicyConfigs
        policySets             = $policySets
        wipPolicies            = $wipPolicies
        mdmWipPolicies         = $mdmWipPolicies
        windowsFeatureUpdates  = $windowsFeatureUpdates
        windowsQualityUpdates  = $windowsQualityUpdates
        windowsDriverUpdates   = $windowsDriverUpdates
        FailedResourceIds      = $failedResourceIds
    }
}
