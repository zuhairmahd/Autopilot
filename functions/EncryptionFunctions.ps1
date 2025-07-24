function Load-EncryptedConfigFile()
{
    <#
    .SYNOPSIS
    Loads and decrypts an encrypted configuration file with retry logic.
    
    .DESCRIPTION
    This function handles the complete process of loading an encrypted configuration file,
    including checking encryption status, prompting for password with retry logic,
    decrypting the file, and returning the configuration content.
    
    .PARAMETER ConfigFile
    Path to the configuration file to load.
    
    .PARAMETER MaxRetries
    Maximum number of password attempts allowed. Defaults to 3.
    
    .PARAMETER UseStoredPassword
    If specified, attempts to use the stored password from $script:UserEncryptionPassword.
    
    .PARAMETER PasswordPrompt
    Custom prompt message for password input.
    
    .OUTPUTS
    System.Object
    Returns an object with Success (boolean), Content (string), and ErrorMessage (string) properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile,
        
        [int]$MaxRetries = 3,
        
        [switch]$UseStoredPassword,
        
        [string]$PasswordPrompt = "Enter your password"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Loading encrypted configuration file: $ConfigFile" -LogLevel "Debug"
    Write-Verbose "[$functionName] Loading encrypted configuration file: $ConfigFile"
    
    $result = @{
        Success      = $false
        Content      = ""
        ErrorMessage = ""
    }
    
    try
    {
        # Check if file exists
        if (-not (Test-Path $ConfigFile))
        {
            $result.ErrorMessage = "Configuration file not found: $ConfigFile"
            Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
            return $result
        }
        
        # Check encryption status
        $encryptionStatus = Test-FileEncryptionStatus -FilePath $ConfigFile
        
        if (-not $encryptionStatus.IsValidFile)
        {
            $result.ErrorMessage = "Configuration file exists but cannot be read: $($encryptionStatus.ErrorMessage)"
            Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
            return $result
        }
        
        if ($encryptionStatus.IsEncrypted)
        {
            # Write-Host "Please enter your password to continue." -ForegroundColor Cyan
            Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file is encrypted, prompting for password" -LogLevel "Information"
            
            $retryCount = 0
            $decryptResult = $null
            
            do
            {
                $retryCount++
                Write-Verbose "[$functionName] Password attempt $retryCount of $MaxRetries"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Password attempt $retryCount of $MaxRetries" -LogLevel "Debug"
                
                # Get the password
                $userPassword = $null
                if ($UseStoredPassword -and ($script:UserEncryptionPassword -or $global:UserEncryptionPassword))
                {
                    Write-Verbose "[$functionName] Using stored password from session"
                    $userPassword = if ($script:UserEncryptionPassword) { $script:UserEncryptionPassword } else { $global:UserEncryptionPassword }
                }
                else
                {
                    # Prompt for password
                    $userPasswordSecure = Get-SecurePassword -Message "$PasswordPrompt (Attempt $retryCount of $MaxRetries)"
                    $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
                }
                
                # Decrypt the file in memory
                $decryptResult = Invoke-JsonFileEncryption -FilePath $ConfigFile -Key $userPassword -Decrypt -InMemoryOnly
                
                if ($decryptResult.Success)
                {
                    Write-Verbose "[$functionName] Configuration file decrypted successfully."
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file decrypted successfully" -LogLevel "Information"
                    $result.Success = $true
                    $result.Content = $decryptResult.Content
                    
                    # Store the password for session use
                    $script:UserEncryptionPassword = $userPassword
                    $global:UserEncryptionPassword = $userPassword
                    break
                }
                else
                {
                    $errorMsg = "Decryption failed: $($decryptResult.ErrorMessage)"
                    Write-Host $errorMsg -ForegroundColor Red
                    Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Error"
                    
                    if ($retryCount -lt $MaxRetries)
                    {
                        Write-Host "Please try again." -ForegroundColor Yellow
                    }
                }
                
                # Clear the password from memory
                Clear-SecureMemory -Variables @("userPassword")
                
            } while ($retryCount -lt $MaxRetries -and -not $decryptResult.Success)
            
            if (-not $decryptResult.Success)
            {
                $result.ErrorMessage = "Failed to decrypt configuration file after $MaxRetries attempts"
                Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
                Clear-SecureMemory -ClearScriptVariables
                return $result
            }
        }
        else
        {
            # File is not encrypted - read directly
            Write-Verbose "[$functionName] Configuration file is not encrypted, reading directly"
            $result.Content = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
            $result.Success = $true
            Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file read successfully (unencrypted)" -LogLevel "Information"
        }
        
        return $result
        
    }
    catch
    {
        $result.ErrorMessage = "Error loading configuration file: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $result
    }
}

function Setup-TemporaryEncryption()
{
    <#
    .SYNOPSIS
    Sets up temporary encrypted configuration for secure in-memory access.
    
    .DESCRIPTION
    This function creates a temporary encryption key and re-encrypts the configuration
    content for secure in-memory access during the session. This allows configuration
    values to be accessed without repeatedly prompting for the user's password.
    
    .PARAMETER ConfigContent
    The decrypted configuration content to be temporarily encrypted.
    
    .OUTPUTS
    System.Boolean
    Returns $true if temporary encryption was set up successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigContent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Setting up temporary encryption for configuration" -LogLevel "Debug"
    Write-Verbose "[$functionName] Setting up temporary encryption for configuration"
    
    try
    {
        # Generate a random temporary encryption key
        $tempEncryptionKey = [System.Guid]::NewGuid().ToString() + [System.Guid]::NewGuid().ToString()
        Write-Log -LogFile $LogFile -Module $functionName -Message "Generated temporary encryption key" -LogLevel "Debug"
        
        # Create a temporary file to encrypt the content
        $tempFile = [System.IO.Path]::GetTempFileName()
        Write-Log -LogFile $LogFile -Module $functionName -Message "Created temporary file for encryption" -LogLevel "Debug"
        
        try
        {
            Set-Content -Path $tempFile -Value $ConfigContent -Encoding UTF8
            $tempEncryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $tempEncryptionKey -InMemoryOnly
            
            if ($tempEncryptResult.Success)
            {
                Write-Verbose "[$functionName] Content re-encrypted with temporary key for in-memory use"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Content re-encrypted with temporary key for in-memory use" -LogLevel "Debug"
                
                # Store the encrypted content for later use during the session
                $script:TempEncryptedConfig = $tempEncryptResult.Content
                $script:TempEncryptionKey = $tempEncryptionKey
                
                return $true
            }
            else
            {
                Write-Warning "Failed to re-encrypt content with temporary key: $($tempEncryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to re-encrypt content with temporary key: $($tempEncryptResult.ErrorMessage)" -LogLevel "Error"
                return $false
            }
        }
        finally
        {
            # Clean up temporary file
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch
    {
        Write-Warning "Error during temporary encryption setup: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error during temporary encryption setup: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }
    finally
    {
        # Clear the temporary encryption key from memory
        Clear-SecureMemory -Variables @("tempEncryptionKey")
    }
}

function Clear-SecureMemory()
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

function Get-SecurePassword()
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
    $password = Get-SecurePassword -Message "Enter your password" -RequireConfirmation
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

function Get-DecryptedConfigValue()
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

function Get-AuthConfigValue()
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

function ConvertFrom-SecureString-ToPlainText()
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

function Test-FileEncryptionStatus()
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

function Initialize-ConfigurationSession()
{
    <#
    .SYNOPSIS
    Initializes a configuration session by loading and setting up encryption.
    
    .DESCRIPTION
    This function consolidates the repeated pattern of loading an encrypted configuration file,
    setting up temporary encryption, and parsing the configuration content. It provides
    a consistent way to handle configuration loading across different contexts in main.ps1.
    
    .PARAMETER ConfigFile
    Path to the encrypted configuration file to load.
    
    .PARAMETER MaxRetries
    Maximum number of password attempts allowed. Defaults to 3.
    
    .PARAMETER UseStoredPassword
    If specified, attempts to use the stored password from $script:UserEncryptionPassword.
    
    .PARAMETER PasswordPrompt
    Custom prompt message for password input.
    
    .OUTPUTS
    System.Object
    Returns an object with Success (boolean), ConfigContent (string), ParsedConfig (object),
    Domain (string), AppId (string), TenantId (string), Name (string), and ErrorMessage (string) properties.
    
    .EXAMPLE
    $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries 3 -UseStoredPassword
    if ($sessionResult.Success) {
        $domain = $sessionResult.Domain
        $configContent = $sessionResult.ConfigContent
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile,
        
        [int]$MaxRetries = 3,
        
        [switch]$UseStoredPassword,
        
        [string]$PasswordPrompt = "Enter your password"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Initializing configuration session for: $ConfigFile" -LogLevel "Debug"
    Write-Verbose "[$functionName] Initializing configuration session for: $ConfigFile"
    
    $result = @{
        Success       = $false
        ConfigContent = ""
        ParsedConfig  = $null
        Domain        = ""
        AppId         = ""
        TenantId      = ""
        Name          = ""
        ErrorMessage  = ""
    }
    
    try
    {
        # Load the encrypted configuration file
        $loadResult = Load-EncryptedConfigFile -ConfigFile $ConfigFile -MaxRetries $MaxRetries -UseStoredPassword:$UseStoredPassword -PasswordPrompt $PasswordPrompt
        
        if (-not $loadResult.Success)
        {
            $result.ErrorMessage = $loadResult.ErrorMessage
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to load configuration file: $($loadResult.ErrorMessage)" -LogLevel "Error"
            return $result
        }
        
        $configContent = $loadResult.Content
        $result.ConfigContent = $configContent
        
        # Setup temporary encryption for in-memory access
        $tempEncryptionResult = Setup-TemporaryEncryption -ConfigContent $configContent
        if (-not $tempEncryptionResult)
        {
            Write-Warning "Temporary encryption setup failed, some features may not work properly"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Temporary encryption setup failed" -LogLevel "Warning"
        }
        
        # Parse the configuration content
        try
        {
            $configJson = ConvertFrom-Json $configContent
            $result.ParsedConfig = $configJson
            $result.Domain = $configJson.domain
            $result.AppId = $configJson.appId
            $result.TenantId = $configJson.tenantId
            $result.Name = $configJson.name
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration session initialized successfully for domain: $($result.Domain)" -LogLevel "Information"
            $result.Success = $true
        }
        catch
        {
            $result.ErrorMessage = "Failed to parse configuration JSON: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
            return $result
        }
        
        # Clear the config content from memory (caller should use result.ConfigContent if needed)
        $configContent = $null
        
        return $result
    }
    catch
    {
        $result.ErrorMessage = "Error during configuration session initialization: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
        return $result
    }
}

function Invoke-PasswordChangeProcess()
{
    <#
    .SYNOPSIS
    Prompts user to change their decryption password and re-encrypts the config file.
    
    .DESCRIPTION
    This function handles the password change process when auth.changePWOnNextStart is true.
    It prompts the user for a new password, re-encrypts the config file with the new password,
    and updates the settings.json file to set changePWOnNextStart to false.
    
    .PARAMETER ConfigFile
    Path to the encrypted configuration file to re-encrypt.
    
    .PARAMETER ConfigContent
    The decrypted configuration content to re-encrypt.
    
    .PARAMETER SettingsFile
    Path to the settings.json file to update.
    
    .PARAMETER NewPassword
    Optional parameter for testing - if provided, skips interactive password prompt.
    
    .OUTPUTS
    System.Boolean
    Returns $true if password change was successful, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile,
        
        [Parameter(Mandatory = $true)]
        [string]$ConfigContent,
        
        [Parameter(Mandatory = $true)]
        [string]$SettingsFile,
        
        [Parameter(Mandatory = $false)]
        [string]$NewPassword
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting password change process" -LogLevel "Information"
    Write-Host "`nPassword Change Required" -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Yellow
    Write-Host "Your administrator has requested that you change your decryption password." -ForegroundColor Cyan
    Write-Host "Please enter a new password to secure your configuration file." -ForegroundColor Cyan
    Write-Host ""
    
    try
    {
        # Get new password - either from parameter (for testing) or prompt user
        if ($NewPassword)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Using provided password for testing" -LogLevel "Debug"
            $newPassword = $NewPassword
        }
        else
        {
            # Prompt for new password with confirmation
            Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting user for new password" -LogLevel "Debug"
            $newPasswordSecure = Get-SecurePassword -Message "Enter your new encryption password" -RequireConfirmation -MinLength 8
            $newPassword = ConvertFrom-SecureString-ToPlainText -SecureString $newPasswordSecure
        }
        
        # Create backup of config file
        $backupPath = "$ConfigFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Creating backup at: $backupPath" -LogLevel "Debug"
        Copy-Item -Path $ConfigFile -Destination $backupPath -Force
        Write-Verbose "[$functionName] Backup created at: $backupPath"
        
        # Re-encrypt the config file with new password
        Write-Host "Re-encrypting configuration file with new password..." -ForegroundColor Cyan
        Write-Log -LogFile $LogFile -Module $functionName -Message "Re-encrypting config file with new password" -LogLevel "Information"
        
        # First write the unencrypted content to a temp file
        $tempFile = [System.IO.Path]::GetTempFileName()
        try
        {
            Set-Content -Path $tempFile -Value $ConfigContent -Encoding UTF8 -NoNewline
            
            # Encrypt with new password
            $encryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $newPassword
            
            if ($encryptResult.Success)
            {
                # Copy encrypted content to original config file
                $encryptedContent = Get-Content -Path $tempFile -Raw -Encoding UTF8
                Set-Content -Path $ConfigFile -Value $encryptedContent -Encoding UTF8 -NoNewline
                
                Write-Host "Configuration file re-encrypted successfully" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file re-encrypted successfully" -LogLevel "Information"
            }
            else
            {
                Write-Host "Failed to re-encrypt configuration file: $($encryptResult.ErrorMessage)" -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to re-encrypt configuration file: $($encryptResult.ErrorMessage)" -LogLevel "Error"
                
                # Restore backup
                Copy-Item -Path $backupPath -Destination $ConfigFile -Force
                return $false
            }
        }
        finally
        {
            # Clean up temp file
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Update settings.json to set changePWOnNextStart to false
        Write-Host "Updating settings..." -ForegroundColor Cyan
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updating settings.json to disable changePWOnNextStart" -LogLevel "Information"
        
        if (Test-Path $SettingsFile)
        {
            try
            {
                $settingsContent = Get-Content -Path $SettingsFile -Raw -Encoding UTF8
                $settings = ConvertFrom-Json $settingsContent
                
                # Update the changePWOnNextStart setting
                if ($settings.auth -and $settings.auth.PSObject.Properties.Name -contains 'changePWOnNextStart')
                {
                    $settings.auth.changePWOnNextStart = $false
                    
                    # Write updated settings back to file
                    $updatedSettingsJson = ConvertTo-Json $settings -Depth 100
                    Set-Content -Path $SettingsFile -Value $updatedSettingsJson -Encoding UTF8
                    
                    Write-Host "Settings updated successfully" -ForegroundColor Green
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Settings.json updated successfully - changePWOnNextStart set to false" -LogLevel "Information"
                }
                else
                {
                    Write-Warning "changePWOnNextStart setting not found in auth section"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "changePWOnNextStart setting not found in auth section" -LogLevel "Warning"
                }
            }
            catch
            {
                Write-Host "Failed to update settings file: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to update settings file: $($_.Exception.Message)" -LogLevel "Error"
                return $false
            }
        }
        else
        {
            Write-Warning "Settings file not found: $SettingsFile"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Settings file not found: $SettingsFile" -LogLevel "Warning"
        }
        
        # Update stored password in session
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updating session password variables" -LogLevel "Debug"
        $script:UserEncryptionPassword = $newPassword
        $global:UserEncryptionPassword = $newPassword
        
        # Clean up the new password from memory
        Clear-SecureMemory -Variables @("newPassword")
        
        # Remove backup file if everything succeeded
        if (Test-Path $backupPath)
        {
            Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
            Write-Log -LogFile $LogFile -Module $functionName -Message "Backup file cleaned up" -LogLevel "Debug"
        }
        
        Write-Host "Password change completed successfully!" -ForegroundColor Green
        Write-Host "Your configuration file is now secured with your new password." -ForegroundColor Cyan
        Write-Host ""
        Write-Log -LogFile $LogFile -Module $functionName -Message "Password change process completed successfully" -LogLevel "Information"
        
        return $true
    }
    catch
    {
        Write-Host "Password change failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Password change failed: $($_.Exception.Message)" -LogLevel "Error"
        
        # Restore backup if it exists
        $backupPath = "$ConfigFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path $backupPath)
        {
            Copy-Item -Path $backupPath -Destination $ConfigFile -Force
            Write-Host "Configuration file restored from backup" -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file restored from backup" -LogLevel "Information"
        }
        
        # Clear sensitive data from memory
        Clear-SecureMemory -Variables @("newPassword")
        
        return $false
    }
}

function Invoke-JsonFileEncryption()
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

