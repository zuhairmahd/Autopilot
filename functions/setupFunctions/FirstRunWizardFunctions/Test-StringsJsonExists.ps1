function Test-StringsJsonExists()
{
    <#
    .SYNOPSIS
        Ensures that strings.json exists with default values.
    
    .DESCRIPTION
        Checks if strings.json exists, and if not, creates it with comprehensive default values
        for all user-facing strings.
    
    .PARAMETER StringsFile
        Path to the strings.json file.
    
    .PARAMETER Silent
        If specified, skips confirmation prompts.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the file exists or was created successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StringsFile,
        
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Ensuring strings.json exists: $StringsFile"
    
    try
    {
        # Define comprehensive default strings structure  
        $defaultStrings = @{
            Description   = "This is the strings file for the Intune Helpdesk script. It contains all the user-facing strings used in the script."
            version       = "1.1.0.0"
            returnValues  = @{
                unknownErrorMessage            = "An unknown error occurred."
                deviceActionPendingMessage     = "The device is pending an action. Turn on the device, make sure it is connected and perform a sync if needed."
                InvalidSignatureMessage        = "The signature is invalid. The update will be aborted."
                InvalidFileHash                = "The file hash is invalid. The update will be aborted."
                NoMenusConfigured              = "No menus are configured. Check the app configuration."
                backoutText                    = "Returning to previous menu"
                invalidFileType                = "Invalid file type."
                UpdateCancelledMessage         = "The update was cancelled."
                noRestartMessage               = "Device not restarted."
                invalidJWTTokenMessage         = "Invalid JWT token format. Expected at least 2 parts."
                noLAPSFoundMessage             = "No LAPS password found for this device."
                EnrolledMessage                = "The device is enrolled."
                notContactedMessage            = "The device has not contacted the enrollment service."
                PendingResetMessage            = "The device is pending a reset."
                EnrollmentFailedMessage        = "The device enrollment failed."
                deviceNotAssignedMessage       = "The device is not assigned to a deployment profile."
                deviceAssignmentPendingMessage = "The device is pending assignment to a deployment profile."
                deviceNotInIntuneMessage       = "The device is not in Intune."
                noUserDeviceFoundMessage       = "No user or device found."
                noUserFoundInDirectoryMessage  = "This user does not exist"
                noBitLockerKeysFoundMessage    = "No BitLocker keys found for this device."
                noDeviceFound                  = "No device found"
                deviceAssignedMessage          = "The device is assigned to a deployment profile."
                deviceUnknownActionMessage     = "The action may still be in progress. You can check the device status in the Intune portal."
                deviceImportSuccessMessage     = "The device was imported successfully."
                deviceImportFailedMessage      = "The device import failed."
                deviceDeleteSuccessMessage     = "The device was deleted successfully."
                deviceDeleteFailedMessage      = "The device deletion failed."
                deviceWipeSuccessMessage       = "The device was wiped successfully."
                deviceWipeFailedMessage        = "The device wipe failed."
                deviceSyncSuccessMessage       = "The device sync was successful."
                deviceSyncFailedMessage        = "The device sync failed."
                deviceRestartSuccessMessage    = "The device was restarted successfully."
                deviceRestartFailedMessage     = "The device restart failed."
                deviceCleanSuccessMessage      = "The device was cleaned successfully."
                deviceCleanFailedMessage       = "The device clean failed."
                serialNumberNotFoundMessage    = "The serial number was not found."
                UpdateFailedMessage            = "Could not download update."
                noAccessTokenMessage           = "Could not obtain an access token. Please check your credentials."
                UpdateSuccessMessage           = "The script was updated successfully."
                UpdateNotNeededMessage         = "The script is already up to date."
                userCanceledMessage            = "Operation canceled by user"
                "999"                          = "No updates were found"
                "1000"                         = "All updates were installed"
                "1001"                         = "Some updates were installed"
                "10002"                        = "Some updates were installed"
                "1003"                         = "Updates failed to install"
            }
            deviceStates  = @{
                Ready    = "The device is ready for the next user"
                NotReady = "The device is not ready for the next user"
            }
            deviceActions = @{
                none            = "No action"
                contactAdmin    = "Contact an Intune administrator"
                contactHelpdesk = "Contact the helpdesk"
                WipeOrClean     = "Wipe or clean the device"
            }
        }

        if (Test-Path -Path $StringsFile)
        {
            Write-Verbose "[$functionName] Strings file exists, checking for missing default values: $StringsFile"
            Write-SafeLog "Strings file exists, checking for updates: $StringsFile" "Information"
            
            try
            {
                # Load existing strings
                $existingStrings = Get-Content -Path $StringsFile -Raw | ConvertFrom-Json
                
                # Convert JSON object to hashtable for merging
                $existingHashtable = @{}
                $existingStrings.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [PSCustomObject])
                    {
                        $existingHashtable[$_.Name] = ConvertFrom-JsonToHashtable -JsonObject $_.Value
                    }
                    else
                    {
                        $existingHashtable[$_.Name] = $_.Value
                    }
                }
                
                # Merge defaults into existing configuration
                $mergedStrings = Merge-ConfigurationDefaults -ExistingConfig $existingHashtable -DefaultConfig $defaultStrings
                
                # Convert back to JSON and save if changes were made
                $mergedJson = $mergedStrings | ConvertTo-Json -Depth $maxJSONDepth
                
                if ($null -ne $mergedJson)
                {
                    Write-Verbose "[$functionName] Merging default strings with existing configuration"
                    Write-SafeLog "Merging default strings with existing configuration" "Information"
                    $mergedJson = ConvertTo-OrderedJson -InputObject $mergedStrings -Depth $maxJSONDepth
                    Set-Content -Path $StringsFile -Value $mergedJson -Encoding UTF8 -Force
                    Write-Verbose "[$functionName] Updated strings.json with missing default values"
                    Write-SafeLog "Updated strings.json with missing default values" "Information"
                    if (-not $Silent)
                    {
                        Write-Host "Strings file updated with new default values." -ForegroundColor Green
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Strings file is up-to-date"
                }
                return $true
            }
            catch
            {
                Write-Verbose "[$functionName] Error processing existing strings file: $($_.Exception.Message)"
                Write-SafeLog "Error processing existing strings file: $($_.Exception.Message)" "Warning"
                # Continue with creating new file as fallback
            }
        }
        
        if (-not $Silent)
        {
            Write-Host "`n── Strings Configuration ──" -ForegroundColor Cyan
            Write-Host "Creating default strings.json file..." -ForegroundColor White
        }
        
        # File doesn't exist, create it with default strings
        if (-not $Silent)
        {
            Write-Host "Creating default strings.json file..." -ForegroundColor White  
        }
        
        # Convert to JSON and write to file
        $stringsJson = $defaultStrings | ConvertTo-Json -Depth $maxJSONDepth
        Set-Content -Path $StringsFile -Value $stringsJson -Encoding UTF8 -Force
        
        Write-Host "Strings file created successfully." -ForegroundColor Green
        Write-SafeLog "Strings file created successfully: $StringsFile" "Information"
        return $true
        
    }
    catch
    {
        Write-SafeLog "Error ensuring strings.json exists: $($_.Exception.Message)" "Error"
        Write-Host "Error creating strings file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $false
    }
}
