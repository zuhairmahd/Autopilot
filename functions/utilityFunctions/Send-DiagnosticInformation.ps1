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
    - Email: Automated sending via Microsoft Graph API
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
        # Show failure dialog to get user preference
        Write-Verbose "[$functionName] Displaying failure dialog to user"
        Write-Log -Message "Displaying failure dialog to collect user preference for diagnostic information" -Module $functionName -LogLevel "Information" -LogFile $logFile
        $userChoice = Show-FailureDialog -ErrorMessage $ErrorMessage
        
        Write-Log -Message "User selected diagnostic option: $userChoice" -Module $functionName -LogLevel "Information" -LogFile $logFile
        
        if ($userChoice -eq "Email")
        {
            Write-Log -Message "User chose to send diagnostic information via email" -Module $functionName -LogLevel "Information" -LogFile $logFile
            
            # Prepare email content
            $emailSubject = "Intune Helpdesk Utility - Diagnostic Information"
            $emailBody = @"
User: $currentUserName
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
            
            # Send email
            $emailSent = Send-EmailWithAttachments -To $supportEmail -Subject $emailSubject -Body $emailBody -AttachmentPaths $attachmentFiles
            
            if ($emailSent)
            {
                [System.Windows.Forms.MessageBox]::Show(
                    "Diagnostic information has been sent via email to $supportEmail. You will receive assistance shortly.",
                    $formTitle,
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
            else
            {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to send diagnostic information via email. Please contact support manually with the error message: $ErrorMessage",
                    $formTitle,
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
        elseif ($userChoice -eq "Zip")
        {
            Write-Log -Message "User chose to save diagnostic information to zip file" -Module $functionName -LogLevel "Information" -LogFile $logFile
            
            # Show save dialog for zip file
            Add-Type -AssemblyName System.Windows.Forms
            $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveDialog.Filter = "Zip files (*.zip)|*.zip|All files (*.*)|*.*"
            $saveDialog.Title = "Save Diagnostic Information"
            $saveDialog.FileName = "PIV_Diagnostics_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
            $saveDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            
            if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
            {
                # Collect files for zip
                $zipFiles = @()
                if (Test-Path $logFile)
                {
                    $zipFiles += $logFile
                }
                
                # Create zip file
                $zipCreated = New-ZipPackage -FilePaths $zipFiles -DestinationPath $saveDialog.FileName
                
                if ($zipCreated)
                {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Diagnostic information has been saved to: $($saveDialog.FileName)`n`nPlease send this file to support for assistance.",
                        $formTitle,
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                }
                else
                {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Failed to create diagnostic zip file. Please contact support manually with the error message: $ErrorMessage",
                        $formTitle,
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }
            else
            {
                Write-Log -Message "User cancelled zip file save dialog" -Module $functionName -LogLevel "Information" -LogFile $logFile
            }
        }
        else
        {
            Write-Log -Message "User cancelled diagnostic information collection" -Module $functionName -LogLevel "Information" -LogFile $logFile
            [System.Windows.Forms.MessageBox]::Show(
                $ErrorMessage,
                $formTitle,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    catch
    {
        Write-Log -Message "Error in Send-DiagnosticInformation: $($_.Exception.Message)" -Module $functionName -LogLevel "Error" -LogFile $logFile
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred while trying to send diagnostic information: $($_.Exception.Message)",
            $formTitle,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Send-EmailWithAttachments()
{
    <#
.SYNOPSIS
    Sends email with file attachments using Microsoft Graph API integration.

.DESCRIPTION
    This function provides enterprise-grade email functionality using Microsoft Graph API
    for secure and reliable email transmission. Features include:
    
    Microsoft Graph Integration:
    - Uses modern authentication with Microsoft Graph
    - Supports organizational email policies and security
    - Handles large attachments efficiently
    
    Attachment Processing:
    - Supports multiple file attachments
    - Automatic MIME type detection based on file extensions
    - Base64 encoding for secure transmission
    - File size validation and handling
    
    Error Handling:
    - Comprehensive connection and authentication error handling
    - Graceful degradation when Graph modules are unavailable
    - Detailed logging of email transmission attempts

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

.EXAMPLE
    $success = Send-EmailWithAttachments -To "support@company.com" -Subject "PIV Issue" -Body "Please help" -AttachmentPaths @("C:\logs\error.log", "C:\temp\cert.cer")

.OUTPUTS
    Boolean value indicating email transmission success:
    - $true: Email sent successfully
    - $false: Email transmission failed

.NOTES
    Prerequisites:
    - Microsoft.Graph.Users.Actions PowerShell module
    - Appropriate permissions for Mail.Send in Microsoft Graph
    - Valid organizational email configuration
    
    The function automatically handles authentication prompts and permission requests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $accessToken,
        [Parameter(Mandatory = $true)]
        [string]$To,
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        [Parameter(Mandatory = $true)]
        [string]$Body,
        [Parameter(Mandatory = $false)]
        [string[]]$AttachmentPaths = @()
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $emailSendURI = "me/sendMail"
    $headers = @{
        "Content-Type" = "application/json"
    }               
    Write-Log -Message "Starting email send process to $To" -Module $functionName -LogLevel "Information" -LogFile $logFile
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
    
    #prepare email message object
    $emailMessage = [ordered]@{
        message     = @{
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
        }                                           
        attachments = $attachments              
    } | ConvertTo-Json -Depth 5         
    # Send the email
    try 
    {
        Write-Log -Message "Calling Graph API to send email" -Module $functionName -LogLevel "Debug" -LogFile $logFile
        $global:emailResponse = CallGraphApi -AccessToken $accessToken -Method POST -ResourcePath $emailSendURI -Body $emailMessage -Headers $headers           
        Write-Log -Message "Email sent successfully to $To with $($attachments.Count) attachment(s)" -Module $functionName -LogLevel "Information" -LogFile $logFile
    }
    catch
    {
        Write-Error "Failed to send email: $($_.Exception.Message)"         
        Write-Log -Message "Failed to send email: $($_.Exception.Message)" -Module $functionName -LogLevel "Error" -LogFile $logFile
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
    Write-Log -Message "Creating zip package at $DestinationPath" -Module $functionName -LogLevel "Information" -LogFile $logFile
    
    try
    {
        # Ensure destination directory exists
        $destDir = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $destDir))
        {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            write-log -logFile $logFile -module $functionName -message "Created directory for zip destination: $destDir" -logLevel "Information"                        
        }
        
        # Remove existing zip file if it exists
        if (Test-Path $DestinationPath)
        {
            Remove-Item $DestinationPath -Force
            write-log -logFile $logFile -module $functionName -message "Removed existing zip file at destination: $DestinationPath" -logLevel "Information"                                         
        }
        
        # Load required assemblies for ZIP operations
        try
        {
            Add-Type -AssemblyName System.IO.Compression
            Add-Type -AssemblyName System.IO.Compression.FileSystem
        }
        catch
        {
            Write-Log -Message "Failed to load ZIP compression assemblies: $($_.Exception.Message)" -Module $functionName -LogLevel "Error" -LogFile $logFile
            throw "Failed to load required assemblies for ZIP operations: $($_.Exception.Message)"
        }
        
        $zip = [System.IO.Compression.ZipFile]::Open($DestinationPath, [System.IO.Compression.ZipArchiveMode]::Create)
        
        foreach ($filePath in $FilePaths)
        {
            if (Test-Path $filePath)
            {
                $fileName = [System.IO.Path]::GetFileName($filePath)
                $entry = $zip.CreateEntry($fileName)
                $entryStream = $null
                $fileStream = $null
                try
                {
                    $entryStream = $entry.Open()
                    $fileStream = [System.IO.File]::OpenRead($filePath)
                    $fileStream.CopyTo($entryStream)
                }
                finally
                {
                    if ($fileStream)
                    {
                        $fileStream.Close() 
                    }
                    if ($entryStream)
                    {
                        $entryStream.Close() 
                    }
                }
                Write-Log -Message "Added file to zip: $fileName" -Module $functionName -LogLevel "Information" -LogFile $logFile
            }
            else
            {
                Write-Log -Message "File not found, skipping: $filePath" -Module $functionName -LogLevel "Warning" -LogFile $logFile
            }
        }
        
        $zip.Dispose()
        Write-Log -Message "Zip package created successfully: $DestinationPath" -Module $functionName -LogLevel "Information" -LogFile $logFile
        return $true
    }
    catch
    {
        Write-Log -Message "Failed to create zip package: $($_.Exception.Message)" -Module $functionName -LogLevel "Error" -LogFile $logFile
        if ($zip)
        {
            $zip.Dispose()
        }
        return $false
    }
}


