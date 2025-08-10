function ShowGroupAssignments()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$GroupId,
        [string]$GroupName
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting function to show group assignments"
    Write-Verbose "[$functionName] GroupId: $GroupId"
    Write-Verbose "[$functionName] GroupName: $GroupName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting ShowGroupAssignments for group: $GroupName (ID: $GroupId)" -LogLevel "Information"
    
    # Validate access token
    if (-not $AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        Write-Host "Could not obtain an access token. Please check your credentials." -ForegroundColor Red
        return
    }
    
    # Display group information header
    Write-Host ""
    Write-Host "=== Group Assignment Information ===" -ForegroundColor Green
    Write-Host "Group Name: " -NoNewline -ForegroundColor White
    Write-Host $GroupName -ForegroundColor Cyan
    Write-Host "Group ID: " -NoNewline -ForegroundColor White  
    Write-Host $GroupId -ForegroundColor Gray
    Write-Host ""
    
    # Get group details first
    Write-Verbose "[$functionName] Getting group details"
    $groupUri = "groups/$GroupId"
    $groupExtraParameters = "select=id,displayName,description,membershipType,groupTypes"
    $groupDetails = CallGraphAPI -accessToken $AccessToken -ResourcePath $groupUri -extraParameters $groupExtraParameters
    
    if ($groupDetails -notin 400, 401, 403, 404)
    {
        Write-Host "Group Details:" -ForegroundColor Yellow
        Write-Host "  Description: $($groupDetails.description)" -ForegroundColor White
        Write-Host "  Group Types: $($groupDetails.groupTypes -join ', ')" -ForegroundColor White
        Write-Host ""
    }
    
    # Initialize counters for summary
    $appAssignmentCount = 0
    $deviceConfigAssignmentCount = 0
    $compliancePolicyAssignmentCount = 0
    
    try {
        # 1. Get Application Assignments
        Write-Host "Application Assignments:" -ForegroundColor Yellow
        Write-Verbose "[$functionName] Getting application assignments for group"
        
        $appUri = "deviceAppManagement/mobileApps"
        $appExtraParameters = "expand=assignments"
        $apps = CallGraphAPI -accessToken $AccessToken -ResourcePath $appUri -extraParameters $appExtraParameters
        
        $assignedApps = @()
        foreach ($app in $apps.value)
        {
            if ($app.assignments)
            {
                $matchingAssignments = $app.assignments | Where-Object { $_.target.groupId -eq $GroupId }
                if ($matchingAssignments)
                {
                    foreach ($assignment in $matchingAssignments)
                    {
                        $assignedApps += [PSCustomObject]@{
                            Name = $app.displayName
                            Type = ($app."@odata.type" -replace '#Microsoft.Graph.', '')
                            Intent = $assignment.intent
                            TargetType = $assignment.target."@odata.type" -replace '#Microsoft.Graph.', ''
                        }
                        $appAssignmentCount++
                    }
                }
            }
        }
        
        if ($assignedApps.Count -gt 0)
        {
            $assignedApps | Sort-Object Name | ForEach-Object {
                Write-Host "  - $($_.Name) ($($_.Type)) - Intent: $($_.Intent)" -ForegroundColor White
            }
        }
        else
        {
            Write-Host "  No application assignments found." -ForegroundColor Gray
        }
        Write-Host ""
        
        # 2. Get Device Configuration Assignments  
        Write-Host "Device Configuration Assignments:" -ForegroundColor Yellow
        Write-Verbose "[$functionName] Getting device configuration assignments for group"
        
        $configUri = "deviceManagement/deviceConfigurations"
        $configExtraParameters = "expand=assignments"
        $configs = CallGraphAPI -accessToken $AccessToken -ResourcePath $configUri -extraParameters $configExtraParameters
        
        $assignedConfigs = @()
        foreach ($config in $configs.value)
        {
            if ($config.assignments)
            {
                $matchingAssignments = $config.assignments | Where-Object { $_.target.groupId -eq $GroupId }
                if ($matchingAssignments)
                {
                    foreach ($assignment in $matchingAssignments)
                    {
                        $assignedConfigs += [PSCustomObject]@{
                            Name = $config.displayName
                            Type = ($config."@odata.type" -replace '#Microsoft.Graph.', '')
                            TargetType = $assignment.target."@odata.type" -replace '#Microsoft.Graph.', ''
                        }
                        $deviceConfigAssignmentCount++
                    }
                }
            }
        }
        
        if ($assignedConfigs.Count -gt 0)
        {
            $assignedConfigs | Sort-Object Name | ForEach-Object {
                Write-Host "  - $($_.Name) ($($_.Type))" -ForegroundColor White
            }
        }
        else
        {
            Write-Host "  No device configuration assignments found." -ForegroundColor Gray
        }
        Write-Host ""
        
        # 3. Get Compliance Policy Assignments
        Write-Host "Compliance Policy Assignments:" -ForegroundColor Yellow
        Write-Verbose "[$functionName] Getting compliance policy assignments for group"
        
        $complianceUri = "deviceManagement/deviceCompliancePolicies"
        $complianceExtraParameters = "expand=assignments"
        $compliancePolicies = CallGraphAPI -accessToken $AccessToken -ResourcePath $complianceUri -extraParameters $complianceExtraParameters
        
        $assignedCompliancePolicies = @()
        foreach ($policy in $compliancePolicies.value)
        {
            if ($policy.assignments)
            {
                $matchingAssignments = $policy.assignments | Where-Object { $_.target.groupId -eq $GroupId }
                if ($matchingAssignments)
                {
                    foreach ($assignment in $matchingAssignments)
                    {
                        $assignedCompliancePolicies += [PSCustomObject]@{
                            Name = $policy.displayName
                            Type = ($policy."@odata.type" -replace '#Microsoft.Graph.', '')
                            TargetType = $assignment.target."@odata.type" -replace '#Microsoft.Graph.', ''
                        }
                        $compliancePolicyAssignmentCount++
                    }
                }
            }
        }
        
        if ($assignedCompliancePolicies.Count -gt 0)
        {
            $assignedCompliancePolicies | Sort-Object Name | ForEach-Object {
                Write-Host "  - $($_.Name) ($($_.Type))" -ForegroundColor White
            }
        }
        else
        {
            Write-Host "  No compliance policy assignments found." -ForegroundColor Gray
        }
        Write-Host ""
        
        # Display summary
        Write-Host "=== Assignment Summary ===" -ForegroundColor Green
        Write-Host "Application Assignments: $appAssignmentCount" -ForegroundColor White
        Write-Host "Device Configuration Assignments: $deviceConfigAssignmentCount" -ForegroundColor White
        Write-Host "Compliance Policy Assignments: $compliancePolicyAssignmentCount" -ForegroundColor White
        $totalAssignments = $appAssignmentCount + $deviceConfigAssignmentCount + $compliancePolicyAssignmentCount
        Write-Host "Total Assignments: $totalAssignments" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "ShowGroupAssignments completed successfully. Total assignments: $totalAssignments" -LogLevel "Information"
    }
    catch {
        Write-Host "An error occurred while retrieving group assignments: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error in ShowGroupAssignments: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "[$functionName] Exception details: $($_.Exception | Out-String)"
    }
}