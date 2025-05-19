#region other code
function BuildFunctionTable()
{
    [CmdletBinding()]
    param(
        [string]$Path = $functionsFolder
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

function FindFileContainingFunction()
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

function FindFunctionsInFile()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [string]$FunctionNameToFind
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Searching for function '$FunctionNameToFind' in file '$FileName'."
    if (Test-Path -Path $FileName)
    {
        $content = Get-Content -Path $FileName
        if ($content -match $FunctionNameToFind)
        {
            Write-Verbose "[$functionName] Function '$FunctionName' found in file '$FileName'."
            return $true
        }
        else
        {
            Write-Verbose "[$functionName] Function '$FunctionName' not found in file '$FileName'."
            return $false
        }
    }
    else
    {
        Write-Warning "File '$FileName' does not exist."
        return $false
    }
}


$choices = @('Clean the device', 'Wipe the device')
$choice = DisplayNumericMenu -Choices $choices 
switch ($choice)
{
    $choices[0]
    {
        Write-Host "Cleaning the device is a distructive action and cannot be undone" -ForegroundColor Red
        Write-Host "Are you sure you want to clean the device?" -ForegroundColor Red
        $subchoices = @('Yes', 'No')
        $subchoice = DisplayNumericMenu -Choices $subchoices
        switch ($subchoice)
        {
            'yes'
            {
                Write-Host "Cleaning device..."
                $accessToken = GetGraphAccessToken -configFile $configFile -Deligated -Scope $scopes -ForceNewToken
                SendDeviceCommand -ManagedDeviceId $deviceAssignment.managedDeviceId -AccessToken $accessToken -Command 'clean'
            }
            'no'
            {
                Write-Host "Exitting... Come back when you are sure."
            }
        }
    }
    $choices[1]
    {
        Write-Host "Wiping device..."
        Write-Host "This will remove all data from the device." -ForegroundColor Red
        Write-Host "Are you sure you want to wipe the device?" -ForegroundColor Red
        Write-Host "This is a destructive action and cannot be undone." -ForegroundColor Red
        $subchoices = @('Yes', 'No')
        $subchoice = DisplayNumericMenu -Choices $subchoices
        switch ($subchoice)
        {
            'yes'
            {
                Write-Host "Wiping device..."
                $accessToken = GetGraphAccessToken -configFile $configFile -Deligated -Scope $scopes
                SendDeviceCommand -ManagedDeviceId $deviceAssignment.managedDeviceId -AccessToken $accessToken -Command 'wipe'
            }
            'no'
            {
                Write-Host "Exitting... Come back when you are sure."
            }
        }
    }
}
#endregion other code
