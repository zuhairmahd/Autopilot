<#
.SYNOPSIS
    Template for Pester tests in Autopilot project
.DESCRIPTION
    Copy this template when creating new Pester tests
    Demonstrates best practices and common patterns
#>

# Import test helpers
Import-Module "$PSScriptRoot\Helpers\AutopilotTestHelpers.psm1" -Force

# Test suite
Describe "Feature Name" -Tags 'Unit', 'FeatureArea' {
    
    # Setup - runs once before all tests in this Describe block
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Load functions
        Import-AutopilotFunctions -RootPath $TestContext.RootPath
        
        # Create test files/data
        $script:TestData = @{
            ExpectedValue = "test"
            InputData = @{ key = "value" }
        }
    }
    
    # Teardown - runs once after all tests in this Describe block
    AfterAll {
        # Clean up test environment
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    # Context groups related tests
    Context "When input is valid" {
        
        # BeforeEach runs before each It block in this Context
        BeforeEach {
            # Reset state for each test
            $script:TestInput = "valid input"
        }
        
        It "Should return expected result" {
            # Arrange
            $input = $script:TestInput
            
            # Act
            $result = Get-SomeFunction -Input $input
            
            # Assert
            $result | Should -Be $script:TestData.ExpectedValue
        }
        
        It "Should not throw exception" {
            # Act & Assert
            { Get-SomeFunction -Input $script:TestInput } | Should -Not -Throw
        }
        
        It "Should call dependency function" {
            # Arrange - Mock dependency
            Mock Invoke-Dependency { return "mocked" } -ModuleName TargetModule
            
            # Act
            $result = Get-SomeFunction -Input $script:TestInput
            
            # Assert - Verify mock was called
            Should -Invoke Invoke-Dependency -Exactly 1 -Scope It
        }
    }
    
    Context "When input is invalid" {
        
        It "Should return null" {
            # Act
            $result = Get-SomeFunction -Input $null
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
        
        It "Should throw exception with clear message" {
            # Act & Assert
            { Get-SomeFunction -Input "invalid" } | Should -Throw "Expected error message*"
        }
    }
    
    Context "When function is mocked" {
        
        It "Should use mock return value" {
            # Arrange
            Mock Get-SomeFunction { return "mocked result" }
            
            # Act
            $result = Get-SomeFunction -Input "any"
            
            # Assert
            $result | Should -Be "mocked result"
        }
    }
}

# Multiple Describe blocks for different components
Describe "Another Feature" -Tags 'Integration' {
    
    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Import-AutopilotFunctions -RootPath $TestContext.RootPath
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    It "Should integrate with other components" {
        # Integration test example
        $result = Invoke-IntegratedFunction
        $result.Status | Should -Be "Success"
    }
}
