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
        )
    }
    
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
    $assignment = New-AssignmentObject -Type "Application" -Name "Office 365" -Id "abc-123" -Intent "required" -Target $targetObj -AssignmentScope "Direct"
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
    
    .PARAMETER AssignmentCategory
    The category under which assignments will be stored in the result object.
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
        [string]$AssignmentCategory
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
                # Filter for All Users and All Devices assignments
                $indirectAssignmentTargets = $responseData.value | Where-Object { 
                    $_.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget' -or 
                    $_.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget'
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
                        
                    $assignmentObject = New-AssignmentObject -Type $AssignmentCategory `
                        -Name $resource.displayName `
                        -Description $(if ($resource.description) { $resource.description } else { "" }) `
                        -Id $resource.id `
                        -Intent $assignment.intent `
                        -Target $assignment.target `
                        -Settings $assignment.settings `
                        -AssignmentScope $assignmentScope
                        
                    Add-AssignmentToCategory -ResultObject $ResultObject -Assignment $assignmentObject -AssignmentCategory $AssignmentCategory
                }
            }
        }
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
