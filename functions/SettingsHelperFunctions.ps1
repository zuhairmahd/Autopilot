# Enhanced Settings Management Functions for PowerShell 5.1 Compatibility
# These functions specifically handle the settings.json file with better nested object support

function Save-SettingsFile {
    <#
    .SYNOPSIS
    Saves settings to the settings.json file with PowerShell 5.1 compatibility for nested objects.
    
    .DESCRIPTION
    This function specifically handles saving the complex nested structure of settings.json
    with improved formatting and PowerShell 5.1 compatibility.
    
    .PARAMETER Settings
    The settings object (hashtable or PSCustomObject) to save
    
    .PARAMETER FilePath
    Path to the settings.json file (default: .\settings.json)
    
    .PARAMETER CreateBackup
    Create a backup of the existing file before overwriting
    
    .EXAMPLE
    Save-SettingsFile -Settings $settingsObject -FilePath ".\settings.json" -CreateBackup
    
    .NOTES
    This function addresses PowerShell 5.1 nested JSON formatting issues specifically for settings files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Settings,
        
        [string]$FilePath = ".\settings.json",
        
        [switch]$CreateBackup
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting settings file save operation"
    
    try {
        # Create backup if requested
        if ($CreateBackup -and (Test-Path -Path $FilePath)) {
            $backupPath = "$FilePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Write-Verbose "[$functionName] Creating backup at: $backupPath"
            Copy-Item -Path $FilePath -Destination $backupPath -Force
        }
        
        # Convert settings to PowerShell 5.1 compatible format
        Write-Verbose "[$functionName] Converting settings to compatible format"
        $compatibleSettings = ConvertTo-CompatibleSettingsFormat -Settings $Settings
        
        # Convert to JSON with enhanced formatting
        Write-Verbose "[$functionName] Converting to JSON with proper formatting"
        $jsonContent = ConvertTo-JsonCompatible -InputObject $compatibleSettings -Depth 10
        
        # Apply settings-specific formatting
        $formattedJson = Format-SettingsJson -JsonString $jsonContent
        
        # Save the file
        Write-Verbose "[$functionName] Saving settings to: $FilePath"
        $success = Save-JsonToFile -JsonContent $formattedJson -FilePath $FilePath -Force
        
        if ($success) {
            Write-Verbose "[$functionName] Settings file saved successfully"
            
            # Verify the saved file
            if (Test-SavedSettingsFile -FilePath $FilePath) {
                Write-Host "Settings file saved and verified successfully: $FilePath" -ForegroundColor Green
                return $true
            } else {
                Write-Warning "Settings file saved but failed verification. Please check the file manually."
                return $false
            }
        } else {
            Write-Error "[$functionName] Failed to save settings file"
            return $false
        }
    }
    catch {
        Write-Error "[$functionName] Error saving settings file: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Error details: $($_.Exception)"
        return $false
    }
}

function ConvertTo-CompatibleSettingsFormat {
    <#
    .SYNOPSIS
    Converts settings objects to a format that serializes well in PowerShell 5.1.
    
    .DESCRIPTION
    This function specifically handles the nested structure of settings files,
    ensuring proper formatting for the globalSettings and domains sections.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Converting settings to compatible format"
    
    # Create ordered hashtable for the root
    $compatibleSettings = [ordered]@{}
    
    # Handle different input types
    if ($Settings -is [hashtable] -or $Settings -is [System.Collections.Specialized.OrderedDictionary]) {
        foreach ($key in $Settings.Keys) {
            $compatibleSettings[$key] = ConvertTo-NestedHashtable -InputObject $Settings[$key] -MaxDepth 10
        }
    }
    elseif ($Settings.PSObject) {
        # Handle PSCustomObject
        foreach ($property in $Settings.PSObject.Properties) {
            $compatibleSettings[$property.Name] = ConvertTo-NestedHashtable -InputObject $property.Value -MaxDepth 10
        }
    }
    else {
        # Fallback - try to convert as-is
        Write-Verbose "[$functionName] Using fallback conversion method"
        $compatibleSettings = ConvertTo-NestedHashtable -InputObject $Settings -MaxDepth 10
    }
    
    Write-Verbose "[$functionName] Settings conversion completed"
    return $compatibleSettings
}

function Format-SettingsJson {
    <#
    .SYNOPSIS
    Applies specific formatting improvements for settings.json files.
    
    .DESCRIPTION
    This function applies formatting specific to settings files to improve
    readability and consistency, especially for the nested domain structure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonString
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Applying settings-specific JSON formatting"
    
    try {
        # Start with base formatting
        $formatted = Format-JsonOutput -JsonString $JsonString
        
        # Additional settings-specific formatting
        # Ensure proper indentation for nested structures
        $lines = $formatted -split "`n"
        $formattedLines = @()
        $indentLevel = 0
        $indentString = "  " # 2 spaces
        
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($trimmedLine)) {
                continue
            }
            
            # Decrease indent for closing braces/brackets
            if ($trimmedLine -match '^[\}\]]') {
                $indentLevel = [Math]::Max(0, $indentLevel - 1)
            }
            
            # Add the properly indented line
            $formattedLines += ($indentString * $indentLevel) + $trimmedLine
            
            # Increase indent for opening braces/brackets
            if ($trimmedLine -match '[\{\[]$') {
                $indentLevel++
            }
        }
        
        $result = $formattedLines -join "`n"
        
        Write-Verbose "[$functionName] Settings JSON formatting completed"
        return $result
    }
    catch {
        Write-Warning "[$functionName] Failed to apply settings formatting, returning base format: $($_.Exception.Message)"
        return Format-JsonOutput -JsonString $JsonString
    }
}

function Test-SavedSettingsFile {
    <#
    .SYNOPSIS
    Verifies that a saved settings file can be properly loaded and parsed.
    
    .DESCRIPTION
    This function tests the integrity of a saved settings.json file by attempting
    to load and parse it, checking for the expected structure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Verifying saved settings file: $FilePath"
    
    try {
        if (-not (Test-Path -Path $FilePath)) {
            Write-Error "[$functionName] Settings file not found: $FilePath"
            return $false
        }
        
        # Load and parse the JSON
        $content = Get-Content -Path $FilePath -Raw -Force
        $parsedSettings = ConvertFrom-Json -InputObject $content
        
        # Basic structure validation
        $hasGlobalSettings = $parsedSettings.PSObject.Properties.Name -contains 'globalSettings'
        $hasDomains = $parsedSettings.PSObject.Properties.Name -contains 'domains'
        
        if ($hasGlobalSettings -and $hasDomains) {
            Write-Verbose "[$functionName] Settings file structure validation passed"
            
            # Check for nested domain settings
            $domainCount = ($parsedSettings.domains.PSObject.Properties).Count
            Write-Verbose "[$functionName] Found $domainCount domain(s) in settings"
            
            return $true
        } else {
            Write-Warning "[$functionName] Settings file missing expected structure (globalSettings or domains)"
            return $false
        }
    }
    catch {
        Write-Error "[$functionName] Failed to verify settings file: $($_.Exception.Message)"
        return $false
    }
}

function Update-ExistingSettingsUsage {
    <#
    .SYNOPSIS
    Helper function to update existing code that uses ConvertTo-Json for settings.
    
    .DESCRIPTION
    This function provides guidance on updating existing code to use the new
    PowerShell 5.1 compatible functions.
    
    .EXAMPLE
    Update-ExistingSettingsUsage
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "`nTo update your existing code for better PowerShell 5.1 compatibility:" -ForegroundColor Cyan
    Write-Host "`nReplace this:" -ForegroundColor Yellow
    Write-Host "  `$settings | ConvertTo-Json -Depth 10 | Set-Content -Path 'settings.json'" -ForegroundColor Gray
    Write-Host "`nWith this:" -ForegroundColor Green
    Write-Host "  Save-SettingsFile -Settings `$settings -FilePath 'settings.json' -CreateBackup" -ForegroundColor Gray
    
    Write-Host "`nOr for general JSON operations:" -ForegroundColor Yellow
    Write-Host "  `$data | ConvertTo-JsonCompatible -Depth 10 | Save-JsonToFile -FilePath 'output.json'" -ForegroundColor Gray
    
    Write-Host "`nThese new functions provide:" -ForegroundColor Cyan
    Write-Host "  ✓ Better PowerShell 5.1 nested object handling" -ForegroundColor Green
    Write-Host "  ✓ Improved JSON formatting and readability" -ForegroundColor Green
    Write-Host "  ✓ Built-in backup and verification features" -ForegroundColor Green
    Write-Host "  ✓ Error handling and detailed logging" -ForegroundColor Green
}

# Example usage function
function Test-JsonHelperFunctions {
    <#
    .SYNOPSIS
    Tests the JSON helper functions with sample nested data.
    
    .DESCRIPTION
    This function demonstrates the improved JSON handling capabilities
    with sample data similar to your settings structure.
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "Testing JSON Helper Functions..." -ForegroundColor Cyan
    
    # Create sample nested data similar to your settings structure
    $sampleSettings = [ordered]@{
        description = "Sample settings file for testing"
        version = "1.0"
        globalSettings = [ordered]@{
            operatingSystem = "Windows"
            testMode = $false
            configFile = ".\\.secrets\\config.json"
            maxWaitTime = "30"
            timeInSeconds = "60"
        }
        domains = [ordered]@{
            'sample.com' = [ordered]@{
                groupsToInclude = @("group1", "group2")
                groupsToExclude = @()
                settings = [ordered]@{
                    domain = "sample.com"
                    deviceNamePrefix = "test-"
                    maxNumberOfDevicesAllowed = 20
                    MinUsernameLength = 3
                    DesiredAutopilotProfiles = @("profile1", "profile2")
                }
            }
        }
    }
    
    Write-Host "Original object structure:" -ForegroundColor Yellow
    $sampleSettings | Format-List
    
    Write-Host "`nConverting with enhanced functions..." -ForegroundColor Yellow
    $jsonResult = ConvertTo-JsonCompatible -InputObject $sampleSettings -Depth 10
    
    Write-Host "`nResulting JSON:" -ForegroundColor Green
    Write-Host $jsonResult
    
    # Test validation
    $isValid = Test-JsonContent -JsonString $jsonResult -ShowErrors
    Write-Host "`nJSON Validation: " -NoNewline
    if ($isValid) {
        Write-Host "PASSED" -ForegroundColor Green
    } else {
        Write-Host "FAILED" -ForegroundColor Red
    }
}

# Export the functions
Export-ModuleMember -Function Save-SettingsFile, ConvertTo-CompatibleSettingsFormat, Test-SavedSettingsFile, Update-ExistingSettingsUsage, Test-JsonHelperFunctions
