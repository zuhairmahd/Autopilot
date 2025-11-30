function Get-BaseCallingContext()
{
    <#
    .SYNOPSIS
    Determines the base calling context for menu operations.

    .DESCRIPTION
    This function analyzes the PowerShell call stack to determine how a menu function was invoked.
    It identifies whether the call originated from navigation (ShowMenu, back/main navigation),
    action execution (Handle-ActionExecution), submenu navigation, or generates a unique context
    based on caller properties. This context information is used for menu state management and
    navigation tracking.

    .PARAMETER CallStack
    The PowerShell call stack array to analyze. This parameter is mandatory.

    .PARAMETER Menu
    Optional hashtable containing the current menu object for context generation.

    .OUTPUTS
    System.String
    Returns a context string: 'Navigation', 'Action', 'Submenu', unique caller context, or 'Direct'.

    .EXAMPLE
    $context = Get-BaseCallingContext -CallStack (Get-PSCallStack) -Menu $currentMenu

    .NOTES
    Known navigation functions: Handle-BackNavigation, Handle-MainMenuNavigation, GoBack, GoToMainMenu.
    Known action functions: Handle-ActionExecution, Handle-MenuItemSelection.
    Known submenu functions: Handle-SubmenuNavigation.
    Skips Get-CallingContext and Get-BaseCallingContext when analyzing stack.
    Falls back to 'Direct' if context cannot be determined.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$CallStack,
        [Parameter(Mandatory = $false)]
        [hashtable]$Menu = $null
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Look at the calling function (skip current function and Get-CallingContext)
    if ($CallStack.Count -gt 2)
    {
        Write-Verbose "[$functionName] Call stack has sufficient depth, analyzing caller"
        $caller = $CallStack[2]  # Skip Get-CallingContext and Get-BaseCallingContext
        Write-Verbose "[$functionName] Called from: $($caller.FunctionName) at line $($caller.ScriptLineNumber)"
        
        # If called from ShowMenu itself, it's likely navigation
        if ($caller.FunctionName -eq 'ShowMenu')
        {
            Write-Verbose "[$functionName] Called from ShowMenu, assuming navigation context"
            return 'Navigation'
        }
        
        # Check if called from known navigation functions
        if ($caller.FunctionName -in @('Handle-BackNavigation', 'Handle-MainMenuNavigation', 'GoBack', 'GoToMainMenu'))
        {
            Write-Verbose "[$functionName] Called from known navigation function: $($caller.FunctionName)"
            return 'Navigation'
        }
        
        # Check if called from menu item action execution functions
        if ($caller.FunctionName -in @('Handle-ActionExecution', 'Handle-MenuItemSelection'))
        {
            Write-Verbose "[$functionName] Called from action execution function: $($caller.FunctionName)"
            return 'Action'
        }
        
        # Check if called from submenu navigation functions
        if ($caller.FunctionName -in @('Handle-SubmenuNavigation'))
        {
            Write-Verbose "[$functionName] Called from submenu navigation function: $($caller.FunctionName)"
            return 'Submenu'
        }
        
        # Generate unique context based on calling function properties
        $callerContext = Get-UniqueCallerContext -CallStack $CallStack -Menu $Menu
        if ($callerContext -ne 'Unknown')
        {
            Write-Verbose "[$functionName] Generated unique caller context: $callerContext"
            return $callerContext
        }
    }
    
    # If we can't determine from call stack, assume direct call
    Write-Verbose "[$functionName] Unable to determine specific context, defaulting to 'Direct'"
    return 'Direct'
}

