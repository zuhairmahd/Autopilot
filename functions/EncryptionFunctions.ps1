function Clear-SecureMemory
{
    <#
    .SYNOPSIS
    Clears sensitive data from memory and forces garbage collection.
    
    .DESCRIPTION
    This function helps ensure sensitive data like passwords and encryption keys
    are properly cleared from memory and garbage collected.
    
    .PARAMETER Variables
    Array of variable names to clear from memory.
    
    .PARAMETER ClearScriptVariables
    If specified, also clears script-level temporary encryption variables.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Variables = @(),
        [switch]$ClearScriptVariables
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting secure memory cleanup operation" -LogLevel "Debug"
    Write-Verbose "[$functionName] Clearing sensitive data from memory"
    
    $clearedVariables = @()
    
    # Clear specified variables
    foreach ($varName in $Variables)
    {
        if (Get-Variable -Name $varName -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name $varName -Force -ErrorAction SilentlyContinue
            $clearedVariables += $varName
            Write-Verbose "[$functionName] Cleared variable: $varName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared variable from memory" -LogLevel "Debug"
        }
        elseif (Get-Variable -Name $varName -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name $varName -Scope Script -Force -ErrorAction SilentlyContinue
            $clearedVariables += $varName
            Write-Verbose "[$functionName] Cleared script variable: $varName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable from memory" -LogLevel "Debug"
        }
    }
    
    # Clear script-level variables only if explicitly requested
    if ($ClearScriptVariables)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Clearing script-level encryption variables" -LogLevel "Debug"
        
        if (Get-Variable -Name "TempEncryptedConfig" -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "TempEncryptedConfig" -Scope Script -Force -ErrorAction SilentlyContinue
            Write-Verbose "[$functionName] Cleared script variable: TempEncryptedConfig"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable: TempEncryptedConfig" -LogLevel "Debug"
        }
        
        if (Get-Variable -Name "TempEncryptionKey" -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "TempEncryptionKey" -Scope Script -Force -ErrorAction SilentlyContinue
            Write-Verbose "[$functionName] Cleared script variable: TempEncryptionKey"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable: TempEncryptionKey" -LogLevel "Debug"
        }
        
        if (Get-Variable -Name "UserEncryptionPassword" -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "UserEncryptionPassword" -Scope Script -Force -ErrorAction SilentlyContinue
            Write-Verbose "[$functionName] Cleared script variable: UserEncryptionPassword"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable: UserEncryptionPassword" -LogLevel "Debug"
        }
    }
    
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    Write-Verbose "[$functionName] Memory cleanup completed"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Memory cleanup completed successfully. Variables cleared: $($clearedVariables.Count)" -LogLevel "Debug"
}

function Get-SecurePassword
{
    <#
    .SYNOPSIS
    Prompts the user for a secure password with confirmation.
    
    .DESCRIPTION
    This function prompts the user to enter a password securely, with an optional confirmation prompt.
    The password is returned as a SecureString for security.
    
    .PARAMETER Message
    The message to display to the user when prompting for the password.
    
    .PARAMETER RequireConfirmation
    If specified, the user will be prompted to confirm their password.
    
    .PARAMETER MinLength
    The minimum length required for the password (default: 8).
    
    .OUTPUTS
    Returns the password as a SecureString.
    
    .EXAMPLE
    $password = Get-SecurePassword -Message "Enter your encryption password" -RequireConfirmation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$RequireConfirmation,
        [int]$MinLength = 8
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting secure password prompt. RequireConfirmation: $RequireConfirmation, MinLength: $MinLength" -LogLevel "Debug"
    Write-Verbose "[$functionName] Prompting user for secure password"
    
    $attemptCount = 0
    do
    {
        $attemptCount++
        $validPassword = $true
        Write-Log -LogFile $LogFile -Module $functionName -Message "Password prompt attempt $attemptCount" -LogLevel "Debug"
        
        $password = Read-Host -Prompt $Message -AsSecureString
        
        # Convert to plain text temporarily for validation
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
        
        # Validate password length
        if ($plainPassword.Length -lt $MinLength)
        {
            Write-Host "Password must be at least $MinLength characters long. Please try again." -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $functionName -Message "Password validation failed: insufficient length" -LogLevel "Warning"
            $validPassword = $false
            continue
        }
        
        # Confirm password if required
        if ($RequireConfirmation)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting for password confirmation" -LogLevel "Debug"
            $confirmPassword = Read-Host -Prompt "Confirm password" -AsSecureString
            $plainConfirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
            
            if ($plainPassword -ne $plainConfirmPassword)
            {
                Write-Host "Passwords do not match. Please try again." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $functionName -Message "Password confirmation failed: passwords do not match" -LogLevel "Warning"
                $validPassword = $false
                continue
            }
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Password confirmation successful" -LogLevel "Debug"
        }
        
        # Clear plain text passwords from memory
        $plainPassword = $null
        if ($plainConfirmPassword)
        {
            $plainConfirmPassword = $null
        }
        
    } while (-not $validPassword)
    
    Write-Verbose "[$functionName] Password obtained successfully"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Secure password obtained successfully after $attemptCount attempts" -LogLevel "Information"
    return $password
}

function Get-DecryptedConfigValue
{
    <#
    .SYNOPSIS
    Retrieves a configuration value from the temporarily encrypted configuration.
    
    .DESCRIPTION
    This function decrypts the temporary configuration and retrieves a specific value.
    This is used during runtime to access configuration values without keeping them in plain text.
    
    .PARAMETER PropertyPath
    The path to the property to retrieve (e.g., "auth.AppId").
    
    .OUTPUTS
    Returns the decrypted configuration value.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving config value for path: $PropertyPath" -LogLevel "Debug"
    Write-Verbose "[$functionName] Retrieving config value for path: $PropertyPath"
    
    if (-not $script:TempEncryptedConfig -or -not $script:TempEncryptionKey)
    {
        Write-Error "No temporary encrypted configuration available"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No temporary encrypted configuration available" -LogLevel "Error"
        return $null
    }
    
    # Create a temporary file to decrypt
    $tempFile = [System.IO.Path]::GetTempFileName()
    Write-Log -LogFile $LogFile -Module $functionName -Message "Created temporary file for decryption" -LogLevel "Debug"
    
    try
    {
        Set-Content -Path $tempFile -Value $script:TempEncryptedConfig -Encoding UTF8
        
        # Decrypt the content
        $decryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $script:TempEncryptionKey -Decrypt -InMemoryOnly
        
        if ($decryptResult.Success)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully decrypted configuration for property access" -LogLevel "Debug"
            $config = ConvertFrom-Json $decryptResult.Content
            
            # Navigate the property path
            $pathParts = $PropertyPath.Split('.')
            $current = $config
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Navigating property path with $($pathParts.Length) segments" -LogLevel "Debug"
            
            foreach ($part in $pathParts)
            {
                if ($current.PSObject.Properties.Name -contains $part)
                {
                    $current = $current.$part
                }
                else
                {
                    Write-Verbose "[$functionName] Property path '$PropertyPath' not found in configuration"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Property path '$PropertyPath' not found in configuration" -LogLevel "debug"
                    return $null
                }
            }
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully retrieved configuration value for path: $PropertyPath" -LogLevel "Debug"
            return $current
        }
        else
        {
            Write-Error "Failed to decrypt temporary configuration: $($decryptResult.ErrorMessage)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decrypt temporary configuration: $($decryptResult.ErrorMessage)" -LogLevel "Error"
            return $null
        }
    }
    finally
    {
        # Clean up temporary file
        if (Test-Path $tempFile)
        {
            Remove-Item $tempFile -Force
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleaned up temporary file" -LogLevel "Debug"
        }
    }
}

function Get-AuthConfigValue
{
    <#
    .SYNOPSIS
    Retrieves an authentication configuration value from the init file.
    
    .DESCRIPTION
    This function retrieves authentication configuration values from the script-level $Auth variable
    which is loaded from the init file.
    
    .PARAMETER PropertyPath
    The path to the property to retrieve (e.g., "scope", "authType").
    
    .EXAMPLE
    Get-AuthConfigValue -PropertyPath "scope"
    
    .EXAMPLE
    Get-AuthConfigValue -PropertyPath "authType"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Retrieving auth config value for path: $PropertyPath"
    
    if (-not $script:Auth)
    {
        Write-Error "No auth configuration available"
        return $null
    }
    
    # Navigate the property path
    $pathParts = $PropertyPath.Split('.')
    $current = $script:Auth
    
    foreach ($part in $pathParts)
    {
        if ($current.ContainsKey($part))
        {
            $current = $current[$part]
        }
        else
        {
            Write-Verbose "[$functionName] Property path '$PropertyPath' not found in auth configuration"
            return $null
        }
    }
    
    return $current
}

function ConvertFrom-SecureString-ToPlainText
{
    <#
    .SYNOPSIS
    Converts a SecureString to plain text.
    
    .DESCRIPTION
    This function converts a SecureString to plain text for use in encryption operations.
    The plain text should be cleared from memory as soon as possible after use.
    
    .PARAMETER SecureString
    The SecureString to convert.
    
    .OUTPUTS
    Returns the plain text string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [SecureString]$SecureString
    )
    
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString))
}

function Test-FileEncryptionStatus
{
    <#
    .SYNOPSIS
    Tests whether a JSON file is encrypted or not.
    
    .DESCRIPTION
    This function examines a file to determine if it contains encrypted content.
    It checks if the file content is valid Base64 (indicating encryption) or valid JSON (indicating unencrypted).
    
    .PARAMETER FilePath
    The path to the file to check.
    
    .OUTPUTS
    Returns a hashtable with the following properties:
    - IsEncrypted: Boolean indicating if the file is encrypted
    - IsValidFile: Boolean indicating if the file exists and is readable
    - FileContent: The raw content of the file (for debugging)
    - ErrorMessage: Any error encountered during the check
    
    .EXAMPLE
    $status = Test-FileEncryptionStatus -FilePath "C:\config.json"
    if ($status.IsEncrypted) {
        Write-Host "File is encrypted"
    } else {
        Write-Host "File is not encrypted"
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting file encryption status check for: $FilePath" -LogLevel "Debug"
    Write-Verbose "[$functionName] Checking encryption status of file: $FilePath"
    
    # Initialize result object
    $result = @{
        IsEncrypted  = $false
        IsValidFile  = $false
        FileContent  = $null
        ErrorMessage = $null
    }
    
    try
    {
        # Check if file exists
        if (-not (Test-Path $FilePath))
        {
            $result.ErrorMessage = "File does not exist: $FilePath"
            Write-Verbose "[$functionName] File not found: $FilePath"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File not found: $FilePath" -LogLevel "Error"
            return $result
        }
        
        # Read file content
        $fileContent = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
        $result.FileContent = $fileContent
        $result.IsValidFile = $true
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully read file. Content length: $($fileContent.Length) characters" -LogLevel "Debug"
        
        if ([string]::IsNullOrWhiteSpace($fileContent))
        {
            $result.ErrorMessage = "File is empty or contains only whitespace"
            Write-Verbose "[$functionName] File is empty: $FilePath"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is empty or contains only whitespace" -LogLevel "Warning"
            return $result
        }
        
        Write-Verbose "[$functionName] File content length: $($fileContent.Length) characters"
        
        # First, try to parse as JSON (unencrypted)
        try
        {
            $null = ConvertFrom-Json $fileContent -ErrorAction Stop
            $result.IsEncrypted = $false
            Write-Verbose "[$functionName] File contains valid JSON - not encrypted"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File contains valid JSON - not encrypted" -LogLevel "Debug"
            return $result
        }
        catch
        {
            Write-Verbose "[$functionName] File is not valid JSON, checking if it's encrypted..."
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is not valid JSON, checking if it's encrypted" -LogLevel "Debug"
        }
        
        # If not JSON, check if it's Base64 encoded (encrypted)
        try
        {
            $decodedBytes = [Convert]::FromBase64String($fileContent.Trim())
            if ($decodedBytes.Length -ge 16)
            {
                # Minimum size for IV + some encrypted content
                $result.IsEncrypted = $true
                Write-Verbose "[$functionName] File contains valid Base64 with sufficient length - appears encrypted"
                Write-Log -LogFile $LogFile -Module $functionName -Message "File contains valid Base64 with sufficient length - appears encrypted" -LogLevel "Debug"
                return $result
            }
            else
            {
                $result.ErrorMessage = "File appears to be Base64 but is too short to be properly encrypted"
                Write-Verbose "[$functionName] Base64 data too short for encryption"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Base64 data too short for encryption" -LogLevel "Warning"
                return $result
            }
        }
        catch
        {
            $result.ErrorMessage = "File is neither valid JSON nor valid Base64 - unknown format"
            Write-Verbose "[$functionName] File is not valid Base64 either: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is neither valid JSON nor valid Base64 - unknown format" -LogLevel "Warning"
            return $result
        }
    }
    catch
    {
        $result.ErrorMessage = "Error reading file: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Error reading file: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error reading file: $($_.Exception.Message)" -LogLevel "Error"
        return $result
    }
}

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
        [switch]$BackupOriginal,
        [Parameter(Mandatory = $false)]
        [switch]$InMemoryOnly
    )

    $functionName = $MyInvocation.MyCommand.Name
    $operationMode = if ($Decrypt) { 'DECRYPT' } else { 'ENCRYPT' }
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting JSON file encryption/decryption operation" -LogLevel "Information"
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
        Write-Log -LogFile $LogFile -Module $functionName -Message "Validating file existence and accessibility" -LogLevel "Debug"
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
            Write-Log -LogFile $LogFile -Module $functionName -Message "File found successfully. Size: $($fileInfo.Length) bytes" -LogLevel "Debug"
        }
        catch
        {
            $errorMsg = "CRITICAL ERROR: Cannot access file '$FilePath'."
            $errorMsg += "`nError details: $($_.Exception.Message)"
            $errorMsg += "`nPlease verify you have the necessary permissions to access this file."
            Write-Host $errorMsg
            Write-Verbose "[$functionName] File accessibility check failed: $($_.Exception.Message)"
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
        Write-Verbose "[$functionName] File validation completed successfully"
        Write-Log -LogFile $LogFile -Module $functionName -Message "File validation completed successfully" -LogLevel "Debug"
        $operationStartTime = Get-Date
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Starting main processing at $($operationStartTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module $functionName -Message "Starting main processing" -LogLevel "Debug"
    
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
                Write-Verbose "[$functionName] Backup creation failed: $($_.Exception.Message)"
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
        Write-Log -LogFile $LogFile -Module $functionName -Message "Reading source file content" -LogLevel "Debug"
        try
        {
            $fileContent = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "[$functionName] File content read successfully:"
            Write-Verbose "[$functionName] Content length: $($fileContent.Length) characters"
            Write-Verbose "[$functionName] First 100 characters: $($fileContent.Substring(0, [Math]::Min(100, $fileContent.Length)))"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File content read successfully. Length: $($fileContent.Length) characters" -LogLevel "Debug"
        }
        catch
        {
            Write-Verbose "[$functionName] File read failed: $($_.Exception.Message)"
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
                Write-Host "`n`nThe decryption key you provided does not match the key used to encrypt this file."
                Write-Verbose "[$functionName] Decryption failed with CryptographicException (likely wrong key): $($_.Exception.Message)"
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
                Write-Verbose "[$functionName] Content preview: $($decryptedText.Substring(0, [Math]::Min(200, $decryptedText.Length)))"
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
                Write-Verbose "[$functionName] ✓ AES encryption object disposed successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] ⚠️ Warning: Error disposing AES object: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $sha256)
        {
            try
            {
                $sha256.Dispose()
                Write-Verbose "[$functionName] ✓ SHA256 hash object disposed successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] ⚠️ Warning: Error disposing SHA256 object: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $encryptor)
        {
            try
            {
                $encryptor.Dispose()
                Write-Verbose "[$functionName] ✓ Encryptor object disposed successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] ⚠️ Warning: Error disposing encryptor: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $decryptor)
        {
            try
            {
                $decryptor.Dispose()
                Write-Verbose "[$functionName] ✓ Decryptor object disposed successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] ⚠️ Warning: Error disposing decryptor: $($_.Exception.Message)"
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


#region Legacy Encryption functions
$excludeFields = @('domain', 'name', 'scope', 'auth')
function TestIsBase64String()
{
    param (
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value))
    {
        return $false
    }
    # A common check: length must be a multiple of 4.
    # And it should not contain characters outside the Base64 character set.
    # This is a basic check; more robust validation might be needed for edge cases.
    if (($Value.Length % 4 -ne 0) -or ($Value -notmatch "^[a-zA-Z0-9+/]*=*$"))
    {
        return $false
    }

    try
    {
        $null = [Convert]::FromBase64String($Value)
        return $true
    }
    catch
    {
        return $false
    }
}

function isEncrypted()
{
    [CmdletBinding()]
    param (
        [psObject]$data,
        [string[]]$excludeFields = $excludeFields
    )
    
    function CountEncryptionStatus
    {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields = $excludeFields
        )
        
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Initializing encryption status count object."
        $result = [PSCustomObject]@{
            EncryptedCount   = 0
            UnencryptedCount = 0
        }
        Write-Verbose "[$functionName] Checking whether the input object is null."
        if ($null -eq $InputObject)
        {
            Write-Verbose "[$functionName] Input object is null, returning default counts."
            return $result
        }
        Write-Verbose "[$functionName] Checking input object type"
        if ($InputObject -is [array])
        {
            Write-Verbose "[$functionName] Input object is an array, iterating through its items."
            foreach ($item in $InputObject)
            {
                Write-Verbose "[$functionName] Checking item $item."
                $itemStatus = CountEncryptionStatus -InputObject $item
                Write-Verbose "[$functionName] Item encryption status: EncryptedCount=$($itemStatus.EncryptedCount), UnencryptedCount=$($itemStatus.UnencryptedCount)"
                $result.EncryptedCount += $itemStatus.EncryptedCount
                $result.UnencryptedCount += $itemStatus.UnencryptedCount
                Write-Verbose "[$functionName] Updated counts: EncryptedCount=$($result.EncryptedCount), UnencryptedCount=$($result.UnencryptedCount)"
            }
            Write-Verbose "[$functionName] Finished processing array. Returning counts."
        }
        elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [hashtable])
        {
            Write-Verbose "[$functionName] Input object is a PSCustomObject or hashtable, iterating through its properties."
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[$functionName] Checking property $($prop.Name) with value $($prop.Value)."
                if ($prop.Name -notin $ExcludeFields)
                {
                    Write-Verbose "[$functionName] Property $($prop.Name) is not excluded, checking its value."
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                    {
                        Write-Verbose "[$functionName] Property $($prop.Name) is a nested object or array, recursing into it."
                        $nestedStatus = CountEncryptionStatus -InputObject $prop.Value
                        $result.EncryptedCount += $nestedStatus.EncryptedCount
                        $result.UnencryptedCount += $nestedStatus.UnencryptedCount
                        Write-Verbose "[$functionName] Nested property $($prop.Name) counts: EncryptedCount=$($nestedStatus.EncryptedCount), UnencryptedCount=$($nestedStatus.UnencryptedCount)"
                    }
                    elseif ($prop.Value -is [string] -and $prop.Value.Length -gt 0)
                    {
                        Write-Verbose "[$functionName] Checking if the value of $($prop.Name) is encrypted."
                        if (TestIsBase64String -Value $prop.Value)
                        {
                            Write-Verbose "[$functionName] The value of $($prop.Name) is encrypted."
                            $result.EncryptedCount++
                        }
                        else
                        {
                            Write-Verbose "[$functionName] The value of $($prop.Name) is not encrypted."
                            $result.UnencryptedCount++
                        }
                    }
                    else
                    {
                        Write-Verbose "[$functionName] The value of $($prop.Name) is not a string, skipping."
                        $result.UnencryptedCount++
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Property $($prop.Name) is excluded, skipping."
                }
            }
        }
        else
        {
            if ($InputObject -is [string] -and $InputObject.Length -gt 0)
            {
                Write-Verbose "[$functionName] Input object is a string, checking if it is encrypted."
                if ($inputObject -notin $ExcludeFields)
                {

                    if (TestIsBase64String -Value $InputObject)
                    {
                        Write-Verbose "[$functionName] The input string is encrypted."
                        $result.EncryptedCount++
                    }
                    else
                    {
                        Write-Verbose "[$functionName] The input string is not encrypted."
                        $result.UnencryptedCount++
                    }
                }
            }
            else
            {
                Write-Verbose "[$functionName] Input object is not a string or is empty, treating as unencrypted."
                $result.UnencryptedCount++
            }
        }
        Write-Verbose "[$functionName] Final counts: EncryptedCount=$($result.EncryptedCount), UnencryptedCount=$($result.UnencryptedCount)"
        return $result
    }

    $functionName = $MyInvocation.MyCommand.Name
    $isEncrypted = $false
    Write-Verbose "[$functionName] Checking if the data is encrypted."
    
    $encryptionStatus = CountEncryptionStatus -InputObject $data
    $encryptedCount = $encryptionStatus.EncryptedCount
    $unencryptedCount = $encryptionStatus.UnencryptedCount
    Write-Verbose "[$functionName] The number of encrypted values is $encryptedCount"
    Write-Verbose "[$functionName] The number of unencrypted values is $unencryptedCount"
    
    # If the number of encrypted values is greater than the number of unencrypted values, the data is encrypted.
    if ($encryptedCount -gt $unencryptedCount -and $encryptedCount -gt 0)
    {
        Write-Verbose "[$functionName] The data is considered encrypted."
        $isEncrypted = $true
    }
    Write-Verbose "[$functionName] The data is encrypted: $isEncrypted"
    return $isEncrypted
}

function DecryptObject()
{
    [CmdletBinding()]
    param (
        [object]$encryptedObject,
        [string[]]$excludeFields = $excludeFields
    )
    
    function Invoke-RecursiveDecryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = "",
            [bool]$ParentIsExcluded = $false # New parameter
        )

        if ($null -eq $InputObject)
        {
            return $null 
        }
        Write-Verbose "[DECRYPT] Path: '$ParentPath', ParentIsExcluded: $ParentIsExcluded, Type: $($InputObject.GetType().FullName)"

        if ($InputObject -is [array])
        {
            Write-Verbose "[DECRYPT] Processing array at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $element = $InputObject[$i]
                $currentElementPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                # Pass ParentIsExcluded status to array elements
                $resultArray += Invoke-RecursiveDecryption -InputObject $element -ExcludeFields $ExcludeFields -ParentPath $currentElementPath -ParentIsExcluded $ParentIsExcluded
            }
            return $resultArray
        }
        elseif ($InputObject -is [hashtable])
        {
            Write-Verbose "[DECRYPT] Processing hashtable at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
        
            # Process hashtable by enumerating through the key-value pairs directly
            foreach ($entry in $InputObject.GetEnumerator())
            {
                $key = $entry.Key
                $value = $entry.Value
            
                Write-Verbose "[DECRYPT] Processing hashtable key '$key' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[DECRYPT] Value type: $($value.GetType().FullName)"
            
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$key" 
                }
                else
                {
                    $key 
                }
            
                $isPropertyItselfExcluded = $ExcludeFields -contains $key
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[DECRYPT] Hashtable key: '$key' at path '$currentPropertyPath'. KeyItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$key] = Invoke-RecursiveDecryption -InputObject $value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[DECRYPT] Hashtable key '$key' is effectively excluded. Assigning original value."
                    $result[$key] = $value
                }
                else # Not effectively excluded, attempt to decrypt if it's a string
                {
                    if ($value -is [string] -and (TestIsBase64String -Value $value))
                    {
                        Write-Verbose ("[DECRYPT] Attempting to decrypt string value for {0}" -f $currentPropertyPath)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($value))
                            $result[$key] = $decodedValue
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPropertyPath, $decodedValue)
                        }
                        catch
                        {
                            Write-Warning "[DECRYPT] Failed to decode Base64 string for key '$key' at path '$currentPropertyPath'. Value: '$value'. Assigning original value."
                            $result[$key] = $value # Keep original if not valid Base64 or UTF8
                        }
                    }
                    else
                    {
                        # Not a string, not Base64, or some other primitive type that wasn't encrypted
                        Write-Verbose "[DECRYPT] Hashtable key '$key' is not a decodable string. Assigning original value."
                        $result[$key] = $value
                    }
                }
            }
        
            return $result
        }
        elseif ($InputObject -is [PSCustomObject])
        {
            Write-Verbose "[DECRYPT] Processing object at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[DECRYPT] Processing property '$($prop.Name)' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[decrypt] Property type: $($prop.Value.GetType().FullName)"
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                $isPropertyItselfExcluded = $ExcludeFields -contains $prop.Name
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[DECRYPT] Property: '$($prop.Name)' at path '$currentPropertyPath'. PropItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[DECRYPT] Property '$($prop.Name)' is effectively excluded. Assigning original value."
                    $result[$prop.Name] = $prop.Value
                }
                else # Not effectively excluded, attempt to decrypt if it's a string
                {
                    if ($prop.Value -is [string] -and (TestIsBase64String -Value $prop.Value))
                    {
                        Write-Verbose ("[DECRYPT] Attempting to decrypt string value for {0}" -f $currentPropertyPath)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($prop.Value))
                            $result[$prop.Name] = $decodedValue
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPropertyPath, $decodedValue)
                        }
                        catch
                        {
                            Write-Warning "[DECRYPT] Failed to decode Base64 string for property '$($prop.Name)' at path '$currentPropertyPath'. Value: '$($prop.Value)'. Assigning original value."
                            $result[$prop.Name] = $prop.Value # Keep original if not valid Base64 or UTF8
                        }
                    }
                    else
                    {
                        # Not a string, not Base64, or some other primitive type that wasn't encrypted
                        Write-Verbose "[DECRYPT] Property '$($prop.Name)' is not a decodable string. Assigning original value."
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            return [PSCustomObject]$result
        }
        # Handle standalone primitive types (e.g., a string element directly in an array)
        elseif ($InputObject -is [string])
        {
            if ($ParentIsExcluded) # If the parent (e.g. an array holding this string) was excluded
            {
                Write-Verbose "[DECRYPT] Primitive string at path '$ParentPath' is part of an excluded parent. Returning as-is."
                return $InputObject
            }
            elseif (TestIsBase64String -Value $InputObject)
            {
                Write-Verbose ("[DECRYPT] Attempting to decrypt primitive string value at path '{0}'" -f $ParentPath)
                try
                {
                    $decodedValuePrim = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
                    Write-Verbose ("[DECRYPT] Decrypted primitive value at path '{0}': {1}" -f $ParentPath, $decodedValuePrim)
                    return $decodedValuePrim
                }
                catch
                {
                    Write-Warning "[DECRYPT] Failed to decode Base64 string for primitive at path '$ParentPath'. Value: '$InputObject'. Returning original value."
                    return $InputObject # Keep original if not valid Base64 or UTF8
                }
            }
            else
            {
                # Not Base64, return as is
                Write-Verbose "[DECRYPT] Primitive string at path '$ParentPath' is not Base64. Returning as-is."
                return $InputObject
            }
        }
        else # Other primitive types (int, bool, etc.) or other object types, return as is
        {
            Write-Verbose "[DECRYPT] Value type '$($InputObject.GetType().FullName)' at path '$ParentPath' not a string or already handled. Returning as-is."
            return $InputObject
        }
    }
    
    $result = Invoke-RecursiveDecryption -InputObject $encryptedObject -ExcludeFields $excludeFields
    
    if ($null -eq $result)
    {
        Write-Error 'No values were decrypted.'
        return $null
    }
    
    Write-Verbose "Decryption complete"
    return $result
}

function EncryptObject()
{
    [CmdletBinding()]
    param (
        [object]$decryptedObject,
        [string[]]$excludeFields = $excludeFields
    )


    function Invoke-RecursiveEncryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = "",
            [bool]$ParentIsExcluded = $false # New parameter
        )

        if ($null -eq $InputObject)
        {
            Write-Verbose "[ENCRYPT] InputObject is null at path '$ParentPath'. Returning null."; return $null 
        }
        Write-Verbose "[ENCRYPT] Path: '$ParentPath', ParentIsExcluded: $ParentIsExcluded, Type: $($InputObject.GetType().FullName)"

        if ($InputObject -is [array])
        {
            Write-Verbose "[ENCRYPT] Processing array at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $element = $InputObject[$i]
                $currentElementPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                # Pass ParentIsExcluded status to array elements
                $resultArray += Invoke-RecursiveEncryption -InputObject $element -ExcludeFields $ExcludeFields -ParentPath $currentElementPath -ParentIsExcluded $ParentIsExcluded
            }
            return $resultArray
        }
        elseif ($InputObject -is [hashtable])
        {
            Write-Verbose "[ENCRYPT] Processing hashtable at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
        
            # Process hashtable by enumerating through the key-value pairs directly
            foreach ($entry in $InputObject.GetEnumerator())
            {
                $key = $entry.Key
                $value = $entry.Value
            
                Write-Verbose "[ENCRYPT] Processing hashtable key '$key' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[ENCRYPT] Value type: $($value.GetType().FullName)"
                Write-Verbose "[ENCRYPT] Value: $value"
            
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$key" 
                }
                else
                {
                    $key 
                }
            
                $isPropertyItselfExcluded = $ExcludeFields -contains $key
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[ENCRYPT] Hashtable key: '$key' at path '$currentPropertyPath'. KeyItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($null -eq $value)
                {
                    Write-Verbose "[ENCRYPT] Hashtable key '$key' has null value. Assigning null."
                    $result[$key] = $null
                }
                elseif ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$key] = Invoke-RecursiveEncryption -InputObject $value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[ENCRYPT] Hashtable key '$key' is effectively excluded. Assigning original value."
                    $result[$key] = $value
                }
                else # Not effectively excluded, encrypt appropriate types
                {
                    # Encrypt strings, numbers, booleans. Other complex types not directly handled here will be returned as-is by the final 'else'.
                    if ($value -is [string] -or $value -is [int] -or $value -is [bool] -or $value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}" -f $currentPropertyPath)
                        $stringValue = $value.ToString() # Convert boolean/numbers to string before encoding
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$key] = $encodedValue
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPropertyPath, $encodedValue)
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Hashtable key '$key' value type '$($value.GetType().FullName)' not directly encrypted. Assigning original value."
                        $result[$key] = $value
                    }
                }
            }
        
            return $result
        }
        elseif ($InputObject -is [PSCustomObject])
        {
            Write-Verbose "[ENCRYPT] Processing object at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[ENCRYPT] Processing property '$($prop.Name)' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[ENCRYPT] Property type: $($prop.Value.GetType().FullName)"
                if ($prop.Name -in $excludeFields)
                {
                    Write-Verbose "[ENCRYPT] Property value: $($prop.Value)"    
                }
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                $isPropertyItselfExcluded = $ExcludeFields -contains $prop.Name
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded
                Write-Verbose "[ENCRYPT] Property: '$($prop.Name)' at path '$currentPropertyPath'. PropItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"
                if ($null -eq $prop.Value)
                {
                    Write-Verbose "[ENCRYPT] Property '$($prop.Name)' is null. Assigning null."
                    $result[$prop.Name] = $null
                }
                elseif ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[ENCRYPT] Property '$($prop.Name)' is effectively excluded. Assigning original value."
                    $result[$prop.Name] = $prop.Value
                }
                else # Not effectively excluded, encrypt appropriate types
                {
                    # Encrypt strings, numbers, booleans. Other complex types not directly handled here will be returned as-is by the final 'else'.
                    if ($prop.Value -is [string] -or $prop.Value -is [int] -or $prop.Value -is [bool] -or $prop.Value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}" -f $currentPropertyPath)
                        $stringValue = $prop.Value.ToString() # Convert boolean/numbers to string before encoding
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$prop.Name] = $encodedValue
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPropertyPath, 'redacted')
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Property '$($prop.Name)' type '$($prop.Value.GetType().FullName)' not directly encrypted. Assigning original value."
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            return [PSCustomObject]$result
        }
        # Handle standalone primitive types (e.g., a string/number/bool element directly in an array)
        elseif (($InputObject -is [string] -or $InputObject -is [int] -or $InputObject -is [bool] -or $InputObject -is [double]))
        {
            if ($ParentIsExcluded) # If the parent (e.g. an array holding this primitive) was excluded
            {
                Write-Verbose "[ENCRYPT] Primitive value at path '$ParentPath' is part of an excluded parent. Returning as-is."
                return $InputObject
            }
            else
            {
                Write-Verbose ("[ENCRYPT] Encrypting primitive value at path '{0}'" -f $ParentPath)
                $stringValuePrim = $InputObject.ToString()
                $encodedValuePrim = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValuePrim))
                Write-Verbose ("[ENCRYPT] Encrypted primitive value at path '{0}': {1}" -f $ParentPath, $encodedValuePrim)
                return $encodedValuePrim
            }
        }
        else # Other types not explicitly handled (e.g. custom objects not PSCustomObject/hashtable, or other primitive types if any), return as is.
        {
            Write-Verbose "[ENCRYPT] Value type '$($InputObject.GetType().FullName)' at path '$ParentPath' not processed for encryption. Returning as-is."
            return $InputObject
        }
    }

    $result = Invoke-RecursiveEncryption -InputObject $decryptedObject -ExcludeFields $excludeFields
    
    if ($null -eq $result)
    {
        Write-Error 'No values were encrypted.'
        return $null
    }
    
    Write-Verbose "Encryption complete"
    return $result
}

function DecryptAndEncrypt()
{
    param (
        $data,
        [string[]]$excludeFields = $excludeFields,
        [string]$operation
    )
    
    # ### Main script ###
    if ($operation -eq 'encrypt')
    {
        if (isEncrypted -data $data)
        {
            Write-Host 'The data is already encrypted.'
            Write-Host 'Nothing to do.'
            exit
        }
        $encodedData = EncryptObject -decryptedObject $data -excludeFields $excludeFields
    }
    elseif ($operation -eq 'decrypt')
    {
        if (!(isEncrypted -data $data))
        {
            Write-Host 'The data is already decrypted.'
            Write-Host 'Nothing to do.'
            exit
        }
        $encodedData = DecryptObject -encryptedObject $data -excludeFields $excludeFields
    }
    elseif ($operation -eq 'check')
    {
        if (isEncrypted -data $data)
        {
            Write-Host 'The data is encrypted.'
        }
        else
        {
            Write-Host "The data in $inputFile is not encrypted."
        }
        exit
    }
    else
    {
        Write-Error 'No operation was specified.'
        exit
    }


    #make sure the output file exists.  If so, prompt to overwrite., otherwise create, unless the Force switch is set.
    if (Test-Path $outputFile)
    {
        if ($Force)
        {
            Clear-Content -Path $OutputFile
        }
        else
        {
            $overwrite = Read-Host -Prompt "The file $outputFile already exists.  Do you want to overwrite it? (Y/N)"
            if ($overwrite -eq 'Y')
            {
                Clear-Content -Path $OutputFile
            }
            else
            {
                Write-Host "The file $outputFile was not overwritten.  Exiting."
                exit
            }
        }
    }
    else
    {
        New-Item -Path $OutputFile -ItemType File -Force | Out-Null
    }


    #write the encoded data to the output file if it is not null.
    if ($encodedData)
    {
        Write-Host "Processing data in $inputFile"
        Write-Host "Writing data to $outputFile"
        Write-Verbose "The encoded data is: $($encodedData | ConvertTo-Json)"
       
        $encodedData | ConvertTo-Json | Set-Content -Path $outputFile -ErrorAction Stop
        Write-Host 'Data processed successfully.'
    }
    else
    {
        Write-Host 'No data was processed.'
        exit
    }
}
#endregion Encryption functions
