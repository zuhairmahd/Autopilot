function Get-StringsFromJson
<#
.SYNOPSIS
    Loads localized strings and messages from strings.json with comprehensive fallback support and caching.

.DESCRIPTION
    This function loads localized strings, return values, device states, and device actions from
    the strings.json file. It uses the consolidated Get-JsonConfiguration function to provide
    robust JSON handling, validation, and fallback to default values when the file is missing
    or contains invalid data. Implements intelligent caching to minimize file I/O operations.

.PARAMETER StringsFile
    The path to the strings.json file. Defaults to "$PWD\strings.json".

.OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with three main sections:
    - returnValues: Messages for various operation results
    - deviceStates: Device state descriptions  
    - deviceActions: Available device actions

.EXAMPLE
    # Load strings from default location
    $strings = Get-StringsFromJson

.EXAMPLE  
    # Load strings from custom location
    $strings = Get-StringsFromJson -StringsFile "C:\Config\custom-strings.json"

.NOTES
    - Uses the consolidated Get-JsonConfiguration function for consistency
    - Provides comprehensive default values for all string categories
    - Handles missing files and invalid JSON gracefully
    - Maintains backward compatibility with existing code
    - Includes detailed logging for troubleshooting
    - Implements intelligent caching based on file timestamps
#>
{
    [CmdletBinding()]
    param(
        [string]$StringsFile = "$PWD\strings.json"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Initialize script-level strings cache if not exists
    if (-not $script:stringsCache) {
        $script:stringsCache = @{}
        $script:stringsFileTimestamp = @{}
        Write-Verbose "[$functionName] Initialized strings configuration cache"
    }
    
    # Create cache key based on file path
    $cacheKey = $StringsFile
    $fileExists = Test-Path $StringsFile
    
    # Check if we have cached data and if file hasn't been modified
    if ($script:stringsCache.ContainsKey($cacheKey) -and $fileExists) {
        $currentFileTime = (Get-Item $StringsFile).LastWriteTime
        $cachedFileTime = $script:stringsFileTimestamp[$cacheKey]
        
        if ($cachedFileTime -and $currentFileTime -eq $cachedFileTime) {
            Write-Verbose "[$functionName] Using cached strings configuration for: $StringsFile"
            return $script:stringsCache[$cacheKey]
        }
    }
    
    Write-Verbose "[$functionName] Loading strings from file: $StringsFile"
    # Default fallback values organized by sections - PowerShell 5.1 compatible
    $defaultStringValues = @{
        returnValues  = @{
            unknownErrorMessage            = 'An unknown error occurred'
            noRestartMessage               = 'Device not restarted.'
            EnrolledMessage                = 'The device is enrolled.'
            notContactedMessage            = 'The device has not contacted the enrollment service.'
            PendingResetMessage            = 'The device is pending a reset.'
            EnrollmentFailedMessage        = 'The device enrollment failed.'
            deviceNotAssignedMessage       = 'The device is not assigned to a deployment profile.'
            deviceAssignmentPendingMessage = 'The device is pending assignment to a deployment profile.'
            deviceNotInIntuneMessage       = 'The device is not in Intune.'
            noUserDeviceFoundMessage       = 'No user or device found.'
            noUserFoundInDirectoryMessage  = 'This user does not exist'
            noGroupFoundInDirectoryMessage = 'This group does not exist'
            deviceUnknownActionMessage     = 'The action may still be in progress. You can check the device status in the Intune portal'
            deviceImportSuccessMessage     = 'The device was imported successfully.'
            deviceImportFailedMessage      = 'The device import failed.'
            deviceDeleteSuccessMessage     = 'The device was deleted successfully.'
            deviceDeleteFailedMessage      = 'The device deletion failed.'
            deviceWipeSuccessMessage       = 'The device was wiped successfully'
            deviceWipeFailedMessage        = 'The device wipe failed'
            deviceSyncSuccessMessage       = 'The device sync was successful'
            deviceSyncFailedMessage        = 'The device sync failed'
            deviceCleanSuccessMessage      = 'The device was cleaned successfully'
            deviceCleanFailedMessage       = 'The device clean failed'
            deviceRestartSuccessMessage    = 'The device was restarted successfully.'
            deviceRestartFailedMessage     = 'The device restart failed'
            serialNumberNotFoundMessage    = 'Serial number was not found'
            UpdateFailedMessage            = 'Could not download update.'
            noAccessTokenMessage           = 'Could not obtain an access token. Please check your credentials.'
            UpdateSuccessMessage           = 'The script was updated successfully.'
            UpdateNotNeededMessage         = 'The script is already up to date.'
            userCanceledMessage            = 'Operation canceled by user'
            999                            = 'No updates were found'
            1000                           = 'All updates were installed'
            1001                           = 'Some updates were installed'
            10002                          = 'Some updates were installed'
            1003                           = 'Updates failed to install'
        }
        deviceStates  = @{
            Ready    = 'The device is ready for the next user'
            NotReady = 'The device is not ready for the next user'
        }
        deviceActions = @{
            none            = 'No action'
            contactAdmin    = 'Contact an Intune administrator'
            contactHelpdesk = 'Contact the helpdesk'
            WipeOrClean     = 'Wipe or clean the device'
        }
    }
    
    try
    {
        # Use the consolidated configuration loader
        Write-Log -LogFile $LogFile -Module $functionName -Message "Loading strings configuration from: $StringsFile" -LogLevel "Debug"
        $stringsConfig = Get-JsonConfiguration -JsonFile $StringsFile -DefaultValues $defaultStringValues
        Write-Verbose "[$functionName] Successfully loaded strings configuration from file"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully loaded strings configuration" -LogLevel "Debug"
        
        # Cache the configuration and file timestamp (if file exists)
        if ($fileExists) {
            $script:stringsCache[$cacheKey] = $stringsConfig
            $script:stringsFileTimestamp[$cacheKey] = (Get-Item $StringsFile).LastWriteTime
            Write-Verbose "[$functionName] Cached strings configuration for: $StringsFile"
        }
        
        return $stringsConfig
    }
    catch
    {
        Write-Warning "[$functionName] Failed to load strings configuration: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning default values"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to load strings configuration: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Returning default values" -LogLevel "Warning"
        return $defaultStringValues
    }
}

