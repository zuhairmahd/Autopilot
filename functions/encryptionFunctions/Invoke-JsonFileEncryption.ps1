function Invoke-JsonFileEncryption()
{
    <#
    .SYNOPSIS
    Encrypts or decrypts JSON configuration files using AES encryption.

    .DESCRIPTION
    This function provides secure encryption and decryption of JSON configuration files using
    AES-256 encryption. It supports in-memory operations, automatic backup creation, and
    comprehensive error handling. The function validates file accessibility, manages encryption
    keys securely, and provides detailed logging throughout the operation.

    .PARAMETER FilePath
    The path to the JSON file to encrypt or decrypt. Must be a valid file path. This parameter is mandatory.

    .PARAMETER Key
    The encryption/decryption key. Must be a non-empty string. This parameter is mandatory.

    .PARAMETER Decrypt
    When specified, decrypts the file instead of encrypting it.

    .PARAMETER BackupOriginal
    When specified, creates a backup of the original file before performing the operation.

    .PARAMETER InMemoryOnly
    When specified, performs the operation in memory only without modifying the file on disk.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with properties:
    - Success: Boolean indicating operation success
    - Content: The encrypted/decrypted content (if InMemoryOnly or error)
    - Operation: 'ENCRYPT' or 'DECRYPT'
    - InMemoryOnly: Boolean indicating if operation was in-memory only
    - ErrorMessage: Error details if operation failed

    .EXAMPLE
    Invoke-JsonFileEncryption -FilePath "config.json" -Key $encryptionKey
    Invoke-JsonFileEncryption -FilePath "config.json" -Key $encryptionKey -Decrypt -BackupOriginal

    .NOTES
    Uses AES-256 encryption with SHA-256 key derivation.
    Creates temporary files during operation and cleans them up automatically.
    Securely clears encryption keys from memory after use.
    Comprehensive logging and error handling throughout.
    Compatible with PowerShell 5.1.
    #>
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
        [switch]$BackupOriginal,
        [Parameter(Mandatory = $false)]
        [switch]$InMemoryOnly
    )

    $functionName = $MyInvocation.MyCommand.Name
    $operationMode = if ($Decrypt) { 'DECRYPT' } else { 'ENCRYPT' }
    
Write-Log -LogFile $LogFile -Module $functionName -Message "Starting JSON file encryption/decryption operation" -LogLevel "Verbose"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: $operationMode" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "File path: $FilePath" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Backup original: $BackupOriginal" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module $functionName -Message "In-memory only: $InMemoryOnly" -LogLevel "Debug"
    
    Write-Verbose "[$functionName] =========================================="
    Write-Verbose "[$functionName] Starting JSON file encryption/decryption operation"
    Write-Verbose "[$functionName] =========================================="
    Write-Verbose "[$functionName] File path: $FilePath"
    Write-Verbose "[$functionName] Operation mode: $operationMode"
    Write-Verbose "[$functionName] Backup original: $BackupOriginal"
    Write-Verbose "[$functionName] In-memory only: $InMemoryOnly"
    Write-Verbose "[$functionName] PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Verbose "[$functionName] Current user: $env:USERNAME"
    Write-Verbose "[$functionName] Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # Initialize variables for error handling and cleanup
    $operationStartTime = $null
    $aes = $null
    $sha256 = $null
    $encryptor = $null
    $decryptor = $null
    
    try
    {
        # Validate file exists and is accessible
Write-Log -LogFile $LogFile -Module $functionName -Message "Validating file existence and accessibility" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Validating file existence and accessibility..."
        if (-not (Test-Path $FilePath))
        {
            Write-Host "CRITICAL ERROR: File not found at path '$FilePath'. `n Please verify that The file path is correct `n - The file exists, `n and that You have read permissions to the file. `n `n"
            Write-Verbose "[$functionName] File validation failed: File does not exist"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File validation failed: File does not exist at path '$FilePath'" -LogLevel "Error"
        }
    
        # Check file accessibility
        try
        {
            $fileInfo = Get-Item $FilePath -ErrorAction Stop
            Write-Verbose "[$functionName] File found successfully:"
            Write-Verbose "[$functionName] Full name: $($fileInfo.FullName)"
            Write-Verbose "[$functionName] Size: $($fileInfo.Length) bytes"
            Write-Verbose "[$functionName] Last modified: $($fileInfo.LastWriteTime)"
            Write-Verbose "[$functionName] Is read-only: $($fileInfo.IsReadOnly)"
Write-Log -LogFile $LogFile -Module $functionName -Message "File found successfully. Size: $($fileInfo.Length) bytes" -LogLevel "Verbose"
        }
        catch
        {
            $errorMsg = "CRITICAL ERROR: Cannot access file '$FilePath'."
            $errorMsg += "`nError details: $($_.Exception.Message)"
            $errorMsg += "`nPlease verify you have the necessary permissions to access this file."
            Write-Host $errorMsg
            Write-Log -LogFile $LogFile -Module $functionName -Message "File accessibility check failed: $($_.Exception.Message)" -LogLevel "Error"
            return @{
                Success      = $false
                Content      = $null
                Operation    = $operationMode
                InMemoryOnly = $InMemoryOnly
                ErrorMessage = $errorMsg
            }
        }        

        # Get absolute path
        $FilePath = Resolve-Path $FilePath
        Write-Verbose "[$functionName] File path resolved to: $FilePath"
Write-Log -LogFile $LogFile -Module $functionName -Message "File validation completed successfully" -LogLevel "Information"
        $operationStartTime = Get-Date
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Starting main processing at $($operationStartTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] =========================================="
Write-Log -LogFile $LogFile -Module $functionName -Message "Starting main processing" -LogLevel "Verbose"
    
        # Create backup if requested
        if ($BackupOriginal)
        {
            Write-Verbose "[$functionName] Backup requested... creating backup copy..."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Creating backup copy" -LogLevel "Information"
            $backupPath = "$FilePath.bak"
            Write-Verbose "[$functionName] Backup destination: $backupPath"
            try
            {
                Copy-Item $FilePath $backupPath -Force -ErrorAction Stop
                $backupInfo = Get-Item $backupPath
                Write-Verbose "[$functionName] Backup created successfully:"
                Write-Verbose "[$functionName] - Backup path: $($backupInfo.FullName)"
                Write-Verbose "[$functionName] - Backup size: $($backupInfo.Length) bytes"
                Write-Verbose "[$functionName] - Backup timestamp: $($backupInfo.CreationTime)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Backup created successfully. Size: $($backupInfo.Length) bytes" -LogLevel "Information"
            }
            catch
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Backup creation failed: $($_.Exception.Message)" -LogLevel "Error"
            }
        }
        else
        {
            Write-Verbose "[$functionName] No backup requested - proceeding without backup. The original file will be overwritten if the operation succeeds."
            Write-Verbose "[$functionName] Consider using -BackupOriginal for safer operations, especially on sensitive or production files."
            Write-Log -LogFile $LogFile -Module $functionName -Message "No backup requested - proceeding without backup" -LogLevel "Debug"
        }
    
        # Read file content
        Write-Verbose "[$functionName] Reading source file content..."
Write-Log -LogFile $LogFile -Module $functionName -Message "Reading source file content" -LogLevel "Verbose"
        try
        {
            $fileContent = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "[$functionName] File content read successfully:"
            Write-Verbose "[$functionName] Content length: $($fileContent.Length) characters"
            Write-Verbose "[$functionName] First 100 characters: $($fileContent.Substring(0, [Math]::Min(100, $fileContent.Length)))"
Write-Log -LogFile $LogFile -Module $functionName -Message "File content read successfully. Length: $($fileContent.Length) characters" -LogLevel "Information"
        }
        catch
        {
            $errorMsg = "CRITICAL ERROR: Failed to read file '$FilePath'."
            Write-Host $errorMsg
            Write-Log -LogFile $LogFile -Module $functionName -Message "File read failed: $($_.Exception.Message)" -LogLevel "Error"
            return @{
                Success      = $false
                Content      = $null
                Operation    = $operationMode
                InMemoryOnly = $InMemoryOnly
                ErrorMessage = $errorMsg
            }
        }
        if ([string]::IsNullOrEmpty($fileContent))
        {
            $warningMsg = "WARNING: File appears to be empty: $FilePath"
            Write-Verbose $warningMsg
            Write-Warning $warningMsg
            Write-Warning "No operation will be performed on empty file."
            Write-Log -LogFile $LogFile -Module $functionName -Message "File appears to be empty - no operation performed" -LogLevel "Warning"
            return @{
                Success      = $false
                Content      = $null
                Operation    = $operationMode
                InMemoryOnly = $InMemoryOnly
                ErrorMessage = $warningMsg
            }
        }
    
        # Initialize cryptographic components
        Write-Verbose "[$functionName] Initializing cryptographic components..."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Initializing cryptographic components (AES-256)" -LogLevel "Debug"
        Write-Verbose "[$functionName] Setting up AES encryption with the following parameters:"
        Write-Verbose "[$functionName] Algorithm: AES (Advanced Encryption Standard)"
        Write-Verbose "[$functionName] Key size: 256 bits"
        Write-Verbose "[$functionName] Mode: CBC (Cipher Block Chaining)"
        Write-Verbose "[$functionName] Padding: PKCS7"
        $aes = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        Write-Verbose "[$functionName] AES provider initialized successfully"
    
        # Create 256-bit key from the provided string using SHA256
        Write-Verbose "[$functionName] Generating 256-bit encryption key from user-provided string..."
        Write-Verbose "[$functionName] Input key length: $($Key.Length) characters"
        Write-Verbose "[$functionName] Using SHA256 hash algorithm for key derivation"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Generating 256-bit encryption key using SHA256" -LogLevel "Debug"
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $keyBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Key))
        $aes.Key = $keyBytes
        Write-Verbose "[$functionName] Encryption key generated successfully:"
        $first8 = $keyBytes[0..7] | ForEach-Object { '{0:X2}' -f $_ }
        Write-Verbose ("Key hash (first 8 bytes): {0}" -f ($first8 -join ''))
        Write-Verbose "[$functionName] Key length: $($keyBytes.Length) bytes"
    
        if ($Decrypt)
        {
            Write-Verbose "[$functionName] =========================================="
            Write-Verbose "[$functionName] STARTING DECRYPTION PROCESS"
            Write-Verbose "[$functionName] =========================================="
            # Pre-decryption validation
            Write-Verbose "[$functionName] Performing pre-decryption validation checks..."
        
            # Check if content looks like encrypted data (base64)
            Write-Verbose "[$functionName] Validating encrypted data format..."
            try
            {
                $encryptedData = [Convert]::FromBase64String($fileContent)
                Write-Verbose "[$functionName] File content is valid base64 format"
                Write-Verbose "[$functionName] Base64 string length: $($fileContent.Length) characters"
                Write-Verbose "[$functionName] Decoded data length: $($encryptedData.Length) bytes"
            }
            catch
            {
                Write-Verbose "[$functionName] Base64 validation failed: $($_.Exception.Message)"
                Write-Host "DECRYPTION ERROR: The file content is not valid base64 encoded data."
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = "The file content is not valid base64 encoded data."
                }
            }
            # Validate encrypted data structure
            Write-Verbose "[$functionName] Validating encrypted data structure..."
            if ($encryptedData.Length -lt 16)
            {
                $errorMsg = "DECRYPTION ERROR: Encrypted data is corrupted or invalid."
                $errorMsg += "`n`nData structure analysis:"
                $errorMsg += "`n Minimum expected size: 16 bytes (IV) + encrypted content"
                $errorMsg += "`n Actual size: $($encryptedData.Length) bytes"
                $errorMsg += "`n`nThis indicates the encrypted file is corrupted or was not properly encrypted."
                Write-Verbose "[$functionName] Encrypted data structure validation failed: Data too short"
                Write-Host $errorMsg
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = $errorMsg
                }
            }
            # Extract IV and encrypted content
            Write-Verbose "[$functionName] Extracting initialization vector (IV) and encrypted content..."
            $iv = $encryptedData[0..15]
            $encryptedContent = $encryptedData[16..($encryptedData.Length - 1)]
            $aes.IV = $iv
            Write-Verbose "[$functionName] Data structure analysis:"
            $first16 = $iv | ForEach-Object { '{0:X2}' -f $_ }
            Write-Verbose "[$functionName] - IV (first 16 bytes): $($first16 -join '')"
            Write-Verbose "[$functionName] - IV length: $($iv.Length) bytes"
            Write-Verbose "[$functionName] - Encrypted content length: $($encryptedContent.Length) bytes"
            Write-Verbose "[$functionName] Total encrypted data: $($encryptedData.Length) bytes"
            Write-Verbose "[$functionName] Beginning AES decryption process..."
        
            # Attempt decryption
            try
            {
                $decryptor = $aes.CreateDecryptor()
                Write-Verbose "[$functionName] AES decryptor created successfully"
                Write-Verbose "[$functionName] Decrypting content block..."
                $decryptedBytes = $decryptor.TransformFinalBlock($encryptedContent, 0, $encryptedContent.Length)
                Write-Verbose "[$functionName] Decryption completed without cryptographic errors"
                Write-Verbose "[$functionName] Decrypted data length: $($decryptedBytes.Length) bytes"
                $decryptedText = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                Write-Verbose "[$functionName] Decrypted bytes converted to UTF-8 string successfully"
                Write-Verbose "[$functionName] Decrypted text length: $($decryptedText.Length) characters"
            }
            catch [System.Security.Cryptography.CryptographicException]
            {
                Write-Verbose "[$functionName] Decryption failed with CryptographicException (likely wrong key): $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Decryption failed with CryptographicException: $($_.Exception.Message)" -LogLevel "Error"
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = "The decryption key you provided does not match the key used to encrypt this file."
                }
            }
            catch
            {
                Write-Host "DECRYPTION ERROR: Unexpected error during decryption process."
                Write-Verbose "[$functionName] `n`nError type: $($_.Exception.GetType().Name)"
                Write-Verbose "[$functionName] `nError details: $($_.Exception.Message)"
                Write-Host "`n`nThis may indicate:"
                Write-Host "`n File corruption"
                Write-Host "`n Incompatible encryption method"
                Write-Host "`n - System cryptography issue"
                Write-Verbose "[$functionName] Decryption failed with unexpected error: $($_.Exception.Message)"
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = "Unexpected error during decryption process: $($_.Exception.Message)"
                }
            }
        
            # Validate decrypted content is valid JSON
            Write-Verbose "[$functionName] Validating decrypted content format..."
            try
            {
                $null = ConvertFrom-Json $decryptedText -ErrorAction Stop
                Write-Verbose "[$functionName] Decrypted content is valid JSON"
                Write-Verbose "[$functionName] JSON validation successful"
            }
            catch
            {
                Write-Host "DECRYPTION ERROR: Decrypted content is not valid JSON."
                Write-Host "⚠️ POSSIBLE INCORRECT DECRYPTION KEY"
                Write-Host "`nThe decryption process completed, but the result is not valid JSON."
                Write-Host "`nThis strongly suggests the wrong decryption key was used."
                if ($null -ne $decryptedText)
                {
                    Write-Verbose "[$functionName] Decrypted content preview:"
                    Write-Verbose "[$functionName] `n$($decryptedText.Substring(0, [Math]::Min(300, $decryptedText.Length)))"
                    if ($decryptedText.Length -gt 300)
                    {
                        Write-Verbose "[$functionName] `n... (truncated)" 
                    }
                }
                Write-Verbose "[$functionName] Expected: Valid JSON data"
                Write-Verbose "[$functionName] Actual: Garbled or corrupted text"
                Write-Verbose "[$functionName] JSON validation failed after decryption: $($_.Exception.Message)"
                return @{
                    Success      = $false
                    Content      = $decryptedText
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = "Decrypted content is not valid JSON - possible incorrect decryption key"
                }
            }
        
            # Write decrypted content back to file or return it
            if ($InMemoryOnly)
            {
                Write-Verbose "[$functionName] In-memory mode: returning decrypted content without writing to disk"
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] DECRYPTION COMPLETED SUCCESSFULLY (IN-MEMORY)"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] Decrypted content length: $($decryptedText.Length) characters"
                
                # Return both success status and decrypted content
                return @{
                    Success      = $true
                    Content      = $decryptedText
                    Operation    = "Decrypt"
                    InMemoryOnly = $true
                }
            }
            else
            {
                Write-Verbose "[$functionName] Writing decrypted content back to original file..."
                try
                {
                    Set-Content $FilePath -Value $decryptedText -Encoding UTF8 -NoNewline -ErrorAction Stop
                    Write-Verbose "[$functionName] Decrypted content written successfully"
                    # Verify the write operation
                    $verifyContent = Get-Content $FilePath -Raw -Encoding UTF8
                    if ($verifyContent -eq $decryptedText)
                    {
                        Write-Verbose "[$functionName] File write verification successful"
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
                    Write-Verbose "[$functionName] File write failed: $($_.Exception.Message)"
                    return @{
                        Success      = $false
                        Content      = $decryptedText
                        Operation    = "Decrypt"
                        InMemoryOnly = $false
                        ErrorMessage = $errorMsg
                    }
                }
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] DECRYPTION COMPLETED SUCCESSFULLY"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] Decryption completed in $([Math]::Round($operationDuration.TotalMilliseconds, 2)) ms"
            }
        }
        else
        {
            Write-Verbose "[$functionName] =========================================="
            Write-Verbose "[$functionName] STARTING ENCRYPTION PROCESS"
            Write-Verbose "[$functionName] =========================================="
            # Pre-encryption validation
            Write-Verbose "[$functionName] Performing pre-encryption validation checks..."
            # Validate that content is valid JSON before encrypting
            Write-Verbose "[$functionName] Validating JSON format of source content..."
            try
            {
                $jsonObject = ConvertFrom-Json $fileContent -ErrorAction Stop
                Write-Verbose "[$functionName] Source content is valid JSON"
                Write-Verbose "[$functionName] JSON validation successful"
                Write-Verbose "[$functionName] JSON object type: $($jsonObject.GetType().Name)"
                if ($jsonObject -is [PSCustomObject])
                {
                    $propertyCount = ($jsonObject | Get-Member -MemberType NoteProperty).Count
                    Write-Verbose "[$functionName] - JSON properties count: $propertyCount"
                }
            }
            catch
            {
                $errorMsg = "ENCRYPTION ERROR: Source file does not contain valid JSON data."
                $errorMsg += "`n`nJSON validation failed:"
                $errorMsg += "`n Error: $($_.Exception.Message)"
                $errorMsg += "`n Line: $($_.Exception.ItemName)"
                $errorMsg += "`n`nFile content preview:"
                $errorMsg += "`n$($fileContent.Substring(0, [Math]::Min(300, $fileContent.Length)))"
                if ($fileContent.Length -gt 300)
                {
                    $errorMsg += "`n... (truncated)" 
                }
                $errorMsg += "`n`nPlease ensure the file contains valid JSON before encryption."
                Write-Verbose "[$functionName] JSON validation failed: $($_.Exception.Message)"
                Write-Host $errorMsg 
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Encrypt"
                    InMemoryOnly = $false
                    ErrorMessage = $errorMsg
                }
            }
            # Generate random IV for this encryption
            Write-Verbose "[$functionName] Generating cryptographically secure random initialization vector (IV)..."
            $aes.GenerateIV()
            Write-Verbose "[$functionName] Random IV generated successfully"
            Write-Verbose "[$functionName] IV length: $($aes.IV.Length) bytes"
            $ivValue = $aes.IV | ForEach-Object { '{0:X2}' -f $_ }   
            Write-Verbose "[$functionName] IV value: $($ivValue -join '')"
            Write-Verbose "[$functionName] IV provides unique encryption for this session"
            Write-Verbose "[$functionName] Beginning AES encryption process..."
        
            # Encrypt the content
            try
            {
                $encryptor = $aes.CreateEncryptor()
                Write-Verbose "[$functionName] AES encryptor created successfully"
                $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
                Write-Verbose "[$functionName] Source content converted to bytes:"
                Write-Verbose "[$functionName] Original text length: $($fileContent.Length) characters"
                Write-Verbose "[$functionName] UTF-8 bytes length: $($contentBytes.Length) bytes"
                Write-Verbose "[$functionName] Encrypting content block..."
                $encryptedBytes = $encryptor.TransformFinalBlock($contentBytes, 0, $contentBytes.Length)
                Write-Verbose "[$functionName] Encryption completed successfully"
                Write-Verbose "[$functionName] Encrypted data length: $($encryptedBytes.Length) bytes"
            }
            catch
            {
                $errorMsg = "ENCRYPTION ERROR: Failed during AES encryption process."
                $errorMsg += "`nError details: $($_.Exception.Message)"
                $errorMsg += "`nError type: $($_.Exception.GetType().Name)"
                Write-Verbose "[$functionName] Encryption process failed: $($_.Exception.Message)"
                Write-Host $errorMsg
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Encrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = $errorMsg
                }
            }
            # Combine IV and encrypted content for storage
            Write-Verbose "[$functionName] Preparing encrypted data for storage..."
            $combinedBytes = $aes.IV + $encryptedBytes
            Write-Verbose "[$functionName] Data structure for storage:"
            Write-Verbose "[$functionName] IV length: $($aes.IV.Length) bytes"
            Write-Verbose "[$functionName] Encrypted content length: $($encryptedBytes.Length) bytes"
            Write-Verbose "[$functionName] Total combined length: $($combinedBytes.Length) bytes"
        
            # Convert to base64 for safe text storage
            Write-Verbose "[$functionName] Converting encrypted data to base64 format..."
            $base64String = [Convert]::ToBase64String($combinedBytes)
            Write-Verbose "[$functionName] Base64 conversion completed"
            Write-Verbose "[$functionName] Base64 string length: $($base64String.Length) characters"
            Write-Verbose "[$functionName] Compression ratio: $([Math]::Round(($base64String.Length / $fileContent.Length) * 100, 2))% of original size"
        
            # Write encrypted content back to file or return it
            if ($InMemoryOnly)
            {
                Write-Verbose "[$functionName] In-memory mode: returning encrypted content without writing to disk"
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] ENCRYPTION COMPLETED SUCCESSFULLY (IN-MEMORY)"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] Encrypted content length: $($base64String.Length) characters"
                
                # Return both success status and encrypted content
                return @{
                    Success      = $true
                    Content      = $base64String
                    Operation    = "Encrypt"
                    InMemoryOnly = $true
                }
            }
            else
            {
                Write-Verbose "[$functionName] Writing encrypted content to original file..."
                try
                {
                    Set-Content $FilePath -Value $base64String -Encoding UTF8 -NoNewline -ErrorAction Stop
                    Write-Verbose "[$functionName] Encrypted content written successfully"
                    # Verify the write operation
                    $verifyContent = Get-Content $FilePath -Raw -Encoding UTF8
                    if ($verifyContent -eq $base64String)
                    {
                        Write-Verbose "[$functionName] File write verification successful"
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
                    Write-Verbose "[$functionName] File write failed: $($_.Exception.Message)"
                    Write-Host $errorMsg
                    return @{
                        Success      = $false
                        Content      = $base64String
                        Operation    = "Encrypt"
                        InMemoryOnly = $false
                        ErrorMessage = $errorMsg
                    }
                }
        
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] ENCRYPTION COMPLETED SUCCESSFULLY"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] File '$FilePath' has been encrypted successfully."
                Write-Verbose "[$functionName] Encryption completed in $([Math]::Round($operationDuration.TotalMilliseconds, 2)) ms"    
            }
        }
    
        # Return success for non-in-memory operations
        return @{
            Success      = $true
            Content      = $null
            Operation    = $(if ($Decrypt) { "Decrypt" } else { "Encrypt" })
            InMemoryOnly = $false
        }
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
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] OPERATION FAILED"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Verbose "[$functionName] Error type: $($_.Exception.GetType().Name)"
        Write-Verbose "[$functionName] Error message: $($_.Exception.Message)"
        if ($_.Exception.InnerException)
        {
            Write-Verbose "[$functionName] Inner exception: $($_.Exception.InnerException.Message)"
        }
        # Log the full call stack for debugging
        Write-Verbose "[$functionName] Call stack:"
        $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Verbose "[$functionName] $_" }
        Write-Error "Operation failed: $($_.Exception.Message)"
                
        # If backup exists and operation failed, provide restoration guidance
        if ($BackupOriginal -and (Test-Path "$FilePath.bak"))
        {
            Write-Warning "BACKUP AVAILABLE: A backup file exists at '$FilePath.bak'"
            Write-Warning " You can restore the original file if needed using:"
            Write-Warning " Copy-Item '$FilePath.bak' '$FilePath' -Force"
        }
        return @{
            Success      = $false
            Content      = $null
            Operation    = $(if ($Decrypt) { "Decrypt" } else { "Encrypt" })
            InMemoryOnly = $InMemoryOnly
            ErrorMessage = "Operation failed: $($_.Exception.Message)"
        }
    }
    finally
    {
        # Clean up cryptographic objects
        Write-Verbose "[$functionName] Performing cleanup of cryptographic resources..."
                
        if ($null -ne $aes)
        {
            try
            {
                $aes.Dispose()
Write-Log -LogFile $LogFile -Module $functionName -Message "AES encryption object disposed successfully" -LogLevel "Information"
            }
            catch
            {
                Write-Verbose "[$functionName] Warning: Error disposing AES object: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Error disposing AES object: $($_.Exception.Message)" -LogLevel "Warning"
            }
        }
        if ($null -ne $sha256)
        {
            try
            {
                $sha256.Dispose()
Write-Log -LogFile $LogFile -Module $functionName -Message "SHA256 hash object disposed successfully" -LogLevel "Information"
            }
            catch
            {
                Write-Verbose "[$functionName] Warning: Error disposing SHA256 object: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Error disposing SHA256 object: $($_.Exception.Message)" -LogLevel "Warning"
            }
        }
        if ($null -ne $encryptor)
        {
            try
            {
                $encryptor.Dispose()
Write-Log -LogFile $LogFile -Module $functionName -Message "Encryptor object disposed successfully" -LogLevel "Information"
            }
            catch
            {
                Write-Verbose "[$functionName] Warning: Error disposing encryptor: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Error disposing encryptor: $($_.Exception.Message)" -LogLevel "Warning"
            }
        }
        if ($null -ne $decryptor)
        {
            try
            {
                $decryptor.Dispose()
Write-Log -LogFile $LogFile -Module $functionName -Message "Decryptor object disposed successfully" -LogLevel "Information"
            }
            catch
            {
                Write-Verbose "[$functionName] Warning: Error disposing decryptor: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Error disposing decryptor: $($_.Exception.Message)" -LogLevel "Warning"
            }
        }
        # Force garbage collection to clear sensitive data from memory
        Write-Verbose "[$functionName] Forcing garbage collection to clear sensitive data..."
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Write-Verbose "[$functionName] Garbage collection completed"
        Write-Verbose "[$functionName] Resource cleanup completed"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] FUNCTION EXECUTION COMPLETED"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Function: Invoke-JsonFileEncryption"
        Write-Verbose "[$functionName] Completion timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')"
        Write-Verbose "[$functionName] All resources cleaned up successfully"
        Write-Verbose "[$functionName] Function execution finished"
    }
}

