# Pester Tests for main.ps1

This directory contains comprehensive Pester tests for the `main.ps1` Intune Helpdesk script, designed to ensure code quality, functionality, and reliability.

## 📋 Overview

The test suite includes:
- **Unit Tests**: Testing individual functions in isolation
- **Integration Tests**: Testing component interactions
- **Validation Tests**: Testing input validation logic
- **Menu Structure Tests**: Testing menu definitions and navigation
- **Error Handling Tests**: Testing error scenarios and graceful failures

## 🚀 Quick Start

### Prerequisites

- PowerShell 5.1 or later
- Pester module (will be auto-installed if missing)

### Running Tests

#### Basic Test Execution
```powershell
# Run all tests with basic output
.\RunTests.ps1
```

#### Detailed Test Execution
```powershell
# Run tests with detailed output
.\RunTests.ps1 -Detailed
```

#### Advanced Test Execution
```powershell
# Run with code coverage analysis
.\TestRunner.ps1 -CodeCoverage

# Run only unit tests
.\TestRunner.ps1 -TestType Unit

# Run for CI/CD pipeline
.\TestRunner.ps1 -CI -CodeCoverage
```

## 📁 File Structure

```
├── main.ps1                 # Main script being tested
├── main.Tests.ps1          # Pester test file
├── RunTests.ps1            # Simple test runner
├── TestRunner.ps1          # Advanced test runner with CI/CD support
├── TestResults/            # Generated test reports (created on first run)
└── TestReports/            # Advanced test reports (created by TestRunner.ps1)
```

## 🧪 Test Categories

### 1. Main Script Structure Tests
- Parameter definitions and defaults
- Function imports and error handling
- Script initialization

### 2. Function Tests

#### `NormalizeUserName` Function
- Domain suffix addition
- Whitespace trimming
- Existing format preservation
- Edge cases (empty input)

#### `validateInput` Function
- **Serial Number Validation**:
  - Length constraints (8-20 characters)
  - Character restrictions (alphanumeric + hyphens)
  - Whitespace handling
- **Username Validation**:
  - Email format validation
  - Length constraints (3-50 characters)
  - Digit prefix rejection
  - Domain normalization

#### `GetUserInput` Function
- Input processing and validation
- Empty input handling (return to menu)
- Error handling and retry logic

#### `DisplayDeviceHealth` Function
- Managed device information display
- Unmanaged device handling
- Health status reporting

#### `ProcessSerialNumber` Function
- Device lookup and processing
- Menu creation for device actions
- Navigation parameter handling
- Managed vs unmanaged device flow

### 3. Menu Structure Tests
- Main menu definition
- Sub-menu structures
- Menu item actions
- Navigation flow

### 4. Integration Tests
- Complete workflow scenarios
- User lookup and device assignment
- Export functionality
- Error scenarios

## 📊 Test Reports

### Basic Reports (RunTests.ps1)
- `TestResults/TestResults.xml` - NUnit format test results
- Console output with pass/fail summary

### Advanced Reports (TestRunner.ps1)
- `TestReports/TestResults.xml` - Detailed NUnit results
- `TestReports/CodeCoverage.xml` - JaCoCo format coverage report
- `TestReports/TestSummary.json` - JSON summary for automation
- Detailed console output with metrics

## 🔧 Configuration

### Test Settings
The tests use mock configurations to avoid dependencies on external services:

```json
{
  "domain": "contoso.com",
  "settings": {
    "MaxUserNameLength": 50,
    "MinUsernameLength": 3,
    "MaxSerialNumberLength": 20,
    "MinSerialNumberLength": 8
  }
}
```

### Mock Functions
Key external functions are mocked to enable isolated testing:
- `GetGraphAccessToken`
- `GetDeviceEnrollmentStatus`
- `SendDeviceCommand`
- `VerifyGroupMembership`
- Menu functions (`NewMenu`, `AddMenuItem`, `ShowMenu`)

## 🎯 Best Practices

### Running Tests During Development
```powershell
# Quick validation during development
.\RunTests.ps1

# Detailed analysis for debugging
.\RunTests.ps1 -Detailed -PassThru
```

### Pre-Commit Testing
```powershell
# Full test suite with coverage
.\TestRunner.ps1 -CodeCoverage -TestType All
```

### CI/CD Pipeline Integration
```powershell
# Automated testing with CI output
.\TestRunner.ps1 -CI -CodeCoverage -OutputFormat NUnitXml
```

## 🐛 Troubleshooting

### Common Issues

#### Test File Not Found
```powershell
# Ensure you're in the correct directory
Set-Location "C:\Users\zuhai\code\Autopilot"
.\RunTests.ps1
```

#### Pester Module Issues
```powershell
# Force reinstall Pester
Uninstall-Module Pester -AllVersions -Force
Install-Module Pester -Force -SkipPublisherCheck
```

#### Mock Function Errors
If you see errors related to missing functions, ensure all function files are present in the `functions/` directory.

#### Permission Issues
```powershell
# Set execution policy for current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Debug Mode
```powershell
# Run tests with verbose output for debugging
.\RunTests.ps1 -Detailed -Verbose
```

## 📈 Coverage Goals

### Target Coverage Metrics
- **Function Coverage**: 90%+ of functions tested
- **Line Coverage**: 80%+ of executable lines
- **Branch Coverage**: 75%+ of decision branches

### Current Test Coverage
Run with `-CodeCoverage` to see current metrics:
```powershell
.\TestRunner.ps1 -CodeCoverage
```

## 🔄 Continuous Integration

### Azure DevOps Pipeline
```yaml
- task: PowerShell@2
  displayName: 'Run Pester Tests'
  inputs:
    targetType: 'filePath'
    filePath: '$(System.DefaultWorkingDirectory)/TestRunner.ps1'
    arguments: '-CI -CodeCoverage -TimeoutMinutes 15'
```

### GitHub Actions
```yaml
- name: Run Pester Tests
  run: |
    .\TestRunner.ps1 -CI -CodeCoverage
  shell: pwsh
```

## 📝 Adding New Tests

### Test Structure Template
```powershell
Describe "Your Function Name" {
    Context "Specific Scenario" {
        BeforeEach {
            # Setup for each test
        }
        
        It "Should do something specific" {
            # Arrange
            $input = "test-value"
            
            # Act
            $result = YourFunction -Parameter $input
            
            # Assert
            $result | Should -Be "expected-value"
        }
    }
}
```

### Mock Template
```powershell
Mock YourExternalFunction {
    return "mock-result"
} -ParameterFilter { $Parameter -eq "specific-value" }
```

## 🆘 Support

For issues with the tests:
1. Check the troubleshooting section above
2. Verify all prerequisites are installed
3. Ensure the main script and function files are present
4. Run with `-Detailed` or `-Verbose` for more information

## 📄 License

These tests are provided as-is for quality assurance of the main.ps1 script. Modify and extend as needed for your environment.
