function ConvertFrom-UserSelection
{
    <#
    .SYNOPSIS
        Processes the result from DisplayUserList and maps it to appropriate return values.
    
    .DESCRIPTION
        This function takes the output from DisplayUserList (which could be a username, 
        navigation command, or special value) and maps it to the appropriate return value
        for the calling context. It handles special cases like "Back", "Main Menu", "0" (exit),
        and navigation messages.
    
    .PARAMETER SelectedValue
        The value returned from DisplayUserList or similar user selection function.
    
    .PARAMETER ReturnValues
        The return values hashtable containing navigation messages.
    
    .OUTPUTS
        Returns either a validated username string or a navigation return value.
    
    .EXAMPLE
        $result = Process-UserSelection -SelectedValue $userChoice -ReturnValues $returnValues
        if ($result -in $returnValues.Values) {
            # Handle navigation
        } else {
            # Use the username
        }
    
    .NOTES
        This function encapsulates the user selection processing logic that was previously
        inline in multiple places throughout main.ps1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$SelectedValue,
        [Parameter(Mandatory = $true)]
        [hashtable]$ReturnValues
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Get type information safely for null values
    $typeInfo = if ($null -eq $SelectedValue)
    {
        "null" 
    }
    else
    {
        $SelectedValue.GetType().Name 
    }
    Write-Verbose "[$functionName] Processing selected value: $SelectedValue (Type: $typeInfo)"
    
    # Handle numeric zero FIRST (exit command) - must come before null check
    # DisplayUserList returns integer 0 when user presses 0 to exit
    if ($SelectedValue -eq 0)
    {
        Write-Verbose "[$functionName] User selected exit (numeric 0) - exiting application"
        return "EXIT_APPLICATION"
    }
    
    # Check if the selection is already a return value (navigation command)
    if ($SelectedValue -in $ReturnValues.Values)
    {
        Write-Verbose "[$functionName] Selected value is a return value message: $SelectedValue"
        return $SelectedValue
    }
    
    # Handle string-based navigation commands
    if ($SelectedValue -is [string])
    {
        switch ($SelectedValue.ToLower())
        {
            "back"
            {
                Write-Verbose "[$functionName] User selected 'Back' - returning backoutText"
                return $ReturnValues.backoutText
            }
            "main menu"
            {
                Write-Verbose "[$functionName] User selected 'Main Menu' - returning to main menu"
                return "Main Menu"
            }
            "0"
            {
                Write-Verbose "[$functionName] User selected exit (string '0') - exiting application"
                return "EXIT_APPLICATION"
            }
            default
            {
                # Assume it's a valid username if none of the above match
                Write-Verbose "[$functionName] Treating selected value as username: $SelectedValue"
                return $SelectedValue
            }
        }
    }
    
    # Handle null or empty selection LAST (after checking for 0)
    # This represents a Back/Cancel action
    if ($null -eq $SelectedValue)
    {
        Write-Verbose "[$functionName] Selected value is null - returning backoutText"
        return $ReturnValues.backoutText
    }
    
    # Default: return the value as-is (likely a username)
    Write-Verbose "[$functionName] Returning selected value as-is: $SelectedValue"
    return $SelectedValue
}
