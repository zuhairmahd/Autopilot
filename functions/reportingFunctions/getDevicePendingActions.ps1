function getDevicePendingActions()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{}
    $deviceActions = @('wipePending')
    $pendingActions = [PSCustomObject]@{}
    $isPendingAction = $false
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking for pending actions on the device..." -LogLevel "Verbose"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device management state: $($enrollmentState.managedDevice.device.managementState)" -LogLevel "Information"
    if ($enrollmentState.managedDevice.device.managementState -in $deviceActions)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device has pending actions." -LogLevel "Information"
        $isPendingAction = $true
        Write-Verbose "Action name $($enrollmentState.managedDevice.device.managementState)"
        Write-Verbose "Action status $($enrollmentState.managedDevice.device.managementState)"
        $pendingActions = [PSCustomObject]@{
            ActionName   = $enrollmentState.managedDevice.device.managementState
            ActionStatus = $enrollmentState.managedDevice.device.managementState
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device has no pending actions." -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device management state: $($enrollmentState.managedDevice.device.managementState)" -LogLevel "Information"
        $isPendingAction = $false
    }

    if ($enrollmentState.managedDevice.device.deviceActionResults -and $enrollmentState.managedDevice.device.deviceActionResults.Count -gt 0)
    {
        Write-Host "$($enrollmentState.managedDevice.device.deviceActionResults.Count ) Pending actions found for the device:"
        foreach ($action in $enrollmentState.managedDevice.device.deviceActionResults)
        {
            Write-Host "- $($action.actionName): $($action.status)"
            $isPendingAction = $true
            $pendingActions += [PSCustomObject]@{
                ActionName   = $action.actionName
                ActionStatus = $action.status
            }
        }
    }        
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Is pending action: $isPendingAction" -LogLevel "Information"
    if ($isPendingAction -eq $true)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "There are pending actions for the device." -LogLevel "Information"
        $returnObject.Add('PendingActions', $pendingActions)
        $returnObject.Add('IsPendingAction', $isPendingAction)
        return $returnObject
    }
    else
    {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No pending actions found for the device." -LogLevel "Verbose"
        $returnObject.Add('PendingActions', $null)
        $returnObject.Add('IsPendingAction', $isPendingAction)
        return $returnObject
    }
}

