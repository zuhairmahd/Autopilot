function Initialize-AutopilotDlls
{
    <#
    .SYNOPSIS
        Loads Autopilot C# DLLs with fallback to PowerShell implementation.
    
    .DESCRIPTION
        Attempts to load compiled C# DLLs (GraphCore, DeviceCore, CacheCore) for performance.
        If DLLs are missing or fail to load, sets flags to use PowerShell fallback implementations.
        Should be called once during application initialization.
    
    .OUTPUTS
        Hashtable with DLL availability flags:
        - GraphCoreLoaded: $true if Autopilot.GraphCore.dll loaded
        - DeviceCoreLoaded: $true if Autopilot.DeviceCore.dll loaded
        - CacheCoreLoaded: $true if Autopilot.CacheCore.dll loaded
    
    .EXAMPLE
        $dllStatus = Initialize-AutopilotDlls
        if ($dllStatus.CacheCoreLoaded) {
            # Use C# cache
        } else {
            # Use PowerShell hashtable
        }
    
    .NOTES
        Author: Windows Autopilot Management Tool Team
        Version: 1.0.0
        DLLs are optional - the tool will work without them but with reduced performance.
    #>
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Initializing Autopilot C# DLLs"
    
    # Initialize result
    $result = @{
        GraphCoreLoaded  = $false
        DeviceCoreLoaded = $false
        CacheCoreLoaded  = $false
    }
    
    # Skip if already loaded (prevent double-loading)
    if ($global:AutopilotDllsLoaded)
    {
        Write-Verbose "[$functionName] DLLs already loaded, returning cached status"
        return $global:AutopilotDllStatus
    }
    
    # Determine DLL path (relative to script root)
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $dllPath = Join-Path $scriptRoot "bin\Release"
    
    Write-Verbose "[$functionName] Looking for DLLs in: $dllPath"
    
    # Check if DLL directory exists
    if (-not (Test-Path $dllPath))
    {
        Write-Verbose "[$functionName] DLL directory not found: $dllPath"
        Write-Verbose "[$functionName] Will use PowerShell fallback implementations"
        $global:AutopilotDllsLoaded = $true
        $global:AutopilotDllStatus = $result
        return $result
    }
    
    # Try to load each DLL
    $dlls = @(
        @{ Name = "Autopilot.GraphCore"; Flag = "GraphCoreLoaded" }
        @{ Name = "Autopilot.DeviceCore"; Flag = "DeviceCoreLoaded" }
        @{ Name = "Autopilot.CacheCore"; Flag = "CacheCoreLoaded" }
    )
    
    foreach ($dll in $dlls)
    {
        $dllFile = Join-Path $dllPath "$($dll.Name).dll"
        
        if (Test-Path $dllFile)
        {
            try
            {
                Write-Verbose "[$functionName] Loading $($dll.Name).dll"
                Add-Type -Path $dllFile -ErrorAction Stop
                $result[$dll.Flag] = $true
                Write-Verbose "[$functionName] Successfully loaded $($dll.Name).dll"
                
                if ($LogFile)
                {
                    Write-Log -LogFile $LogFile -Module $functionName `
                        -Message "Loaded $($dll.Name).dll for enhanced performance" -LogLevel "Information"
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to load $($dll.Name).dll: $($_.Exception.Message)"
                
                if ($LogFile)
                {
                    Write-Log -LogFile $LogFile -Module $functionName `
                        -Message "Failed to load $($dll.Name).dll, using PowerShell fallback: $($_.Exception.Message)" `
                        -LogLevel "Warning"
                }
            }
        }
        else
        {
            Write-Verbose "[$functionName] DLL not found: $dllFile"
        }
    }
    
    # Cache the result globally
    $global:AutopilotDllsLoaded = $true
    $global:AutopilotDllStatus = $result
    
    # Log summary
    $loadedCount = ($result.Values | Where-Object { $_ -eq $true }).Count
    Write-Verbose "[$functionName] Loaded $loadedCount of 3 DLLs successfully"
    
    if ($loadedCount -gt 0 -and $LogFile)
    {
        Write-Log -LogFile $LogFile -Module $functionName `
            -Message "C# DLLs initialized: GraphCore=$($result.GraphCoreLoaded), DeviceCore=$($result.DeviceCoreLoaded), CacheCore=$($result.CacheCoreLoaded)" `
            -LogLevel "Information"
    }
    
    return $result
}
