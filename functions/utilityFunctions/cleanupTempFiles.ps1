function cleanupTempFiles()
{
    [CmdletBinding()]
    param()

    $functionName = $MyInvocation.MyCommand.Name
    $tempFiles = @(Get-ChildItem "*.backup.*", "*.tmp", "*.log", "*.old" -ErrorAction SilentlyContinue)
    $returnObject = [PSCustomObject]@{}
    $removedFiles = 0
    $allRemoved = $true
    Write-Verbose "[$functionName] Backup files found: $($tempFiles.Count)"
    Write-Log -logFile $LogFile -Module $functionName -Message "Backup files found: $($tempFiles.Count)" -LogLevel "Information"
    if ($tempFiles.Count -gt 0)
    {
        Write-Verbose "[$functionName] Removing old backup files."
        Write-Log -logFile $LogFile -Module $functionName -Message "Removing old backup files." -LogLevel "Information"
        foreach ($backupFile in $tempFiles)
        {
            Write-Verbose "[$functionName] Moving backup file $($backupFile.FullName) to TEMP."
            Write-Log -logFile $LogFile -Module $functionName -Message "Moving backup file $($backupFile.FullName) to TEMP." -LogLevel "Information"
            if (Test-Path "$env:TEMP\$($backupFile.Name)")
            {
                Write-Verbose "[$functionName] Removing existing file in TEMP: $($backupFile.Name)"
                Write-Log -logFile $LogFile -Module $functionName -Message "Removing existing file in TEMP: $($backupFile.Name)" -LogLevel "Information"
                Remove-Item -Path "$env:TEMP\$($backupFile.Name)" -Force
            }
            try
            {
                Move-Item -Path $backupFile -Destination $env:TEMP -Force    
                $removedFiles++
                Write-Verbose "[$functionName] Backup file $($backupFile.Name) moved to TEMP."
                Write-Log -logFile $LogFile -Module $functionName -Message "Backup file $($backupFile.Name) moved to TEMP." -LogLevel "Information"
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to move backup file $($backupFile.Name) to TEMP: $_"
                Write-Log -logFile $LogFile -Module $functionName -Message "Failed to move backup file $($backupFile.Name) to TEMP: $_" -LogLevel "Error"
                $allRemoved = $false
            }
        }
    }
    else
    {
        Write-Verbose "[$functionName] No backup files found."
        Write-Log -logFile $LogFile -Module $functionName -Message "No backup files found." -LogLevel "Information"
    }
    $returnObject | Add-Member -MemberType NoteProperty -Name "tempFilesCount" -Value $tempFiles.Count
    $returnObject | Add-Member -MemberType NoteProperty -Name "RemovedFilesCount" -Value $removedFiles
    $returnObject | Add-Member -MemberType NoteProperty -Name "AllRemoved" -Value $allRemoved
    Write-Verbose "[$functionName] Cleanup completed. Removed files: $removedFiles, Total files found: $($tempFiles.Count), All removed: $allRemoved"
    Write-Log -logFile $LogFile -Module $functionName -Message "Cleanup completed. Removed files: $removedFiles, Total files found: $($tempFiles.Count), All removed: $allRemoved" -LogLevel "Information"  
    return $returnObject
}

