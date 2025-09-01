function Clear-SecureMemory()
{
    <#
    .SYNOPSIS
    Clears sensitive data from memory and forces garbage collection.
    
    .DESCRIPTION
    This function helps ensure sensitive data like passwords and encryption keys
    are properly cleared from memory and garbage collected.
    
    .PARAMETER Variables
    Array of variable names to clear from memory.
    
    .PARAMETER ClearScriptVariables
    If specified, also clears script-level temporary encryption variables.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Variables = @(),
        [switch]$ClearScriptVariables
    )
    
    $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $LogFile -Module $functionName -Message "Starting secure memory cleanup operation" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Clearing sensitive data from memory"
    
    $clearedVariables = @()
    
    # Clear specified variables
    foreach ($varName in $Variables)
    {
        if (Get-Variable -Name $varName -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name $varName -Force -ErrorAction SilentlyContinue
            $clearedVariables += $varName
            Write-Verbose "[$functionName] Cleared variable: $varName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared variable from memory" -LogLevel "Debug"
        }
        elseif (Get-Variable -Name $varName -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name $varName -Scope Script -Force -ErrorAction SilentlyContinue
            $clearedVariables += $varName
            Write-Verbose "[$functionName] Cleared script variable: $varName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable from memory" -LogLevel "Debug"
        }
    }
    
    # Clear script-level variables only if explicitly requested
    if ($ClearScriptVariables)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Clearing script-level encryption variables" -LogLevel "Debug"
        
        if (Get-Variable -Name "TempEncryptedConfig" -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "TempEncryptedConfig" -Scope Script -Force -ErrorAction SilentlyContinue
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable: TempEncryptedConfig" -LogLevel "Debug"
        }
        
        if (Get-Variable -Name "TempEncryptionKey" -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "TempEncryptionKey" -Scope Script -Force -ErrorAction SilentlyContinue
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable: TempEncryptionKey" -LogLevel "Debug"
        }
        
        if (Get-Variable -Name "UserEncryptionPassword" -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "UserEncryptionPassword" -Scope Script -Force -ErrorAction SilentlyContinue
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable: UserEncryptionPassword" -LogLevel "Debug"
        }
    }
    
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    Write-Verbose "[$functionName] Memory cleanup completed"
Write-Log -LogFile $LogFile -Module $functionName -Message "Memory cleanup completed successfully. Variables cleared: $($clearedVariables.Count)" -LogLevel "Information"
}

