function Invoke-JsonFileEncryption
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        [Parameter(Mandatory = $false)]
        [switch]$Decrypt,
        [Parameter(Mandatory = $false)]
        [switch]$BackupOriginal
    )

    Write-Verbose "=========================================="
    Write-Verbose "Starting JSON file encryption/decryption operation"
    Write-Verbose "=========================================="
    Write-Verbose "File path: $FilePath"
    Write-Verbose "Operation mode: $(if ($Decrypt) { 'DECRYPT' } else { 'ENCRYPT' })"
    Write-Verbose "Backup original: $BackupOriginal"
    Write-Verbose "PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Verbose "Current user: $env:USERNAME"
    Write-Verbose "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # Initialize variables for error handling and cleanup
    $operationStartTime = $null
    $aes = $null
    $sha256 = $null
    $encryptor = $null
    $decryptor = $null
    
    try
    {
        # Validate file exists and is accessible
        Write-Verbose "Validating file existence and accessibility..."
        if (-not (Test-Path $FilePath))
        {
            Write-Host "CRITICAL ERROR: File not found at path '$FilePath'. `n Please verify that The file path is correct `n  - The file exists, `n and that You have read permissions to the file. `n `n"
            Write-Verbose "File validation failed: File does not exist"
        }
    
        # Check file accessibility
        try
        {
            $fileInfo = Get-Item $FilePath -ErrorAction Stop
            Write-Verbose "File found successfully:"
            Write-Verbose "Full name: $($fileInfo.FullName)"
            Write-Verbose "Size: $($fileInfo.Length) bytes"
            Write-Verbose "Last modified: $($fileInfo.LastWriteTime)"
            Write-Verbose "Is read-only: $($fileInfo.IsReadOnly)"
        }
        catch
        {
            $errorMsg = "CRITICAL ERROR: Cannot access file '$FilePath'."
            $errorMsg += "`nError details: $($_.Exception.Message)"
            $errorMsg += "`nPlease verify you have the necessary permissions to access this file."
            Write-Host $errorMsg
            Write-Verbose "File accessibility check failed: $($_.Exception.Message)"
            return $false
        }        

        # Get absolute path
        $FilePath = Resolve-Path $FilePath
        Write-Verbose "File path resolved to: $FilePath"
        Write-Verbose "File validation completed successfully"
        $operationStartTime = Get-Date
        Write-Verbose "=========================================="
        Write-Verbose "Starting main processing at $($operationStartTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "=========================================="
    
        # Create backup if requested
        if ($BackupOriginal)
        {
            Write-Verbose "Backup requested... creating backup copy..."
            $backupPath = "$FilePath.bak"
            Write-Verbose "Backup destination: $backupPath"
            try
            {
                Copy-Item $FilePath $backupPath -Force -ErrorAction Stop
                $backupInfo = Get-Item $backupPath
                Write-Verbose "Backup created successfully:"
                Write-Verbose "  - Backup path: $($backupInfo.FullName)"
                Write-Verbose "  - Backup size: $($backupInfo.Length) bytes"
                Write-Verbose "  - Backup timestamp: $($backupInfo.CreationTime)"
            }
            catch
            {
                Write-Verbose "Backup creation failed: $($_.Exception.Message)"
            }
        }
        else
        {
            Write-Verbose "No backup requested - proceeding without backup. The original file will be overwritten if the operation succeeds."
            Write-Verbose "Consider using -BackupOriginal for safer operations, especially on sensitive or production files."
        }
    
        # Read file content
        Write-Verbose "Reading source file content..."
        try
        {
            $fileContent = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "File content read successfully:"
            Write-Verbose "Content length: $($fileContent.Length) characters"
            Write-Verbose "First 100 characters: $($fileContent.Substring(0, [Math]::Min(100, $fileContent.Length)))"
        }
        catch
        {
            Write-Verbose "File read failed: $($_.Exception.Message)"
            $errorMsg = "CRITICAL ERROR: Failed to read file '$FilePath'."
            Write-Host $errorMsg
            return $false
        }
        if ([string]::IsNullOrEmpty($fileContent))
        {
            $warningMsg = "WARNING: File appears to be empty: $FilePath"
            Write-Verbose $warningMsg
            Write-Warning $warningMsg
            Write-Warning "No operation will be performed on empty file."
            return $false
        }
    
        # Initialize cryptographic components
        Write-Verbose "Initializing cryptographic components..."
        Write-Verbose "Setting up AES encryption with the following parameters:"
        Write-Verbose "Algorithm: AES (Advanced Encryption Standard)"
        Write-Verbose "Key size: 256 bits"
        Write-Verbose "Mode: CBC (Cipher Block Chaining)"
        Write-Verbose "Padding: PKCS7"
        $aes = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        Write-Verbose "AES provider initialized successfully"
    
        # Create 256-bit key from the provided string using SHA256
        Write-Verbose "Generating 256-bit encryption key from user-provided string..."
        Write-Verbose "Input key length: $($Key.Length) characters"
        Write-Verbose "Using SHA256 hash algorithm for key derivation"
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $keyBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Key))
        $aes.Key = $keyBytes
        Write-Verbose "Encryption key generated successfully:"
        $first8 = $keyBytes[0..7] | ForEach-Object { '{0:X2}' -f $_ }
        Write-Verbose ("Key hash (first 8 bytes): {0}" -f ($first8 -join ''))
        Write-Verbose "Key length: $($keyBytes.Length) bytes"
    
        if ($Decrypt)
        {
            Write-Verbose "=========================================="
            Write-Verbose "STARTING DECRYPTION PROCESS"
            Write-Verbose "=========================================="
            # Pre-decryption validation
            Write-Verbose "Performing pre-decryption validation checks..."
        
            # Check if content looks like encrypted data (base64)
            Write-Verbose "Validating encrypted data format..."
            try
            {
                $encryptedData = [Convert]::FromBase64String($fileContent)
                Write-Verbose "File content is valid base64 format"
                Write-Verbose "Base64 string length: $($fileContent.Length) characters"
                Write-Verbose "Decoded data length: $($encryptedData.Length) bytes"
            }
            catch
            {
                Write-Verbose "Base64 validation failed: $($_.Exception.Message)"
                Write-Host "DECRYPTION ERROR: The file content is not valid base64 encoded data."
                return $false
            }
            # Validate encrypted data structure
            Write-Verbose "Validating encrypted data structure..."
            if ($encryptedData.Length -lt 16)
            {
                $errorMsg = "DECRYPTION ERROR: Encrypted data is corrupted or invalid."
                $errorMsg += "`n`nData structure analysis:"
                $errorMsg += "`n Minimum expected size: 16 bytes (IV) + encrypted content"
                $errorMsg += "`n Actual size: $($encryptedData.Length) bytes"
                $errorMsg += "`n`nThis indicates the encrypted file is corrupted or was not properly encrypted."
                Write-Verbose "Encrypted data structure validation failed: Data too short"
                Write-Host $errorMsg
                return $false
            }
            # Extract IV and encrypted content
            Write-Verbose "Extracting initialization vector (IV) and encrypted content..."
            $iv = $encryptedData[0..15]
            $encryptedContent = $encryptedData[16..($encryptedData.Length - 1)]
            $aes.IV = $iv
            Write-Verbose "Data structure analysis:"
            $first16 = $iv | ForEach-Object { '{0:X2}' -f $_ }
            Write-Verbose "  - IV (first 16 bytes): $($first16 -join '')"
            Write-Verbose "  - IV length: $($iv.Length) bytes"
            Write-Verbose "  - Encrypted content length: $($encryptedContent.Length) bytes"
            Write-Verbose "Total encrypted data: $($encryptedData.Length) bytes"
            Write-Verbose "Beginning AES decryption process..."
        
            # Attempt decryption
            try
            {
                $decryptor = $aes.CreateDecryptor()
                Write-Verbose "AES decryptor created successfully"
                Write-Verbose "Decrypting content block..."
                $decryptedBytes = $decryptor.TransformFinalBlock($encryptedContent, 0, $encryptedContent.Length)
                Write-Verbose "Decryption completed without cryptographic errors"
                Write-Verbose "Decrypted data length: $($decryptedBytes.Length) bytes"
                $decryptedText = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                Write-Verbose "Decrypted bytes converted to UTF-8 string successfully"
                Write-Verbose "Decrypted text length: $($decryptedText.Length) characters"
            }
            catch [System.Security.Cryptography.CryptographicException]
            {
                Write-Host "`n`nThe decryption key you provided does not match the key used to encrypt this file."
                Write-Verbose "Decryption failed with CryptographicException (likely wrong key): $($_.Exception.Message)"
                return $false
            }
            catch
            {
                Write-Host "DECRYPTION ERROR: Unexpected error during decryption process."
                Write-Verbose "`n`nError type: $($_.Exception.GetType().Name)"
                Write-Verbose "`nError details: $($_.Exception.Message)"
                Write-Host "`n`nThis may indicate:"
                Write-Host "`n File corruption"
                Write-Host "`n Incompatible encryption method"
                Write-Host "`n  - System cryptography issue"
                Write-Verbose "Decryption failed with unexpected error: $($_.Exception.Message)"
                return $false
            }
        
            # Validate decrypted content is valid JSON
            Write-Verbose "Validating decrypted content format..."
            try
            {
                $null = ConvertFrom-Json $decryptedText -ErrorAction Stop
                Write-Verbose "Decrypted content is valid JSON"
                Write-Verbose "JSON validation successful"
                Write-Verbose "Content preview: $($decryptedText.Substring(0, [Math]::Min(200, $decryptedText.Length)))"
            }
            catch
            {
                Write-Host "DECRYPTION ERROR: Decrypted content is not valid JSON."
                Write-Host "⚠️  POSSIBLE INCORRECT DECRYPTION KEY"
                Write-Host "`nThe decryption process completed, but the result is not valid JSON."
                Write-Host "`nThis strongly suggests the wrong decryption key was used."
                if ($null -ne $decryptedText)
                {
                    Write-Verbose "Decrypted content preview:"
                    Write-Verbose "`n$($decryptedText.Substring(0, [Math]::Min(300, $decryptedText.Length)))"
                    if ($decryptedText.Length -gt 300)
                    {
                        Write-Verbose "`n... (truncated)" 
                    }
                }
                Write-Verbose "Expected: Valid JSON data"
                Write-Verbose "Actual: Garbled or corrupted text"
                Write-Verbose "JSON validation failed after decryption: $($_.Exception.Message)"
                return $false
            }
        
            # Write decrypted content back to file
            Write-Verbose "Writing decrypted content back to original file..."
            try
            {
                Set-Content $FilePath -Value $decryptedText -Encoding UTF8 -NoNewline -ErrorAction Stop
                Write-Verbose "Decrypted content written successfully"
                # Verify the write operation
                $verifyContent = Get-Content $FilePath -Raw -Encoding UTF8
                if ($verifyContent -eq $decryptedText)
                {
                    Write-Verbose "File write verification successful"
                }
                else
                {
                    Write-Warning "File write verification failed - content may not have been written correctly"
                }
            }
            catch
            {
                $errorMsg = "CRITICAL ERROR: Failed to write decrypted content to file."
                $errorMsg += "`nFile path: $FilePath"
                $errorMsg += "`nError details: $($_.Exception.Message)"
                $errorMsg += "`n`nThe decryption was successful, but the file could not be updated."
                Write-Host $errorMsg
                Write-Verbose "File write failed: $($_.Exception.Message)"
                return $false
            }
            $operationEndTime = Get-Date
            $operationDuration = $operationEndTime - $operationStartTime
            Write-Verbose "=========================================="
            Write-Verbose "DECRYPTION COMPLETED SUCCESSFULLY"
            Write-Verbose "=========================================="
            Write-Verbose "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
            Write-Verbose "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
            Write-Host "File '$FilePath' has been decrypted successfully." -ForegroundColor Green
            Write-Host "  Decryption completed in $([Math]::Round($operationDuration.TotalMilliseconds, 2)) ms" -ForegroundColor Green
        }
        else
        {
            Write-Verbose "=========================================="
            Write-Verbose "STARTING ENCRYPTION PROCESS"
            Write-Verbose "=========================================="
            # Pre-encryption validation
            Write-Verbose "Performing pre-encryption validation checks..."
            # Validate that content is valid JSON before encrypting
            Write-Verbose "Validating JSON format of source content..."
            try
            {
                $jsonObject = ConvertFrom-Json $fileContent -ErrorAction Stop
                Write-Verbose "Source content is valid JSON"
                Write-Verbose "JSON validation successful"
                Write-Verbose "JSON object type: $($jsonObject.GetType().Name)"
                if ($jsonObject -is [PSCustomObject])
                {
                    $propertyCount = ($jsonObject | Get-Member -MemberType NoteProperty).Count
                    Write-Verbose "  - JSON properties count: $propertyCount"
                }
            }
            catch
            {
                $errorMsg = "ENCRYPTION ERROR: Source file does not contain valid JSON data."
                $errorMsg += "`n`nJSON validation failed:"
                $errorMsg += "`n  Error: $($_.Exception.Message)"
                $errorMsg += "`n  Line: $($_.Exception.ItemName)"
                $errorMsg += "`n`nFile content preview:"
                $errorMsg += "`n$($fileContent.Substring(0, [Math]::Min(300, $fileContent.Length)))"
                if ($fileContent.Length -gt 300)
                {
                    $errorMsg += "`n... (truncated)" 
                }
                $errorMsg += "`n`nPlease ensure the file contains valid JSON before encryption."
                Write-Verbose "JSON validation failed: $($_.Exception.Message)"
                Write-Host $errorMsg 
                return $false   
            }
            # Generate random IV for this encryption
            Write-Verbose "Generating cryptographically secure random initialization vector (IV)..."
            $aes.GenerateIV()
            Write-Verbose "Random IV generated successfully"
            Write-Verbose "IV length: $($aes.IV.Length) bytes"
            $ivValue = $aes.IV | ForEach-Object { '{0:X2}' -f $_ }   
            Write-Verbose "IV value: $($ivValue -join '')"
            Write-Verbose "IV provides unique encryption for this session"
            Write-Verbose "Beginning AES encryption process..."
        
            # Encrypt the content
            try
            {
                $encryptor = $aes.CreateEncryptor()
                Write-Verbose "AES encryptor created successfully"
                $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
                Write-Verbose "Source content converted to bytes:"
                Write-Verbose "Original text length: $($fileContent.Length) characters"
                Write-Verbose "UTF-8 bytes length: $($contentBytes.Length) bytes"
                Write-Verbose "Encrypting content block..."
                $encryptedBytes = $encryptor.TransformFinalBlock($contentBytes, 0, $contentBytes.Length)
                Write-Host "Encryption completed successfully"
                Write-Verbose "Encrypted data length: $($encryptedBytes.Length) bytes"
            }
            catch
            {
                $errorMsg = "ENCRYPTION ERROR: Failed during AES encryption process."
                $errorMsg += "`nError details: $($_.Exception.Message)"
                $errorMsg += "`nError type: $($_.Exception.GetType().Name)"
                Write-Verbose "Encryption process failed: $($_.Exception.Message)"
                Write-Host $errorMsg
                return $false
            }
            # Combine IV and encrypted content for storage
            Write-Verbose "Preparing encrypted data for storage..."
            $combinedBytes = $aes.IV + $encryptedBytes
            Write-Verbose "Data structure for storage:"
            Write-Verbose "IV length: $($aes.IV.Length) bytes"
            Write-Verbose "Encrypted content length: $($encryptedBytes.Length) bytes"
            Write-Verbose "Total combined length: $($combinedBytes.Length) bytes"
        
            # Convert to base64 for safe text storage
            Write-Verbose "Converting encrypted data to base64 format..."
            $base64String = [Convert]::ToBase64String($combinedBytes)
            Write-Verbose "Base64 conversion completed"
            Write-Verbose "Base64 string length: $($base64String.Length) characters"
            Write-Verbose "Compression ratio: $([Math]::Round(($base64String.Length / $fileContent.Length) * 100, 2))% of original size"
        
            # Write encrypted content back to file
            Write-Verbose "Writing encrypted content to original file..."
            try
            {
                Set-Content $FilePath -Value $base64String -Encoding UTF8 -NoNewline -ErrorAction Stop
                Write-Verbose "Encrypted content written successfully"
                # Verify the write operation
                $verifyContent = Get-Content $FilePath -Raw -Encoding UTF8
                if ($verifyContent -eq $base64String)
                {
                    Write-Verbose "File write verification successful"
                }
                else
                {
                    Write-Warning "File write verification failed - content may not have been written correctly"
                }
            }
            catch
            {
                $errorMsg = "CRITICAL ERROR: Failed to write encrypted content to file."
                $errorMsg += "`nFile path: $FilePath"
                $errorMsg += "`nError details: $($_.Exception.Message)"
                $errorMsg += "`n`nThe encryption was successful, but the file could not be updated."
                Write-Verbose "File write failed: $($_.Exception.Message)"
                Write-Host $errorMsg
            }
        
            $operationEndTime = Get-Date
            $operationDuration = $operationEndTime - $operationStartTime
            Write-Verbose "=========================================="
            Write-Verbose "ENCRYPTION COMPLETED SUCCESSFULLY"
            Write-Verbose "=========================================="
            Write-Verbose "Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
            Write-Verbose "Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
            Write-Host "File '$FilePath' has been encrypted successfully." -ForegroundColor Green
            Write-Host "Encryption completed in $([Math]::Round($operationDuration.TotalMilliseconds, 2)) ms" -ForegroundColor Green
            Write-Host "File is now secured with AES-256 encryption"
        }
    
        return $true
    }
    catch
    {
        $operationEndTime = Get-Date
        $operationDuration = if ($operationStartTime)
        {
            $operationEndTime - $operationStartTime 
        }
        else
        {
            [TimeSpan]::Zero 
        }
        Write-Verbose "=========================================="
        Write-Verbose "OPERATION FAILED"
        Write-Verbose "=========================================="
        Write-Verbose "Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Verbose "Error type: $($_.Exception.GetType().Name)"
        Write-Verbose "Error message: $($_.Exception.Message)"
        if ($_.Exception.InnerException)
        {
            Write-Verbose "Inner exception: $($_.Exception.InnerException.Message)"
        }
        # Log the full call stack for debugging
        Write-Verbose "Call stack:"
        $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Verbose "  $_" }
        Write-Error "Operation failed: $($_.Exception.Message)"
                
        # If backup exists and operation failed, provide restoration guidance
        if ($BackupOriginal -and (Test-Path "$FilePath.bak"))
        {
            Write-Warning "BACKUP AVAILABLE: A backup file exists at '$FilePath.bak'"
            Write-Warning "   You can restore the original file if needed using:"
            Write-Warning "   Copy-Item '$FilePath.bak' '$FilePath' -Force"
        }
        return $false
    }
    finally
    {
        # Clean up cryptographic objects
        Write-Verbose "Performing cleanup of cryptographic resources..."
                
        if ($null -ne $aes)
        {
            try
            {
                $aes.Dispose()
                Write-Verbose "✓ AES encryption object disposed successfully"
            }
            catch
            {
                Write-Verbose "⚠️  Warning: Error disposing AES object: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $sha256)
        {
            try
            {
                $sha256.Dispose()
                Write-Verbose "✓ SHA256 hash object disposed successfully"
            }
            catch
            {
                Write-Verbose "⚠️  Warning: Error disposing SHA256 object: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $encryptor)
        {
            try
            {
                $encryptor.Dispose()
                Write-Verbose "✓ Encryptor object disposed successfully"
            }
            catch
            {
                Write-Verbose "⚠️  Warning: Error disposing encryptor: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $decryptor)
        {
            try
            {
                $decryptor.Dispose()
                Write-Verbose "✓ Decryptor object disposed successfully"
            }
            catch
            {
                Write-Verbose "⚠️  Warning: Error disposing decryptor: $($_.Exception.Message)"
            }
        }
                
        # Force garbage collection to clear sensitive data from memory
        Write-Verbose "Forcing garbage collection to clear sensitive data..."
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Write-Verbose "Garbage collection completed"
        Write-Verbose "Resource cleanup completed"
        Write-Verbose "=========================================="
        Write-Verbose "FUNCTION EXECUTION COMPLETED"
        Write-Verbose "=========================================="
        Write-Verbose "Function: Invoke-JsonFileEncryption"
        Write-Verbose "Completion timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')"
        Write-Verbose "All resources cleaned up successfully"
        Write-Verbose "Function execution finished"
    }
}
