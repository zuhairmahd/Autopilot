function validateInput()
{
    <#
    .SYNOPSIS
    Validates user input according to specified type and settings constraints.

    .DESCRIPTION
    This function validates user input for different types (serialNumber, userName, groupName)
    against configured constraints such as length limits, character patterns, and domain
    requirements. It returns a hashtable with validation status and the processed value.
    The function trims input and provides detailed validation feedback.

    .PARAMETER UserInput
    The user input string to validate. This parameter is mandatory.

    .PARAMETER type
    The type of input to validate. Valid values: 'serialNumber', 'userName', 'groupName'.
    This parameter is mandatory.

    .PARAMETER settings
    The settings object containing validation parameters (domain, length limits, etc.).
    Defaults to script-level $settings.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with two properties:
    - valid: Boolean indicating if validation passed
    - value: The validated/processed input value (or $null if invalid)

    .EXAMPLE
    $result = validateInput -UserInput "ABC123456" -type "serialNumber"
    if ($result.valid) { Write-Host "Valid serial: $($result.value)" }

    $result = validateInput -UserInput "john.doe" -type "userName" -settings $customSettings

    .NOTES
    Validation rules:
    - serialNumber: Length constraints, alphanumeric with dashes/spaces
    - userName: Length constraints, optional domain suffix, valid characters
    - groupName: Similar to userName validation

    Automatically trims leading/trailing whitespace.
    Displays colored error messages for validation failures.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserInput,
        [parameter(Mandatory = $true)]
        [string]$type,
        $settings = $settings # Use the script-level $settings by default
    )
    $functionName = $MyInvocation.MyCommand.Name
    $domain = $settings.domain
    $MaxUserNameLength = $settings.MaxUserNameLength
    $MaxSerialNumberLength = $settings.MaxSerialNumberLength
    $MinSerialNumberLength = $settings.MinSerialNumberLength
    $minUsernameLength = $settings.MinUsernameLength
    $returnValue = @{
        valid = $false
        value = $null
    }

    Write-Verbose "[$functionName] Validating input of type '$type': '$UserInput'"
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] MaxUserNameLength: $MaxUserNameLength"
    Write-Verbose "[$functionName] MinUserNameLength: $minUsernameLength"
    Write-Verbose "[$functionName] MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    #log the above values in a single Write-Log call.
    Write-Log -logFile $logFile -module $functionName -Message "Domain: $domain; MaxUserNameLength: $MaxUserNameLength; MinUserNameLength: $minUsernameLength; MaxSerialNumberLength: $MaxSerialNumberLength; MinSerialNumberLength: $MinSerialNumberLength"
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    Write-Log -logFile $logFile -module $functionName -Message "Trimmed input: '$UserInput'"
    switch ($type)
    {
        'serialNumber'
        {
            Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
            Write-Log -logFile $logFile -module $functionName -Message "Checking serial number length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxSerialNumberLength)
            {
                Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
                Write-Log -logFile $logFile -module $functionName -Message "Serial number exceeds maximum length of $MaxSerialNumberLength characters" -logLevel "Error"
                Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput.Length -lt $MinSerialNumberLength)
            {
                Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
                Write-Log -logFile $logFile -module $functionName -Message "Serial number is shorter than minimum length of $MinSerialNumberLength characters" -logLevel "Error"
                Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput -match '^[a-zA-Z0-9-\s]+$')
            {
                Write-Verbose "[$functionName] Serial number validation passed"
                Write-Log -logFile $logFile -module $functionName -Message "Serial number validation passed"
                $returnValue.value = $UserInput
                $returnValue.valid = $true
                return $returnValue
            }
            else
            {
                Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
                Write-Log -logFile $logFile -module $functionName -Message "Serial number validation failed - invalid characters detected" -logLevel "Error"
                return $returnValue
            }
        }
        'userName'
        {
            Write-Verbose "[$functionName] Checking user name length: $($UserInput.Length)"
            Write-Log -logFile $logFile -module $functionName -Message "Checking user name length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxUserNameLength -or $UserInput.Length -lt $minUsernameLength -or $UserInput -match '^\d' -and $null -ne $UserInput)
            {
                Write-Verbose "[$functionName] Username exceeds maximum length of $MaxUserNameLength characters"
                Write-Log -logFile $logFile -module $functionName -Message "Username exceeds maximum length of $MaxUserNameLength characters" -logLevel "Error"
                Write-Host "Username needs to have a minimum of $minUsernameLength characters and cannot exceed $MaxUserNameLength characters." -ForegroundColor Red
                Write-Host "The username cannot start with a digit." -ForegroundColor Red
                return $returnValue
            }
            $normalizedUserInput = NormalizeUserName -UserName $UserInput -Settings $settings
            Write-Log -logFile $logFile -module $functionName -Message "Normalized username: '$normalizedUserInput'"
            # Basic email format check
            if ($normalizedUserInput -match '^[a-zA-Z0-9][a-zA-Z0-9._%+-]*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$')
            {
                Write-Verbose "[$functionName] Username validation passed"
                Write-Log -logFile $logFile -module $functionName -Message "Username validation passed"
                $returnValue.valid = $true
                $returnValue.value = $normalizedUserInput
            }
            else
            {
                Write-Verbose "[$functionName] Username validation failed - must be a valid email format (e.g., user@$domain)"
                Write-Log -logFile $logFile -module $functionName -Message "Username validation failed - invalid email format" -logLevel "Error"
                Write-Host "Invalid user name format. Please enter a valid email address (e.g., user@$domain)." -ForegroundColor Red
                return $returnValue
            }
        }
        'groupName'
        {
            Write-Verbose "[$functionName] Checking group name length: $($UserInput.Length)"
            Write-Log -logFile $logFile -module $functionName -Message "Checking group name length: $($UserInput.Length)"
            # Group names can be longer than usernames, set reasonable limits
            $maxGroupNameLength = 256  # Microsoft Graph limit for displayName
            $minGroupNameLength = 1
            Write-Log -logFile $logFile -module $functionName -Message "MaxGroupNameLength: $maxGroupNameLength; MinGroupNameLength: $minGroupNameLength"
            if ($UserInput.Length -gt $maxGroupNameLength)
            {
                Write-Verbose "[$functionName] Group name exceeds maximum length of $maxGroupNameLength characters"
                Write-Log -logFile $logFile -module $functionName -Message "Group name exceeds maximum length of $maxGroupNameLength characters" -logLevel "Error"
                Write-Host "Group name cannot exceed $maxGroupNameLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput.Length -lt $minGroupNameLength)
            {
                Write-Verbose "[$functionName] Group name is shorter than minimum length of $minGroupNameLength characters"
                Write-Log -logFile $logFile -module $functionName -Message "Group name is shorter than minimum length of $minGroupNameLength characters" -logLevel "Error"
                Write-Host "Group name must be at least $minGroupNameLength character." -ForegroundColor Red
                return $returnValue
            }
            else
            {
                Write-Verbose "[$functionName] Group name validation passed"
                Write-Log -logFile $logFile -module $functionName -Message "Group name validation passed"
                $returnValue.value = $UserInput
                $returnValue.valid = $true
                return $returnValue
            }
        }
        default
        {
            Write-Verbose "[$functionName] Unknown validation type: '$type'. Returning as is."
            Write-Log -logFile $logFile -module $functionName -Message "Unknown validation type: '$type'. Returning as is." -logLevel "Warning"
            $returnValue.value = $UserInput
            $returnValue.valid = $true
            return $returnValue
        }
    }
    Write-Verbose "[$functionName] Returning validation result: $($returnValue.valid)"
    Write-Verbose "[$functionName] Returning validation value: $($returnValue.value)"
    Write-Log -logFile $logFile -module $functionName -Message "Returning validation result: $($returnValue.valid); Returning validation value: $($returnValue.value)"
    return $returnValue
}

