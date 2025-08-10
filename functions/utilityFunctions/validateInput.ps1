function validateInput()
{
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
    $returnValue = @{ valid = $false; value = $null } # Initialize return hash table
    Write-Verbose "[$functionName] Validating input of type '$type': '$UserInput'"
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] MaxUserNameLength: $MaxUserNameLength"
    Write-Verbose "[$functionName] MinUserNameLength: $minUsernameLength"
    Write-Verbose "[$functionName] MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    switch ($type)
    {
        'serialNumber'
        {
            Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxSerialNumberLength)
            {
                Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
                Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput.Length -lt $MinSerialNumberLength)
            {
                Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
                Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput -match '^[a-zA-Z0-9-\s]+$') 
            {
                Write-Verbose "[$functionName] Serial number validation passed"
                $returnValue.value = $UserInput
                $returnValue.valid = $true
                return $returnValue
            }
            else
            {
                Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
                return $returnValue
            }
        }
        'userName'
        {
            Write-Verbose "[$functionName] Checking user name length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxUserNameLength -or $UserInput.Length -lt $minUsernameLength -or $UserInput -match '^\d' -and $null -ne $UserInput)
            {
                Write-Verbose "[$functionName] Username exceeds maximum length of $MaxUserNameLength characters"
                Write-Host "Username needs to have a minimum of $minUsernameLength characters and cannot exceed $MaxUserNameLength characters." -ForegroundColor Red
                Write-Host "The username cannot start with a digit." -ForegroundColor Red
                return $returnValue
            }
            $normalizedUserInput = NormalizeUserName -UserName $UserInput -Settings $settings
            
            # Basic email format check
            if ($normalizedUserInput -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            {
                Write-Verbose "[$functionName] Username validation passed"
                $returnValue.valid = $true
                $returnValue.value = $normalizedUserInput
            }
            else
            {
                Write-Verbose "[$functionName] Username validation failed - must be a valid email format (e.g., user@$domain)"
                Write-Host "Invalid user name format. Please enter a valid email address (e.g., user@$domain)." -ForegroundColor Red
                return $returnValue
            }
        }
        'groupName'
        {
            Write-Verbose "[$functionName] Checking group name length: $($UserInput.Length)"
            # Group names can be longer than usernames, set reasonable limits
            $maxGroupNameLength = 256  # Microsoft Graph limit for displayName
            $minGroupNameLength = 1
            
            if ($UserInput.Length -gt $maxGroupNameLength)
            {
                Write-Verbose "[$functionName] Group name exceeds maximum length of $maxGroupNameLength characters"
                Write-Host "Group name cannot exceed $maxGroupNameLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput.Length -lt $minGroupNameLength)
            {
                Write-Verbose "[$functionName] Group name is shorter than minimum length of $minGroupNameLength characters"
                Write-Host "Group name must be at least $minGroupNameLength character." -ForegroundColor Red
                return $returnValue
            }
            else
            {
                Write-Verbose "[$functionName] Group name validation passed"
                $returnValue.value = $UserInput
                $returnValue.valid = $true
                return $returnValue
            }
        }
        default
        {
            Write-Verbose "[$functionName] Unknown validation type: '$type'"
            Write-Host "Unknown validation type: '$type'" -ForegroundColor Red
            return $returnValue
        }
    }
    Write-Verbose "[$functionName] Returning validation result: $($returnValue.valid)"
    Write-Verbose "[$functionName] Returning validation value: $($returnValue.value)"
    return $returnValue
}

