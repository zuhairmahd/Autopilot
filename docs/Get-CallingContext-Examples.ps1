# Practical Examples Script for Get-CallingContext Function
# This script demonstrates various real-world usage scenarios

[CmdletBinding()]
param()

# Import the MenuFunctions to access Get-CallingContext
. "$PSScriptRoot\functions\MenuFunctions.ps1"

Write-Host "=== Get-CallingContext Practical Examples ===" -ForegroundColor Green

# Example 1: Data Access Functions
Write-Host "`n--- Example 1: Data Access Functions ---" -ForegroundColor Yellow

function Get-UserDeviceList()
{
    [CmdletBinding()]
    param([string]$UserName)
    
    Write-Host "Retrieving device list for user: $UserName"
    $context = Get-CallingContext
    Write-Host "  Called from context: $context" -ForegroundColor Cyan
    
    # Simulate returning device data
    return @("Device1", "Device2", "Device3")
}

function Set-DeviceConfiguration()
{
    [CmdletBinding()]
    param([string]$DeviceId, [hashtable]$Config)
    
    Write-Host "Setting configuration for device: $DeviceId"
    $context = Get-CallingContext
    Write-Host "  Called from context: $context" -ForegroundColor Cyan
    
    # Simulate configuration update
    return "Configuration updated successfully"
}

# Call the data functions
$devices = Get-UserDeviceList -UserName "john.doe@company.com"
$result = Set-DeviceConfiguration -DeviceId "DEV001" -Config @{Setting1 = "Value1"}

# Example 2: Menu Integration
Write-Host "`n--- Example 2: Menu Integration ---" -ForegroundColor Yellow

function Show-DeviceManagementMenu()
{
    [CmdletBinding()]
    param()
    
    Write-Host "Displaying Device Management Menu"
    
    # Create a sample menu
    $menu = @{
        Title       = "Device Management"
        Description = "Manage devices and users"
        Items       = @()
    }
    
    $context = Get-CallingContext -Menu $menu
    Write-Host "  Menu context: $context" -ForegroundColor Cyan
    
    # Different behavior based on context
    switch -Regex ($context)
    {
        '^Getter_.*'
        {
            Write-Host "  Adding data retrieval options to menu" -ForegroundColor Green
        }
        '^Setter_.*'
        {
            Write-Host "  Adding data modification options to menu" -ForegroundColor Green
        }
        '^Custom_.*'
        {
            Write-Host "  Adding custom business logic options to menu" -ForegroundColor Green
        }
        default
        {
            Write-Host "  Adding standard menu options" -ForegroundColor Green
        }
    }
    
    return $menu
}

# Call menu function
$menu = Show-DeviceManagementMenu

# Example 3: Action Functions with Context
Write-Host "`n--- Example 3: Action Functions ---" -ForegroundColor Yellow

function Execute-DeviceReport()
{
    [CmdletBinding()]
    param([string]$ReportType)
    
    Write-Host "Executing $ReportType report"
    $context = Get-CallingContext
    Write-Host "  Action context: $context" -ForegroundColor Cyan
    
    # Enhanced logging based on context
    $logLevel = if ($context -match '^Action.*') { "INFO" } else { "DEBUG" }
    Write-Host "  Log Level: $logLevel" -ForegroundColor Magenta
    
    return "Report completed: $ReportType"
}

function Process-UserSelection()
{
    [CmdletBinding()]
    param([string]$Selection)
    
    Write-Host "Processing user selection: $Selection"
    $context = Get-CallingContext
    Write-Host "  Processing context: $context" -ForegroundColor Cyan
    
    return "Selection processed successfully"
}

# Call action functions
$reportResult = Execute-DeviceReport -ReportType "Weekly Summary"
$selectionResult = Process-UserSelection -Selection "Option A"

# Example 4: Validation and Testing
Write-Host "`n--- Example 4: Validation and Testing ---" -ForegroundColor Yellow

function Test-UserPermissions()
{
    [CmdletBinding()]
    param([string]$UserName)
    
    Write-Host "Testing permissions for user: $UserName"
    $context = Get-CallingContext
    Write-Host "  Validation context: $context" -ForegroundColor Cyan
    
    # Simulate permission check
    return $true
}

function Validate-DeviceCompliance()
{
    [CmdletBinding()]
    param([string]$DeviceId)
    
    Write-Host "Validating compliance for device: $DeviceId"
    $context = Get-CallingContext
    Write-Host "  Compliance context: $context" -ForegroundColor Cyan
    
    # Simulate compliance check
    return @{
        IsCompliant = $true
        Issues      = @()
    }
}

# Call validation functions
$hasPermissions = Test-UserPermissions -UserName "admin@company.com"
$compliance = Validate-DeviceCompliance -DeviceId "DEV001"

# Example 5: Connection Management
Write-Host "`n--- Example 5: Connection Management ---" -ForegroundColor Yellow

function Connect-ToGraphAPI()
{
    [CmdletBinding()]
    param([string]$TenantId)
    
    Write-Host "Connecting to Graph API for tenant: $TenantId"
    $context = Get-CallingContext
    Write-Host "  Connection context: $context" -ForegroundColor Cyan
    
    # Different connection strategies based on context
    if ($context -match '^Connection_.*')
    {
        Write-Host "  Using optimized connection strategy" -ForegroundColor Green
    }
    else
    {
        Write-Host "  Using standard connection strategy" -ForegroundColor Green
    }
    
    return "Connected successfully"
}

function Disconnect-FromService()
{
    [CmdletBinding()]
    param([string]$ServiceName)
    
    Write-Host "Disconnecting from service: $ServiceName"
    $context = Get-CallingContext
    Write-Host "  Disconnection context: $context" -ForegroundColor Cyan
    
    return "Disconnected successfully"
}

# Call connection functions
$connectionResult = Connect-ToGraphAPI -TenantId "12345-67890"
$disconnectionResult = Disconnect-FromService -ServiceName "GraphAPI"

# Example 6: Custom Business Logic
Write-Host "`n--- Example 6: Custom Business Logic ---" -ForegroundColor Yellow

function ProcessAutopilotDevice()
{
    [CmdletBinding()]
    param([string]$SerialNumber)
    
    Write-Host "Processing Autopilot device with serial: $SerialNumber"
    $context = Get-CallingContext
    Write-Host "  Business logic context: $context" -ForegroundColor Cyan
    
    # Context-aware processing
    $processingMode = switch -Regex ($context)
    {
        '^Getter_.*' { "ReadOnly" }
        '^Setter_.*' { "Modification" }
        '^Creator_.*' { "Creation" }
        '^Remover_.*' { "Deletion" }
        default { "Standard" }
    }
    
    Write-Host "  Processing mode: $processingMode" -ForegroundColor Magenta
    
    return "Device processed in $processingMode mode"
}

function CalculateComplianceScore()
{
    [CmdletBinding()]
    param([array]$Devices)
    
    Write-Host "Calculating compliance score for $($Devices.Count) devices"
    $context = Get-CallingContext
    Write-Host "  Calculation context: $context" -ForegroundColor Cyan
    
    # Simulate score calculation
    $score = 85.5
    return $score
}

# Call custom functions
$deviceResult = ProcessAutopilotDevice -SerialNumber "ABC123"
$score = CalculateComplianceScore -Devices @("DEV001", "DEV002")

# Example 7: Preferred Context Override
Write-Host "`n--- Example 7: Preferred Context Override ---" -ForegroundColor Yellow

function FlexibleFunction()
{
    [CmdletBinding()]
    param([string]$Mode = "Auto")
    
    Write-Host "Running flexible function in $Mode mode"
    
    if ($Mode -eq "Action")
    {
        $context = Get-CallingContext -PreferredContext 'Action'
        Write-Host "  Forced Action context: $context" -ForegroundColor Cyan
    }
    else
    {
        $context = Get-CallingContext
        Write-Host "  Auto-detected context: $context" -ForegroundColor Cyan
    }
    
    return "Function completed with context: $context"
}

# Call with auto-detection
$autoResult = FlexibleFunction -Mode "Auto"

# Call with forced context
$forcedResult = FlexibleFunction -Mode "Action"

# Example 8: Error Handling with Context
Write-Host "`n--- Example 8: Error Handling with Context ---" -ForegroundColor Yellow

function SafeOperation()
{
    [CmdletBinding()]
    param([string]$Operation)
    
    try
    {
        Write-Host "Attempting operation: $Operation"
        $context = Get-CallingContext
        
        # Enhanced error context
        if ($context -eq 'Unknown')
        {
            Write-Warning "Unknown calling context - using safe defaults"
            $context = "Safe_Unknown"
        }
        
        Write-Host "  Safe operation context: $context" -ForegroundColor Cyan
        
        # Simulate operation
        if ($Operation -eq "FailTest")
        {
            throw "Simulated error"
        }
        
        return "Operation '$Operation' completed successfully from context '$context'"
    }
    catch
    {
        $context = Get-CallingContext
        Write-Error "Operation failed from context '$context': $_"
        return "Operation failed"
    }
}

# Call safe operation
$safeResult1 = SafeOperation -Operation "TestOp"
$safeResult2 = SafeOperation -Operation "FailTest"

Write-Host "`n=== Examples Complete ===" -ForegroundColor Green
Write-Host "All examples demonstrate different aspects of Get-CallingContext usage" -ForegroundColor White
