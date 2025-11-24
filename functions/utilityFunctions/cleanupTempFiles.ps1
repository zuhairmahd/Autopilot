function cleanupTempFiles()
{
    <#
    .SYNOPSIS
    Cleans up temporary and backup files from the working directory.

    .DESCRIPTION
    This function identifies and moves temporary files (backups, test files, logs, old executables)
    from the current directory to the system TEMP folder. It provides detailed logging of the
    cleanup process and returns statistics about files processed. The function handles errors
    gracefully and reports on the success of each file operation.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns an object with properties: tempFilesCount, RemovedFilesCount, and AllRemoved (boolean).

    .EXAMPLE
    $cleanupResult = cleanupTempFiles
    Write-Host "Cleaned up $($cleanupResult.RemovedFilesCount) files"

    .NOTES
    Removes files matching patterns: *.backup.*, test*.*.psd1, test-*.*, contoso.com.psd1, *.tmp, *.log, *.old, main.exe.old
    Files are moved to $env:TEMP rather than deleted for safety.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param()

    $functionName = $MyInvocation.MyCommand.Name
    $tempFiles = @(Get-ChildItem "*.backup.*", "test*.*.psd1", "test-*.*", "contoso.com.psd1", "*.tmp", "*.log", "*.old", "main.exe.old" -ErrorAction SilentlyContinue)
    $returnObject = [PSCustomObject]@{}
    $removedFiles = 0
    $allRemoved = $true
    if (Get-Command Write-Log -ErrorAction SilentlyContinue)
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "Backup files found: $($tempFiles.Count)"
    }
    else
    {
        Write-Verbose "[$functionName] Backup files found: $($tempFiles.Count)"
    }
    if ($tempFiles.Count -gt 0)
    {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "Removing old backup files." -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] Removing old backup files."
        }
        foreach ($backupFile in $tempFiles)
        {
            if (Get-Command Write-Log -ErrorAction SilentlyContinue)
            {
                Write-Log -logFile $LogFile -Module $functionName -Message "Moving backup file $($backupFile.FullName) to TEMP." -LogLevel "Information"
            }
            else
            {
                Write-Verbose "[$functionName] Moving backup file $($backupFile.FullName) to TEMP."
            }
            if (Test-Path "$env:TEMP\$($backupFile.Name)")
            {
                if (Get-Command Write-Log -ErrorAction SilentlyContinue)
                {
                    Write-Log -logFile $LogFile -Module $functionName -Message "Removing existing file in TEMP: $($backupFile.Name)" -LogLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] Removing existing file in TEMP: $($backupFile.Name)"
                }
                Remove-Item -Path "$env:TEMP\$($backupFile.Name)" -Force -ErrorAction SilentlyContinue | Out-Null
            }
            try
            {
                Move-Item -Path $backupFile -Destination $env:TEMP -Force -ErrorAction SilentlyContinue
                $removedFiles++
                if (Get-Command Write-Log -ErrorAction SilentlyContinue)
                {
                    Write-Log -logFile $LogFile -Module $functionName -Message "Backup file $($backupFile.Name) moved to TEMP." -LogLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] Backup file $($backupFile.Name) moved to TEMP."
                }
            }
            catch
            {
                if (Get-Command Write-Log -ErrorAction SilentlyContinue)
                {
                    Write-Log -logFile $LogFile -Module $functionName -Message "Failed to move backup file $($backupFile.Name) to TEMP: $_" -LogLevel "Error"
                }
                else
                {
                    Write-Verbose "[$functionName] Failed to move backup file $($backupFile.Name) to TEMP: $_"
                }
                $allRemoved = $false
            }
        }
    }
    else
    {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "No backup files found."
        }
        else
        {
            Write-Verbose "[$functionName] No backup files found."
        }
    }
    $returnObject | Add-Member -MemberType NoteProperty -Name "tempFilesCount" -Value $tempFiles.Count
    $returnObject | Add-Member -MemberType NoteProperty -Name "RemovedFilesCount" -Value $removedFiles
    $returnObject | Add-Member -MemberType NoteProperty -Name "AllRemoved" -Value $allRemoved
    if (Get-Command Write-Log -ErrorAction SilentlyContinue)
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "Cleanup completed. Removed files: $removedFiles, Total files found: $($tempFiles.Count), All removed: $allRemoved" -LogLevel "Verbose"
    }
    else
    {
        Write-Verbose "[$functionName] Cleanup completed. Removed files: $removedFiles, Total files found: $($tempFiles.Count), All removed: $allRemoved"
    }
    return $returnObject
}

