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
    $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -UseStoredPassword
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
        encrypted     = $true
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
            $result.encrypted = $loadResult.encrypted
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

