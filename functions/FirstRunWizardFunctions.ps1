function Start-FirstRunWizard {
    <#
    .SYNOPSIS
        Launches the first run wizard to set up initial configuration for the Autopilot application.
    
    .DESCRIPTION
        This function guides users through the initial setup process by prompting for essential configuration
        parameters and creating the necessary configuration files. It handles:
        - App ID, Tenant ID, Domain Name, and Application Name collection
        - Authentication type selection (delegated vs application)
        - App secret or certificate thumbprint for delegated authentication
        - Configuration file creation and encryption
        - Default settings.json and strings.json creation if missing
    
    .PARAMETER ConfigFile
        Path to the config.json file to be created. Defaults to ".secrets\config.json".
    
    .PARAMETER SettingsFile
        Path to the settings.json file. Defaults to "settings.json".
    
    .PARAMETER StringsFile
        Path to the strings.json file. Defaults to "strings.json".
    
    .PARAMETER Silent
        If specified, skips interactive prompts and uses default values where possible.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the wizard completed successfully, $false otherwise.
    
    .EXAMPLE
        Start-FirstRunWizard
        
        Launches the wizard with default file paths.
    
    .EXAMPLE
        Start-FirstRunWizard -ConfigFile "C:\Config\.secrets\config.json" -SettingsFile "C:\Config\settings.json"
        
        Launches the wizard with custom file paths.
    
    .NOTES
        - Requires Write-Log function for logging
        - Uses existing encryption functions for config.json protection
        - Maintains PowerShell 5.1 compatibility
        - Provides comprehensive error handling and validation
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigFile = "$PWD\.secrets\config.json",
        [string]$SettingsFile = "$PWD\settings.json",  
        [string]$StringsFile = "$PWD\strings.json",
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Helper function for safe logging
    function Write-SafeLog {
        param($Message, $LogLevel = "Information")
        if ($script:LogFile -and (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            Write-Log -Message $Message -LogFile $script:LogFile -Module $functionName -LogLevel $LogLevel
        }
        Write-Verbose "[$functionName] $Message"
    }
    
    Write-SafeLog "Starting First Run Wizard" "Information"
    Write-Verbose "[$functionName] Starting First Run Wizard"
    
    try {
        # Display welcome message
        if (-not $Silent) {
            Write-Host "`n" -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "                    Welcome to the Autopilot First Run Wizard                  " -ForegroundColor Green  
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "`nThis wizard will help you set up your Autopilot application configuration." -ForegroundColor White
            Write-Host "Please have the following information ready:" -ForegroundColor White
            Write-Host "• Application ID (from Azure AD)" -ForegroundColor White
            Write-Host "• Tenant ID (from Azure AD)" -ForegroundColor White
            Write-Host "• Domain Name" -ForegroundColor White
            Write-Host "• Application Name" -ForegroundColor White
            Write-Host "• Authentication details (app secret or certificate)" -ForegroundColor White
            Write-Host "`nPress Enter to continue or Ctrl+C to exit..." -ForegroundColor Yellow
            Read-Host
        }
        
        # Step 1: Collect basic configuration
        Write-SafeLog "Collecting basic configuration parameters" "Information"
        $config = Get-BasicConfigurationFromUser -Silent:$Silent
        
        if (-not $config) {
            Write-SafeLog "Failed to collect basic configuration" "Error"
            return $false
        }
        
        # Step 2: Collect authentication configuration
        Write-SafeLog "Collecting authentication configuration" "Information"
        $authConfig = Get-AuthenticationConfigurationFromUser -Silent:$Silent
        
        if (-not $authConfig) {
            Write-SafeLog "Failed to collect authentication configuration" "Error"
            return $false
        }
        
        # Step 3: Merge configurations
        $finalConfig = @{
            domain = $config.domain
            TenantId = $config.TenantId
            AppId = $config.AppId
            AppSecret = $authConfig.AppSecret
            Thumbprint = $authConfig.Thumbprint
            Subject = $authConfig.Subject
        }
        
        # Step 4: Create and encrypt configuration file
        Write-SafeLog "Creating configuration file at: $ConfigFile" "Information"
        $configCreated = New-ConfigurationFile -ConfigFile $ConfigFile -ConfigData $finalConfig -Silent:$Silent
        
        if (-not $configCreated) {
            Write-SafeLog "Failed to create configuration file" "Error"
            return $false
        }
        
        # Step 5: Ensure settings.json exists with defaults
        Write-SafeLog "Ensuring settings.json exists with defaults" "Information"
        $settingsCreated = Ensure-SettingsJsonExists -SettingsFile $SettingsFile -Silent:$Silent -AuthType $authConfig.AuthType -IsDelegated $authConfig.IsDelegated
        
        if (-not $settingsCreated) {
            Write-SafeLog "Failed to ensure settings.json exists" "Warning"
        }
        
        # Step 6: Ensure strings.json exists with defaults
        Write-SafeLog "Ensuring strings.json exists with defaults" "Information"
        $stringsCreated = Ensure-StringsJsonExists -StringsFile $StringsFile -Silent:$Silent
        
        if (-not $stringsCreated) {
            Write-SafeLog "Failed to ensure strings.json exists" "Warning"
        }
        
        # Step 7: Display completion message
        if (-not $Silent) {
            Write-Host "`n" -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "                          Setup Complete!                                       " -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "`nYour Autopilot application has been configured successfully." -ForegroundColor White
            Write-Host "Configuration files created:" -ForegroundColor White
            Write-Host "• $ConfigFile (encrypted)" -ForegroundColor Green
            Write-Host "• $SettingsFile" -ForegroundColor Green
            Write-Host "• $StringsFile" -ForegroundColor Green
            Write-Host "`nYou can now run the application normally." -ForegroundColor White
        }
        
        Write-SafeLog "First Run Wizard completed successfully" "Information"
        return $true
        
    } catch {
        Write-SafeLog "First Run Wizard failed with error: $($_.Exception.Message)" "Error"
        Write-Host "An error occurred during setup: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error details: $($_.Exception.StackTrace)"
        return $false
    }
}

function Get-BasicConfigurationFromUser {
    <#
    .SYNOPSIS
        Collects basic configuration parameters from the user.
    
    .DESCRIPTION
        Prompts the user for essential configuration parameters including App ID, Tenant ID, 
        Domain Name, and Application Name with validation.
    
    .PARAMETER Silent
        If specified, uses default values where possible.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable containing the collected configuration parameters.
    #>
    [CmdletBinding()]
    param(
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Helper function for safe logging
    function Write-SafeLog {
        param($Message, $LogLevel = "Information")
        if ($script:LogFile -and (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            Write-Log -Message $Message -LogFile $script:LogFile -Module $functionName -LogLevel $LogLevel
        }
        Write-Verbose "[$functionName] $Message"
    }
    
    Write-SafeLog "Collecting basic configuration parameters"
    
    $config = @{}
    
    try {
        if (-not $Silent) {
            Write-Host "`n── Basic Configuration ──" -ForegroundColor Cyan
        }
        
        # Collect App ID
        do {
            if ($Silent) {
                $appId = "00000000-0000-0000-0000-000000000000"
                Write-SafeLog "Using default App ID in silent mode" "Information"
                break
            }
            
            $appId = Read-Host "Enter your Azure AD Application ID (GUID format)"
            
            if ([string]::IsNullOrWhiteSpace($appId)) {
                Write-Host "Application ID cannot be empty. Please try again." -ForegroundColor Red
                continue
            }
            
            # Validate GUID format
            $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
            if ($appId -notmatch $guidPattern) {
                Write-Host "Invalid GUID format. Please enter a valid Application ID." -ForegroundColor Red
                continue
            }
            
            break
        } while ($true)
        
        $config.AppId = $appId
        Write-SafeLog "App ID collected: $appId" "Debug"
        Write-Verbose "[$functionName] App ID collected: $appId"
        
        # Collect Tenant ID
        do {
            if ($Silent) {
                $tenantId = "00000000-0000-0000-0000-000000000000"
                Write-SafeLog "Using default Tenant ID in silent mode" "Information"
                break
            }
            
            $tenantId = Read-Host "Enter your Azure AD Tenant ID (GUID format)"
            
            if ([string]::IsNullOrWhiteSpace($tenantId)) {
                Write-Host "Tenant ID cannot be empty. Please try again." -ForegroundColor Red
                continue
            }
            
            # Validate GUID format
            if ($tenantId -notmatch $guidPattern) {
                Write-Host "Invalid GUID format. Please enter a valid Tenant ID." -ForegroundColor Red
                continue
            }
            
            break
        } while ($true)
        
        $config.TenantId = $tenantId
        if ($LogFile) {
            Write-SafeLog "Tenant ID collected: $tenantId" "Debug"
        }
        Write-Verbose "[$functionName] Tenant ID collected: $tenantId"
        
        # Collect Domain Name
        do {
            if ($Silent) {
                $domain = "example.com"
                Write-SafeLog "Using default domain in silent mode" "Information"
                break
            }
            
            $domain = Read-Host "Enter your domain name (e.g., contoso.com)"
            
            if ([string]::IsNullOrWhiteSpace($domain)) {
                Write-Host "Domain name cannot be empty. Please try again." -ForegroundColor Red
                continue
            }
            
            # Basic domain validation
            $domainPattern = '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
            if ($domain -notmatch $domainPattern) {
                Write-Host "Invalid domain format. Please enter a valid domain name." -ForegroundColor Red
                continue
            }
            
            break
        } while ($true)
        
        $config.domain = $domain
        if ($LogFile) {
            Write-SafeLog "Domain collected: $domain" "Debug"
        }
        Write-Verbose "[$functionName] Domain collected: $domain"
        
        Write-Verbose "[$functionName] Basic configuration collected successfully"
        return $config
        
    } catch {
        Write-SafeLog "Error collecting basic configuration: $($_.Exception.Message)" "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $null
    }
}

function Get-AuthenticationConfigurationFromUser {
    <#
    .SYNOPSIS
        Collects authentication configuration parameters from the user.
    
    .DESCRIPTION
        Prompts the user to choose between delegated and application authentication,
        then collects the appropriate credentials (app secret or certificate details).
    
    .PARAMETER Silent
        If specified, uses delegated authentication with default values.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable containing the authentication configuration.
    #>
    [CmdletBinding()]
    param(
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Helper function for safe logging
    function Write-SafeLog {
        param($Message, $LogLevel = "Information")
        if ($script:LogFile -and (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            Write-Log -Message $Message -LogFile $script:LogFile -Module $functionName -LogLevel $LogLevel
        }
        Write-Verbose "[$functionName] $Message"
    }
    
    Write-SafeLog "Collecting authentication configuration"
    
    $authConfig = @{
        AppSecret = ""
        Thumbprint = ""
        Subject = ""
        AuthType = ""
        IsDelegated = $true
    }
    
    try {
        if (-not $Silent) {
            Write-Host "`n── Authentication Configuration ──" -ForegroundColor Cyan
            Write-Host "Choose your authentication method:" -ForegroundColor White
            Write-Host "1. Delegated Authentication (recommended for interactive use)" -ForegroundColor White
            Write-Host "2. Application Authentication (for service/daemon scenarios)" -ForegroundColor White
        }
        
        # Get authentication type
        $authType = ""
        if ($Silent) {
            $authType = "1"
            Write-SafeLog "Using delegated authentication in silent mode" "Information"
        } else {
            do {
                $authType = Read-Host "Enter your choice (1 or 2)"
                if ($authType -in @("1", "2")) {
                    break
                }
                Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
            } while ($true)
        }
        
        Write-SafeLog "Authentication type selected: $authType" "Debug"
        
        # Set authentication type flags
        if ($authType -eq "1") {
            $authConfig.AuthType = "Delegated"
            $authConfig.IsDelegated = $true
        } else {
            $authConfig.AuthType = "Application"
            $authConfig.IsDelegated = $false
        }
        
        if ($authType -eq "1") {
            # Delegated Authentication
            if (-not $Silent) {
                Write-Host "`nDelegated Authentication Selected" -ForegroundColor Green
                Write-Host "Choose your credential type:" -ForegroundColor White
                Write-Host "1. App Secret" -ForegroundColor White
                Write-Host "2. Certificate (Thumbprint)" -ForegroundColor White
            }
            
            $credType = ""
            if ($Silent) {
                $credType = "1"
                Write-SafeLog "Using app secret in silent mode" "Information"
            } else {
                do {
                    $credType = Read-Host "Enter your choice (1 or 2)"
                    if ($credType -in @("1", "2")) {
                        break
                    }
                    Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
                } while ($true)
            }
            
            if ($credType -eq "1") {
                # App Secret
                if ($Silent) {
                    $authConfig.AppSecret = "default_app_secret_placeholder"
                    Write-SafeLog "Using default app secret in silent mode" "Information"
                } else {
                    do {
                        $appSecret = Read-Host "Enter your App Secret" -AsSecureString
                        $appSecretPlain = ConvertFrom-SecureString-ToPlainText -SecureString $appSecret
                        
                        if ([string]::IsNullOrWhiteSpace($appSecretPlain)) {
                            Write-Host "App Secret cannot be empty. Please try again." -ForegroundColor Red
                            continue
                        }
                        
                        $authConfig.AppSecret = $appSecretPlain
                        break
                    } while ($true)
                }
            } else {
                # Certificate
                if ($Silent) {
                    $authConfig.Thumbprint = "0000000000000000000000000000000000000000"
                    $authConfig.Subject = "CN=DefaultCertificate"
                    Write-SafeLog "Using default certificate in silent mode" "Information"
                } else {
                    do {
                        $thumbprint = Read-Host "Enter your Certificate Thumbprint"
                        
                        if ([string]::IsNullOrWhiteSpace($thumbprint)) {
                            Write-Host "Certificate Thumbprint cannot be empty. Please try again." -ForegroundColor Red
                            continue
                        }
                        
                        # Validate thumbprint format (40 hex characters)
                        $thumbprintPattern = '^[0-9a-fA-F]{40}$'
                        if ($thumbprint -notmatch $thumbprintPattern) {
                            Write-Host "Invalid thumbprint format. Please enter a valid 40-character hex string." -ForegroundColor Red
                            continue
                        }
                        
                        $authConfig.Thumbprint = $thumbprint
                        break
                    } while ($true)
                    
                    do {
                        $subject = Read-Host "Enter your Certificate Subject (e.g., CN=MyCertificate)"
                        
                        if ([string]::IsNullOrWhiteSpace($subject)) {
                            Write-Host "Certificate Subject cannot be empty. Please try again." -ForegroundColor Red
                            continue
                        }
                        
                        $authConfig.Subject = $subject
                        break
                    } while ($true)
                }
            }
        } else {
            # Application Authentication - still needs credentials
            if (-not $Silent) {
                Write-Host "`nApplication Authentication Selected" -ForegroundColor Green
                Write-Host "Choose your credential type:" -ForegroundColor White
                Write-Host "1. App Secret" -ForegroundColor White
                Write-Host "2. Certificate (Thumbprint)" -ForegroundColor White
            }
            
            $credType = ""
            if ($Silent) {
                $credType = "1"
                Write-SafeLog "Using app secret for application authentication in silent mode" "Information"
            } else {
                do {
                    $credType = Read-Host "Enter your choice (1 or 2)"
                    if ($credType -in @("1", "2")) {
                        break
                    }
                    Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
                } while ($true)
            }
            
            if ($credType -eq "1") {
                # App Secret
                if ($Silent) {
                    $authConfig.AppSecret = "default_app_secret_placeholder"
                    Write-SafeLog "Using default app secret for application authentication in silent mode" "Information"
                } else {
                    do {
                        $appSecret = Read-Host "Enter your App Secret" -AsSecureString
                        $appSecretPlain = ConvertFrom-SecureString-ToPlainText -SecureString $appSecret
                        
                        if ([string]::IsNullOrWhiteSpace($appSecretPlain)) {
                            Write-Host "App Secret cannot be empty. Please try again." -ForegroundColor Red
                            continue
                        }
                        
                        $authConfig.AppSecret = $appSecretPlain
                        break
                    } while ($true)
                }
            } else {
                # Certificate
                if ($Silent) {
                    $authConfig.Thumbprint = "0000000000000000000000000000000000000000"
                    $authConfig.Subject = "CN=DefaultCertificate"
                    Write-SafeLog "Using default certificate for application authentication in silent mode" "Information"
                } else {
                    do {
                        $thumbprint = Read-Host "Enter your Certificate Thumbprint"
                        
                        if ([string]::IsNullOrWhiteSpace($thumbprint)) {
                            Write-Host "Certificate Thumbprint cannot be empty. Please try again." -ForegroundColor Red
                            continue
                        }
                        
                        $authConfig.Thumbprint = $thumbprint
                        break
                    } while ($true)
                    
                    do {
                        $subject = Read-Host "Enter your Certificate Subject (e.g., CN=MyCertificate)"
                        
                        if ([string]::IsNullOrWhiteSpace($subject)) {
                            Write-Host "Certificate Subject cannot be empty. Please try again." -ForegroundColor Red
                            continue
                        }
                        
                        $authConfig.Subject = $subject
                        break
                    } while ($true)
                }
            }
        }
        
        Write-Verbose "[$functionName] Authentication configuration collected successfully"
        return $authConfig
        
    } catch {
        Write-SafeLog "Error collecting authentication configuration: $($_.Exception.Message)" "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $null
    }
}

function New-ConfigurationFile {
    <#
    .SYNOPSIS
        Creates and encrypts a new configuration file with the provided data.
    
    .DESCRIPTION
        Creates a new config.json file with the provided configuration data,
        then encrypts it using the encryption functions.
    
    .PARAMETER ConfigFile
        Path to the configuration file to create.
    
    .PARAMETER ConfigData
        Hashtable containing the configuration data.
    
    .PARAMETER Silent
        If specified, uses default encryption password.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the file was created successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,
        
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating configuration file: $ConfigFile"
    
    try {
        # Ensure the directory exists
        $configDir = Split-Path -Path $ConfigFile -Parent
        if (-not (Test-Path -Path $configDir)) {
            Write-Verbose "[$functionName] Creating directory: $configDir"
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            Write-SafeLog "Created directory: $configDir" "Information"
        }
        
        # Create the configuration JSON
        $configJson = $ConfigData | ConvertTo-Json -Depth 10
        
        # Write the configuration to file
        Write-Verbose "[$functionName] Writing configuration to file"
        Set-Content -Path $ConfigFile -Value $configJson -Encoding UTF8 -Force
        Write-SafeLog "Configuration file created: $ConfigFile" "Information"
        
        # Encrypt the file
        if (-not $Silent) {
            Write-Host "`n── Encryption Setup ──" -ForegroundColor Cyan
            Write-Host "Your configuration file needs to be encrypted for security." -ForegroundColor White
        }
        
        $encryptionPassword = ""
        if ($Silent) {
            $encryptionPassword = "DefaultPassword123!"
            Write-SafeLog "Using default encryption password in silent mode" "Information"
        } else {
            do {
                $encryptionPasswordSecure = Read-Host -Prompt "Enter a password to encrypt your configuration file" -AsSecureString
                
                # Validate password is not empty
                if ($encryptionPasswordSecure.Length -eq 0) {
                    Write-Host "Encryption password cannot be empty. Please try again." -ForegroundColor Red
                    continue
                }
                
                # Convert to plain text for length validation
                $encryptionPassword = ConvertFrom-SecureString-ToPlainText -SecureString $encryptionPasswordSecure
                
                if ($encryptionPassword.Length -lt 8) {
                    Write-Host "Password must be at least 8 characters long. Please try again." -ForegroundColor Red
                    continue
                }
                
                # Get confirmation
                $confirmPasswordSecure = Read-Host -Prompt "Confirm password" -AsSecureString
                $confirmPassword = ConvertFrom-SecureString-ToPlainText -SecureString $confirmPasswordSecure
                
                if ($encryptionPassword -ne $confirmPassword) {
                    Write-Host "Passwords do not match. Please try again." -ForegroundColor Red
                    continue
                }
                
                # Clear confirmation password from memory
                $confirmPassword = $null
                
                break
            } while ($true)
        }
        
        # Encrypt the configuration file
        Write-Verbose "[$functionName] Encrypting configuration file"
        $encryptResult = Invoke-JsonFileEncryption -FilePath $ConfigFile -Key $encryptionPassword
        
        if ($encryptResult.Success) {
            if (-not $Silent) {
                Write-Host "Configuration file encrypted successfully." -ForegroundColor Green
            }
            Write-SafeLog "Configuration file encrypted successfully" "Information"
            
            # Store the password for session use
            $global:UserEncryptionPassword = $encryptionPassword
            
            return $true
        } else {
            Write-Host "Failed to encrypt configuration file: $($encryptResult.ErrorMessage)" -ForegroundColor Red
            Write-SafeLog "Failed to encrypt configuration file: $($encryptResult.ErrorMessage)" "Error"
            return $false
        }
        
    } catch {
        Write-SafeLog "Error creating configuration file: $($_.Exception.Message)" "Error"
        Write-Host "Error creating configuration file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $false
    } finally {
        # Clear sensitive data from memory
        if ($encryptionPassword) {
            Clear-SecureMemory -Variables @("encryptionPassword")
        }
    }
}

function Ensure-SettingsJsonExists {
    <#
    .SYNOPSIS
        Ensures that settings.json exists with default values.
    
    .DESCRIPTION
        Checks if settings.json exists, and if not, creates it with comprehensive default values
        based on the existing settings structure.
    
    .PARAMETER SettingsFile
        Path to the settings.json file.
    
    .PARAMETER Silent
        If specified, skips confirmation prompts.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the file exists or was created successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsFile,
        
        [switch]$Silent,
        
        [string]$AuthType = "Delegated",
        
        [bool]$IsDelegated = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Ensuring settings.json exists: $SettingsFile"
    
    # Helper function for safe logging
    function Write-SafeLog {
        param($Message, $LogLevel = "Information")
        if ($script:LogFile -and (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            Write-Log -Message $Message -LogFile $script:LogFile -Module $functionName -LogLevel $LogLevel
        }
        Write-Verbose "[$functionName] $Message"
    }
    
    try {
        if (Test-Path -Path $SettingsFile) {
            Write-Verbose "[$functionName] Settings file already exists: $SettingsFile"
            Write-SafeLog "Settings file already exists: $SettingsFile" "Information"
            return $true
        }
        
        if (-not $Silent) {
            Write-Host "`n── Settings Configuration ──" -ForegroundColor Cyan
            Write-Host "Creating default settings.json file..." -ForegroundColor White
        }
        
        # Get the requiredScopes from init.json as the template
        $initJsonPath = "$PWD\init.json"
        $requiredScopes = @()
        if (Test-Path $initJsonPath) {
            try {
                $initData = Get-Content -Path $initJsonPath -Raw | ConvertFrom-Json
                $requiredScopes = $initData | Where-Object { $_.name -eq "requiredScopes" } | Select-Object -ExpandProperty value
                Write-Verbose "[$functionName] Loaded requiredScopes from init.json: $($requiredScopes.Count) scopes"
            } catch {
                Write-SafeLog "Warning: Could not load requiredScopes from init.json: $($_.Exception.Message)" "Warning"
            }
        }
        
        # Create comprehensive settings.json using ordered dictionary
        $settings = [ordered]@{
            description = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
            version = "1.1.0.0"
            auth = [ordered]@{
                Delegated = $IsDelegated
                authType = "PublicAuthFlow"
                renewalLeadTime = 5
                NoSaveRefreshToken = $false
                SecureString = $false
                ForceNewToken = $false
                CacheType = "Memory"
                scope = @(
                    "offline_access",
                    "openid",
                    "Device.ReadWrite.All",
                    "DeviceManagementApps.Read.All",
                    "DeviceManagementConfiguration.ReadWrite.All",
                    "DeviceManagementManagedDevices.PrivilegedOperations.All",
                    "DeviceManagementManagedDevices.ReadWrite.All",
                    "DeviceManagementServiceConfig.ReadWrite.All",
                    "BitlockerKey.Read.All",
                    "User.Read.All"
                )
            }
            globalSettings = [ordered]@{
                operatingSystem = "Windows"
                showLicenseBanner = $true
                testMode = $false
                configFile = ".\.secrets\config.json"
                maxWaitTime = "30"
                maxUserMatchDisplay = "10"
                timeInSeconds = "60"
                Release = "main"
                Repo = "Github"
                appMode = "helpdesk"
            }
            requiredScopes = $requiredScopes
            domains = [ordered]@{}
        }
        
        # Convert to JSON and write to file
        $settingsJson = $settings | ConvertTo-Json -Depth 10
        Set-Content -Path $SettingsFile -Value $settingsJson -Encoding UTF8 -Force
        Write-Verbose "[$functionName] Created comprehensive settings.json with requiredScopes"
        
        $success = $true
        
        if ($success) {
            Write-Host "Settings file created successfully." -ForegroundColor Green
            Write-SafeLog "Settings file created successfully: $SettingsFile" "Information"
            return $true
        } else {
            Write-Host "Failed to create settings file." -ForegroundColor Red
            Write-SafeLog "Failed to create settings file: $SettingsFile" "Error"
            return $false
        }
        
    } catch {
        Write-SafeLog "Error ensuring settings.json exists: $($_.Exception.Message)" "Error"
        Write-Host "Error creating settings file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $false
    }
}

function Ensure-StringsJsonExists {
    <#
    .SYNOPSIS
        Ensures that strings.json exists with default values.
    
    .DESCRIPTION
        Checks if strings.json exists, and if not, creates it with comprehensive default values
        for all user-facing strings.
    
    .PARAMETER StringsFile
        Path to the strings.json file.
    
    .PARAMETER Silent
        If specified, skips confirmation prompts.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the file exists or was created successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StringsFile,
        
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Ensuring strings.json exists: $StringsFile"
    
    # Helper function for safe logging
    function Write-SafeLog {
        param($Message, $LogLevel = "Information")
        if ($script:LogFile -and (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            Write-Log -Message $Message -LogFile $script:LogFile -Module $functionName -LogLevel $LogLevel
        }
        Write-Verbose "[$functionName] $Message"
    }
    
    try {
        if (Test-Path -Path $StringsFile) {
            Write-Verbose "[$functionName] Strings file already exists: $StringsFile"
            Write-SafeLog "Strings file already exists: $StringsFile" "Information"
            return $true
        }
        
        if (-not $Silent) {
            Write-Host "`n── Strings Configuration ──" -ForegroundColor Cyan
            Write-Host "Creating default strings.json file..." -ForegroundColor White
        }
        
        # Create default strings.json using ordered dictionary with comprehensive structure
        $defaultStrings = [ordered]@{
            Description = "This is the strings file for the Intune Helpdesk script. It contains all the user-facing strings used in the script."
            version = "1.1.0.0"
            returnValues = [ordered]@{
                unknownErrorMessage = "An unknown error occurred."
                deviceActionPendingMessage = "The device is pending an action. Turn on the device, make sure it is connected and perform a sync if needed."
                backoutText = "Returning to previous menu"
                invalidFileType = "Invalid file type."
                UpdateCancelledMessage = "The update was cancelled."
                noRestartMessage = "Device not restarted."
                invalidJWTTokenMessage = "Invalid JWT token format. Expected at least 2 parts."
                noLAPSFoundMessage = "No LAPS password found for this device."
                EnrolledMessage = "The device is enrolled."
                notContactedMessage = "The device has not contacted the enrollment service."
                PendingResetMessage = "The device is pending a reset."
                EnrollmentFailedMessage = "The device enrollment failed."
                deviceNotAssignedMessage = "The device is not assigned to a deployment profile."
                deviceAssignmentPendingMessage = "The device is pending assignment to a deployment profile."
                deviceNotInIntuneMessage = "The device is not in Intune."
                noUserDeviceFoundMessage = "No user or device found."
                noUserFoundInDirectoryMessage = "This user does not exist"
                noBitLockerKeysFoundMessage = "No BitLocker keys found for this device."
                noDeviceFound = "No device found"
                deviceAssignedMessage = "The device is assigned to a deployment profile."
                deviceUnknownActionMessage = "The action may still be in progress. You can check the device status in the Intune portal."
                deviceImportSuccessMessage = "The device was imported successfully."
                deviceImportFailedMessage = "The device import failed."
                deviceDeleteSuccessMessage = "The device was deleted successfully."
                deviceDeleteFailedMessage = "The device deletion failed."
                deviceWipeSuccessMessage = "The device was wiped successfully."
                deviceWipeFailedMessage = "The device wipe failed."
                deviceSyncSuccessMessage = "The device sync was successful."
                deviceSyncFailedMessage = "The device sync failed."
                deviceRestartSuccessMessage = "The device was restarted successfully."
                deviceRestartFailedMessage = "The device restart failed."
                deviceCleanSuccessMessage = "The device was cleaned successfully."
                deviceCleanFailedMessage = "The device clean failed."
                serialNumberNotFoundMessage = "The serial number was not found."
                UpdateFailedMessage = "Could not download update."
                noAccessTokenMessage = "Could not obtain an access token. Please check your credentials."
                UpdateSuccessMessage = "The script was updated successfully."
                UpdateNotNeededMessage = "The script is already up to date."
                userCanceledMessage = "Operation canceled by user"
                "999" = "No updates were found"
                "1000" = "All updates were installed"
                "1001" = "Some updates were installed"
                "10002" = "Some updates were installed"
                "1003" = "Updates failed to install"
            }
            deviceStates = [ordered]@{
                Ready = "The device is ready for the next user"
                NotReady = "The device is not ready for the next user"
            }
            deviceActions = [ordered]@{
                none = "No action"
                contactAdmin = "Contact an Intune administrator"
                contactHelpdesk = "Contact the helpdesk"
                WipeOrClean = "Wipe or clean the device"
            }
        }
        
        # Convert to JSON and write to file
        $stringsJson = $defaultStrings | ConvertTo-Json -Depth 10
        Set-Content -Path $StringsFile -Value $stringsJson -Encoding UTF8 -Force
        
        Write-Host "Strings file created successfully." -ForegroundColor Green
        Write-SafeLog "Strings file created successfully: $StringsFile" "Information"
        return $true
        
    } catch {
        Write-SafeLog "Error ensuring strings.json exists: $($_.Exception.Message)" "Error"
        Write-Host "Error creating strings file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $false
    }
}