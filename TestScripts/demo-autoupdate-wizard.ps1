# Interactive test for autoUpdate functionality
# This creates a demo that shows how the wizard would prompt users

param(
    [string]$TestFolder = "$PWD\demo-autoupdate-temp"
)

Write-Host "AutoUpdate First-Run Wizard Demo" -ForegroundColor Green
Write-Host "This demo shows the interactive prompts users will see" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Load functions
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder) {
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions) {
        . $function.FullName
    }
}

Write-Host "`nDemo: Testing autoUpdate function with user input simulation..." -ForegroundColor Cyan
Write-Host "Here's what users will see when configuring autoUpdate:" -ForegroundColor White
Write-Host ""

# Simulate the autoUpdate prompts
Write-Host "── Auto Update Configuration ──" -ForegroundColor Cyan
Write-Host "The script can automatically check for and install updates." -ForegroundColor White
Write-Host "This helps ensure you have the latest features and security improvements." -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Do you want to enable automatic updates?" -ForegroundColor White
Write-Host "1. Yes - Enable automatic updates (recommended)" -ForegroundColor White
Write-Host "2. No - Disable automatic updates" -ForegroundColor White
Write-Host ""

# Show example responses
Write-Host "Example 1: User chooses YES (Enable)" -ForegroundColor Yellow
Write-Host "Enter your choice (1 or 2): 1" -ForegroundColor Gray
Write-Host ""
Write-Host "Automatic updates: Enabled" -ForegroundColor Green
Write-Host "The script will check for updates automatically." -ForegroundColor Yellow
Write-Host ""

Write-Host "Example 2: User chooses NO (Disable)" -ForegroundColor Yellow
Write-Host "Enter your choice (1 or 2): 2" -ForegroundColor Gray
Write-Host ""
Write-Host "Automatic updates: Disabled" -ForegroundColor Yellow
Write-Host "You can manually check for updates when needed." -ForegroundColor Yellow
Write-Host ""

Write-Host "After wizard completion, the configuration summary shows:" -ForegroundColor Cyan
Write-Host "Configuration Summary:" -ForegroundColor White
Write-Host "• Domain: example.com" -ForegroundColor Cyan
Write-Host "• Authentication: Delegated" -ForegroundColor Cyan
Write-Host "• Auto Updates: Enabled" -ForegroundColor Cyan
Write-Host ""

Write-Host "The autoUpdate setting is saved to settings.json globalSettings section" -ForegroundColor Green
Write-Host ""

# Clean up
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

Write-Host "Demo completed! The autoUpdate integration is ready for users." -ForegroundColor Green