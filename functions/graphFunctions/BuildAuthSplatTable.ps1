function BuildAuthSplatTable()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $auth,
        [switch]$includeAllScopes
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Received object of type $($auth.GetType().Name)"
    # Dynamic splatting approach - iterate over all auth properties    # Create clean splatting hashtable starting with required parameter
    $getTokenParams = @{
        configFile = $configFile
    }    # Define valid parameters for GetGraphAccessToken function (case-insensitive comparison)
    $validParams = @('renewalLeadTime', 'SecureString', 'NoSaveRefreshToken', 'delegated', 'Scope', 'AuthType', 'ForceNewToken', 'ForceNewRefreshToken', 'CacheType', 'configFile')
    # Define parameters that are only valid when delegated is true (parameterSetName = 'delegated')
    $delegatedOnlyParams = @('NoSaveRefreshToken', 'delegated', 'Scope', 'AuthType', 'ForceNewRefreshToken')

    Write-Verbose "[$functionName] Debugging BuildAuthSplatTable - Auth object properties:"
    foreach ($key in $auth.Keys)
    {
        $value = $auth[$key]
        Write-Verbose "[$functionName]  Property: '$key' = '$value' (Type: $($value.GetType().Name))"
    }
    
    # Iterate over all properties in the auth object
    foreach ($property in $auth.Keys)
    {
        $paramName = $property
        $paramValue = $auth[$property]
        Write-Verbose "[$functionName] Processing property '$paramName' with value '$paramValue'"

        # Special debugging for scope parameter
        if ($paramName -ieq 'scope')
        {
            Write-Verbose "[$functionName] SCOPE DEBUG: Found scope parameter with value: '$paramValue'"
            Write-Verbose "[$functionName] SCOPE DEBUG: Value type: $($paramValue.GetType().Name)"
            if ($paramValue -is [array])
            {
                Write-Verbose "[$functionName] SCOPE DEBUG: Scope is array with $($paramValue.Count) elements: $($paramValue -join ', ')"
            }
        }
        
        # Find the correct parameter name (case-insensitive match)
        $correctParamName = $validParams | Where-Object { $_ -ieq $paramName } | Select-Object -First 1

        Write-Verbose "[$functionName] Case-insensitive match for '$paramName': '$correctParamName'"
        # Skip if not a valid parameter for the function
        if (-not $correctParamName)
        {
            Write-Verbose "[$functionName] Skipping parameter '$paramName' as it's not valid for GetGraphAccessToken"
            continue
        }
        
        # Skip if value is null, empty, or false for switch parameters
        if ($null -eq $paramValue -or $paramValue -eq '' -or $paramValue -eq $false)
        {
            Write-Verbose "[$functionName] Skipping parameter '$paramName' due to null/empty/false value"
            continue
        }        # Check if this is a delegated-only parameter (case-insensitive)
        $isDelegatedOnlyParam = $delegatedOnlyParams | Where-Object { $_ -ieq $paramName } | Select-Object -First 1
        if ($isDelegatedOnlyParam)
        {
            # Only add if delegated is true in the auth object
            # Handle both hashtable and PSObject cases
            $hasDelegatedProperty = $false
            $delegatedValue = $false
            
            if ($auth -is [hashtable])
            {
                $hasDelegatedProperty = $auth.ContainsKey('delegated')
                if ($hasDelegatedProperty)
                {
                    $delegatedValue = $auth.delegated
                }
            }
            else
            {
                $hasDelegatedProperty = $auth.PSObject.Properties.Name -contains 'delegated'
                if ($hasDelegatedProperty)
                {
                    $delegatedValue = $auth.delegated
                }
            }
            
            Write-Verbose "[$functionName] Delegated check: HasProperty=$hasDelegatedProperty, Value=$delegatedValue, ValueType=$($delegatedValue.GetType().Name)"
            
            if ($hasDelegatedProperty -and $delegatedValue)
            {
                Write-Verbose "[$functionName] Adding delegated parameter '$paramName' with value: $paramValue"
                #Check if the parameter is an array, and if so convert it to a space seperated string
                if ($paramValue -is [array])
                {
                    $paramValue = $paramValue -join ' '
                    Write-Verbose "[$functionName] Converted array parameter '$paramName' to space-separated string: $paramValue"
                }
                # Use the correct parameter name (properly capitalized) for the hashtable
                $getTokenParams[$correctParamName] = $paramValue
                Write-Verbose "[$functionName] Added delegated parameter '$correctParamName' with value: $paramValue"
                
                # Special debugging for scope parameter
                if ($correctParamName -ieq 'Scope')
                {
                    Write-Verbose "[$functionName] SCOPE DEBUG: Added scope to hashtable with key '$correctParamName' and value '$paramValue'"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Skipping delegated parameter '$paramName' because delegated is not true (HasProperty=$hasDelegatedProperty, Value=$delegatedValue)"
            }
        }
        else
        {
            # Add general parameters (not restricted to delegated mode)
            Write-Verbose "[$functionName] Adding parameter '$paramName' with value: $paramValue"
            # Use the correct parameter name (properly capitalized) for the hashtable
            $getTokenParams[$correctParamName] = $paramValue
        }
    }    # Log the final splatting parameters for verification
    Write-Verbose "[$functionName] Final splatting parameters:"
    foreach ($param in $getTokenParams.GetEnumerator())
    {
        if ($param.Key -eq 'configFile')
        {
            Write-Verbose "[$functionName]   $($param.Key): $($param.Value)"
        }
        elseif ($param.Value -is [bool])
        {
            Write-Verbose "[$functionName]  $($param.Key): $($param.Value)"
        }
        else
        {
            Write-Verbose "[$functionName]  $($param.Key): '$($param.Value)'"
        }
    }
    
    # Special debug for Scope parameter
    if ($getTokenParams.ContainsKey('Scope'))
    {
        Write-Verbose "[$functionName] DEBUG: Scope parameter found in hashtable: '$($getTokenParams.Scope)'" 
    }
    else
    {
        Write-Verbose "[$functionName] DEBUG: Scope parameter NOT found in hashtable!"
        Write-Verbose "[$functionName] DEBUG: Available keys: $($getTokenParams.Keys -join ', ')"
    }
    
    # Return the splatting hashtable
    Write-Verbose "[$functionName] Returning splatting hashtable with parameters for GetGraphAccessToken"
    return $getTokenParams
}

