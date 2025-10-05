#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Demonstration of Initialize-ApplicationConfiguration enhancements
.DESCRIPTION
    Shows how the updated Initialize-ApplicationConfiguration now returns
    Strings and Menu configuration objects along with existing properties.
.NOTES
    This demonstrates the new functionality added in the enhancement.
#>

[CmdletBinding()]
param()

Write-Host "=== Initialize-ApplicationConfiguration Enhancement Demo ===" -ForegroundColor Cyan
Write-Host ""

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load functions
$functionsFolder = Join-Path $RootPath "functions"
if (Test-Path $functionsFolder)
{
    Write-Host "Loading functions..." -ForegroundColor Yellow
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach ($function in $functions)
    {
        try
        {
            . $function.FullName
        }
        catch
        {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
    Write-Host "Functions loaded successfully" -ForegroundColor Green
    Write-Host ""
}

# Set up global log file
$global:LogFile = Join-Path $RootPath "Logs" "demo-strings-menu.log"

# Use existing configuration files
$settingsFile = Join-Path $RootPath "settings.psd1"
$stringsFile = Join-Path $RootPath "strings.psd1"
$menuFile = Join-Path $RootPath "menu.psd1"

Write-Host "=== Configuration Files ===" -ForegroundColor Cyan
Write-Host "Settings: $settingsFile" -ForegroundColor White
Write-Host "Strings:  $stringsFile" -ForegroundColor White
Write-Host "Menu:     $menuFile" -ForegroundColor White
Write-Host ""

# Initialize configuration
Write-Host "=== Initializing Application Configuration ===" -ForegroundColor Cyan
$config = Initialize-ApplicationConfiguration `
    -InitFile $settingsFile `
    -StringsFile $stringsFile `
    -menuFile $menuFile `
    -Domain "contoso.com" `
    -BoundParameters @{} `
    -Verbose

Write-Host ""

if ($config.Success)
{
    Write-Host "✓ Configuration initialized successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Show all returned properties
    Write-Host "=== Returned Configuration Properties ===" -ForegroundColor Cyan
    foreach ($key in $config.Keys | Sort-Object)
    {
        $value = $config[$key]
        $type = $value.GetType().Name
        
        if ($value -is [hashtable])
        {
            $count = $value.Keys.Count
            Write-Host "  $key (${type}): $count keys" -ForegroundColor White
        }
        elseif ($value -is [array])
        {
            $count = $value.Count
            Write-Host "  $key (${type}): $count items" -ForegroundColor White
        }
        else
        {
            Write-Host "  $key (${type}): $value" -ForegroundColor White
        }
    }
    Write-Host ""
    
    # Demonstrate Strings usage
    Write-Host "=== Strings Configuration Sample ===" -ForegroundColor Cyan
    if ($config.Strings -and $config.Strings.Keys.Count -gt 0)
    {
        Write-Host "  Total string keys: $($config.Strings.Keys.Count)" -ForegroundColor White
        
        if ($config.Strings.ContainsKey('returnValues'))
        {
            Write-Host "  Return values:" -ForegroundColor Yellow
            $sampleKeys = $config.Strings.returnValues.Keys | Select-Object -First 5
            foreach ($key in $sampleKeys)
            {
                Write-Host "    - ${key}: $($config.Strings.returnValues[$key])" -ForegroundColor Gray
            }
        }
        
        if ($config.Strings.ContainsKey('deviceActions'))
        {
            Write-Host "  Device actions:" -ForegroundColor Yellow
            foreach ($key in $config.Strings.deviceActions.Keys)
            {
                Write-Host "    - ${key}: $($config.Strings.deviceActions[$key])" -ForegroundColor Gray
            }
        }
    }
    else
    {
        Write-Host "  No strings loaded" -ForegroundColor Red
    }
    Write-Host ""
    
    # Demonstrate Menu usage
    Write-Host "=== Menu Configuration Sample ===" -ForegroundColor Cyan
    if ($config.Menu -and $config.Menu.Keys.Count -gt 0)
    {
        Write-Host "  Total menu definitions: $($config.Menu.Keys.Count)" -ForegroundColor White
        
        # Show main menu structure
        if ($config.Menu.ContainsKey('mainMenu'))
        {
            $mainMenu = $config.Menu.mainMenu
            Write-Host "  Main Menu:" -ForegroundColor Yellow
            Write-Host "    Title: $($mainMenu.Title)" -ForegroundColor Gray
            Write-Host "    Description: $($mainMenu.Description)" -ForegroundColor Gray
            Write-Host "    Type: $($mainMenu.type)" -ForegroundColor Gray
            Write-Host "    Items: $($mainMenu.items.Count)" -ForegroundColor Gray
            
            if ($mainMenu.items.Count -gt 0)
            {
                Write-Host "    Sample items:" -ForegroundColor Yellow
                $sampleItems = $mainMenu.items | Select-Object -First 3
                foreach ($item in $sampleItems)
                {
                    Write-Host "      - $($item.name)" -ForegroundColor Gray
                }
            }
        }
        
        # Show app mode defaults
        if ($config.Menu.ContainsKey('appModeDefaults'))
        {
            Write-Host "  App Modes:" -ForegroundColor Yellow
            foreach ($mode in $config.Menu.appModeDefaults.Keys)
            {
                $desc = $config.Menu.appModeDefaults[$mode].description
                Write-Host "    - ${mode}: $desc" -ForegroundColor Gray
            }
        }
    }
    else
    {
        Write-Host "  No menu loaded" -ForegroundColor Red
    }
    Write-Host ""
    
    # Show traditional configuration properties
    Write-Host "=== Traditional Configuration Properties ===" -ForegroundColor Cyan
    Write-Host "  Auth Type: $($config.Auth.authType)" -ForegroundColor White
    Write-Host "  Delegated: $($config.Auth.delegated)" -ForegroundColor White
    Write-Host "  Global Settings Keys: $($config.GlobalSettings.Keys.Count)" -ForegroundColor White
    Write-Host "  Local Settings Keys: $($config.LocalSettings.Keys.Count)" -ForegroundColor White
    Write-Host "  Required Scopes: $($config.RequiredScopes.Count)" -ForegroundColor White
    Write-Host ""
    
    # Usage example
    Write-Host "=== Usage Example ===" -ForegroundColor Cyan
    Write-Host "  # Access strings for UI text" -ForegroundColor Yellow
    Write-Host '  $message = $config.Strings.returnValues.userCanceledMessage' -ForegroundColor Gray
    Write-Host '  Write-Host $message' -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Access menu for navigation" -ForegroundColor Yellow
    Write-Host '  $menuItems = $config.Menu.mainMenu.items' -ForegroundColor Gray
    Write-Host '  foreach ($item in $menuItems) {' -ForegroundColor Gray
    Write-Host '      Write-Host $item.name' -ForegroundColor Gray
    Write-Host '  }' -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "=== Demo Complete ===" -ForegroundColor Green
    Write-Host "All configuration objects successfully loaded and accessible!" -ForegroundColor Green
}
else
{
    Write-Host "✗ Configuration initialization failed!" -ForegroundColor Red
    Write-Host "Error: $($config.ErrorMessage)" -ForegroundColor Red
    exit 1
}
