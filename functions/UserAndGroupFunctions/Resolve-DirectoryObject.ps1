function Resolve-DirectoryObject
{
    <#
    .SYNOPSIS
        Resolves a username or group name to a valid Entra entity with support for fuzzy matching.
    
    .DESCRIPTION
        This function attempts to find an exact match for the provided name in Entra ID.
        If no exact match is found, it searches for similar entities and prompts the user to 
        select from a list of possible matches. The function handles all user interaction 
        and returns a validated entity name or appropriate status codes for navigation.
        
        This unified function replaces the legacy Resolve-UserWithMatching function and uses
        the consolidated Get-EntraDirectoryObject and Show-DirectoryObjectList functions.
    
    .PARAMETER EntityName
        The username (email address) or group name to search for in Entra ID.
    
    .PARAMETER AccessToken
        The access token for authenticating with Microsoft Graph API.
    
    .PARAMETER Settings
        The settings object containing configuration such as maxUserMatchDisplay or maxGroupMatchDisplay.
    
    .PARAMETER ReturnValues
        The return values hashtable containing navigation messages.
    
    .PARAMETER EntityType
        Specifies whether to resolve 'User' or 'Group'. Defaults to 'User' for backward compatibility.
    
    .PARAMETER NoPrompt
        When specified, single-item results are automatically accepted without user confirmation.
        Useful for automated testing scenarios.
    
    .PARAMETER ReturnEntity
        When specified, returns the full entity object instead of just the identifier.
        Useful when caller needs additional entity properties beyond the name.
    
    .OUTPUTS
        Returns the validated userPrincipalName/displayName if an entity is found and confirmed,
        or the full entity object if -ReturnEntity is specified,
        or a return value code for navigation (back, exit, etc.).
    
    .EXAMPLE
        # Resolve a user
        $resolvedUser = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken $token -Settings $settings -ReturnValues $returnValues -EntityType "User"
        if ($resolvedUser -notin $returnValues.Values) {
            # Proceed with the resolved username
        }
    
    .EXAMPLE
        # Resolve a group
        $resolvedGroup = Resolve-DirectoryObject -EntityName "Marketing Team" -AccessToken $token -Settings $settings -ReturnValues $returnValues -EntityType "Group"
        if ($resolvedGroup -notin $returnValues.Values) {
            # Proceed with the resolved group
        }
    
    .EXAMPLE
        # Resolve with NoPrompt for automated testing
        $resolvedUser = Resolve-DirectoryObject -EntityName "john.doe@contoso.com" -AccessToken $token -Settings $settings -ReturnValues $returnValues -EntityType "User" -NoPrompt
    
    .NOTES
        This function encapsulates the entity lookup and matching workflow that was previously
        inline in various actions in main.ps1. It supports both users and groups.
        
        This is a unified replacement for Resolve-UserWithMatching that uses the new
        consolidated functions Get-EntraDirectoryObject and Show-DirectoryObjectList.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$EntityName,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,
        [Parameter(Mandatory = $true)]
        [hashtable]$ReturnValues,
        [Parameter(Mandatory = $false)]
        [ValidateSet("User", "Group")]
        [string]$EntityType = "User",
        [Parameter(Mandatory = $false)]
        [switch]$NoPrompt,
        [Parameter(Mandatory = $false)]
        [switch]$ReturnEntity
    )    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Resolving $EntityType`: $EntityName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting $EntityType resolution for: $EntityName" -LogLevel "Verbose"
    
    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($EntityName))
    {
        Write-Verbose "[$functionName] $EntityType name is null or empty"
        if ($EntityType -eq "User")
        {
            return $ReturnValues.noUserFoundInDirectoryMessage
        }
        else
        {
            return $ReturnValues.noGroupFoundMessage
        }
    }
    
    if ([string]::IsNullOrWhiteSpace($AccessToken))
    {
        Write-Verbose "[$functionName] AccessToken is null or empty"
        Write-Log -LogFile $LogFile -Module $functionName -Message "AccessToken is required but was not provided" -LogLevel "Error"
        return $ReturnValues.noAccessTokenMessage
    }
    
    # Use the unified Get-EntraDirectoryObject function
    $entityInfo = Get-EntraDirectoryObject -EntityName $EntityName -AccessToken $AccessToken -EntityType $EntityType -FindSimilar
    
    # Handle exact match found
    if ($null -ne $entityInfo -and $entityInfo[1] -eq $false)
    {
        # entityInfo[0] is the API response with a 'value' array property
        # Get the first (and only) item from the value array
        $entity = $entityInfo[0].value[0]
        
        if ($EntityType -eq "User")
        {
            Write-Host "Found user: $($entity.displayName) ($($entity.userPrincipalName))" -ForegroundColor Green
            $resolvedName = $entity.userPrincipalName
        }
        else
        {
            Write-Host "Found group: $($entity.displayName) ($($entity.id))" -ForegroundColor Green
            $resolvedName = $entity.displayName
        }
        Write-Verbose "[$functionName] Exact match found. Resolved $EntityType name: $resolvedName"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Exact match for $EntityType`: $resolvedName" -LogLevel "Information"
        
        # Return full entity object if requested, otherwise return name
        if ($ReturnEntity)
        {
            Write-Verbose "[$functionName] Returning full entity object for $EntityType"
            return $entity
        }
        return $resolvedName
    }
    
    # Handle fuzzy matches found
    if ($null -ne $entityInfo -and $entityInfo[1] -eq $true)
    {
        Write-Verbose "[$functionName] No exact match found. Processing $($entityInfo[0].value.count) similar $EntityType entities"
        
        # Display appropriate message based on match count
        Write-Host "Could not find an exact match for $EntityType $($EntityName)." -ForegroundColor Yellow
        
        if ($entityInfo[0].value.count -eq 1)
        {
            Write-Host "Found a $EntityType with a similar name." -ForegroundColor Cyan
        }
        else
        {
            Write-Host "Found $($entityInfo[0].value.count) $EntityType entities with similar names:" -ForegroundColor Cyan
        }
        
        # Check if we need to truncate the display
        $maxDisplay = if ($EntityType -eq "User")
        {
            [int]$Settings.maxUserMatchDisplay 
        }
        else
        {
            [int]$Settings.maxGroupMatchDisplay 
        }
        if ($entityInfo[0].value.count -gt $maxDisplay)
        {
            Write-Host "Displaying the first $maxDisplay matches:" -ForegroundColor Yellow
        }
        elseif ($entityInfo[0].value.count -eq 1)
        {
            Write-Host "Is this the correct $EntityType`?" -ForegroundColor Cyan
        }
        else
        {
            Write-Host "Displaying all $($entityInfo[0].value.count) matches:" -ForegroundColor Cyan
        }
        
        # Use the unified Show-DirectoryObjectList function
        $possibleEntityName = Show-DirectoryObjectList -EntityList $entityInfo[0].value -EntityType $EntityType -MaxDisplay $maxDisplay -NoPrompt:$NoPrompt
        
        Write-Verbose "[$functionName] $EntityType selection result: $possibleEntityName"
        Write-Log -LogFile $LogFile -Module $functionName -Message "$EntityType selected from list: $possibleEntityName" -LogLevel "Verbose"
        
        # Process the selection result using the unified conversion function
        $result = ConvertFrom-DirectoryObjectSelection -SelectedValue $possibleEntityName -ReturnValues $ReturnValues
        Write-Verbose "[$functionName] Processed $EntityType selection: $result"
        
        # If ReturnEntity is specified and result is not a navigation command, find and return the entity object
        if ($ReturnEntity -and $result -notin $ReturnValues.Values -and $result -ne "EXIT_APPLICATION" -and $result -ne "Main Menu")
        {
            Write-Verbose "[$functionName] Finding entity object for: $result"
            $selectedEntity = $entityInfo[0].value | Where-Object {
                if ($EntityType -eq "User")
                {
                    $_.userPrincipalName -eq $result 
                }
                else
                {
                    $_.displayName -eq $result 
                }
            } | Select-Object -First 1
            
            if ($null -ne $selectedEntity)
            {
                Write-Verbose "[$functionName] Returning full entity object for $EntityType"
                return $selectedEntity
            }
        }
        
        return $result
    }
    
    # Handle no matches found
    $noEntityFoundMessage = if ($EntityType -eq "User")
    {
        $ReturnValues.noUserFoundInDirectoryMessage 
    }
    else
    {
        $ReturnValues.noGroupFoundMessage 
    }
    if ($entityInfo -eq $noEntityFoundMessage)
    {
        Write-Verbose "[$functionName] No $EntityType found in directory"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No $EntityType found in directory for: $EntityName" -LogLevel "Warning"
        return $noEntityFoundMessage
    }
    
    # Default fallback
    Write-Verbose "[$functionName] $EntityType resolution failed - returning no entity found message"
    Write-Log -LogFile $LogFile -Module $functionName -Message "$EntityType resolution failed for: $EntityName" -LogLevel "Warning"
    return $noEntityFoundMessage
}
