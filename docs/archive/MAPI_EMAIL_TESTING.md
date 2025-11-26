# Manual Testing Guide for Outlook COM Email Functionality

This document describes how to manually test the Outlook COM email functionality added to the `Send-EmailWithAttachments` function.

## Prerequisites

- **Classic Outlook** must be installed and configured on the test machine
- The user must have permission to use Outlook COM automation
- At least one email account must be configured in Outlook

### Important Notes

- **Classic Outlook Required**: This feature requires Classic Outlook (desktop application)
- **New Outlook Not Supported**: The New Outlook app does not support COM automation and will not work with this feature
- If New Outlook is enabled, the feature will detect this and provide an appropriate error message

## Test Scenarios

### Scenario 1: Send Email Using Outlook COM Mode

This tests the basic Outlook COM functionality of opening Classic Outlook with a pre-filled email.

```powershell
# Load the required functions
. ./functions/utilityFunctions/Write-Log.ps1
. ./functions/utilityFunctions/Send-DiagnosticInformation.ps1

# Set up a test log file
$testLogFile = Join-Path $env:TEMP "test-email.log"
"Test log entry" | Out-File -FilePath $testLogFile -Encoding utf8
$global:logFile = $testLogFile

# Send email using Outlook COM
$result = Send-EmailWithAttachments `
    -To "support@example.com" `
    -Subject "Test Email from Outlook COM" `
    -Body "This is a test email sent using Outlook COM automation." `
    -AttachmentPaths @($testLogFile) `
    -UseMAPI `
    -Verbose
```

**Expected Result:**
- Classic Outlook should open with a new email compose window
- The email should have the specified recipient, subject, and body
- The log file should be attached
- The user can review, edit, and manually send the email

### Scenario 2: Send Email with Multiple Attachments

This tests the attachment handling with multiple files.

```powershell
# Create multiple test files
$file1 = Join-Path $env:TEMP "attachment1.txt"
$file2 = Join-Path $env:TEMP "attachment2.log"
"Content 1" | Out-File -FilePath $file1 -Encoding utf8
"Content 2" | Out-File -FilePath $file2 -Encoding utf8

# Send email with multiple attachments
$result = Send-EmailWithAttachments `
    -To "support@example.com" `
    -Subject "Multiple Attachments Test" `
    -Body "This email has multiple attachments." `
    -AttachmentPaths @($file1, $file2) `
    -UseMAPI
```

**Expected Result:**
- Classic Outlook should open with both files attached

### Scenario 3: Test Error Handling (New Outlook Enabled)

This tests the error handling when New Outlook is enabled instead of Classic Outlook.

```powershell
# On a system with New Outlook enabled
$result = Send-EmailWithAttachments `
    -To "support@example.com" `
    -Subject "Test" `
    -Body "Test" `
    -UseMAPI `
    -ErrorAction SilentlyContinue
    
# Check result
if ($result -eq $false) {
    Write-Host "Error handled correctly - returned false" -ForegroundColor Green
}
```

**Expected Result:**
- Function should return $false
- Error message should indicate New Outlook is enabled
- User should see message to switch to Classic Outlook or use Graph API

### Scenario 4: Compare Graph API vs MAPI Mode

This tests both modes to ensure backward compatibility.

```powershell
# Graph API mode (requires authentication)
$resultGraph = Send-EmailWithAttachments `
    -AccessToken $accessToken `
    -To "support@example.com" `
    -Subject "Graph API Test" `
    -Body "Sent via Graph API" `
    -AttachmentPaths @($testLogFile)

# MAPI mode
$resultMAPI = Send-EmailWithAttachments `
    -To "support@example.com" `
    -Subject "MAPI Test" `
    -Body "Sent via MAPI" `
    -AttachmentPaths @($testLogFile) `
    -UseMAPI
```

**Expected Result:**
- Graph API mode should send email automatically (if authenticated)
- Outlook COM mode should open Classic Outlook for manual review and sending
- Both modes should handle attachments correctly

### Scenario 5: Test Send-DiagnosticInformation Integration

This tests the complete workflow from the user-facing function.

```powershell
# This will prompt for email method selection
Send-DiagnosticInformation -ErrorMessage "Test Error"
```

**User Workflow:**
1. User is prompted: Email/Zip/Cancel - choose [E]
2. User is prompted: Graph/MAPI - choose [M]
3. Classic Outlook should open with diagnostic email pre-filled
4. User can review and send

**Expected Result:**
- User sees both prompts
- Selecting MAPI opens Classic Outlook with diagnostic information
- Log file is attached

## Verification Checklist

- [ ] Classic Outlook opens when using -UseMAPI switch
- [ ] Email has correct recipient address
- [ ] Email has correct subject line
- [ ] Email has correct body text
- [ ] Single attachment is attached correctly
- [ ] Multiple attachments are attached correctly
- [ ] Non-existent files are skipped gracefully
- [ ] Function returns $true on success
- [ ] Function returns $false when Classic Outlook is not available
- [ ] Function detects and reports when New Outlook is enabled
- [ ] Appropriate error messages are displayed
- [ ] Error messages are logged to log file
- [ ] Verbose output provides useful debugging information
- [ ] Integration with Send-DiagnosticInformation works correctly
- [ ] User can choose between Graph API and MAPI methods
- [ ] Graph API mode still works (backward compatibility)

## Troubleshooting

### Issue: "New Outlook is currently enabled" error

**Cause:** New Outlook does not support COM automation.

**Solution:** 
1. Switch back to Classic Outlook using the toggle in Outlook
2. Or use the Graph API option instead (choose [G] when prompted)

### Issue: "Classic Outlook is not installed" error

**Possible Causes:**
- Outlook is not installed
- Only New Outlook app is installed
- Outlook installation path is not in registry

**Solution:** 
1. Install Classic Outlook (Microsoft 365 Apps or Office suite)
2. Or use the Graph API option instead

### Issue: COM automation fails even with Classic Outlook installed

**Possible Causes:**
- Outlook is not properly configured
- User permissions issue
- Outlook is in a corrupted state

**Solution:**
1. Try running Outlook manually to ensure it starts correctly
2. Check Windows Event Viewer for COM-related errors
3. Repair Office/Outlook installation
4. Check antivirus/security software isn't blocking COM automation

### Issue: Email doesn't have attachments

**Possible Causes:**
- File paths are incorrect
- Files don't exist at specified paths
- File access permissions issue

**Solution:** Verify file paths exist and are accessible, check verbose output for attachment processing messages.

## Notes

- Outlook COM mode requires user interaction (manual send)
- Graph API mode sends automatically without user interaction
- Outlook COM mode does not require authentication
- Graph API mode requires valid access token
- Both modes log activities to the configured log file
- Classic Outlook must be used - New Outlook does not support COM automation
- The function automatically detects New Outlook and provides appropriate guidance
