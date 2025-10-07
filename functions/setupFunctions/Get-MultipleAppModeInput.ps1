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
        [switch]$AllowSingleMode
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting multiple app mode input. Current value: '$CurrentValue'" -LogLevel "Verbose"

    $returnObject = @{
        modeSelection    = $null
        useGlobalStorage = $false
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
        $marker = if ($isSelected)
        {
            " [X]" 
        }
        else
        {
            "   " 
        }
        $color = if ($isSelected)
        {
            'Green' 
        }
        else
        {
            'White' 
        }
        
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
            $returnObject.modeSelection = if ($currentModes.Count -eq 1 -and $AllowSingleMode)
            {
                $currentModes[0] 
            }
            else
            {
                $currentModes 
            }
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
        
        # Parse multiple mode selection
        $selectedIndices = @()
        $parts = $choice -split '[,\s]+'
        $validSelection = $true
        
        foreach ($part in $parts)
        {
            $part = $part.Trim()
            if ([string]::IsNullOrWhiteSpace($part))
            {
                continue 
            }
            
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
        
        if (-not $validSelection)
        {
            continue 
        }
        
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
                
                do
                {
                    $storageChoice = Read-Host "Save to Global Settings (1) or Domain Settings (2)? (1/2)"
                    
                    if ($storageChoice -eq '1')
                    {
                        $useGlobalSettings = $true
                        Write-Host "Saving to Global Settings..." -ForegroundColor Green
                        break
                    }
                    elseif ($storageChoice -eq '2')
                    {
                        $useGlobalSettings = $false
                        Write-Host "Saving to Domain Settings..." -ForegroundColor Green
                        break
                    }
                    else
                    {
                        Write-Host "Invalid choice. Please enter 1 for Global or 2 for Domain." -ForegroundColor Red
                    }
                } while ($true)
                
                # Always return array format (eliminate legacy appMode)
                $modesArray = if ($selectedModes.Count -eq 1)
                {
                    @($selectedModes[0]) 
                }
                else
                {
                    $selectedModes 
                }
                $returnObject.modeSelection = $modesArray
                $returnObject.useGlobalStorage = $useGlobalSettings
                return $returnObject
            }
        }
        else
        {
            Write-Host ""
            Write-Host "INVALID SELECTION:" -ForegroundColor Red
            Write-Host "$($validationResult.ErrorMessage)" -ForegroundColor Red
        }
    } while ($true)
    return $returnObject
}
