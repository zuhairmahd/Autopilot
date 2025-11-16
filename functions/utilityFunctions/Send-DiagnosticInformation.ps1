function Send-DiagnosticInformation()
{
    <#
.SYNOPSIS
    Collects and transmits diagnostic information for troubleshooting.

.DESCRIPTION
    This function implements a comprehensive diagnostic information collection and
    transmission system for activation failures. The system provides:
    
    Diagnostic Collection:
    - Gathers detailed log files with error context
    - Collects system and environment information
    
    User Interface:
    - Presents user-friendly options for diagnostic sharing
    - Supports both automated email transmission and manual file saving
    - Allows users to control how diagnostic information is handled
    
    Transmission Methods:
    - Email (Graph API): Automated sending via Microsoft Graph API
    - Email (MAPI): Opens default email client for manual review and sending
    - Zip File: Manual save to user-specified location
    - Secure handling of sensitive diagnostic data
    
    The function ensures that sensitive information is handled appropriately and
    provides multiple options for getting diagnostic data to support personnel.

.PARAMETER ErrorMessage
    The error message that triggered the diagnostic collection.
    This message is included in all diagnostic communications to provide context.

.PARAMETER Certificate
    Optional X509Certificate2 object to include in diagnostic package.
    If not provided, the function attempts to retrieve a certificate automatically.

.EXAMPLE
    Send-DiagnosticInformation -ErrorMessage "PIV card not detected" -Certificate $cert

.EXAMPLE
    Send-DiagnosticInformation -ErrorMessage "Active Directory update failed"
    # Function will attempt to find certificate automatically

.NOTES
    Email Functionality Requirements:
    - Microsoft Graph PowerShell module
    - Appropriate permissions for Mail.Send
    - Valid organizational email configuration
    
    Privacy Considerations:
    - Log files may contain system information but no credentials
    - Users control how diagnostic information is transmitted
    
    The function automatically cleans up temporary files after processing.
    #>
    [CmdletBinding()]
    param(
        [string]$ErrorMessage = 'Support Request'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting diagnostic information collection"
    Write-Log -Message "Starting diagnostic information collection for error: $ErrorMessage" -Module $functionName -LogLevel "Information" -LogFile $logFile
    
    try
    {
        $userChoice = Read-Host -Prompt "How would you like to send diagnostic information to support? ([E]mail/[Z]ip/[C]ancel)"
        Write-Log -Message "User selected diagnostic option: $userChoice" -Module $functionName -LogLevel "Information" -LogFile $logFile
        Write-Verbose "[$functionName] User selected option: $userChoice"   
        while ($userChoice -notin @("E", "Z", "C", "e", "z", "c"))
        {
            Write-Host "Invalid selection. Please enter E, Z, or C." -ForegroundColor Yellow
            [console]::beep(1000, 300)                       
            $userChoice = Read-Host -Prompt "How would you like to send diagnostic information to support? ([E]mail/[Z]ip/[C]ancel)"
            Write-Log -Message "User re-selected diagnostic option: $userChoice" -Module $functionName -LogLevel "Information" -LogFile $logFile
            Write-Verbose "[$functionName] User re-selected option: $userChoice"   
        }                                               
        if ($userChoice -eq "E" -or $userChoice -eq "e")
        {
            Write-Log -Message "User chose to send diagnostic information via email" -Module $functionName -LogLevel "Information" -LogFile $logFile
            
            # Ask user which email method to use
            Write-Host ""
            Write-Host "Select email sending method:" -ForegroundColor Cyan
            Write-Host "  [G] - Graph API (automated, requires authentication)" -ForegroundColor White
            Write-Host "  [M] - MAPI/Outlook (opens email client for manual review)" -ForegroundColor White
            $emailMethod = Read-Host -Prompt "Choose email method ([G]raph/[M]API)"
            Write-Log -Message "User selected email method: $emailMethod" -Module $functionName -LogLevel "Information" -LogFile $logFile
            
            while ($emailMethod -notin @("G", "M", "g", "m"))
            {
                Write-Host "Invalid selection. Please enter G or M." -ForegroundColor Yellow
                [console]::beep(1000, 300)
                $emailMethod = Read-Host -Prompt "Choose email method ([G]raph/[M]API)"
                Write-Log -Message "User re-selected email method: $emailMethod" -Module $functionName -LogLevel "Information" -LogFile $logFile
            }
            
            # Prepare email content
            $emailSubject = "Intune Helpdesk Utility - Diagnostic Information"
            $emailBody = @"
User: $env:USERNAME
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $env:COMPUTERNAME
Error: $ErrorMessage

Please find the attached log file for further analysis.

Best regards,
"@
            
            # Collect files for email
            $attachmentFiles = @()
            if (Test-Path $logFile)
            {
                $attachmentFiles += $logFile
            }
            
            # Validate supportEmail before sending
            if ([string]::IsNullOrWhiteSpace($settings.supportEmail))
            {
                Write-Host "Support email address is not configured. Cannot send diagnostic information email." -ForegroundColor Red
                Write-Log -Message "Support email address is not configured. Email not sent." -Module $functionName -LogLevel "Error" -LogFile $logFile
                $emailSent = $false
            }
            else
            {
                # Send email using selected method
                if ($emailMethod -eq "M" -or $emailMethod -eq "m")
                {
                    Write-Log -Message "Using MAPI/Outlook method to send email" -Module $functionName -LogLevel "Information" -LogFile $logFile
                    $emailSent = Send-EmailWithAttachments -To $settings.supportEmail -Subject $emailSubject -Body $emailBody -AttachmentPaths $attachmentFiles -UseMAPI
                }
                else
                {
                    Write-Log -Message "Using Graph API method to send email" -Module $functionName -LogLevel "Information" -LogFile $logFile
                    $emailSent = Send-EmailWithAttachments -AccessToken $accessToken -To $settings.supportEmail -Subject $emailSubject -Body $emailBody -AttachmentPaths $attachmentFiles
                }
            }
            
            if ($emailSent)
            {
                if ($emailMethod -eq "M" -or $emailMethod -eq "m")
                {
                    Write-Host "Email client opened successfully with diagnostic information" -ForegroundColor Green
                    Write-Log -Message "Email client opened successfully with diagnostic information" -Module $functionName -LogLevel "Information" -LogFile $logFile
                }
                else
                {
                    Write-Host "Diagnostic information email sent successfully" -ForegroundColor Green
                    Write-Log -Message "Diagnostic information email sent successfully" -Module $functionName -LogLevel "Information" -LogFile $logFile
                }
            }
            else
            {
                Write-Host "Failed to send diagnostic information email" -ForegroundColor Red
                Write-Log -Message "Failed to send diagnostic information email" -Module $functionName -LogLevel "Error" -LogFile $logFile                                                                          
            }
        }
        elseif ($userChoice -eq "Z" -or $userChoice -eq "z")
        {
            Write-Log -Message "User chose to save diagnostic information to zip file" -Module $functionName -LogLevel "Information" -LogFile $logFile
            # Collect files for zip
            $zipFiles = @()
            if (Test-Path $logFile)
            {
                $zipFiles += $logFile
                $zipFileName = "DiagnosticInformation_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"                                                        
                write-log -logFile $logFile -module $functionName -message "Preparing to create zip file: $zipFileName" -logLevel "Information"                
                # Create zip file
                $zipCreated = New-ZipPackage -FilePaths $zipFiles -DestinationPath $zipFileName
                if ($null -ne $zipCreated)
                {
                    Write-Host "Diagnostic information saved to zip file: $zipCreated" -ForegroundColor Green
                    Write-Log -Message "Diagnostic information saved to zip file: $zipCreated" -Module $functionName -LogLevel "Information" -LogFile $logFile                         
                }
                else
                {
                    write-log -logFile $logFile -module $functionName -message "Failed to create zip file for diagnostic information" -logLevel "Error"                                   
                    Write-Host "Failed to create zip file for diagnostic information" -ForegroundColor Red
                    Write-Log -Message "Failed to create zip file for diagnostic information" -Module $functionName -LogLevel "Error" -LogFile $logFile                 
                    Write-Host "Please manually collect the log file located at: $logFile" -ForegroundColor Yellow                      
                }
            }
            else
            {
                Write-Host "No log file found to include in zip" -ForegroundColor Yellow
                Write-Log -Message "No log file found to include in zip" -Module $functionName -LogLevel "Warning" -LogFile $logFile                 
            }                                   
        }
        else
        {
            Write-Log -Message "User cancelled diagnostic information collection" -Module $functionName -LogLevel "Information" -LogFile $logFile
            Write-Host "Diagnostic information collection cancelled by user" -ForegroundColor Yellow                        
        }
    }
    catch
    {
        Write-Log -Message "Error in Send-DiagnosticInformation: $($_.Exception.Message)" -Module $functionName -LogLevel "Error" -LogFile $logFile
        Write-Error "Failed to send diagnostic information: $($_.Exception.Message)"                    
        
    }
}

function Send-EmailWithAttachments()
{
    <#
.SYNOPSIS
    Sends email with file attachments using Microsoft Graph API or MAPI (Outlook COM automation).

.DESCRIPTION
    This function provides enterprise-grade email functionality using either Microsoft Graph API
    or MAPI/Outlook COM automation for secure and reliable email transmission. Features include:
    
    Microsoft Graph Integration (Default):
    - Uses modern authentication with Microsoft Graph
    - Supports organizational email policies and security
    - Handles large attachments efficiently
    - Sends email automatically without user interaction
    
    MAPI/Outlook COM Integration (Optional):
    - Opens default email client (Outlook) with pre-filled message
    - Allows user to review and edit before sending
    - Works with standard user permissions
    - Does not require Graph API authentication
    
    Attachment Processing:
    - Supports multiple file attachments
    - Automatic MIME type detection based on file extensions
    - Base64 encoding for secure transmission (Graph API)
    - Direct file attachment (MAPI/Outlook)
    - File size validation and handling
    
    Error Handling:
    - Comprehensive connection and authentication error handling
    - Graceful degradation when Graph modules are unavailable
    - Fallback options when Outlook is not available (MAPI mode)
    - Detailed logging of email transmission attempts

.PARAMETER AccessToken
    Access token for Microsoft Graph API authentication.
    Required when using Graph API mode (default). Not used when -UseMAPI is specified.

.PARAMETER To
    Email address of the recipient. Should be a valid email address
    within the organization or allowed external domain.

.PARAMETER Subject
    Subject line for the email message. Will be included exactly as provided.

.PARAMETER Body
    Plain text body content for the email message.
    HTML formatting is not supported in the current implementation.

.PARAMETER AttachmentPaths
    Array of file paths to include as email attachments.
    Files are validated for existence before inclusion.
    Supported file types include .txt, .log, .cer, .zip, and others.

.PARAMETER UseMAPI
    Switch parameter to use MAPI/Outlook COM automation instead of Microsoft Graph API.
    When specified, opens the default email client with a pre-filled message,
    allowing the user to review, edit, and send manually.

.EXAMPLE
    $success = Send-EmailWithAttachments -AccessToken $token -To "support@company.com" -Subject "PIV Issue" -Body "Please help" -AttachmentPaths @("C:\logs\error.log")
    Sends email using Microsoft Graph API.

.EXAMPLE
    $success = Send-EmailWithAttachments -To "support@company.com" -Subject "PIV Issue" -Body "Please help" -AttachmentPaths @("C:\logs\error.log") -UseMAPI
    Opens Outlook with pre-filled email for user review and manual sending.

.OUTPUTS
    Boolean value indicating email operation success:
    - $true: Email sent successfully (Graph API) or email client opened successfully (MAPI)
    - $false: Email transmission or client opening failed

.NOTES
    Prerequisites for Graph API mode:
    - Microsoft.Graph.Users.Actions PowerShell module
    - Appropriate permissions for Mail.Send in Microsoft Graph
    - Valid organizational email configuration
    - AccessToken parameter
    
    Prerequisites for MAPI mode:
    - Microsoft Outlook installed and configured
    - Default email client set to Outlook
    - No authentication required
    
    The function automatically handles authentication prompts and permission requests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $accessToken,
        [Parameter(Mandatory = $true)]
        [string]$To,
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        [Parameter(Mandatory = $true)]
        [string]$Body,
        [Parameter(Mandatory = $false)]
        [string[]]$AttachmentPaths = @(),
        [Parameter(Mandatory = $false)]
        [switch]$UseMAPI
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -Message "Starting email send process to $To $(if ($UseMAPI) { '(MAPI mode)' } else { '(Graph API mode)' })" -Module $functionName -LogLevel "Information" -LogFile $logFile
    
    # MAPI Mode: Use Outlook COM automation to open email client
    if ($UseMAPI)
    {
        Write-Log -Message "Using MAPI/Outlook COM automation to create email" -Module $functionName -LogLevel "Information" -LogFile $logFile
        Write-Verbose "[$functionName] Using MAPI/Outlook COM automation"
        
        try
        {
            # Attempt to create Outlook COM object
            $outlook = New-Object -ComObject Outlook.Application -ErrorAction Stop
            Write-Log -Message "Successfully created Outlook COM object" -Module $functionName -LogLevel "Debug" -LogFile $logFile
            
            # Create a new mail item
            $mail = $outlook.CreateItem(0)
            Write-Log -Message "Created new Outlook mail item" -Module $functionName -LogLevel "Debug" -LogFile $logFile
            
            # Set email properties
            $mail.To = $To
            $mail.Subject = $Subject
            $mail.Body = $Body
            Write-Log -Message "Set email properties: To=$To, Subject=$Subject" -Module $functionName -LogLevel "Debug" -LogFile $logFile
            
            # Add attachments
            $attachmentCount = 0
            foreach ($attachmentPath in $AttachmentPaths)
            {
                if (Test-Path $attachmentPath)
                {
                    try
                    {
                        $mail.Attachments.Add($attachmentPath) | Out-Null
                        $fileName = [System.IO.Path]::GetFileName($attachmentPath)
                        $attachmentCount++
                        Write-Log -Message "Added attachment: $fileName" -Module $functionName -LogLevel "Information" -LogFile $logFile
                        Write-Verbose "[$functionName] Added attachment: $fileName"
                    }
                    catch
                    {
                        Write-Log -Message "Failed to add attachment $attachmentPath : $($_.Exception.Message)" -Module $functionName -LogLevel "Warning" -LogFile $logFile
                        Write-Warning "[$functionName] Failed to add attachment $attachmentPath : $($_.Exception.Message)"
                    }
                }
                else
                {
                    Write-Log -Message "Attachment file not found: $attachmentPath" -Module $functionName -LogLevel "Warning" -LogFile $logFile
                    Write-Verbose "[$functionName] Attachment file not found: $attachmentPath"
                }
            }
            
            # Display the email for user review and sending
            $mail.Display()
            Write-Log -Message "Email displayed in Outlook with $attachmentCount attachment(s)" -Module $functionName -LogLevel "Information" -LogFile $logFile
            Write-Verbose "[$functionName] Email displayed in Outlook with $attachmentCount attachment(s)"
            
            return $true
        }
        catch
        {
            $errorMessage = "Failed to create email using Outlook COM automation: $($_.Exception.Message)"
            Write-Error $errorMessage
            Write-Log -Message $errorMessage -Module $functionName -LogLevel "Error" -LogFile $logFile
            
            # Check if Outlook is installed
            $outlookInstalled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE" -ErrorAction SilentlyContinue
            if (-not $outlookInstalled)
            {
                Write-Log -Message "Microsoft Outlook does not appear to be installed on this system" -Module $functionName -LogLevel "Error" -LogFile $logFile
                Write-Host "Microsoft Outlook is not installed. MAPI mode requires Outlook to be installed." -ForegroundColor Red
            }
            
            return $false
        }
    }
    
    # Graph API Mode: Continue with existing implementation
    $requiredScope = "Mail.Send"
    if (-not $accessToken)
    {
        Write-Error "AccessToken is required when not using MAPI mode"
        Write-Log -Message "AccessToken is required when not using MAPI mode" -Module $functionName -LogLevel "Error" -LogFile $logFile
        return $false
    }
    
    # Extract user info from access token to ensure we're sending from the correct mailbox
    $tokenClaims = DecodeJwtToken -Token $accessToken -raw
    $grantedScopes = @()
    if ($tokenClaims.scp)
    {
        # Delegated auth - scp is space-separated string
        Write-Verbose "[$functionName] Cached token has delegated scopes (scp)"
        $grantedScopes = $tokenClaims.scp -split ' ' | Where-Object { $_ -and $_.Trim() }
        Write-Verbose "[$functionName] Cached token has delegated scopes (scp): $($grantedScopes -join ', ')"
        write-log -logFile $logFile -Module "$functionName" -Message "Cached token has delegated scopes (scp): $($grantedScopes -join ', ')"                                
    }
    elseif ($tokenClaims.roles)
    {
        # Application auth - roles is array
        $grantedScopes = $tokenClaims.roles
        Write-Verbose "[$functionName] Cached token has application scopes (roles): $($grantedScopes -join ', ')"
        write-log -logFile $logFile -Module "$functionName" -Message "Cached token has application scopes (roles): $($grantedScopes -join ', ')"                    
    }
    else 
    {
        Write-Error "Could not determine granted scopes from access token"
        Write-Log -Message "Could not determine granted scopes from access token" -Module $functionName -LogLevel "Error" -LogFile $logFile
        return $false
    }                                                               
    
    if (-not ($grantedScopes -contains $requiredScope))
    {
        Write-Error "The access token does not have the required scope '$requiredScope' to send email."
        Write-Log -Message "The access token does not have the required scope '$requiredScope' to send email." -Module $functionName -LogLevel "Error" -LogFile $logFile
        return $false
    }                                                                                   
    Write-Verbose "[$functionName] Access token has required scope: $requiredScope"                                     
    write-log -logFile $logFile -Module "$functionName" -Message "Access token has required scope: $requiredScope"                  
    $senderUPN = $null
    
    # Try to get UPN from token claims (preferred_username, upn, email, unique_name in order of preference)
    if ($tokenClaims.preferred_username)
    {
        $senderUPN = $tokenClaims.preferred_username
        Write-Log -Message "Using preferred_username from token: $senderUPN" -Module $functionName -LogLevel "Debug" -LogFile $logFile
    }
    elseif ($tokenClaims.upn)
    {
        $senderUPN = $tokenClaims.upn
        Write-Log -Message "Using upn from token: $senderUPN" -Module $functionName -LogLevel "Debug" -LogFile $logFile
    }
    elseif ($tokenClaims.email)
    {
        $senderUPN = $tokenClaims.email
        Write-Log -Message "Using email from token: $senderUPN" -Module $functionName -LogLevel "Debug" -LogFile $logFile
    }
    elseif ($tokenClaims.unique_name)
    {
        $senderUPN = $tokenClaims.unique_name
        Write-Log -Message "Using unique_name from token: $senderUPN" -Module $functionName -LogLevel "Debug" -LogFile $logFile
    }
    else
    {
        write-log -logFile $logFile -module $functionName -message "Could not determine sender UPN from token claims" -logLevel "Warning" 
        $senderUPN = Read-Host -Prompt "Please enter your email address"                     
        #ensure we get a valid email address format
        while (-not ($senderUPN -match '^[^@\s]+@[^@\s]+\.[^@\s]+$'))                                     
        {
            Write-Host "Incorrect email format. Please enter a valid email address." -ForegroundColor Yellow                                
            [console]::beep(1000, 300)                       
            $senderUPN = Read-Host -Prompt "Please enter your email address"                     
        }
        write-log -logFile $logFile -module $functionName -message "Using user-provided sender UPN: $senderUPN" -logLevel "Debug"                                           
        Write-Verbose "[$functionName] Using user-provided sender UPN: $senderUPN"                              
    }
    
    # Use me/sendMail since we're using the authenticated user's context
    $emailSendURI = "me/sendMail"
    # Prepare attachments
    $attachments = @()
    foreach ($attachmentPath in $AttachmentPaths)
    {
        if (Test-Path $attachmentPath)
        {
            $fileBytes = [System.IO.File]::ReadAllBytes($attachmentPath)
            $fileName = [System.IO.Path]::GetFileName($attachmentPath)
            $contentType = switch ([System.IO.Path]::GetExtension($attachmentPath).ToLower())
            {
                ".txt"
                {
                    "text/plain" 
                }
                ".log"
                {
                    "text/plain" 
                }
                ".cer"
                {
                    "application/x-x509-ca-cert" 
                }
                ".zip"
                {
                    "application/zip" 
                }
                default
                {
                    "application/octet-stream" 
                }
            }
                
            $attachment = @{
                "@odata.type"  = "#microsoft.graph.fileAttachment"
                "name"         = $fileName
                "contentType"  = $contentType
                "contentBytes" = [System.Convert]::ToBase64String($fileBytes)
            }
            $attachments += $attachment
            Write-Log -Message "Added attachment: $fileName ($([math]::Round($fileBytes.Length / 1KB, 2)) KB)" -Module $functionName -LogLevel "Information" -LogFile $logFile
        }
        else
        {
            Write-Log -Message "Attachment file not found: $attachmentPath" -Module $functionName -LogLevel "Warning" -LogFile $logFile
        }
    }
    
    #prepare email message object - attachments MUST be inside the message object per Microsoft Graph API spec
    $emailMessage = [ordered]@{
        message         = @{
            subject      = $Subject
            body         = @{
                contentType = "Text"
                content     = $Body
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $To
                    }
                }
            )
            attachments  = $attachments
        }
        saveToSentItems = $true                                           
    } | ConvertTo-Json -Depth 5         
    # Send the email
    try 
    {
        Write-Log -Message "Calling Graph API to send email" -Module $functionName -LogLevel "Debug" -LogFile $logFile
        $emailResponse = CallGraphApi -AccessToken $accessToken -Method POST -ResourcePath $emailSendURI -Body $emailMessage
        Write-Log -Message "Email sent successfully to $To with $($attachments.Count) attachment(s)" -Module $functionName -LogLevel "Information" -LogFile $logFile
        if ([string]::IsNullOrEmpty($emailResponse))
        {
            return $true
        }
        else
        {
            Write-Log -Message "Unexpected response from email send: $emailResponse" -Module $functionName -LogLevel "Warning" -LogFile $logFile
            return $false
        }                           
    }
    catch
    {
        $errorDetails = @(
            "Failed to send email: $($_.Exception.Message)"
            "Error Type: $($_.Exception.GetType().FullName)"
            "Sender UPN: $senderUPN"
            "Recipient: $To"
            "Attachment Count: $($attachments.Count)"
        )
        
        if ($_.ErrorDetails.Message)
        {
            $errorDetails += "API Error Details: $($_.ErrorDetails.Message)"
        }
        
        $fullErrorMessage = $errorDetails -join ' | '
        Write-Error $fullErrorMessage
        Write-Log -Message $fullErrorMessage -Module $functionName -LogLevel "Error" -LogFile $logFile
        
        # Try to decode Graph API error if available
        if ($_.ErrorDetails.Message)
        {
            try
            {
                $graphError = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($graphError.error)
                {
                    Write-Log -Message "Graph API Error Code: $($graphError.error.code)" -Module $functionName -LogLevel "Error" -LogFile $logFile
                    Write-Log -Message "Graph API Error Message: $($graphError.error.message)" -Module $functionName -LogLevel "Error" -LogFile $logFile
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Could not parse Graph API error details"
            }
        }
        
        return $false
    }
}

function New-ZipPackage()
{
    <#
.SYNOPSIS
    Creates compressed ZIP archives from multiple files for diagnostic package distribution.

.DESCRIPTION
    This function provides robust ZIP file creation functionality using .NET compression
    libraries. The implementation includes:
    
    Archive Creation:
    - Uses System.IO.Compression.FileSystem for reliable compression
    - Creates directory structure automatically if needed
    - Handles existing file replacement safely
    
    File Processing:
    - Validates source files before inclusion
    - Preserves original filenames in archive
    - Handles file access and permission issues gracefully
    - Provides progress logging for large operations
    
    Error Handling:
    - Comprehensive exception handling for I/O operations
    - Automatic cleanup of partial archives on failure
    - Detailed logging of each file addition process

.PARAMETER FilePaths
    Array of file paths to include in the ZIP archive.
    Non-existent files are skipped with appropriate logging.

.PARAMETER DestinationPath
    Full path where the ZIP archive should be created.
    Parent directories are created automatically if they don't exist.
    Existing files at the destination are replaced.

.EXAMPLE
    $created = New-ZipPackage -FilePaths @("C:\logs\app.log", "C:\temp\cert.cer") -DestinationPath "C:\packages\diagnostic.zip"

.EXAMPLE
    $files = Get-ChildItem "C:\diagnostics\*.log" | Select-Object -ExpandProperty FullName
    New-ZipPackage -FilePaths $files -DestinationPath "$env:TEMP\logs.zip"

.OUTPUTS
    Boolean value indicating ZIP creation success:
    - $true: ZIP archive created successfully with all available files
    - $false: ZIP creation failed due to errors

.NOTES
    The function uses native .NET compression capabilities, requiring no additional
    tools or modules. ZIP files created are compatible with standard archive utilities.
    
    Large files or many files may take significant time to compress.
    The function automatically disposes of file handles to prevent resource leaks.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FilePaths,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -Message "Creating zip package at $DestinationPath with files: $($FilePaths -join ', ')" -Module $functionName -LogLevel "Information" -LogFile $logFile
    Write-Verbose "[$functionName] Creating zip package at $DestinationPath with files: $($FilePaths -join ', ')"                       
    #if the destination file does not have a parent, assume current directory
    if (-not (Split-Path $DestinationPath -Parent))         
    {
        $DestinationPath = Join-Path -Path (Get-Location) -ChildPath $DestinationPath
        Write-Verbose "[$functionName] Adjusted DestinationPath to include current directory: $DestinationPath"                       
        write-log -logFile $logFile -module $functionName -message "Adjusted DestinationPath to include current directory: $DestinationPath" -logLevel "Debug"                        
    }                                                       
    try
    {
        # Ensure destination directory exists
        $destDir = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $destDir))
        {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            write-log -logFile $logFile -module $functionName -message "Created directory for zip destination: $destDir" -logLevel "Information"                        
            Write-Verbose "[$functionName] Created directory for zip destination: $destDir"                             
        }
        
        # Remove existing zip file if it exists
        if (Test-Path $DestinationPath)
        {
            Remove-Item $DestinationPath -Force
            write-log -logFile $logFile -module $functionName -message "Removed existing zip file at destination: $DestinationPath" -logLevel "Information"                                         
            Write-Verbose "[$functionName] Removed existing zip file at destination: $DestinationPath"                  
        }
        
        # Load required assemblies for ZIP operations
        try
        {
            Write-Verbose "[$functionName] Loading ZIP compression assemblies"                  
            write-log -logFile $logFile -module $functionName -message "Loading ZIP compression assemblies" -logLevel "Debug"               
            Add-Type -AssemblyName System.IO.Compression
            Add-Type -AssemblyName System.IO.Compression.FileSystem
        }
        catch
        {
            Write-Log -Message "Failed to load ZIP compression assemblies: $($_.Exception.Message)" -Module $functionName -LogLevel "Error" -LogFile $logFile
            throw "Failed to load required assemblies for ZIP operations: $($_.Exception.Message)"
        }
        
        $zip = [System.IO.Compression.ZipFile]::Open($DestinationPath, [System.IO.Compression.ZipArchiveMode]::Create)
        write-log -logFile $logFile -module $functionName -message "Opened zip archive for creation: $DestinationPath" -logLevel "Information"                              
        Write-Verbose "[$functionName] Opened zip archive for creation: $DestinationPath"                       
        foreach ($filePath in $FilePaths)
        {
            Write-Verbose "[$functionName] Adding file to zip: $filePath"       
            if (Test-Path $filePath)
            {
                # Copy the file to a temporary file in the system temp folder.
                # This workaround is necessary because the original file may be locked or in use by another process,
                # which can cause issues when attempting to add it directly to the zip archive.
                # Copying to a temporary location ensures reliable access for zipping.
                $tempFilePath = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetFileName($filePath))
                Write-Verbose "[$functionName] Copying file $filePath to temporary location: $tempFilePath"                           
                Copy-Item -Path $filePath -Destination $tempFilePath -Force
                $fileName = [System.IO.Path]::GetFileName($tempFilePath)
                Write-Verbose "[$functionName] Adding temporary file to zip: $tempFilePath as $fileName"            
                $entry = $zip.CreateEntry($fileName)
                $entryStream = $null
                $fileStream = $null
                try
                {
                    $entryStream = $entry.Open()
                    $fileStream = [System.IO.File]::OpenRead($tempFilePath)
                    $fileStream.CopyTo($entryStream)
                    Write-Verbose "[$functionName] Added file to zip: $filePath"                                            
                    write-log -logFile $logFile -module $functionName -message "Added file to zip: $fileName" -logLevel "Information"                                       
                }
                finally
                {
                    if ($fileStream)
                    {
                        $fileStream.Close() 
                        Write-Verbose "[$functionName] Closed file stream for: $filePath"                   
                        write-log -logFile $logFile -module $functionName -message "Closed file stream for: $fileName" -logLevel "Information"                                                                                                  
                    }
                    if ($entryStream)
                    {
                        $entryStream.Close() 
                    }
                    if (Test-Path $tempFilePath)
                    {
                        Remove-Item -Path $tempFilePath -Force
                        Write-Verbose "[$functionName] Removed temporary file: $tempFilePath"                   
                        write-log -logFile $logFile -module $functionName -message "Removed temporary file: $tempFilePath" -logLevel "Information"                                                                                                  
                    }                                               
                }
                Write-Log -Message "Added file to zip: $fileName" -Module $functionName -LogLevel "Information" -LogFile $logFile
                Write-Verbose "[$functionName] Added file to zip: $filePath"                                                                            
            }
            else
            {
                Write-Log -Message "File not found, skipping: $filePath" -Module $functionName -LogLevel "Warning" -LogFile $logFile
                Write-Verbose "[$functionName] File not found, skipping: $filePath"                                 
            }
        }
        $zip.Dispose()
        Write-Log -Message "Zip package created successfully: $DestinationPath" -Module $functionName -LogLevel "Information" -LogFile $logFile
        Write-Verbose "[$functionName] Zip package created successfully: $DestinationPath"                  
        return $DestinationPath
    }
    catch
    {
        Write-Log -Message "Failed to create zip package: $($_.Exception.Message)" -Module $functionName -LogLevel "Error" -LogFile $logFile
        Write-Verbose "[$functionName] Failed to create zip package: $($_.Exception.Message)"                                           
        if ($zip)
        {
            $zip.Dispose()
            Write-Verbose "[$functionName] Disposed zip archive due to error"
            write-log -logFile $logFile -module $functionName -message "Disposed zip archive due to error" -logLevel "Information"                                                                                                                                                          
        }
        return $null
    }
}
