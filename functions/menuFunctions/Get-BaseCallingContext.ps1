function Get-BaseCallingContext()
{
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

