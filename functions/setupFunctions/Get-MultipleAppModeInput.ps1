function Get-MultipleAppModeInput()
{
    <#
    .SYNOPSIS
        Gets multiple app mode input from user with conflict validation and resolution.
    
    .DESCRIPTION
        Allows users to select multiple app modes, validates for conflicts, and provides
        clear information about mode hierarchies and superseding behavior. Supports both
        single and multiple mode selection with comprehensive conflict resolution feedback.
    
    .PARAMETER CurrentValue
        Current app mode configuration (single mode string, or array of modes)
        
    .PARAMETER AllowSingleMode
        If true, allows user to select single mode. If false, requires multiple modes.
        
    .OUTPUTS
        Array of selected app modes, or single mode string for backward compatibility
        
    .EXAMPLE
        $selectedModes = Get-MultipleAppModeInput -CurrentValue 'helpDesk'
        
    .EXAMPLE
        $selectedModes = Get-MultipleAppModeInput -CurrentValue @('helpDesk', 'registration')
        
    .NOTES
        - Provides conflict detection and resolution information
        - Shows mode hierarchies and superseding behavior
        - Maintains backward compatibility with single mode selection
        - Validates mode combinations and warns about redundancies
    #>
    [CmdletBinding()]
    param(
        $CurrentValue,
        [switch]$AllowSingleMode = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting multiple app mode input. Current value: '$CurrentValue'" -LogLevel "Verbose"
    
    # Load required dependencies
    $dependencyFunctions = @(
        "$PWD/functions/menuFunctions/Get-AppModeHierarchy.ps1",
        "$PWD/functions/menuFunctions/Get-CombinedAppModeHierarchy.ps1"
    )
    
    foreach ($depFunc in $dependencyFunctions)
    {
        if (Test-Path $depFunc)
        {
            try 
            {
                . $depFunc
                Write-Log -LogFile $logFile -Module $functionName -Message "Loaded dependency: $($depFunc | Split-Path -Leaf)" -LogLevel "Verbose"
            }
            catch 
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Warning: Could not load dependency $($depFunc | Split-Path -Leaf): $($_.Exception.Message)" -LogLevel "Warning"
            }
        }
    }
    
    $availableModes = @(
        @{ Mode = 'full'; Name = 'Full Mode'; Description = 'Complete access to all features (supersedes all other modes)' }
        @{ Mode = 'admin'; Name = 'Administrator Mode'; Description = 'Administrative functions and system configuration' }
        @{ Mode = 'advanced'; Name = 'Advanced Mode'; Description = 'Advanced features for experienced users' }
        @{ Mode = 'advancedRegistration'; Name = 'Advanced Registration Mode'; Description = 'Advanced device registration with extended options' }
        @{ Mode = 'helpDesk'; Name = 'Help Desk Mode'; Description = 'Streamlined interface for help desk operations' }
        @{ Mode = 'registration'; Name = 'Registration Mode'; Description = 'Device registration and enrollment focused interface' }
        @{ Mode = 'custom'; Name = 'Custom Mode'; Description = 'Custom configuration for specialized deployments' }
    )
    
    # Normalize current value to array
    $currentModes = @()
    if ($CurrentValue -is [array])
    {
        $currentModes = $CurrentValue
    }
    elseif ($CurrentValue -and $CurrentValue -ne '')
    {
        $currentModes = @($CurrentValue)
    }
    
    Write-Host ""
    Write-Host "=== App Mode Selection ===" -ForegroundColor Cyan
    Write-Host "Configure application modes for this installation." -ForegroundColor White
    Write-Host "You can select multiple modes to combine their permissions." -ForegroundColor Yellow
    
    if ($currentModes.Count -gt 0)
    {
        Write-Host ""
        Write-Host "Current modes: [$($currentModes -join ', ')]" -ForegroundColor Green
        
        # Show current hierarchy
        try
        {
            $currentHierarchy = Get-MultipleAppModeHierarchy -AppModes $currentModes
            Write-Host "Current effective permissions: [$($currentHierarchy -join ', ')]" -ForegroundColor Cyan
        }
        catch
        {
            Write-Host "Current effective permissions: [$($currentModes -join ', ')]" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "Available app modes:" -ForegroundColor White
    for ($i = 0; $i -lt $availableModes.Count; $i++)
    {
        $mode = $availableModes[$i]
        $isSelected = $currentModes -contains $mode.Mode
        $marker = if ($isSelected) { " [X]" } else { "   " }
        $color = if ($isSelected) { 'Green' } else { 'White' }
        
        Write-Host "$($i + 1).$marker $($mode.Name)" -ForegroundColor $color
        Write-Host "    $($mode.Description)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Selection Options:" -ForegroundColor Yellow
    Write-Host "* Enter mode numbers (e.g., '2,5' for Admin and Help Desk modes)" -ForegroundColor White
    Write-Host "* Enter 'single' to select only one mode" -ForegroundColor White
    Write-Host "* Enter 'clear' to start fresh selection" -ForegroundColor White
    Write-Host "* Press Enter to keep current selection" -ForegroundColor White
    Write-Host "* Enter 'help' for mode hierarchy information" -ForegroundColor White
    
    do
    {
        $choice = Read-Host "Your choice"
        
        # Handle special commands
        if ([string]::IsNullOrWhiteSpace($choice))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current app modes: [$($currentModes -join ', ')]" -LogLevel "Verbose"
            return if ($currentModes.Count -eq 1 -and $AllowSingleMode) { $currentModes[0] } else { $currentModes }
        }
        
        if ($choice -eq 'help')
        {
            Show-AppModeHierarchyInfo
            continue
        }
        
        if ($choice -eq 'clear')
        {
            $currentModes = @()
            Write-Host "Selection cleared. Choose your modes:" -ForegroundColor Yellow
            continue
        }
        
        if ($choice -eq 'single')
        {
            $singleMode = Get-SingleAppModeSelection -AvailableModes $availableModes -CurrentModes $currentModes
            if ($singleMode)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "User selected single app mode: '$singleMode'" -LogLevel "Information"
                return $singleMode
            }
            continue
        }
        
        # Parse multiple mode selection
        $selectedIndices = @()
        $parts = $choice -split '[,\s]+'
        $validSelection = $true
        
        foreach ($part in $parts)
        {
            $part = $part.Trim()
            if ([string]::IsNullOrWhiteSpace($part)) { continue }
            
            if ($part -match '^\d+$')
            {
                $index = [int]$part - 1
                if ($index -ge 0 -and $index -lt $availableModes.Count)
                {
                    $selectedIndices += $index
                }
                else
                {
                    Write-Host "Invalid mode number: $part. Please enter numbers between 1 and $($availableModes.Count)." -ForegroundColor Red
                    $validSelection = $false
                    break
                }
            }
            else
            {
                Write-Host "Invalid input: '$part'. Please enter numbers only." -ForegroundColor Red
                $validSelection = $false
                break
            }
        }
        
        if (-not $validSelection) { continue }
        
        if ($selectedIndices.Count -eq 0)
        {
            Write-Host "No valid modes selected. Please try again." -ForegroundColor Red
            continue
        }
        
        # Convert indices to modes
        $selectedModes = @()
        foreach ($index in ($selectedIndices | Sort-Object -Unique))
        {
            $selectedModes += $availableModes[$index].Mode
        }
        
        # Validate selection and show conflicts/resolutions
        $validationResult = Test-AppModeSelection -SelectedModes $selectedModes
        
        if ($validationResult.IsValid)
        {
            Write-Host ""
            Write-Host "Selected modes: [$($selectedModes -join ', ')]" -ForegroundColor Green
            Write-Host "Effective permissions: [$($validationResult.EffectivePermissions -join ', ')]" -ForegroundColor Cyan
            
            if ($validationResult.HasConflicts)
            {
                Write-Host ""
                Write-Host "CONFLICT INFORMATION:" -ForegroundColor Yellow
                foreach ($conflict in $validationResult.Conflicts)
                {
                    Write-Host "* $($conflict.Description)" -ForegroundColor Yellow
                }
                Write-Host ""
                Write-Host "Resolution: $($validationResult.Resolution)" -ForegroundColor Green
            }
            
            if ($validationResult.HasRedundancy)
            {
                Write-Host ""
                Write-Host "NOTE: Some modes may be redundant due to hierarchy:" -ForegroundColor Cyan
                foreach ($redundancy in $validationResult.Redundancies)
                {
                    Write-Host "* $redundancy" -ForegroundColor Cyan
                }
            }
            
            # Confirm selection
            $confirm = Read-Host "Confirm this selection? (y/N)"
            if ($confirm -match '^[yY]')
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "User selected multiple app modes: [$($selectedModes -join ', ')]" -LogLevel "Information"
                
                # Ask user for storage location preference
                Write-Host ""
                Write-Host "Storage Location Options:" -ForegroundColor Yellow
                Write-Host "1. Global Settings - Available to all users and domains"
                Write-Host "2. Domain Settings - Specific to the active domain only"
                Write-Host ""
                
                do {
                    $storageChoice = Read-Host "Save to Global Settings (1) or Domain Settings (2)? (1/2)"
                    
                    if ($storageChoice -eq '1') {
                        $useGlobalSettings = $true
                        Write-Host "Saving to Global Settings..." -ForegroundColor Green
                        break
                    }
                    elseif ($storageChoice -eq '2') {
                        $useGlobalSettings = $false
                        Write-Host "Saving to Domain Settings..." -ForegroundColor Green
                        break
                    }
                    else {
                        Write-Host "Invalid choice. Please enter 1 for Global or 2 for Domain." -ForegroundColor Red
                    }
                } while ($true)
                
                # Always return array format (eliminate legacy appMode)
                $modesArray = if ($selectedModes.Count -eq 1) { @($selectedModes[0]) } else { $selectedModes }
                
                # Use Update-AppModeSettings for specialized handling with storage preference
                try {
                    $saveResult = Update-AppModeSettings -Configuration $modesArray -SettingsFile $initFile -UseGlobalSettings:$useGlobalSettings
                    
                    if ($saveResult) {
                        $storageType = if ($useGlobalSettings) { "Global Settings" } else { "Domain Settings" }
                        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully saved app mode configuration to $storageType" -LogLevel "Information"
                        Write-Host "App mode configuration saved successfully to $storageType" -ForegroundColor Green
                        return $modesArray
                    }
                    else {
                        Write-Log -LogFile $logFile -Module $functionName -Message "Failed to save app mode configuration" -LogLevel "Error"
                        Write-Host "Failed to save app mode configuration" -ForegroundColor Red
                        return $null
                    }
                }
                catch {
                    $errorMessage = "Error saving app mode configuration: $($_.Exception.Message)"
                    Write-Log -LogFile $logFile -Module $functionName -Message $errorMessage -LogLevel "Error"
                    Write-Host $errorMessage -ForegroundColor Red
                    return $null
                }
            }
        }
        else
        {
            Write-Host ""
            Write-Host "INVALID SELECTION:" -ForegroundColor Red
            Write-Host "$($validationResult.ErrorMessage)" -ForegroundColor Red
        }
        
    } while ($true)
}

function Show-AppModeHierarchyInfo()
{
    <#
    .SYNOPSIS
        Displays app mode hierarchy and conflict resolution information.
    #>
    
    Write-Host ""
    Write-Host "=== App Mode Hierarchy Information ===" -ForegroundColor Cyan
    Write-Host "Understanding mode combinations and conflicts:" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Mode Precedence (highest to lowest):" -ForegroundColor Yellow
    Write-Host "1. Full Mode - Grants all permissions, supersedes all other modes" -ForegroundColor White
    Write-Host "2. Admin Mode - Administrative functions + Advanced + Help Desk + Registration" -ForegroundColor White  
    Write-Host "3. Advanced Mode - Advanced features + Help Desk + Registration" -ForegroundColor White
    Write-Host "4. Advanced Registration - Extended registration features" -ForegroundColor White
    Write-Host "5. Help Desk Mode - Troubleshooting and device management" -ForegroundColor White
    Write-Host "6. Registration Mode - Device enrollment and basic operations" -ForegroundColor White
    Write-Host "7. Custom Mode - User-defined permissions" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Conflict Resolution:" -ForegroundColor Yellow
    Write-Host "* ADDITIVE: Combines permissions from all selected modes (default)" -ForegroundColor White
    Write-Host "* Higher precedence modes include lower precedence permissions" -ForegroundColor White
    Write-Host "* Selecting both 'Admin' and 'Help Desk' is redundant (Admin includes Help Desk)" -ForegroundColor Cyan
    Write-Host "* 'Full' mode with any other mode is redundant (Full includes everything)" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "Recommended Combinations:" -ForegroundColor Yellow
    Write-Host "* Help Desk + Registration: Comprehensive support operations" -ForegroundColor White
    Write-Host "* Advanced Registration: Specialized device enrollment" -ForegroundColor White
    Write-Host "* Custom: For unique organizational requirements" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    Read-Host | Out-Null
}

function Get-SingleAppModeSelection()
{
    <#
    .SYNOPSIS
        Handles single app mode selection with simplified interface.
    #>
    [CmdletBinding()]
    param(
        [array]$AvailableModes,
        [array]$CurrentModes
    )
    
    Write-Host ""
    Write-Host "=== Single App Mode Selection ===" -ForegroundColor Cyan
    Write-Host "Select one app mode for this installation:" -ForegroundColor White
    
    for ($i = 0; $i -lt $AvailableModes.Count; $i++)
    {
        $mode = $AvailableModes[$i]
        $isCurrent = $CurrentModes.Count -eq 1 -and $CurrentModes[0] -eq $mode.Mode
        $marker = if ($isCurrent) { " (Current)" } else { "" }
        $color = if ($isCurrent) { 'Green' } else { 'White' }
        
        Write-Host "$($i + 1). $($mode.Name)$marker" -ForegroundColor $color
        Write-Host "   $($mode.Description)" -ForegroundColor Gray
    }
    
    do
    {
        $choice = Read-Host "Select mode (1-$($AvailableModes.Count)) or Enter to cancel"
        
        if ([string]::IsNullOrWhiteSpace($choice))
        {
            return $null
        }
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $AvailableModes.Count)
        {
            $selectedMode = $AvailableModes[[int]$choice - 1].Mode
            Write-Host "Selected: $selectedMode" -ForegroundColor Green
            return $selectedMode
        }
        
        Write-Host "Invalid choice. Please enter a number between 1 and $($AvailableModes.Count)." -ForegroundColor Red
    } while ($true)
}

function Test-AppModeSelection()
{
    <#
    .SYNOPSIS
        Validates app mode selection and detects conflicts/redundancies.
    #>
    [CmdletBinding()]
    param(
        [array]$SelectedModes
    )
    
    $result = @{
        IsValid = $true
        ErrorMessage = ""
        HasConflicts = $false
        HasRedundancy = $false
        Conflicts = @()
        Redundancies = @()
        EffectivePermissions = @()
        Resolution = ""
    }
    
    try
    {
        # Get combined hierarchy and check for conflicts
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes $SelectedModes -ResolutionStrategy 'Additive'
        
        $result.EffectivePermissions = $combinedResult.AllowedModes
        $result.Resolution = $combinedResult.Resolution
        
        if ($combinedResult.Conflicts.Count -gt 0)
        {
            $result.HasConflicts = $true
            $result.Conflicts = $combinedResult.Conflicts
        }
        
        # Check for redundancies (when higher precedence modes include lower ones)
        $precedenceOrder = @('full', 'admin', 'advanced', 'advancedRegistration', 'helpDesk', 'registration', 'custom')
        
        foreach ($mode in $SelectedModes)
        {
            $modeHierarchy = Get-AppModeHierarchy -CurrentAppMode $mode
            
            foreach ($otherMode in $SelectedModes)
            {
                if ($mode -ne $otherMode -and $modeHierarchy -contains $otherMode)
                {
                    $result.HasRedundancy = $true
                    $result.Redundancies += "'$mode' already includes '$otherMode' permissions"
                }
            }
        }
        
        # Special case: full mode with any other mode
        if ($SelectedModes -contains 'full' -and $SelectedModes.Count -gt 1)
        {
            $result.HasRedundancy = $true
            $result.Redundancies += "Full mode grants all permissions - other modes are redundant"
        }
        
    }
    catch
    {
        $result.IsValid = $false
        $result.ErrorMessage = "Error validating mode selection: $($_.Exception.Message)"
    }
    
    return $result
}