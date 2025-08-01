#!/usr/bin/env pwsh
#
# Manual demonstration of mnemonic navigation functionality
# This script shows the mnemonic keys in action
#

param(
    [switch]$Verbose
)

# Set verbose preference if requested
if ($Verbose) {
    $VerbosePreference = 'Continue'
}

Write-Host "=== Mnemonic Navigation Demo ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This demo shows the new mnemonic navigation keys:" -ForegroundColor Yellow
Write-Host "  - Press 'b' for Back (when available)" -ForegroundColor Green
Write-Host "  - Press 'm' for Main Menu (when available)" -ForegroundColor Green  
Write-Host "  - Press 'q' or 'e' to Exit" -ForegroundColor Green
Write-Host "  - Numeric keys (1, 2, 3, etc.) still work as before" -ForegroundColor White
Write-Host ""

try {
    # Load functions
    Write-Host "Loading functions..." -ForegroundColor Gray
    $functionsFolder = "$PWD\functions"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions) {
        . $function.FullName
    }
    
    # Initialize required global variables for logging
    $Global:LogFile = "$env:TEMP\mnemonic-demo.log"
    
    Write-Host "Functions loaded successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Demo 1: Menu with no navigation options
    Write-Host "Demo 1: Basic menu (only q/e for exit work)" -ForegroundColor Magenta
    Write-Host "Available mnemonic keys: q, e" -ForegroundColor Gray
    $choices1 = @("Option A", "Option B", "Option C")
    Write-Host ""
    
    Write-Host "Simulating menu display (DisplayNumericMenu would show):" -ForegroundColor Gray
    Write-Host "1. Option A" -ForegroundColor White
    Write-Host "2. Option B" -ForegroundColor White  
    Write-Host "3. Option C" -ForegroundColor White
    Write-Host "0. Exit" -ForegroundColor White
    Write-Host "(Hidden: Press 'q' or 'e' for quick exit)" -ForegroundColor DarkGray
    Write-Host ""
    
    # Demo 2: Menu with Back option
    Write-Host "Demo 2: Menu with Back option" -ForegroundColor Magenta
    Write-Host "Available mnemonic keys: b, q, e" -ForegroundColor Gray
    $choices2 = @("Sub Option 1", "Sub Option 2", "Back")
    Write-Host ""
    
    Write-Host "Simulating menu display:" -ForegroundColor Gray
    Write-Host "1. Sub Option 1" -ForegroundColor White
    Write-Host "2. Sub Option 2" -ForegroundColor White
    Write-Host "3. Back" -ForegroundColor White
    Write-Host "0. Exit" -ForegroundColor White
    Write-Host "(Hidden: Press 'b' for quick back, 'q' or 'e' for quick exit)" -ForegroundColor DarkGray
    Write-Host ""
    
    # Demo 3: Menu with Back and Main Menu options
    Write-Host "Demo 3: Deep submenu (Back + Main Menu available)" -ForegroundColor Magenta
    Write-Host "Available mnemonic keys: b, m, q, e" -ForegroundColor Gray
    $choices3 = @("Deep Option 1", "Deep Option 2", "Back", "Main Menu")
    Write-Host ""
    
    Write-Host "Simulating menu display:" -ForegroundColor Gray
    Write-Host "1. Deep Option 1" -ForegroundColor White
    Write-Host "2. Deep Option 2" -ForegroundColor White
    Write-Host "3. Back" -ForegroundColor White
    Write-Host "4. Main Menu" -ForegroundColor White
    Write-Host "0. Exit" -ForegroundColor White
    Write-Host "(Hidden: Press 'b' for back, 'm' for main menu, 'q' or 'e' for exit)" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "Implementation Summary:" -ForegroundColor Cyan
    Write-Host "✓ Mnemonic keys are detected automatically based on available choices" -ForegroundColor Green
    Write-Host "✓ 'b' key works when 'Back' option is present" -ForegroundColor Green
    Write-Host "✓ 'm' key works when 'Main Menu' option is present" -ForegroundColor Green
    Write-Host "✓ 'q' and 'e' keys always work for exit" -ForegroundColor Green
    Write-Host "✓ All existing numeric navigation continues to work" -ForegroundColor Green
    Write-Host "✓ Case-insensitive input (B, b, M, m, Q, q, E, e all work)" -ForegroundColor Green
    Write-Host "✓ Works in both immediate keystroke and Enter-required modes" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "This is an 'easter egg' feature - not documented in the UI!" -ForegroundColor Yellow
    Write-Host "Users who discover it will have a faster navigation experience." -ForegroundColor Yellow
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Demo completed!" -ForegroundColor Green