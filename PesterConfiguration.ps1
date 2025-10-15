<#
.SYNOPSIS
    Central Pester configuration for Autopilot test suite
.DESCRIPTION
    Defines standard Pester configuration used across all test executions
    Compatible with PowerShell 5.1 and Pester 5.x
#>

function Get-AutopilotPesterConfiguration
{
    [CmdletBinding()]
    param(
        [ValidateSet('Unit', 'Integration', 'Comprehensive', 'All')]
        [string]$TestType = 'All',
        [switch]$EnableCodeCoverage,
        [switch]$CI
    )
    
    $config = New-PesterConfiguration
    
    # Output configuration
    $config.Output.Verbosity = 'Normal'
    
    # Test discovery
    switch ($TestType)
    {
        'Unit'
        {
            $config.Run.Path = '.\tests\Unit'
            $config.Filter.Tag = 'Unit'
        }
        'Integration'
        {
            $config.Run.Path = '.\tests\Integration'
            $config.Filter.Tag = 'Integration'
        }
        'Comprehensive'
        {
            $config.Run.Path = '.\tests\Comprehensive'
            $config.Filter.Tag = 'Comprehensive'
        }
        'All'
        {
            $config.Run.Path = '.\tests'
            # Exclude template and helper files from test execution
            $config.Run.ExcludePath = @('*Template.Tests.ps1', '*Helpers*')
        }
    }
    
    # Test execution
    $config.Run.Exit = $false  # Don't exit PowerShell after tests
    $config.Run.PassThru = $true  # Return test results object
    
    # Code coverage
    if ($EnableCodeCoverage)
    {
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = '.\functions\**\*.ps1'
        $config.CodeCoverage.OutputPath = '.\coverage.xml'
        $config.CodeCoverage.OutputFormat = 'JaCoCo'
    }
    
    # CI/CD integration
    if ($CI)
    {
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath = '.\TestResults.xml'
        $config.Output.Verbosity = 'Normal'
    }
    
    return $config
}
