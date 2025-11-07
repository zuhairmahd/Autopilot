function Restore-ApplicationDefaults()
{
    <#
    .SYNOPSIS
        Restores application default settings by removing specified configuration files.
    .DESCRIPTION
        This function removes configuration files to restore the application to its default state.
        It provides comprehensive error reporting and requires user confirmation before proceeding.
    .PARAMETER FilesToDelete
        Array of file paths to be deleted during the restore operation.
    .PARAMETER Domain
        The domain name used to identify domain-specific configuration files.
    .PARAMETER ScriptPath
        The script's root directory path for locating domain-specific files.
    .PARAMETER Silent
        If specified, skips confirmation prompts and "Press any key" pauses.
    .OUTPUTS
        Returns a hashtable with detailed results including success status, messages, and file operation details.
    #>
    [CmdletBinding()]
    param (
        [string[]]$FilesToDelete,
        [string]$Domain,
        [string]$ScriptPath,
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{
        Success            = $false
        Message            = ""
        ProcessedFiles     = @()
        FileCount          = 0
        RemovedFiles       = @()
        RemovedFileCount   = 0        
        MissingFiles       = @()
        MissingFileCount   = 0
        UndeletedFiles     = @()
        UndeletedFileCount = 0
        UserCancelled      = $false
        ErrorMessages      = @()
    }
        
    
    # Manual validation for FilesToDelete since ValidateNotNullOrEmpty doesn't work well with arrays
    if ($null -eq $FilesToDelete -or $FilesToDelete.Count -eq 0)
    {
        Write-Verbose "[$functionName] No files specified for deletion."
        Write-Log -LogFile $logFile -Module $functionName -Message "No files specified for deletion." -LogLevel "Error"         
        return $returnObject            
    }
    
    # Build complete list of files to process
    $allFilesToDelete = @($FilesToDelete)
    # Add domain-specific file if it exists
    $domainFileName = Join-Path $ScriptPath "$Domain.psd1"
    if (Test-Path -Path $domainFileName)
    {
        Write-Verbose "[$functionName] Found domain file: $domainFileName"
        Write-Log -LogFile $logFile -Module $functionName -Message "Found domain file: $domainFileName" -LogLevel "Verbose"
        $allFilesToDelete += $domainFileName
    }
    else
    {
        Write-Verbose "[$functionName] Domain file not found: $domainFileName"
        Write-Log -LogFile $logFile -Module $functionName -Message "Domain file not found: $domainFileName" -LogLevel "Verbose"
    }
    
    $returnObject.ProcessedFiles = $allFilesToDelete
    $returnObject.FileCount = $allFilesToDelete.Count
    
    Write-Verbose "[$functionName] Processing $($allFilesToDelete.Count) files for deletion."
    Write-Log -LogFile $logFile -Module $functionName -Message "Processing $($allFilesToDelete.Count) files for deletion."
    
    # Validation check
    if ($allFilesToDelete.Count -eq 0)
    {
        $errorMessage = "No files found to delete (including domain-specific files)."
        Write-Error $errorMessage
        Write-Log -LogFile $logFile -Module $functionName -Message $errorMessage -LogLevel "Error"
        $returnObject.Message = $errorMessage
        $returnObject.ErrorMessages += $errorMessage
        return $returnObject
    }
    
    # User confirmation
    Write-Host "This will restore the application settings to their default values by removing the specified configuration files."
    Write-Host "Files to be deleted:" -ForegroundColor Yellow
    foreach ($file in $allFilesToDelete)
    {
        $fileName = Split-Path -Leaf $file
        Write-Host "  - $fileName" -ForegroundColor Gray
    }
    Write-Host "`nThis operation cannot be undone. Do you want to continue? (Y/N)" -ForegroundColor Yellow
    $confirmation = ’Y’ 
    if (-not $Silent) 
    { 
        $confirmation = Read-Host -Prompt "Enter Y to continue or N to cancel" 
        Write-Verbose "[$functionName] User confirmation received: $confirmation" 
        Write-Log -LogFile $logFile -Module $functionName -Message "User confirmation received: $confirmation" 
        while ($confirmation -notin @(’Y’, ’y’, ’N’, ’n’)) 
        { 
            Write-Host "Invalid input. Please enter Y to continue or N to cancel." -ForegroundColor Red 
            $confirmation = Read-Host -Prompt "Enter Y to continue or N to cancel" 
            Write-Log -LogFile $logFile -Module $functionName -Message "User provided invalid input. Prompting again." 
            [console]::beep(1000, 300) 
        } 
    } 
    if ($confirmation -in @(’N’, ’n’)) 
    { 
        $cancelMessage = "Operation cancelled by user." 
        Write-Host $cancelMessage -ForegroundColor Yellow 
        Write-Log -LogFile $logFile -Module $functionName -Message $cancelMessage 
        $returnObject.Message = $cancelMessage 
        $returnObject.UserCancelled = $true 
        return $returnObject 
    }
    # Process file deletions
    Write-Verbose "[$functionName] Beginning file deletion process."            
    
    foreach ($file in $allFilesToDelete)
    {
        try
        {
            if (Test-Path -Path $file)
            {
                Remove-Item -Path $file -Force -ErrorAction Stop
                Write-Verbose "[$functionName] Successfully deleted file: $file"
                Write-Log -LogFile $logFile -Module $functionName -Message "Successfully deleted file: $file"
                $returnObject.RemovedFiles += $file
                $returnObject.RemovedFileCount++
                $fileName = Split-Path -Leaf $file
                Write-Verbose "[$functionName] Deleted: $fileName"                  
                write-log -LogFile $logFile -Module $functionName -Message "Deleted: $fileName" -LogLevel "Verbose"                         
            }
            else
            {
                Write-Verbose "[$functionName] File not found: $file"
                Write-Log -LogFile $logFile -Module $functionName -Message "File not found: $file" -LogLevel "Warning"
                $returnObject.MissingFiles += $file
                $returnObject.MissingFileCount++
                $fileName = Split-Path -Leaf $file
                Write-Verbose "[$functionName] Not found: $fileName"                  
                Write-Log -LogFile $logFile -Module $functionName -Message "Not found: $fileName" -LogLevel "Warning"                           
            }                                                       
        }
        catch
        {
            $errorMsg = "Failed to delete file: $file. Error: $($_.Exception.Message)"
            Write-Error $errorMsg
            Write-Log -LogFile $logFile -Module $functionName -Message $errorMsg -LogLevel "Error"
            $returnObject.UndeletedFiles += $file
            $returnObject.UndeletedFileCount++
            $returnObject.ErrorMessages += $errorMsg
            $fileName = Split-Path -Leaf $file
            Write-Verbose "[$functionName] Failed: $fileName - $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed: $fileName - $($_.Exception.Message)" -LogLevel "Error"       
        }
    }
    
    # Determine overall success and build comprehensive message
    $totalProcessed = $returnObject.RemovedFileCount + $returnObject.MissingFileCount + $returnObject.UndeletedFileCount
    Write-Verbose "[$functionName] File deletion process completed. Processed: $totalProcessed, Deleted: $($returnObject.RemovedFileCount), Missing: $($returnObject.MissingFileCount), Failed: $($returnObject.UndeletedFileCount)"                                    
    Write-Log -LogFile $logFile -Module $functionName -Message "File deletion process completed. Processed: $totalProcessed, Deleted: $($returnObject.RemovedFileCount), Missing: $($returnObject.MissingFileCount), Failed: $($returnObject.UndeletedFileCount)" -LogLevel "Verbose"
    
    if ($returnObject.UndeletedFileCount -eq 0)
    {
        # No failures occurred
        if ($returnObject.RemovedFileCount -gt 0)
        {
            $returnObject.Success = $true
            $returnObject.Message = "Successfully deleted $($returnObject.RemovedFileCount) file(s). Application settings have been restored to default values."
        }
        elseif ($returnObject.MissingFileCount -gt 0)
        {
            # All files were already missing - still consider this a success since the end result is achieved
            $returnObject.Success = $true
            $returnObject.Message = "All configuration files were already missing. Default settings are already in effect."
        }
        else
        {
            # This shouldn't happen with proper validation, but handle it anyway
            $returnObject.Success = $false
            $returnObject.Message = "No files were processed."
            $returnObject.ErrorMessages += "No files were processed."
        }
    }
    else
    {
        # Some files could not be deleted
        $returnObject.Success = $false
        $returnObject.Message = "Restoration partially completed. $($returnObject.RemovedFileCount) file(s) deleted, $($returnObject.UndeletedFileCount) file(s) could not be deleted."
        if ($returnObject.RemovedFileCount -gt 0)
        {
            $returnObject.Message += " Some settings have been reset, but manual intervention may be required."
        }
    }
    # Add summary to message if there were missing files
    if ($returnObject.MissingFileCount -gt 0)
    {
        $returnObject.Message += " $($returnObject.MissingFileCount) file(s) were already missing."
    }
    Write-Verbose "[$functionName] Operation completed. Success: $($returnObject.Success), Deleted: $($returnObject.RemovedFileCount), Missing: $($returnObject.MissingFileCount), Failed: $($returnObject.UndeletedFileCount)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Operation completed. Success: $($returnObject.Success), Deleted: $($returnObject.RemovedFileCount), Missing: $($returnObject.MissingFileCount), Failed: $($returnObject.UndeletedFileCount)"    
    return $returnObject
}


function Show-RestoreApplicationDefaultsResults()
{
    [CmdletBinding()]                                    
    param(
        [string[]]$FilesToDelete,
        [string]$Domain,
        [string]$ScriptPath,
        [switch]$Silent
    )

    $functionName = $MyInvocation.MyCommand.Name                        
    
    $restoreResult = Restore-ApplicationDefaults -FilesToDelete $FilesToDelete -Domain $Domain -ScriptPath $ScriptPath -Silent:$Silent
    Write-Verbose "[$functionName] Restore operation result: $($restoreResult | Out-String)"                    
    Write-Log -LogFile $logFile -Module $functionName -Message "Restore operation result: $($restoreResult | Out-String)" -LogLevel "Verbose"                                                   
    if ($restoreResult.UserCancelled)
    {
        Write-Host "`nRestore operation cancelled by user." -ForegroundColor Yellow
        Write-Log -LogFile $logFile -Module $functionName -Message "Restore operation cancelled by user." -LogLevel "Warning"                                                   
        return $returnValues.backoutText
    }
    elseif ($restoreResult.Success)
    {
        Write-Host "`n$($restoreResult.Message)" -ForegroundColor Green
        Write-Log -LogFile $logFile -Module $functionName -Message "$($restoreResult.Message)" -LogLevel "Information"                                                                              
        if ($restoreResult.RemovedFileCount -gt 0)
        {
            Write-Host "Files successfully removed:" -ForegroundColor Green
            foreach ($file in $restoreResult.RemovedFiles)
            {
                $fileName = Split-Path -Leaf $file
                Write-Host "   $fileName" -ForegroundColor Gray
                Write-Log -LogFile $logFile -Module $functionName -Message "File successfully removed: $fileName" -LogLevel "Information"                                           
            }
        }
        Write-Host "\nThe application will now exit. Please restart to use default settings." -ForegroundColor Cyan
        if (-not $Silent)
        {
            Write-Host "Press any key to exit..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        return $returnValues.exitString
    }
    else
    {
        # Partial success or complete failure
        if ($restoreResult.RemovedFileCount -gt 0)
        {
            # Partial success - some files could not be deleted
            Write-Host "`n$($restoreResult.Message)" -ForegroundColor Yellow
            Write-Log -LogFile $logFile -Module $functionName -Message "$($restoreResult.Message)" -LogLevel "Warning"                                                   
            if ($restoreResult.RemovedFiles.Count -gt 0)
            {
                Write-Host "`nFiles successfully removed:" -ForegroundColor Green
                Write-Log -LogFile $logFile -Module $functionName -Message "Files successfully removed:" -LogLevel "Information"                                                                                                                                    
                foreach ($file in $restoreResult.RemovedFiles)
                {
                    $fileName = Split-Path -Leaf $file
                    Write-Host "   $fileName" -ForegroundColor Gray
                    Write-Log -LogFile $logFile -Module $functionName -Message "File successfully removed: $fileName" -LogLevel "Information"                               
                }
            }
            if ($restoreResult.UndeletedFiles.Count -gt 0)
            {
                Write-Host "`nFiles that could not be deleted:" -ForegroundColor Red
                Write-Log -LogFile $logFile -Module $functionName -Message "Files that could not be deleted:" -LogLevel "Error"                                         
                foreach ($file in $restoreResult.UndeletedFiles)
                {
                    $fileName = Split-Path -Leaf $file
                    Write-Host "   $fileName" -ForegroundColor Gray
                    Write-Log -LogFile $logFile -Module $functionName -Message "File could not be deleted: $fileName" -LogLevel "Error"                                         
                }
                Write-Host "`nYou may need to delete these files manually or run as administrator." -ForegroundColor Yellow
            }
            Write-Host "\nSome settings have been reset. The application will now exit." -ForegroundColor Cyan
            Write-Log -LogFile $logFile -Module $functionName -Message "Some settings have been reset. The application will now exit." -LogLevel "Information"
            if (-not $Silent)
            {
                Write-Host "Press any key to exit..." -ForegroundColor Yellow
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            return $returnValues.exitString
        }
        else
        {
            # Complete failure
            Write-Host "`n$($restoreResult.Message)" -ForegroundColor Red
            Write-Log -LogFile $logFile -Module $functionName -Message "$($restoreResult.Message)" -LogLevel "Error"                                                                
            if ($restoreResult.UndeletedFiles.Count -gt 0)
            {
                Write-Host "`nFiles that could not be deleted:" -ForegroundColor Red
                Write-Log -LogFile $logFile -Module $functionName -Message "Files that could not be deleted:" -LogLevel "Error"                                                                         
                foreach ($file in $restoreResult.UndeletedFiles)
                {
                    $fileName = Split-Path -Leaf $file
                    Write-Host "   $fileName" -ForegroundColor Gray
                    Write-Log -LogFile $logFile -Module $functionName -Message "File could not be deleted: $fileName" -LogLevel "Error"                                                                     
                }
            }
            if ($restoreResult.MissingFiles.Count -gt 0)
            {
                Write-Host "`nFiles that were already missing:" -ForegroundColor Yellow
                Write-Log -LogFile $logFile -Module $functionName -Message "Files that were already missing:" -LogLevel "Warning"                                                               
                foreach ($file in $restoreResult.MissingFiles)
                {
                    $fileName = Split-Path -Leaf $file
                    Write-Host "  ! $fileName" -ForegroundColor Gray
                    Write-Log -LogFile $logFile -Module $functionName -Message "File was already missing: $fileName" -LogLevel "Warning"                                                               
                }
            }
            if ($restoreResult.ErrorMessages.Count -gt 0)
            {
                Write-Host "`nDetailed error information:" -ForegroundColor Red
                Write-Log -LogFile $logFile -Module $functionName -Message "Detailed error information:" -LogLevel "Error"                              
                foreach ($errorMsg in $restoreResult.ErrorMessages)
                {
                    Write-Host "  $errorMsg" -ForegroundColor Gray
                    Write-Log -LogFile $logFile -Module $functionName -Message $errorMsg -LogLevel "Error"          
                }
            }
            Write-Host "`nNo files were removed. Please check file permissions or run as administrator." -ForegroundColor Red
            Write-Log -LogFile $logFile -Module $functionName -Message "No files were removed. Please check file permissions or run as administrator." -LogLevel "Error"                                  
            Write-Host "`nThe application will now exit." -ForegroundColor Cyan     
            return $returnValues.backoutText
        }
    }
}

