function Initialize-AutopilotDlls()
{
    <#
    .SYNOPSIS
        Loads Autopilot C# DLLs with fallback to PowerShell implementation.
    
    .DESCRIPTION
        Attempts to load compiled C# DLLs (GraphCore, DeviceCore, CacheCore, LogCore, ConfigCore, 
        StringCore, CsvCore, CollectionCore) for performance. If DLLs are missing or fail to load, 
        sets flags to use PowerShell fallback implementations. Should be called once during application initialization.
    
    .OUTPUTS
        Hashtable with DLL availability flags and diagnostic information:
        - Success: $true if all DLLs loaded successfully
        - GraphCoreLoaded: $true if Autopilot.GraphCore.dll loaded
        - DeviceCoreLoaded: $true if Autopilot.DeviceCore.dll loaded
        - CacheCoreLoaded: $true if Autopilot.CacheCore.dll loaded
        - LogCoreLoaded: $true if Autopilot.LogCore.dll loaded
        - ConfigCoreLoaded: $true if Autopilot.ConfigCore.dll loaded
        - StringCoreLoaded: $true if Autopilot.StringCore.dll loaded
        - CsvCoreLoaded: $true if Autopilot.CsvCore.dll loaded
        - CollectionCoreLoaded: $true if Autopilot.CollectionCore.dll loaded
        - LoadedCount: Number of DLLs successfully loaded (0-8)
        - AnyLoaded: $true if any DLL loaded (convenience flag)
        - Errors: Array of error details for failed loads
        - DllPath: The path that was searched
        - LoadedAssemblies: Array of successfully loaded assembly names
    
    .EXAMPLE
        $dllStatus = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release"
        if ($dllStatus.Success) {
            Write-Host "All DLLs loaded successfully"
        }
        if ($dllStatus.CacheCoreLoaded) {
            # Use C# cache
        } else {
            # Use PowerShell hashtable
        }
        # Check for errors
        if ($dllStatus.Errors.Count -gt 0) {
            $dllStatus.Errors | ForEach-Object { Write-Warning $_.Message }
        }
    
    .NOTES
        Author: Windows Autopilot Management Tool Team
        Version: 2.0.0
        DLLs are optional - the tool will work without them but with reduced performance.
        Enhanced with comprehensive diagnostic information for troubleshooting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DLLPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Initializing Autopilot C# DLLs"
    
    # Detect PowerShell version and select appropriate target framework
    $psVersion = $PSVersionTable.PSVersion.Major
    $targetFramework = if ($psVersion -ge 7)
    {
        "net9.0"  # PowerShell 7+ uses .NET 9.0
    }
    else
    {
        "netstandard2.0"  # PowerShell 5.1 uses .NET Framework 4.x
    }
    
    # Adjust DLL path for multi-targeting
    $frameworkPath = Join-Path $DLLPath $targetFramework
    
    Write-Verbose "[$functionName] PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Verbose "[$functionName] Target Framework: $targetFramework"
    Write-Verbose "[$functionName] Looking for DLLs in: $frameworkPath"
    
    # Initialize result with diagnostic information
    $result = @{
        Success              = $false
        GraphCoreLoaded      = $false
        DeviceCoreLoaded     = $false
        CacheCoreLoaded      = $false
        LogCoreLoaded        = $false
        ConfigCoreLoaded     = $false
        StringCoreLoaded     = $false
        CsvCoreLoaded        = $false
        CollectionCoreLoaded = $false
        LoadedCount          = 0
        AnyLoaded            = $false
        Errors               = @()
        DllPath              = $frameworkPath
        TargetFramework      = $targetFramework
        PowerShellVersion    = $PSVersionTable.PSVersion.ToString()
        LoadedAssemblies     = @()
    }
    
    Write-Verbose "[$functionName] Looking for DLLs in: $frameworkPath"
    
    # Check if DLL directory exists
    if (-not (Test-Path $frameworkPath))
    {
        $errorMsg = "DLL directory not found: $frameworkPath"
        Write-Verbose "[$functionName] $errorMsg"
        Write-Verbose "[$functionName] Will use PowerShell fallback implementations"
        $result.Errors += @{
            Dll       = "Directory"
            Path      = $frameworkPath
            ErrorType = "PathNotFound"
            Message   = $errorMsg
            Exception = $null
            Timestamp = Get-Date
        }
        $global:AutopilotDllStatus = $result
        return $result
    }
    
    # Register AssemblyResolve handler for dependency loading (especially important for PS 5.1)
    # This allows .NET to find dependency DLLs (like System.Text.Json) in the same directory
    $assemblyResolveHandler = [System.ResolveEventHandler] {
        param($sender, $eventArgs)
        
        # Extract simple assembly name (e.g., "System.Text.Json" from "System.Text.Json, Version=8.0.0.0, ...")
        $assemblyName = $eventArgs.Name.Split(',')[0]
        $dllFileName = "$assemblyName.dll"
        $dllPath = Join-Path $frameworkPath $dllFileName
        
        Write-Verbose "[$functionName] AssemblyResolve: Looking for $dllFileName in $frameworkPath"
        
        if (Test-Path $dllPath)
        {
            Write-Verbose "[$functionName] AssemblyResolve: Loading $dllPath"
            try
            {
                # Use LoadFrom instead of LoadFile for better dependency resolution
                $assembly = [System.Reflection.Assembly]::LoadFrom($dllPath)
                Write-Verbose "[$functionName] AssemblyResolve: Successfully loaded $dllFileName"
                return $assembly
            }
            catch
            {
                Write-Verbose "[$functionName] AssemblyResolve: Failed to load $dllFileName - $_"
                return $null
            }
        }
        else
        {
            Write-Verbose "[$functionName] AssemblyResolve: $dllFileName not found in $frameworkPath"
            return $null
        }
    }
    
    # Register the handler
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($assemblyResolveHandler)
    Write-Verbose "[$functionName] Registered AssemblyResolve handler for dependency loading"
    
    # Try to load each DLL
    # Skip LogCore on PowerShell 5.1 due to stack overflow issues
    $dlls = @(
        @{ Name = "Autopilot.GraphCore"; Flag = "GraphCoreLoaded" }
        @{ Name = "Autopilot.DeviceCore"; Flag = "DeviceCoreLoaded" }
        @{ Name = "Autopilot.CacheCore"; Flag = "CacheCoreLoaded" }
        @{ Name = "Autopilot.ConfigCore"; Flag = "ConfigCoreLoaded" }
        @{ Name = "Autopilot.StringCore"; Flag = "StringCoreLoaded" }
        @{ Name = "Autopilot.CsvCore"; Flag = "CsvCoreLoaded" }
        @{ Name = "Autopilot.CollectionCore"; Flag = "CollectionCoreLoaded" }
    )
    
    # Only load LogCore on PowerShell 7+
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
        $dlls += @{ Name = "Autopilot.LogCore"; Flag = "LogCoreLoaded" }
    }
    
    foreach ($dll in $dlls)
    {
        $dllFile = Join-Path $frameworkPath "$($dll.Name).dll"
        if (-not (Test-Path $dllFile))
        {
            $errorMsg = "DLL file not found: $dllFile"
            Write-Verbose "[$functionName] $errorMsg"
            
            $result.Errors += @{
                Dll       = $dll.Name
                Path      = $dllFile
                ErrorType = "FileNotFound"
                Message   = $errorMsg
                Exception = $null
                Timestamp = Get-Date
            }
            continue
        }
        try
        {
            Write-Verbose "[$functionName] Loading $($dll.Name).dll from: $dllFile"
            # Check if assembly is already loaded (prevents ReflectionTypeLoadException)
            $assemblyName = $dll.Name
            $alreadyLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | 
                Where-Object { $_.GetName().Name -eq $assemblyName }
            if ($alreadyLoaded)
            {
                Write-Verbose "[$functionName] Assembly $assemblyName already loaded in AppDomain"
                $result[$dll.Flag] = $true
                $result.LoadedAssemblies += $assemblyName
                Write-Verbose "[$functionName] Using existing $($dll.Name) assembly"
            }
            else
            {
                # Load the assembly
                $assembly = Add-Type -Path $dllFile -PassThru -ErrorAction Stop
                $result[$dll.Flag] = $true
                $result.LoadedAssemblies += $assemblyName
                Write-Verbose "[$functionName] Successfully loaded $($dll.Name).dll"
                Write-Verbose "[$functionName] Assembly full name: $($assembly[0].Assembly.FullName)"
            }
            if (Get-Command Write-Log -ErrorAction SilentlyContinue)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Loaded $($dll.Name).dll for enhanced performance" -LogLevel "Information"
            }
        }
        catch
        {
            $errorMsg = "Failed to load $($dll.Name).dll: $($_.Exception.Message)"
            Write-Verbose "[$functionName] $errorMsg"
            
            # Collect detailed error information
            $errorDetail = @{
                Dll            = $dll.Name
                Path           = $dllFile
                ErrorType      = $_.Exception.GetType().FullName
                Message        = $_.Exception.Message
                InnerException = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
                StackTrace     = $_.ScriptStackTrace
                Exception      = $_.Exception
                Timestamp      = Get-Date
            }
            
            # Add loader exceptions if available (ReflectionTypeLoadException)
            if ($_.Exception.LoaderExceptions)
            {
                $errorDetail.LoaderExceptions = $_.Exception.LoaderExceptions | ForEach-Object {
                    @{
                        Type    = $_.GetType().FullName
                        Message = $_.Message
                    }
                }
            }
            
            $result.Errors += $errorDetail
            
            Write-Verbose "[$functionName] Exception Type: $($errorDetail.ErrorType)"
            if ($errorDetail.InnerException)
            {
                Write-Verbose "[$functionName] Inner Exception: $($errorDetail.InnerException)"
            }
            if (Get-Command Write-Log -ErrorAction SilentlyContinue)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to load $($dll.Name).dll, using PowerShell fallback: $errorMsg" -LogLevel "Warning"
            }
        }
    }
    
    # Calculate final statistics
    $result.LoadedCount = ($result.LoadedAssemblies).Count
    $result.Success = ($result.LoadedCount -eq 8)  # Now expecting 8 DLLs (added CsvCore and CollectionCore)
    $result.AnyLoaded = ($result.LoadedCount -gt 0)
    
    # Cache the result globally
    $global:AutopilotDllsLoaded = $true
    $global:AutopilotDllStatus = $result
    
    # Log summary
    Write-Verbose "[$functionName] Loaded $($result.LoadedCount) of 8 DLLs successfully"
    
    if ($result.Success)
    {
        Write-Verbose "[$functionName] All DLLs loaded - C# performance optimizations enabled"
    }
    elseif ($result.LoadedCount -gt 0)
    {
        Write-Verbose "[$functionName] Partial DLL load - Some optimizations enabled"
    }
    else
    {
        Write-Verbose "[$functionName] No DLLs loaded - Using PowerShell fallback implementations"
    }
    
    if ($result.Errors.Count -gt 0)
    {
        Write-Verbose "[$functionName] Encountered $($result.Errors.Count) error(s) during load"
    }
    
    $status = if ($result.Success) { "All loaded" } 
    elseif ($result.LoadedCount -gt 0) { "Partial ($($result.LoadedCount)/8)" }
    else { "None loaded" }
    
    if (Get-Command Write-Log -ErrorAction SilentlyContinue)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "C# DLLs initialized: $status - GraphCore=$($result.GraphCoreLoaded), DeviceCore=$($result.DeviceCoreLoaded), CacheCore=$($result.CacheCoreLoaded), LogCore=$($result.LogCoreLoaded), ConfigCore=$($result.ConfigCoreLoaded), StringCore=$($result.StringCoreLoaded), CsvCore=$($result.CsvCoreLoaded), CollectionCore=$($result.CollectionCoreLoaded)" -LogLevel "Information"
    }
    
    $global:AutopilotDllStatus = $result
    return $result
}
