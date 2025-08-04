function Get-BasicConfigurationFromUser()
{
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
    
    Write-SafeLog "Collecting basic configuration parameters"
    
    $config = @{}
    
    try
    {
        if (-not $Silent)
        {
            Write-Host "`n── Basic Configuration ──" -ForegroundColor Cyan
        }
        
        # Collect App ID
        do
        {
            if ($Silent)
            {
                $appId = "00000000-0000-0000-0000-000000000000"
                Write-SafeLog "Using default App ID in silent mode" "Information"
                break
            }
            
            $appId = Read-Host "Enter your Azure AD Application ID (GUID format)"
            
            if ([string]::IsNullOrWhiteSpace($appId))
            {
                Write-Host "Application ID cannot be empty. Please try again." -ForegroundColor Red
                continue
            }
            
            # Validate GUID format
            $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
            if ($appId -notmatch $guidPattern)
            {
                Write-Host "Invalid GUID format. Please enter a valid Application ID." -ForegroundColor Red
                continue
            }
            
            break
        } while ($true)
        
        $config.AppId = $appId
        Write-SafeLog "App ID collected: $appId" "Debug"
        Write-Verbose "[$functionName] App ID collected: $appId"
        
        # Collect Tenant ID
        do
        {
            if ($Silent)
            {
                $tenantId = "00000000-0000-0000-0000-000000000000"
                Write-SafeLog "Using default Tenant ID in silent mode" "Information"
                break
            }
            
            $tenantId = Read-Host "Enter your Azure AD Tenant ID (GUID format)"
            
            if ([string]::IsNullOrWhiteSpace($tenantId))
            {
                Write-Host "Tenant ID cannot be empty. Please try again." -ForegroundColor Red
                continue
            }
            
            # Validate GUID format
            if ($tenantId -notmatch $guidPattern)
            {
                Write-Host "Invalid GUID format. Please enter a valid Tenant ID." -ForegroundColor Red
                continue
            }
            
            break
        } while ($true)
        
        $config.TenantId = $tenantId
        if ($LogFile)
        {
            Write-SafeLog "Tenant ID collected: $tenantId" "Debug"
        }
        Write-Verbose "[$functionName] Tenant ID collected: $tenantId"
        
        # Collect Domain Name
        do
        {
            if ($Silent)
            {
                $domain = "example.com"
                Write-SafeLog "Using default domain in silent mode" "Information"
                break
            }
            
            $domain = Read-Host "Enter your domain name (e.g., contoso.com)"
            
            if ([string]::IsNullOrWhiteSpace($domain))
            {
                Write-Host "Domain name cannot be empty. Please try again." -ForegroundColor Red
                continue
            }
            
            # Basic domain validation
            $domainPattern = '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
            if ($domain -notmatch $domainPattern)
            {
                Write-Host "Invalid domain format. Please enter a valid domain name." -ForegroundColor Red
                continue
            }
            
            break
        } while ($true)
        
        $config.domain = $domain
        if ($LogFile)
        {
            Write-SafeLog "Domain collected: $domain" "Debug"
        }
        Write-Verbose "[$functionName] Domain collected: $domain"

        #collect appname.
        do
        {
            if ($Silent)
            {
                $appName = "Intune Helpdesk"
                Write-SafeLog "Using default application name in silent mode" "Information"
                break
            }
            
            $appName = Read-Host "Enter your Azure registered application name (e.g., Intune Helpdesk)"
            
            if ([string]::IsNullOrWhiteSpace($appName))
            {
                Write-Host "Application name cannot be empty. Please try again." -ForegroundColor Red
                continue
            }
            
            break
        } while ($true)
        $config.Name = $appName
        if ($LogFile)
        {
            Write-SafeLog "Application name collected: $appName" "Debug"
        }
        Write-Verbose "[$functionName] Application name collected: $appName"
        
        Write-Verbose "[$functionName] Basic configuration collected successfully"
        return $config
        
    }
    catch
    {
        Write-SafeLog "Error collecting basic configuration: $($_.Exception.Message)" "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $null
    }
}

