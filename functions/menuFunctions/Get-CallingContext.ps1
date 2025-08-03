function Get-CallingContext()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Menu = $null,
        [Parameter(Mandatory = $false)]
        [string]$PreferredContext = $null,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeNavigationPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Analyzing call stack to determine context"
    Write-Verbose "[$functionName] PreferredContext: $PreferredContext"
    Write-Verbose "[$functionName] Menu provided: $($null -ne $Menu)"
    Write-Verbose "[$functionName] IncludeNavigationPath: $IncludeNavigationPath"
    
    $callStack = Get-PSCallStack
    Write-Verbose "[$functionName] Call stack depth: $($callStack.Count)"
    
    # If PreferredContext is provided and valid, use it (but still apply navigation path if requested)
    if ($PreferredContext -and $PreferredContext -in @('Direct', 'Action', 'Submenu', 'Navigation'))
    {
        Write-Verbose "[$functionName] Using preferred context: $PreferredContext"
        $baseContext = $PreferredContext
    }
    else
    {
        # Determine base context using original logic
        $baseContext = Get-BaseCallingContext -CallStack $callStack -Menu $Menu
    }
    
    # If navigation path is requested and available, enhance the context
    if ($IncludeNavigationPath -and $Global:MenuHistory -and $Global:MenuHistory.Count -gt 0)
    {
        $navigationContext = Get-NavigationPathContext
        if ($navigationContext -ne 'Unknown')
        {
            $enhancedContext = "$baseContext-$navigationContext"
            Write-Verbose "[$functionName] Enhanced context with navigation path: $enhancedContext"
            return $enhancedContext
        }
    }
    
    Write-Verbose "[$functionName] Returning base context: $baseContext"
    return $baseContext
}

