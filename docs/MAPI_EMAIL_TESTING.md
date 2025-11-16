# Manual Testing Guide for MAPI Email Functionality

This document describes how to manually test the MAPI email functionality added to the `Send-EmailWithAttachments` function.

## Prerequisites

- Microsoft Outlook must be installed and configured on the test machine
- The user must have permission to create Outlook COM objects
- At least one email account must be configured in Outlook

## Test Scenarios

### Scenario 1: Send Email Using MAPI Mode

This tests the basic MAPI functionality of opening Outlook with a pre-filled email.

```powershell
# Load the required functions
. ./functions/utilityFunctions/Write-Log.ps1
. ./functions/utilityFunctions/Send-DiagnosticInformation.ps1

# Set up a test log file
$testLogFile = Join-Path $env:TEMP "test-email.log"
"Test log entry" | Out-File -FilePath $testLogFile -Encoding utf8
$global:logFile = $testLogFile

# Send email using MAPI
$result = Send-EmailWithAttachments `
    -To "support@example.com" `
    -Subject "Test Email from MAPI Mode" `
    -Body "This is a test email sent using MAPI/Outlook COM automation." `
    -AttachmentPaths @($testLogFile) `
    -UseMAPI `
    -Verbose
```

**Expected Result:**
- Outlook should open with a new email window
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
- Outlook should open with both files attached

### Scenario 3: Test Error Handling (No Outlook)

This tests the error handling when Outlook is not available.

```powershell
# On a machine without Outlook, or with mocked New-Object
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
- Error message should be logged
- User should see message that Outlook is not installed

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
- MAPI mode should open Outlook for manual review and sending
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
3. Outlook should open with diagnostic email pre-filled
4. User can review and send

**Expected Result:**
- User sees both prompts
- Selecting MAPI opens Outlook with diagnostic information
- Log file is attached

## Verification Checklist

- [ ] Outlook opens when using -UseMAPI switch
- [ ] Email has correct recipient address
- [ ] Email has correct subject line
- [ ] Email has correct body text
- [ ] Single attachment is attached correctly
- [ ] Multiple attachments are attached correctly
- [ ] Non-existent files are skipped gracefully
- [ ] Function returns $true on success
- [ ] Function returns $false when Outlook is not available
- [ ] Appropriate error messages are displayed
- [ ] Error messages are logged to log file
- [ ] Verbose output provides useful debugging information
- [ ] Integration with Send-DiagnosticInformation works correctly
- [ ] User can choose between Graph API and MAPI methods
- [ ] Graph API mode still works (backward compatibility)

## Troubleshooting

### Issue: "Outlook is not installed" error

**Solution:** Ensure Microsoft Outlook is installed on the test machine and properly configured.

### Issue: COM object creation fails

**Possible Causes:**
- Outlook is not installed
- User does not have permission to create COM objects
- Outlook is not set as the default mail client

**Solution:** Check Outlook installation and permissions, set Outlook as default mail client in Windows settings.

### Issue: Email doesn't have attachments

**Possible Causes:**
- File paths are incorrect
- Files don't exist at specified paths
- File access permissions issue

**Solution:** Verify file paths exist and are accessible, check verbose output for attachment processing messages.

## Notes

- MAPI mode requires user interaction (manual send)
- Graph API mode sends automatically without user interaction
- MAPI mode does not require authentication
- Graph API mode requires valid access token
- Both modes log activities to the configured log file
