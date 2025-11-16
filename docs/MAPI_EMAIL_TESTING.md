# Manual Testing Guide for Windows Simple MAPI Email Functionality

This document describes how to manually test the Windows Simple MAPI email functionality added to the `Send-EmailWithAttachments` function.

## Prerequisites

- A MAPI-compatible mail client must be installed and configured on the test machine
- The mail client should be set as the default in Windows settings
- The user must have permission to use Windows MAPI
- At least one email account must be configured in the mail client

### Supported Mail Clients

- Microsoft Outlook (all versions - Classic, 2016, 2019, 2021, 365)
- Mozilla Thunderbird
- eM Client
- Other MAPI-compatible mail clients

**Note:** Windows 10/11 Mail app does NOT support Simple MAPI and will not work with this feature.

## Test Scenarios

### Scenario 1: Send Email Using MAPI Mode

This tests the basic Windows Simple MAPI functionality of opening the default mail client with a pre-filled email.

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
    -Subject "Test Email from Windows MAPI" `
    -Body "This is a test email sent using Windows Simple MAPI." `
    -AttachmentPaths @($testLogFile) `
    -UseMAPI `
    -Verbose
```

**Expected Result:**
- The default mail client should open with a new email compose window
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
- The default mail client should open with both files attached

### Scenario 3: Test Error Handling (No MAPI Support)

This tests the error handling when a MAPI-compatible mail client is not available.

```powershell
# On a machine without a MAPI-compatible client, or with Windows Mail
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
- Error message should be logged with MAPI error code
- User should see message explaining the MAPI failure

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
- MAPI mode should open the default mail client for manual review and sending
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
3. Default mail client should open with diagnostic email pre-filled
4. User can review and send

**Expected Result:**
- User sees both prompts
- Selecting MAPI opens the default mail client with diagnostic information
- Log file is attached

## Verification Checklist

- [ ] Default mail client opens when using -UseMAPI switch
- [ ] Email has correct recipient address
- [ ] Email has correct subject line
- [ ] Email has correct body text
- [ ] Single attachment is attached correctly
- [ ] Multiple attachments are attached correctly
- [ ] Non-existent files are skipped gracefully
- [ ] Function returns $true on success
- [ ] Function returns $false when MAPI-compatible client is not available
- [ ] Appropriate error messages with MAPI error codes are displayed
- [ ] Error messages are logged to log file
- [ ] Verbose output provides useful debugging information
- [ ] Integration with Send-DiagnosticInformation works correctly
- [ ] User can choose between Graph API and MAPI methods
- [ ] Graph API mode still works (backward compatibility)

## Troubleshooting

### Issue: MAPI error or mail client doesn't open

**Possible Causes:**
- No MAPI-compatible mail client is installed
- Windows 10/11 Mail app is set as default (it does not support MAPI)
- MAPI configuration is broken
- User does not have permission to use MAPI

**Solution:** 
1. Ensure a MAPI-compatible client (Outlook, Thunderbird, eM Client) is installed
2. Set the MAPI-compatible client as the default mail app in Windows Settings
3. Verify MAPI configuration by running "fixmapi.exe" (for Outlook)
4. Check verbose output and log file for specific MAPI error codes

### Common MAPI Error Codes

- **Error 1**: User cancelled the operation
- **Error 2**: General MAPI failure - mail client may not be properly configured
- **Error 3**: MAPI login failure - check mail client configuration
- **Error 11**: Attachment file not found
- **Error 12**: Attachment open failure - check file permissions
- **Error 14**: Invalid recipient address

### Issue: Email doesn't have attachments

**Possible Causes:**
- File paths are incorrect
- Files don't exist at specified paths
- File access permissions issue
- MAPI error 11 or 12 (attachment-related)

**Solution:** Verify file paths exist and are accessible, check verbose output and MAPI error codes for attachment processing messages.

### Issue: Windows 10/11 Mail App

The built-in Windows 10/11 Mail app **does not support Simple MAPI**. If this is set as your default mail client:

**Solution:**
1. Install a MAPI-compatible client (Outlook, Thunderbird, or eM Client)
2. Set it as the default mail app in Windows Settings > Apps > Default apps
3. Retry the operation

## Notes

- Windows Simple MAPI mode requires user interaction (manual send)
- Graph API mode sends automatically without user interaction
- MAPI mode does not require authentication
- Graph API mode requires valid access token
- Both modes log activities to the configured log file
- MAPI mode works with any MAPI-compatible mail client, not just Outlook
- Error codes and messages help diagnose MAPI configuration issues
