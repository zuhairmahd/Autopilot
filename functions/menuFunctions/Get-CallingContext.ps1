function Get-CallingContext()
{
    <#
    .SYNOPSIS
    Gets the calling context for menu operations with optional navigation path enhancement.

    .DESCRIPTION
    This function determines the calling context for menu operations by either using a preferred
    context or analyzing the call stack. It can optionally enhance the context with navigation
    path information from the global menu history, creating contexts like "Action-ViaCheckMenu"
    or "Navigation-ViaAutopilotMenu" for more precise menu state tracking.

    .PARAMETER Menu
    Optional hashtable containing the current menu object for context generation.

    .PARAMETER PreferredContext
    Optional preferred context string. If provided and valid ('Direct', 'Action', 'Submenu', 'Navigation'),
    it will be used instead of analyzing the call stack.

    .PARAMETER IncludeNavigationPath
    When specified, enhances the context with navigation path information from MenuHistory.

    .OUTPUTS
    System.String
    Returns a context string, optionally enhanced with navigation path (e.g., "Action-ViaCheckMenu").

    .EXAMPLE
    $context = Get-CallingContext -Menu $currentMenu
    $context = Get-CallingContext -PreferredContext 'Action' -IncludeNavigationPath

    .NOTES
    Valid contexts: Direct, Action, Submenu, Navigation.
    Navigation path enhancement creates contexts like "baseContext-pathContext".
    Uses global $MenuHistory for navigation path analysis.
    Compatible with PowerShell 5.1.
    #>
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

