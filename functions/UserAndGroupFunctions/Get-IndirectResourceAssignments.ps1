function Get-IndirectResourceAssignments()
{
    <#
    .SYNOPSIS
    Processes a set of resources to retrieve their indirect assignments via virtual groups.
    
    .DESCRIPTION
    This nested helper function iterates over a collection of resources (such as apps, configurations, etc.)
    and retrieves assignments that are indirectly assigned through the "All Users" or "All Devices" virtual groups.
    It is called by the parent function for each resource type and assignment category.
    
    Unlike the parent function, which orchestrates the overall retrieval and aggregation of indirect assignments,
    this helper focuses on processing a specific resource type and category, making API calls and updating the result object.
    
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
        
    # Use CallGraphAPI's native batch support
    $batchResult = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentPaths -APIVersion $apiVersion -Method "GET"
        
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
                        
                    $assignmentObject = [PSCustomObject]@{
                        Type            = $AssignmentCategory
                        Name            = $resource.displayName
                        Description     = if ($resource.description) { $resource.description } else { "" }
                        Id              = $resource.id
                        Intent          = $assignment.intent
                        Target          = $assignment.target
                        Settings        = $assignment.settings
                        AssignmentScope = $assignmentScope
                    }
                        
                    switch ($AssignmentCategory)
                    {
                        "Application" { $indirectAssignments.AppAssignments += $assignmentObject }
                        "Configuration" { $indirectAssignments.ConfigurationAssignments += $assignmentObject }
                        "Compliance" { $indirectAssignments.ComplianceAssignments += $assignmentObject }
                        "AutopilotProfile" { $indirectAssignments.AutopilotAssignments += $assignmentObject }
                        "Script" { $indirectAssignments.ScriptAssignments += $assignmentObject }
                        "HealthScript" { $indirectAssignments.HealthScriptAssignments += $assignmentObject }
                        "AppProtection" { $indirectAssignments.AppProtectionAssignments += $assignmentObject }
                        "Intent" { $indirectAssignments.IntentAssignments += $assignmentObject }
                        "ResourceAccess" { $indirectAssignments.ResourceAccessAssignments += $assignmentObject }
                        "ConfigurationPolicy" { $indirectAssignments.ConfigurationPolicyAssignments += $assignmentObject }
                        "GroupPolicy" { $indirectAssignments.GroupPolicyAssignments += $assignmentObject }
                        "WindowsInformationProtection" { $indirectAssignments.WindowsInformationProtectionAssignments += $assignmentObject }
                        "PolicySet" { $indirectAssignments.PolicySetAssignments += $assignmentObject }
                    }
                    $indirectAssignments.AllAssignments += $assignmentObject
                }
            }
        }
    }
}
    