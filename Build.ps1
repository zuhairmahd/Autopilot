[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FileName
)


# $scriptName = $MyInvocation.MyCommand.Name

function BuildFunctionTable()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    $functionName = $MyInvocation.MyCommand.Name
    $FunctionPattern = "^function\s+([A-Za-z0-9\-]+)" 
    $filesList = Get-ChildItem -Path "$Path\*.ps1"
    # Create a hashtable for quick function-to-file lookups
    $functionToFile = @{}
    Write-Verbose "[$functionName] - Found $($filesList.Count) files in the current directory and subdirectories."
    Write-Host "Found $($filesList.Count) files in the function directory ."
    foreach ($file in $filesList)
    {
        Write-Verbose "[$functionName] Processing file $($file.name)"
        $functionNames = @(Select-String -Path $file.FullName -Pattern $FunctionPattern | ForEach-Object { $_.Matches.Groups[1].Value })
        Write-Verbose "[$functionName] Found $($functionNames.count) functions in file $($file.name)"
        if ($functionNames)
        {
            Write-Verbose "[$functionName] Adding $($functionNames.count) functions to the list."
            $functionList = @()
            foreach ($functionName in $functionNames)
            {
                Write-Verbose "[$functionName] Adding function $functionName to the list."
                $functionList += $functionName
                # Add to our lookup hashtable - function name is the key, file name is the value
                $functionToFile[$functionName] = $file.Name
            }
        }
        else
        {
            Write-Verbose "[$functionName] No functions found in file $($file.name)"
        }
    }
    return $functionToFile
}

function FindFunctionFile
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FunctionNameToFind,
        $FunctionTable
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Looking for function: $FunctionNameToFind"
    if ($functionTable.ContainsKey($FunctionNameToFind))
    {
        Write-Verbose "[$functionName] Found function: $FunctionNameToFind in file: $($functionTable[$FunctionNameToFind])"
        return $functionTable[$FunctionNameToFind]
    }
    else
    {
        Write-Verbose "[$functionName] Function: $FunctionNameToFind not found in the function table."
        Write-Warning "Function '$FunctionNameToFind' not found in any files."
        return $null
    }
}

$functionTable = BuildFunctionTable -Path "$pwd\functions"

