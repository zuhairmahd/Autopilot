function Get-AuthenticationConfigurationFromUser()
{
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
    
    Write-SafeLog "Collecting authentication configuration"
    
    $authConfig = @{
        AppSecret   = ""
        Thumbprint  = ""
        AuthType    = ""
        IsDelegated = $true
    }
    
    try
    {
        if (-not $Silent)
        {
            Write-Host "`n── Authentication Configuration ──" -ForegroundColor Cyan
            Write-Host "Choose your authentication method:" -ForegroundColor White
            Write-Host "1. Delegated Authentication (recommended for interactive use)" -ForegroundColor White
            Write-Host "2. Application Authentication (for service/daemon scenarios)" -ForegroundColor White
        }
        
        # Get authentication type
        $authType = ""
        if ($Silent)
        {
            $authType = "1"
            Write-SafeLog "Using delegated authentication in silent mode" "Information"
        }
        else
        {
            do
            {
                $authType = Read-Host "Enter your choice (1 or 2)"
                if ($authType -in @("1", "2"))
                {
                    break
                }
                Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
            } while ($true)
        }
        
        Write-SafeLog "Authentication type selected: $authType" "Debug"
        
        # Set authentication type flags
        if ($authType -eq "1")
        {
            $authConfig.AuthType = "Delegated"
            $authConfig.IsDelegated = $true
        }
        else
        {
            $authConfig.AuthType = "Application"
            $authConfig.IsDelegated = $false
        }
        
        if ($authType -eq "1")
        {
            # Delegated Authentication - no credentials needed from user
            if (-not $Silent)
            {
                Write-Host "`nDelegated Authentication Selected" -ForegroundColor Green
                Write-Host "Note: Delegated authentication uses interactive sign-in. No app secrets or certificates required." -ForegroundColor Yellow
            }
            Write-SafeLog "Delegated authentication configured - no additional credentials required" "Information"
        }
        else
        {
            # Application Authentication - still needs credentials
            if (-not $Silent)
            {
                Write-Host "`nApplication Authentication Selected" -ForegroundColor Green
                Write-Host "Choose your credential type:" -ForegroundColor White
                Write-Host "1. App Secret" -ForegroundColor White
                Write-Host "2. Certificate (Thumbprint)" -ForegroundColor White
            }
            
            $credType = ""
            if ($Silent)
            {
                $credType = "1"
                Write-SafeLog "Using app secret for application authentication in silent mode" "Information"
            }
            else
            {
                do
                {
                    $credType = Read-Host "Enter your choice (1 or 2)"
                    if ($credType -in @("1", "2"))
                    {
                        break
                    }
                    Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
                } while ($true)
            }
            
            if ($credType -eq "1")
            {
                # App Secret
                if ($Silent)
                {
                    $authConfig.AppSecret = "default_app_secret_placeholder"
                    Write-SafeLog "Using default app secret for application authentication in silent mode" "Information"
                }
                else
                {
                    do
                    {
                        $appSecret = Read-Host "Enter your App Secret" -AsSecureString
                        $appSecretPlain = ConvertFrom-SecureString-ToPlainText -SecureString $appSecret
                        
                        if ([string]::IsNullOrWhiteSpace($appSecretPlain))
                        {
                            Write-Host "App Secret cannot be empty. Please try again." -ForegroundColor Red
                            continue
                        }
                        
                        $authConfig.AppSecret = $appSecretPlain
                        break
                    } while ($true)
                }
            }
            else
            {
                # Certificate
                if ($Silent)
                {
                    $authConfig.Thumbprint = "0000000000000000000000000000000000000000"
                    Write-SafeLog "Using default certificate for application authentication in silent mode" "Information"
                }
                else
                {
                    do
                    {
                        $thumbprint = Read-Host "Enter your Certificate Thumbprint"
                        
                        if ([string]::IsNullOrWhiteSpace($thumbprint))
                        {
                            Write-Host "Certificate Thumbprint cannot be empty. Please try again." -ForegroundColor Red
                            continue
                        }
                        
                        $authConfig.Thumbprint = $thumbprint
                        break
                    } while ($true)
                }
            }
        }
        
        Write-Verbose "[$functionName] Authentication configuration collected successfully"
        return $authConfig
    }
    catch
    {
        Write-SafeLog "Error collecting authentication configuration: $($_.Exception.Message)" "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $null
    }
}

