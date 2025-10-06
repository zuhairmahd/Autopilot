function Get-DomainForEditor()
{
    <#
    .SYNOPSIS
        Gets the domain name for editor operations, with fallback to domain selection.
    
    .DESCRIPTION
        Common logic for determining which domain to use when editing domain-specific settings.
        Attempts to use provided domain name, then falls back to currently loaded domain,
        then prompts user to select from available domains if needed.
    
    .PARAMETER DomainName
        Domain name provided by caller. If empty, will attempt auto-detection.
    
    .PARAMETER SettingsFile
        Path to settings file for domain discovery.
    
    .PARAMETER Silent
        If true, uses first available domain in silent mode rather than prompting.
    
    .PARAMETER FunctionName
        Calling function name for logging.
    
    .OUTPUTS
        String domain name, or empty string if no domain could be determined.
    #>
    [CmdletBinding()]
    param(
        [string]$DomainName,
        [string]$SettingsFile,
        [switch]$Silent
    )
    $FunctionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Getting domain for editor. Provided domain: '$DomainName'" -LogLevel "Verbose"
    Write-Verbose "[$FunctionName] Getting domain for editor. Provided domain: '$DomainName'"
    
    # If domain was provided, use it
    if (-not [string]::IsNullOrWhiteSpace($DomainName))
    {
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Using provided domain: '$DomainName'" -LogLevel "Verbose"
        Write-Verbose "[$FunctionName] Using provided domain: '$DomainName'"
        return $DomainName
    }
    
    # Try to get the current domain from calling scope
    $currentDomain = $null
    try
    {
        # Check if $domain variable exists in calling scope
        $currentDomain = Get-Variable -Name "domain" -Scope 2 -ValueOnly -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($currentDomain))
        {
            Write-Log -LogFile $logFile -Module $FunctionName -Message "Found loaded domain from scope: '$currentDomain'" -LogLevel "Verbose"
            Write-Verbose "[$FunctionName] Found loaded domain from scope: '$currentDomain'"
            return $currentDomain
        }
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Unable to access domain variable from calling scope: $($_.Exception.Message)" -LogLevel "Warning"
        Write-Verbose "[$FunctionName] Unable to access domain variable from calling scope: $($_.Exception.Message)"
    }
    
    # Fall back to domain selection
    Write-Log -LogFile $logFile -Module $FunctionName -Message "No loaded domain found, falling back to domain selection" -LogLevel "Warning"
    Write-Verbose "[$FunctionName] No loaded domain found, falling back to domain selection"
    
    $configPath = Split-Path $SettingsFile -Parent
    $availableDomains = Get-AvailableDomains -ConfigurationPath $configPath -SettingsFile $SettingsFile
    if ($availableDomains.Count -eq 0)
    {
        Write-Log -LogFile $logFile -Module $FunctionName -Message "No domains available" -LogLevel "Error"
        Write-Warning "[$FunctionName] No domains available"
        return ""
    }
    
    if ($availableDomains.Count -eq 1)
    {
        $selectedDomain = $availableDomains[0]
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Auto-selected single domain: '$selectedDomain'" -LogLevel "Information"
        Write-Verbose "[$FunctionName] Auto-selected single domain: '$selectedDomain'"
        return $selectedDomain
    }
    
    if (-not $Silent)
    {
        Write-Host "`nAvailable domains:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $availableDomains.Count; $i++)
        {
            Write-Host "$($i + 1). $($availableDomains[$i])" -ForegroundColor White
        }
        
        do
        {
            $choice = Read-Host "Select domain (1-$($availableDomains.Count))"
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $availableDomains.Count)
            {
                $selectedDomain = $availableDomains[[int]$choice - 1]
                Write-Log -LogFile $logFile -Module $FunctionName -Message "User selected domain: '$selectedDomain'" -LogLevel "Information"
                Write-Verbose "[$FunctionName] User selected domain: '$selectedDomain'"
                return $selectedDomain
            }
            Write-Host "Invalid choice. Please enter a number between 1 and $($availableDomains.Count)." -ForegroundColor Red
        } while ($true)
    }
    else
    {
        # Use first domain in silent mode
        $selectedDomain = $availableDomains[0]
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Selected first domain in silent mode: '$selectedDomain'" -LogLevel "Information"
        Write-Verbose "[$FunctionName] Selected first domain in silent mode: '$selectedDomain'"
        return $selectedDomain
    }
}

function Compare-EditorArrayContents()
{
    <#
    .SYNOPSIS
        Compares two arrays to determine if they have different contents.
        Supports both string arrays and hashtable arrays with name/id properties.
    
    .DESCRIPTION
        Consolidated function for comparing arrays across different editors.
        Handles format differences and provides consistent comparison logic.
    #>
    [CmdletBinding()]
    param(
        [array]$Array1,
        [array]$Array2
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$FunctionName] Comparing array contents"
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Comparing array contents" -LogLevel "Verbose"
    
    # Handle null or empty arrays
    if (($null -eq $Array1 -or $Array1.Count -eq 0) -and ($null -eq $Array2 -or $Array2.Count -eq 0))
    {
        Write-Verbose "[$FunctionName] Both arrays are null or empty - no change"
        return $false  # No change
    }
    
    if (($null -eq $Array1 -or $Array1.Count -eq 0) -and ($Array2.Count -gt 0))
    {
        Write-Verbose "[$FunctionName] Array1 is empty but Array2 has content - change detected"
        return $true  # Change detected
    }
    
    if (($Array1.Count -gt 0) -and ($null -eq $Array2 -or $Array2.Count -eq 0))
    {
        Write-Verbose "[$FunctionName] Array1 has content but Array2 is empty - change detected"
        return $true  # Change detected
    }
    
    # Detect array formats
    $format1 = if ($Array1[0] -is [string])
    {
        "String" 
    }
    elseif (($Array1[0] -is [hashtable] -and $Array1[0].ContainsKey('name') -and $Array1[0].ContainsKey('id')) -or
        ($Array1[0] -is [PSCustomObject] -and ($Array1[0].PSObject.Properties.Name -contains 'name') -and ($Array1[0].PSObject.Properties.Name -contains 'id')))
    {
        "HashTable" 
    }
    else
    {
        "Unknown" 
    }
    
    $format2 = if ($Array2[0] -is [string])
    {
        "String" 
    }
    elseif (($Array2[0] -is [hashtable] -and $Array2[0].ContainsKey('name') -and $Array2[0].ContainsKey('id')) -or
        ($Array2[0] -is [PSCustomObject] -and ($Array2[0].PSObject.Properties.Name -contains 'name') -and ($Array2[0].PSObject.Properties.Name -contains 'id')))
    {
        "HashTable" 
    }
    else
    {
        "Unknown" 
    }
    
    Write-Verbose "[$FunctionName] Array1 format: $format1, Array2 format: $format2"
    
    # If formats are different, there's definitely a change
    if ($format1 -ne $format2)
    {
        Write-Verbose "[$FunctionName] Different array formats detected - change detected"
        return $true
    }
    
    # Compare based on format
    if ($format1 -eq "HashTable" -and $format2 -eq "HashTable")
    {
        # Compare hashtable arrays by name and id
        if ($Array1.Count -ne $Array2.Count)
        {
            Write-Verbose "[$FunctionName] Different array lengths - change detected"
            return $true
        }
        
        for ($i = 0; $i -lt $Array1.Count; $i++)
        {
            $item1 = $Array1[$i]
            $item2 = $Array2[$i]
            $name1 = $item1.name
            $id1 = $item1.id
            $name2 = $item2.name
            $id2 = $item2.id
            
            if ($name1 -ne $name2 -or $id1 -ne $id2)
            {
                Write-Verbose "[$FunctionName] Hashtable content difference detected at index $i"
                return $true
            }
        }
        
        Write-Verbose "[$FunctionName] Hashtable arrays are identical - no change"
        return $false
    }
    else
    {
        # Use standard Compare-Object for string arrays
        $comparison = Compare-Object -ReferenceObject $Array1 -DifferenceObject $Array2
        $hasChanges = $null -ne $comparison
        
        Write-Verbose "[$FunctionName] Array comparison result: hasChanges = $hasChanges"
        return $hasChanges
    }
}

function Get-EditorArrayFormat()
{
    <#
    .SYNOPSIS
        Determines the format of an array for editor display.
    
    .DESCRIPTION
        Common logic for detecting array formats (Empty, StringArray, HashTableArray, Unknown)
        used across different editors for consistent format detection.
    #>
    [CmdletBinding()]
    param(
        [array]$Array
    )
    $functionName = $MyInvocation.MyCommand.Name    
    if (-not $Array -or $Array.Count -eq 0)
    {
        Write-Verbose "[$FunctionName] Array is empty or null"
        return "Empty"
    }
    
    $firstElement = $Array[0]
    if ($firstElement -is [string])
    {
        Write-Verbose "[$FunctionName] Array format detected as StringArray"
        return "StringArray"
    }
    elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and 
        (($firstElement -is [hashtable] -and $firstElement.ContainsKey('name') -and $firstElement.ContainsKey('id')) -or 
        ($firstElement -is [PSCustomObject] -and ($firstElement.PSObject.Properties.Name -contains 'name') -and ($firstElement.PSObject.Properties.Name -contains 'id'))))
    {
        Write-Verbose "[$FunctionName] Array format detected as HashTableArray"
        return "HashTableArray"
    }
    else
    {
        Write-Verbose "[$FunctionName] Array format detected as Unknown"
        return "Unknown"
    }
}

function Show-EditorArrayContents()
{
    <#
    .SYNOPSIS
        Displays array contents in a consistent format across editors.
    
    .DESCRIPTION
        Common display logic for showing array contents with proper formatting
        based on the detected array format.
    #>
    [CmdletBinding()]
    param(
        [array]$Array,
        [string]$ArrayName
    )
    $functionName = $MyInvocation.MyCommand.Name
    if (-not $Array -or $Array.Count -eq 0)
    {
        Write-Host "  (no $ArrayName specified)" -ForegroundColor Gray
        return
    }
    
    $arrayFormat = Get-EditorArrayFormat -Array $Array
    Write-Verbose "[$FunctionName] Displaying array in format: $arrayFormat"
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Displaying $ArrayName array in format: $arrayFormat" -LogLevel "Verbose"
    
    if ($arrayFormat -eq "HashTableArray")
    {
        foreach ($item in $Array)
        {
            Write-Host "  - Name: $($item.name)" -ForegroundColor White
            if ($item.id)
            {
                Write-Host "    ID:   $($item.id)" -ForegroundColor Gray
            }
            else
            {
                Write-Host "    ID:   (not resolved)" -ForegroundColor Yellow
            }
        }
    }
    else
    {
        foreach ($item in $Array)
        {
            Write-Host "  - $item" -ForegroundColor White
        }
        if ($arrayFormat -eq "StringArray")
        {
            Write-Host "  (Note: Items are in old format - will be upgraded)" -ForegroundColor Yellow
        }
    }
}

function Get-EditorReplaceOrAddChoice()
{
    <#
    .SYNOPSIS
        Gets user choice for whether to replace existing array items or add to them.
    
    .DESCRIPTION
        Common logic for prompting users about array modification behavior.
        Returns choice and whether to proceed with input.
    #>
    [CmdletBinding()]
    param(
        [array]$CurrentArray,
        [string]$ItemType
    )
    $functionName = $MyInvocation.MyCommand.Name    
    if (-not $CurrentArray -or $CurrentArray.Count -eq 0)
    {
        Write-Verbose "[$FunctionName] No existing items, will create new array"
        return @{
            ShouldReplaceExisting = $true
            ShouldProceed         = $true
        }
    }
    
    Write-Host "`nYou have existing $ItemType in this list." -ForegroundColor Yellow
    Write-Host "Do you want to:" -ForegroundColor White
    Write-Host "  1. Replace all existing $ItemType with new ones" -ForegroundColor White
    Write-Host "  2. Add new $ItemType to the existing ones" -ForegroundColor White
    Write-Host "  3. Keep current $ItemType unchanged" -ForegroundColor White
    
    $choice = Read-Host "Enter your choice (1-3)"
    Write-Verbose "[$FunctionName] User choice input: $choice"
    while ($choice -notin '1', '2', '3')
    {
        Write-Host "Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
        #beep
        [console]::beep(1000, 200)
        $choice = Read-Host "Enter your choice (1-3)"
    }
    switch ($choice)
    {
        '1'
        {
            Write-Host "`n[*] You chose: REPLACE all existing $ItemType" -ForegroundColor Yellow
            Write-Host "  -> All current $ItemType will be removed" -ForegroundColor Red
            Write-Host "  -> Only new $ItemType you enter will be saved" -ForegroundColor Green
            Write-Log -LogFile $logFile -Module $FunctionName -Message "User chose to replace existing $ItemType" -LogLevel "Verbose"
            Write-Verbose "[$FunctionName] User chose to replace existing $ItemType"
            return @{
                ShouldReplaceExisting = $true
                ShouldProceed         = $true
            }
        }
        '2'
        {
            Write-Host "`n[*] You chose: ADD new $ItemType to existing ones" -ForegroundColor Yellow
            Write-Host "  -> All current $ItemType will be kept" -ForegroundColor Green
            Write-Host "  -> New $ItemType you enter will be added to the list" -ForegroundColor Green
            Write-Log -LogFile $logFile -Module $FunctionName -Message "User chose to add to existing $ItemType" -LogLevel "Verbose"
            Write-Verbose "[$FunctionName] User chose to add to existing $ItemType"
            return @{
                ShouldReplaceExisting = $false
                ShouldProceed         = $true
            }
        }
        '3'
        {
            Write-Host "`n[*] You chose: KEEP current $ItemType unchanged" -ForegroundColor Yellow
            Write-Host "  -> No changes will be made" -ForegroundColor Cyan
            Write-Host "  -> Returning to previous menu" -ForegroundColor Cyan
            Write-Log -LogFile $logFile -Module $FunctionName -Message "User chose to keep current $ItemType unchanged" -LogLevel "Verbose"
            Write-Verbose "[$FunctionName] User chose to keep current $ItemType unchanged"
            return @{
                ShouldReplaceExisting = $false
                ShouldProceed         = $false
            }
        }
    }
}

function Convert-StringArrayToHashTableArray()
{
    <#
    .SYNOPSIS
        Converts a string array to hashtable array format for consistency.
    
    .DESCRIPTION
        Common conversion logic to upgrade old string format arrays to
        new hashtable format with name/id properties.
    #>
    [CmdletBinding()]
    param(
        [array]$StringArray
    )
    $FunctionName = $MyInvocation.MyCommand.Name    
    $convertedArray = @()
    Write-Host "`nConverting existing items to new format..." -ForegroundColor Yellow
    Write-Verbose "[$FunctionName] Converting $($StringArray.Count) items from string to hashtable format"
    
    foreach ($itemName in $StringArray)
    {
        $convertedArray += @{
            name = $itemName
            id   = $null  # Will be resolved when needed
        }
    }
    
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Converted $($StringArray.Count) items to hashtable format" -LogLevel "Information"
    return $convertedArray
}

function Update-DomainArraySetting()
{
    <#
    .SYNOPSIS
        Updates domain-level array settings using separate domain configuration files.
    
    .DESCRIPTION
        Consolidated function for updating various array-based domain settings.
        Handles loading, updating, and saving domain configuration with proper verification.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile,
        [string]$DomainName,
        [string]$SettingName,
        [array]$SettingValue
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Updating $SettingName for domain '$DomainName'" -LogLevel "Information"
    Write-Verbose "[$FunctionName] Updating $SettingName for domain '$DomainName'"
    
    try
    {
        # Determine configuration path from settings file
        $configPath = Split-Path $SettingsFile -Parent
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Configuration path: $configPath" -LogLevel "Verbose"
        Write-Verbose "[$FunctionName] Configuration path: $configPath"
        
        # Load current domain configuration
        $domainConfig = Get-DomainConfigurationFromFiles -DomainName $DomainName -ConfigurationPath $configPath
        if ($null -eq $domainConfig)
        {
            Write-Log -LogFile $logFile -Module $FunctionName -Message "Failed to load domain configuration for '$DomainName'" -LogLevel "Error"
            Write-Warning "[$FunctionName] Failed to load domain configuration for '$DomainName'"
            return $false
        }
        
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Successfully loaded domain configuration for '$DomainName'" -LogLevel "Information"
        Write-Verbose "[$FunctionName] Successfully loaded domain configuration for '$DomainName'"
        
        # Update the specific setting
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Setting $SettingName to array with $($SettingValue.Count) items" -LogLevel "Verbose"
        Write-Verbose "[$FunctionName] Setting $SettingName to array with $($SettingValue.Count) items"
        
        # Ensure SettingValue is always an array, even for single items
        $settingArray = @($SettingValue)
        
        # Update the domain configuration - handle both hashtable and PSCustomObject
        if ($domainConfig -is [hashtable])
        {
            $domainConfig[$SettingName] = $settingArray
        }
        else
        {
            # PSCustomObject - add or update property
            if ($domainConfig.PSObject.Properties.Name -contains $SettingName)
            {
                $domainConfig.$SettingName = $settingArray
            }
            else
            {
                $domainConfig | Add-Member -MemberType NoteProperty -Name $SettingName -Value $settingArray
            }
        }
        
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Updated $SettingName in domain configuration object" -LogLevel "Verbose"
        Write-Verbose "[$FunctionName] Updated $SettingName in domain configuration object"
        
        # Save the updated domain configuration
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Saving updated domain configuration" -LogLevel "Verbose"
        Write-Verbose "[$FunctionName] Saving updated domain configuration"
        
        $success = Save-DomainConfiguration -DomainName $DomainName -DomainConfiguration $domainConfig -ConfigurationPath $configPath
        if ($success)
        {
            Write-Log -LogFile $logFile -Module $FunctionName -Message "Successfully saved updated domain configuration" -LogLevel "Information"
            Write-Verbose "[$FunctionName] Successfully saved updated domain configuration"
            
            # Verify the saved configuration
            $verifyConfig = Get-DomainConfigurationFromFiles -DomainName $DomainName -ConfigurationPath $configPath
            if ($verifyConfig)
            {
                # Convert to hashtable if needed for consistent access
                $verifyConfigHash = Test-IsHashtableOrConvert -InputObject $verifyConfig
                
                # Get the actual saved setting
                $actualSetting = $verifyConfigHash[$SettingName]
                
                # Ensure actualSetting is always an array
                $actualSetting = @($actualSetting)
                
                Write-Log -LogFile $logFile -Module $FunctionName -Message "Verification: Saved $($settingArray.Count) items, Loaded $($actualSetting.Count) items" -LogLevel "Verbose"
                Write-Verbose "[$FunctionName] Verification: Saved $($settingArray.Count) items, Loaded $($actualSetting.Count) items"
                
                # Use simplified comparison approach
                $verificationResult = $false
                
                if ($settingArray.Count -eq 0 -and $actualSetting.Count -eq 0)
                {
                    # Both are empty - verification successful
                    $verificationResult = $true
                }
                elseif ($settingArray.Count -eq $actualSetting.Count)
                {
                    # Same count, compare content
                    if ($settingArray.Count -gt 0 -and $settingArray[0] -is [hashtable])
                    {
                        # Hashtable comparison - compare by ID and name
                        $verificationResult = $true
                        for ($i = 0; $i -lt $settingArray.Count; $i++)
                        {
                            $saved = $settingArray[$i]
                            $loaded = $actualSetting[$i]
                            
                            # Convert loaded item to hashtable if needed
                            $loadedHash = Test-IsHashtableOrConvert -InputObject $loaded
                            
                            if (($saved.name -ne $loadedHash.name) -or ($saved.id -ne $loadedHash.id))
                            {
                                Write-Log -LogFile $logFile -Module $FunctionName -Message "Content mismatch at index $i`: saved($($saved.name),$($saved.id)) vs loaded($($loadedHash.name),$($loadedHash.id))" -LogLevel "Verbose"
                                $verificationResult = $false
                                break
                            }
                        }
                    }
                    else
                    {
                        # Simple array comparison
                        $comparisonResult = Compare-Object -ReferenceObject $settingArray -DifferenceObject $actualSetting
                        $verificationResult = ($null -eq $comparisonResult)
                    }
                }
                
                if ($verificationResult)
                {
                    Write-Log -LogFile $logFile -Module $FunctionName -Message "Successfully updated and verified $SettingName" -LogLevel "Information"
                    Write-Verbose "[$FunctionName] Successfully updated and verified $SettingName"
                    return $true
                }
                else
                {
                    Write-Log -LogFile $logFile -Module $FunctionName -Message "Verification failed for $SettingName" -LogLevel "Warning"
                    Write-Verbose "[$FunctionName] Verification failed for $SettingName. Saved: $($settingArray.Count) items, Loaded: $($actualSetting.Count) items"
                    Write-Warning "[$FunctionName] Verification failed for $SettingName"
                    return $false
                }
            }
            else
            {
                Write-Log -LogFile $logFile -Module $FunctionName -Message "Failed to reload domain configuration for verification" -LogLevel "Warning"
                Write-Warning "[$FunctionName] Failed to reload domain configuration for verification"
                return $false
            }
        }
        else
        {
            Write-Log -LogFile $logFile -Module $FunctionName -Message "Failed to save updated domain configuration" -LogLevel "Error"
            Write-Warning "[$FunctionName] Failed to save updated domain configuration"
            return $false
        }
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Error updating $($SettingName): $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$FunctionName] Error updating $($SettingName): $($_.Exception.Message)"
        return $false
    }
}

function Show-EditorInteractiveChoice()
{
    <#
    .SYNOPSIS
        Shows an interactive choice prompt for various editor operations.
    
    .DESCRIPTION
        Common logic for showing choice prompts with validation and beep on invalid input.
    #>
    [CmdletBinding()]
    param(
        [string]$PromptText
    )
    $FunctionName = $MyInvocation.MyCommand.Name    
    $choice = Read-Host $PromptText
    while ($choice -notin @('y', 'Y', 'yes', 'n', 'N', 'no'))
    {
        Write-Host "Invalid selection. Please enter 'y' or 'n'." -ForegroundColor Red
        [console]::beep(1000, 500)
        $choice = Read-Host $PromptText
    }
    
    $result = ($choice -eq 'y' -or $choice -eq 'Y')
    Write-Log -LogFile $logFile -Module $FunctionName -Message "User interactive choice result: $result for prompt: $PromptText" -LogLevel "Verbose"
    return $result
}

function Test-ItemExists()
{
    [CmdletBinding()]
    param(
        $ItemName, 
        $ItemId, 
        $ExistingList
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$FunctionName] Checking if item exists: Name='$ItemName', Id='$ItemId'"
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Checking if item exists: Name='$ItemName', Id='$ItemId'"
    
    foreach ($existing in $ExistingList)
    {
        Write-Verbose "[$FunctionName] Comparing against existing item: $($existing | Out-String)"
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Comparing against existing item: $($existing | Out-String)"
        if ($existing -is [hashtable] -or $existing -is [PSCustomObject])
        {
            $existingName = $existing.name 
            Write-Verbose "[$FunctionName] Existing item name: '$existingName'"
            Write-Log -LogFile $logFile -Module $FunctionName -Message "Existing item name: '$existingName'"    
            $existingId = $existing.id 
            Write-Verbose "[$FunctionName] Existing item id: '$existingId'"
            Write-Log -LogFile $logFile -Module $FunctionName -Message "Existing item id: '$existingId'"            
            if (($existingName -and $existingName -eq $ItemName) -or ($ItemId -and $existingId -and $existingId -eq $ItemId))
            {
                Write-Verbose "[$FunctionName] Item exists: Name='$ItemName', Id='$ItemId'"
                Write-Log -LogFile $logFile -Module $FunctionName -Message "Item exists: Name='$ItemName', Id='$ItemId'"
                return $true
            }
        }
        elseif ($existing -is [string] -and $existing -eq $ItemName)
        {
            Write-Verbose "[$FunctionName] Item exists in string array: Name='$ItemName'"       
            Write-Log -LogFile $logFile -Module $FunctionName -Message "Item exists in string array: Name='$ItemName'"      
            return $true
        }
    }
    Write-Verbose "[$FunctionName] Item does not exist: Name='$ItemName', Id='$ItemId'"
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Item does not exist: Name='$ItemName', Id='$ItemId'"
    return $false
}
