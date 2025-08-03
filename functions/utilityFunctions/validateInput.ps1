function validateInput()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserInput
    )

    #Get the function name
    $functionName = $MyInvocation.MyCommand.Name
    $MaxSerialNumberLength = '11'
    $MinSerialNumberLength = '7'
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting serial number validation" -LogLevel "Debug"
    Write-Verbose "[$functionName] MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    $returnValue = @{}
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Validating serial number length: $($UserInput.Length)" -LogLevel "Debug"
    
    if ($UserInput.Length -gt $MaxSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
        Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Serial number validation failed: exceeds maximum length of $MaxSerialNumberLength characters" -LogLevel "Warning"
    }
    elseif ($UserInput.Length -lt $MinSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
        Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Serial number validation failed: shorter than minimum length of $MinSerialNumberLength characters" -LogLevel "Warning"
    }
    elseif ($UserInput -match '^[a-zA-Z0-9]+$') 
    {
        Write-Verbose "[$functionName] Serial number validation passed"
        $returnValue.valid = $true
        $returnValue.value = $UserInput
        Write-Log -LogFile $LogFile -Module $functionName -Message "Serial number validation passed" -LogLevel "Debug"
    }
    else
    {
        Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Serial number validation failed: invalid format (non-alphanumeric characters)" -LogLevel "Warning"
    }
    Write-Verbose "[$functionName] Returning validation result: $($returnValue.valid)"
    Write-Verbose "[$functionName] Returning validation value: $($returnValue.value)"
    return $returnValue
}

