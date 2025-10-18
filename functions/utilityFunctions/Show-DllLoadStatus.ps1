function Show-DllLoadStatus
{
    <#
    .SYNOPSIS
        Displays detailed DLL load status and diagnostic information.
    
    .DESCRIPTION
        Formats and displays the results from Initialize-AutopilotDlls, including
        success status, loaded assemblies, and any errors encountered.
        Useful for troubleshooting DLL loading issues.
    
    .PARAMETER DllStatus
        The hashtable returned by Initialize-AutopilotDlls containing load status.
    
    .PARAMETER ShowErrors
        If specified, displays detailed error information including exceptions.
    
    .PARAMETER Quiet
        If specified, only shows errors and warnings (suppresses success messages).
    
    .EXAMPLE
        $status = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release"
        Show-DllLoadStatus -DllStatus $status -ShowErrors
    
    .NOTES
        Author: Windows Autopilot Management Tool Team
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DllStatus,
        [Parameter(Mandatory = $false)]
        [switch]$ShowErrors,
        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying DLL load status"
    if (-not $Quiet)
    {
        Write-Host "`n=== C# DLL Load Status ===" -ForegroundColor Cyan
        Write-Host "Overall Success: " -NoNewline
        if ($DllStatus.Success)
        {
            Write-Host "YES" -ForegroundColor Green
        }
        else
        {
            Write-Host "PARTIAL" -ForegroundColor Yellow
        }
        
        Write-Host "DLLs Loaded: $($DllStatus.LoadedCount) of 3"
        Write-Host "Search Path: $($DllStatus.DllPath)"
        
        if ($DllStatus.LoadedCount -gt 0)
        {
            Write-Host "`nLoaded Assemblies:" -ForegroundColor Green
            $DllStatus.LoadedAssemblies | ForEach-Object {
                Write-Host "  - $_" -ForegroundColor Green
            }
        }
        
        Write-Host "`nComponent Status:" -ForegroundColor Cyan
        Write-Host "  GraphCore (Graph API):  " -NoNewline
        Write-Host $(if ($DllStatus.GraphCoreLoaded) { "LOADED" } else { "FALLBACK" }) `
            -ForegroundColor $(if ($DllStatus.GraphCoreLoaded) { "Green" } else { "Yellow" })
        
        Write-Host "  DeviceCore (Filtering): " -NoNewline
        Write-Host $(if ($DllStatus.DeviceCoreLoaded) { "LOADED" } else { "FALLBACK" }) `
            -ForegroundColor $(if ($DllStatus.DeviceCoreLoaded) { "Green" } else { "Yellow" })
        
        Write-Host "  CacheCore (Caching):    " -NoNewline
        Write-Host $(if ($DllStatus.CacheCoreLoaded) { "LOADED" } else { "FALLBACK" }) `
            -ForegroundColor $(if ($DllStatus.CacheCoreLoaded) { "Green" } else { "Yellow" })
    }
    
    # Always show errors if present
    if ($DllStatus.Errors.Count -gt 0)
    {
        Write-Host "`n=== Errors Detected ($($DllStatus.Errors.Count)) ===" -ForegroundColor Red
        
        foreach ($errorDetail in $DllStatus.Errors)
        {
            Write-Host "`nDLL: " -NoNewline -ForegroundColor Yellow
            Write-Host $errorDetail.Dll
            
            Write-Host "Error Type: " -NoNewline -ForegroundColor Yellow
            Write-Host $errorDetail.ErrorType
            
            Write-Host "Message: " -NoNewline -ForegroundColor Yellow
            Write-Host $errorDetail.Message
            
            if ($ShowErrors -and $errorDetail.Path)
            {
                Write-Host "Path: " -NoNewline -ForegroundColor Yellow
                Write-Host $errorDetail.Path
            }
            
            if ($ShowErrors -and $errorDetail.InnerException)
            {
                Write-Host "Inner Exception: " -NoNewline -ForegroundColor Yellow
                Write-Host $errorDetail.InnerException
            }
            
            if ($ShowErrors -and $errorDetail.StackTrace)
            {
                Write-Host "Stack Trace:" -ForegroundColor Yellow
                Write-Host $errorDetail.StackTrace -ForegroundColor Gray
            }
            
            if ($ShowErrors -and $errorDetail.LoaderExceptions)
            {
                Write-Host "Loader Exceptions:" -ForegroundColor Yellow
                $errorDetail.LoaderExceptions | ForEach-Object {
                    Write-Host "  Type: $($_.Type)" -ForegroundColor Gray
                    Write-Host "  Message: $($_.Message)" -ForegroundColor Gray
                }
            }
        }
        
        Write-Host "`nNote: The tool will use PowerShell fallback implementations" -ForegroundColor Yellow
        Write-Host "Performance may be reduced but functionality is preserved" -ForegroundColor Yellow
    }
    elseif (-not $Quiet)
    {
        Write-Host "`nNo errors detected" -ForegroundColor Green
    }
    
    if (-not $Quiet)
    {
        Write-Host "========================`n" -ForegroundColor Cyan
    }
}
