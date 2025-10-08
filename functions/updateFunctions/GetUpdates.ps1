function GetUpdates()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$executableFileName = "$pwd\main.exe",
        [Parameter(Mandatory = $true)]
        [string]$updateURL,
        [string]$metaDataURL = "$updateURL/lastrun.json",
        [switch]$noConfirmation
    )

    #region define variables and write logs 
    $functionName = $MyInvocation.MyCommand.Name
    $updateTest = $false
    $returnMessage = $returnValues.UpdateSuccessMessage
    if ($executableFileName -notmatch 'exe')
    {
        Write-Verbose "[$functionName] The provided executable file name '$executableFileName' does not match 'exe'."
        Write-Verbose "[$functionName] Checking whether a similar executable is found."
        #replace whatever the extension of $executableFileName with .exe
        $executableFileName = [System.IO.Path]::ChangeExtension($executableFileName, ".exe")
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The provided executable file name '$executableFileName' does not match 'exe'. Checking for similar executable." -LogLevel "Warning"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executable filename resolved to $executableFileName" -LogLevel "Information"
        if (-not (Test-Path $executableFileName))
        {
            Write-Verbose "[$functionName] No similar executable found."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No similar executable found." -LogLevel "Warning"
        }
        Write-Verbose "[$functionName] Found similar executable: $executableFileName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found similar executable: $executableFileName" -LogLevel "Information"        
        $updateTest = $true
    }
    $fileName = Split-Path -Path $executableFileName -Leaf
    $tempUpdateFile = "$env:TEMP\$fileName"
    $executableUpdateURL = "$updateURL/$fileName"
    Write-Verbose "[$functionName] Executable File Name: $executableFileName"
    Write-Verbose "[$functionName] updateURL: $updateURL"
    Write-Verbose "[$functionName] metaDataURL: $metaDataURL"
    Write-Verbose "[$functionName] Temp Update File: $tempUpdateFile"
    Write-Verbose "[$functionName] Executable Update URL: $executableUpdateURL"
    Write-Verbose "[$functionName] No confirmation: $noConfirmation"
    #now write-log the above
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executable File Name: $executableFileName" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "updateURL: $updateURL" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "metaDataURL: $metaDataURL" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Temp Update File: $tempUpdateFile" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executable Update URL: $executableUpdateURL" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "No confirmation: $noConfirmation" -LogLevel "Information"
    #endregion

    #region helper functions
    function DownloadRemoteFile()
    {
        [cmdletBinding()]
        param (
            [string]$url,
            [string]$outputFile
        )
        $functionName = $MyInvocation.MyCommand.Name
        $returnObject = [PSCustomObject]@{
            Success    = $false
            StatusCode = $null
            Content    = $null
        }
        Write-Verbose "[$functionName] Downloading file from $url to $outputFile"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Downloading file from $url to $outputFile" -LogLevel "Information"
        try 
        {
            $response = Invoke-WebRequest -Uri $url -OutFile $outputFile -Method Get -ErrorAction SilentlyContinue -PassThru
            Write-Verbose "[$functionName] Response received from $($url): $($response.StatusCode)"
            $returnObject.Success = $true
            $returnObject.StatusCode = $response.StatusCode
            $returnObject.Content = $response.Content
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response received from $($url): $($response.StatusCode)" -LogLevel "Information"
        }   
        catch 
        {
            Write-Verbose "[$functionName] Error downloading file from $($url): $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error downloading file from $($url): $($_.Exception.Message)" -LogLevel "Error"
            $returnObject.Success = $false
            $returnObject.StatusCode = $_.Exception.Response.StatusCode.Value__
            $returnObject.Content = $_.Exception.Message
        }    
        return $returnObject
    }
    #endregion
    
    $localVersion = (getFileVersion -executableFileName $executableFileName).version
    
    #region get the remote version.
    Write-Verbose "[$functionName] Getting metadata from $metaDataURL"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting metadata from $metaDataURL" -LogLevel "Information"
    try 
    {
        $fileMetaData = Invoke-RestMethod -Uri $metaDataURL -UseBasicParsing
        Write-Verbose "[$functionName] Metadata retrieved successfully."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Metadata retrieved successfully." -LogLevel "Information"
        Write-Verbose "Response: $fileMetaData"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response: $fileMetaData" -LogLevel "Information"
        Write-Verbose "[$functionName] Metadata content: $($fileMetaData.Content)"
        $remoteVersion = $fileMetaData.version
    }
    catch 
    {
        Write-Error "[$functionName] Failed to retrieve metadata from $metaDataURL. Please check the URL and try again."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to retrieve metadata from $metaDataURL. Please check the URL and try again." -LogLevel "Error"
        $returnValues.UpdateFailedMessage
    }
    Write-Verbose "[$functionName] remoteVersion = $remoteVersion"
    #endregion
    
    #region compare versions
    Write-Verbose "[$functionName] Comparing local version $localVersion with remote version $remoteVersion"
    if ($remoteVersion -gt $localVersion)
    {
        Write-Verbose "[$functionName] Remote version $remoteVersion is greater than local version $localVersion. Proceeding with update."
        Write-Host "An update is available." -ForegroundColor Yellow
        Write-Host "Current version: $localVersion" -ForegroundColor Cyan
        Write-Host "New version: $remoteVersion" -ForegroundColor Cyan
        #convert $fileMetaData.date to a datetime object in local time.
        $fileMetaData.date = [datetime]::Parse($fileMetaData.date).ToLocalTime()
        Write-Host "Release date: $($fileMetaData.date | FormatDateWithTimeZone)" -ForegroundColor Cyan
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current version: $localVersion, New version: $remoteVersion" -LogLevel "Information"
        if ($noConfirmation)
        {
            Write-Host "No confirmation required. Proceeding with the update..." -ForegroundColor Green
        }
        else
        {
            Write-Host "Would you like to download the update?" -ForegroundColor Yellow
            $userInput = Read-Host "Type 'yes' to proceed with the update, or 'no' to cancel"
            while ($userInput -notin @('yes', 'no'))
            {
                Write-Host "Invalid input. Please type 'yes' to proceed with the update, or 'no' to cancel." -ForegroundColor Red
                #beep
                [console]::beep(1000, 500)
                $userInput = Read-Host
            }
            if ($userInput -eq 'no')
            {
                Write-Host "Update cancelled by user." -ForegroundColor Yellow
                return $returnValues.UpdateCancelledMessage
            }
        }
        Write-Host "Proceeding with the update..." -ForegroundColor Green
        Write-Verbose "[$functionName] Proceeding with the update."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Proceeding with the update..."
        Write-Verbose "[$functionName] Checking whether the temp update file $tempUpdateFile exists."
        if (Test-Path $tempUpdateFile)
        {
            Write-Verbose "[$functionName] Temp update file $tempUpdateFile exists. Removing it."
            Remove-Item -Path $tempUpdateFile -Force
        }
        Write-Verbose "[$functionName] Getting remote file from $executableUpdateURL"
        $response = DownloadRemoteFile -url $executableUpdateURL -outputFile $tempUpdateFile
        if (-not $response.Success)
        {
            Write-Error "[$functionName] Failed to download the update file from $updateURL. Please check the URLs and try again."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to download the update file from $updateURL. Please check the URLs and try again." -LogLevel "Error"
            return $response
        }
        else
        {
            Write-Verbose "[$functionName] Successfully downloaded the update file from $updateURL"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully downloaded the update file from $updateURL" -LogLevel "Information"
        }
        Write-Host "Checking file signature..."
        if (-not (Invoke-FileCertVerification -FilePath $tempUpdateFile))
        {
            Write-Host "File signature is invalid. Aborting update." -ForegroundColor Red
            return $returnValues.InvalidSignatureMessage
        }   
        Write-Host "File signature is valid"
        Write-Verbose "[$functionName] File signature is valid."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "File signature is valid." -LogLevel "Information"
        Write-Verbose "[$functionName] Getting file hash for $tempUpdateFile"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting file hash for $tempUpdateFile" -LogLevel "Information"
        $fileHash = Get-FileHash -Path $tempUpdateFile -Algorithm SHA256        
        Write-Verbose "[$functionName] File hash for $($tempUpdateFile) is $($fileHash.Hash)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "File hash for $tempUpdateFile is $($fileHash.Hash)" -LogLevel "Information"
        Write-Host "Comparing file hash..."
        if ($fileMetaData.Hash -eq $fileHash.Hash)
        {
            Write-Host "File hash matches." -NoNewline
            Write-Host " - Proceeding with update..." -ForegroundColor Green
            Write-Verbose "[$functionName] File hash matches the expected hash."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "File hash matches the expected hash." -LogLevel "Information"
        }
        else
        {
            Write-Host "File hash does not match the expected hash." -ForegroundColor Red
            Write-Host "Expected hash: $($fileMetaData.Hash)" -ForegroundColor Yellow
            Write-Host "Actual hash: $($fileHash.Hash)" -ForegroundColor Yellow
            Write-Verbose "[$functionName] File hash does not match the expected hash."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "File hash does not match the expected hash." -LogLevel "Error"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Expected hash: $($fileMetaData.Hash)" -LogLevel "Error"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Actual hash: $($fileHash.Hash)" -LogLevel "Error"
            Write-Host "Aborting update." -ForegroundColor Red
            return $returnValues.InvalidFileHash
        }
        if (-not $updateTest)    
        {
            Write-Verbose "[$functionName] Proceeding with update installation."
            $backupFile = Join-Path -Path $env:TEMP -ChildPath "$fileName.bak"
            Write-Verbose "[$functionName] Backing up current $executableFileName to $backupFile."
            try
            {
                Copy-Item -Path $executableFileName -Destination $backupFile -Force
                Write-Verbose "[$functionName] Backup created successfully."
                Write-Verbose "[$functionName] Renaming $executableFileName to $executableFileName.old"
                if (Test-Path "$executableFileName.old")
                {
                    Write-Verbose "[$functionName] Old backup file $executableFileName.old already exists. Removing it."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removing old backup file $executableFileName.old" -LogLevel "Information"
                    Remove-Item -Path "$executableFileName.old" -Force
                    Write-Verbose "[$functionName] Old backup file removed."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Old backup file $executableFileName.old removed" -LogLevel "Information"
                }
                Rename-Item -Path $executableFileName -NewName "$executableFileName.old" -Force
                Write-Verbose "[$functionName] Renamed $executableFileName to $executableFileName.old"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Renamed $executableFileName to $executableFileName.old" -LogLevel "Information"
                Write-Verbose "[$functionName] Copying the update file from $tempUpdateFile to $executableFileName"
                Copy-Item -Path $tempUpdateFile -Destination $executableFileName -Force
                Write-Verbose "[$functionName] Update completed successfully. New version: $remoteVersion"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update completed successfully. New version: $remoteVersion" -LogLevel "Information"
            }
            catch
            {
                Write-Error "[$functionName] Error during update: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error during update: $($_.Exception.Message)" -LogLevel "Error"
                Write-Error "Failed to update $executableFileName. Please check the error message above."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extended error message: $_" -LogLevel "Error"
                if ($localVersion -ne (getFileVersion -executableFileName $executableFileName))
                {
                    $backupFileName = Split-Path -Path $backupFile -Leaf
                    $executableFileParrentFolder = Split-Path -Path $executableFileName -Parent
                    Write-Host "Restoring backup from $backupFile to $executableFileName" -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Restoring backup from $backupFile to $executableFileName" -LogLevel "Error"
                    Copy-Item -Path $backupFile -Destination $executableFileParrentFolder -Force
                    Write-Verbose "[$functionName] copied backup file $backupFile to $executableFileParrentFolder directory."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Copied backup file $backupFile to $executableFileParrentFolder directory." -LogLevel "Error"
                    Write-Verbose "[$functionName] Extracted backup file name: $backupFileName"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extracted backup file name: $backupFileName" -LogLevel "Error"
                    Rename-Item -Path $executableFileName -NewName "$executableFileName.tmp" -Force
                    Write-Verbose "[$functionName] Renamed $executableFileName to $executableFileName.tmp"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Renamed $executableFileName to $executableFileName.tmp" -LogLevel "Error"
                    Rename-Item -Path $backupFileName -NewName $executableFileName -Force
                    Write-Verbose "[$functionName] Renamed $backupFileName to $executableFileName"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Renamed $backupFileName to $executableFileName" -LogLevel "Error"
                    Write-Host "The update has been rolled back to the previous version." -ForegroundColor Green
                    Remove-Item -Path "$executableFileName.tmp" -Force
                    Write-Verbose "[$functionName] Removed temporary file $executableFileName.tmp"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removed temporary file $executableFileName.tmp" -LogLevel "Error"
                    Write-Host "Please try the update again later." -ForegroundColor Yellow
                }
                #cleanup temp files if they exist.
                if (Test-Path $tempUpdateFile)
                {
                    Write-Verbose "[$functionName] Removing temporary update file $tempUpdateFile"
                    Remove-Item -Path $tempUpdateFile -Force
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removed temporary update file $tempUpdateFile" -LogLevel "Error"
                }
                #same for the backup file.
                if (Test-Path $backupFile)
                {
                    Write-Verbose "[$functionName] Removing backup file $backupFile"
                    Remove-Item -Path $backupFile -Force
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removed backup file $backupFile" -LogLevel "Error"
                }
                return $false
            }
        }
        else 
        {
            Write-Host "Since this is a development run, no update will be downloaded."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Development run - skipping update download." -LogLevel "Information"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Local version $localVersion is up to date with remote version $remoteVersion. No update required."
        Write-Host "Current version: $localVersion" -ForegroundColor Cyan
        Write-Host "Remote version: $remoteVersion" -ForegroundColor Cyan
        Write-Host "Release date: $($fileMetaData.date)" -ForegroundColor Cyan
        return $returnValues.UpdateNotNeededMessage
    }
    #endregion
    return $returnMessage
}
