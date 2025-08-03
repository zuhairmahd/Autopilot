function Get-UniqueCallerContext()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$CallStack,
        [Parameter(Mandatory = $false)]
        [hashtable]$Menu = $null
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Generating unique context from call stack"
    
    if ($CallStack.Count -lt 2) 
    {
        Write-Verbose "[$functionName] Insufficient call stack depth"
        return 'Unknown'
    }
    
    # Skip Get-CallingContext (index 0) and look at actual caller (index 1)
    $caller = $CallStack[1]
    Write-Verbose "[$functionName] Caller: $caller"
    $callerFunction = $caller.FunctionName
    Write-Verbose "[$functionName] Caller function name: $callerFunction"
    $callerLine = $caller.ScriptLineNumber
    Write-Verbose "[$functionName] Caller line number: $callerLine"
    if ($null -ne $caller.ScriptName)
    {
        $callerFile = Split-Path -Leaf $caller.ScriptName    
        Write-Verbose "[$functionName] Caller script name: $callerFile"
    }
    else
    {
        Write-Verbose "[$functionName] Caller script name is null"
        $callerFile = 'main.exe'
    }
    
    
    Write-Verbose "[$functionName] Analyzing caller: $callerFunction in $callerFile at line $callerLine"
    
    # Create context based on function name patterns
    switch -Regex ($callerFunction)
    {
        '^Get-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Get function"
            return "Getter_$($callerFunction)"
        }
        '^Set-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Set function"
            return "Setter_$($callerFunction)"
        }
        '^New-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a New/Create function"
            return "Creator_$($callerFunction)"
        }
        '^Remove-.*|^Delete-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Remove/Delete function"
            return "Remover_$($callerFunction)"
        }
        '^Test-.*|^Validate-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Test/Validate function"
            return "Validator_$($callerFunction)"
        }
        '^Connect-.*|^Disconnect-.*'
        {
            Write-Verbose "[$functionName] Caller appears to be a Connection function"
            return "Connection_$($callerFunction)"
        }
        '.*Menu.*'
        {
            Write-Verbose "[$functionName] Caller appears to be menu-related"
            return "MenuFunction_$($callerFunction)"
        }
        '.*Action.*|.*Execute.*'
        {
            Write-Verbose "[$functionName] Caller appears to be action/execution related"
            return "ActionFunction_$($callerFunction)"
        }
        default
        {
            # If no pattern matches, create context based on file and function combination
            if ($callerFile -and $callerFunction)
            {
                $fileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($callerFile)
                Write-Verbose "[$functionName] Creating context from file and function: $fileBaseName/$callerFunction"
                return "Custom_$($fileBaseName)_$($callerFunction)"
            }
            else
            {
                Write-Verbose "[$functionName] Unable to create unique context, caller function: $callerFunction"
                return 'Unknown'
            }
        }
    }
}

