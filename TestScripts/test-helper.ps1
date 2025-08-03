# Test Helper Functions
# This file provides common utilities for test scripts

function Load-AllFunctions {
    <#
    .SYNOPSIS
        Loads all functions from the reorganized functions folder structure
    .DESCRIPTION
        This function recursively loads all PowerShell function files from the functions folder
        to support the reorganized codebase structure
    #>
    param(
        [string]$RootPath = $null
    )
    
    if (-not $RootPath) {
        $RootPath = Split-Path -Parent $PSScriptRoot
    }
    
    $functionsFolder = Join-Path $RootPath "functions"
    
    if (-not (Test-Path $functionsFolder)) {
        throw "Functions folder not found at: $functionsFolder"
    }
    
    Write-Verbose "Loading functions from: $functionsFolder"
    
    try {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
        $loadedCount = 0
        $errorCount = 0
        
        foreach ($function in $functions) {
            try {
                Write-Verbose "Loading function: $($function.FullName)"
                . $function.FullName
                $loadedCount++
            }
            catch {
                $errorCount++
                Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
                if ($VerbosePreference -eq 'Continue') {
                    Write-Verbose $_.ScriptStackTrace
                }
            }
        }
        
        Write-Verbose "Successfully loaded $loadedCount function files"
        if ($errorCount -gt 0) {
            Write-Warning "Failed to load $errorCount function files"
        }
        
        return $loadedCount -gt 0
    }
    catch {
        Write-Error "Failed to enumerate functions: $($_.Exception.Message)"
        return $false
    }
}

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Tests if we're running PowerShell 5.1 and returns compatibility info
    .DESCRIPTION
        Checks PowerShell version and returns information about Unicode support
        and other version-specific capabilities
    #>
    
    $version = $PSVersionTable.PSVersion
    $isPS51 = $version.Major -eq 5 -and $version.Minor -eq 1
    $supportsUnicode = -not $isPS51
    
    return @{
        Version = $version
        IsPS51 = $isPS51
        SupportsUnicode = $supportsUnicode
        MajorVersion = $version.Major
        MinorVersion = $version.Minor
    }
}

function Write-TestResult {
    <#
    .SYNOPSIS
        Writes test results with PowerShell 5.1 compatibility
    .DESCRIPTION
        Displays test results using appropriate characters based on PowerShell version
    #>
    param(
        [string]$Message,
        [bool]$Success,
        [string]$ForegroundColor = $null
    )
    
    $psInfo = Test-PowerShellVersion
    
    if ($Success) {
        $symbol = if ($psInfo.SupportsUnicode) { "✓" } else { "[PASS]" }
        $color = if ($ForegroundColor) { $ForegroundColor } else { "Green" }
    } else {
        $symbol = if ($psInfo.SupportsUnicode) { "✗" } else { "[FAIL]" }
        $color = if ($ForegroundColor) { $ForegroundColor } else { "Red" }
    }
    
    Write-Host "$symbol $Message" -ForegroundColor $color
}

function Write-TestSection {
    <#
    .SYNOPSIS
        Writes a test section header with PowerShell 5.1 compatibility
    #>
    param(
        [string]$Title,
        [string]$ForegroundColor = "Yellow"
    )
    
    Write-Host "`n=== $Title ===" -ForegroundColor $ForegroundColor
}