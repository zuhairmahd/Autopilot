function ConvertTo-OrderedJson()
{
    <#
    .SYNOPSIS
        Converts a hashtable to JSON with a specific property order.
    
    .DESCRIPTION
        This function converts a hashtable to JSON while maintaining a specific order
        for root-level properties. This ensures that settings.json files have a 
        consistent structure that is easy to read and maintain.
    
    .PARAMETER InputObject
        The hashtable to convert to JSON.
    
    .PARAMETER Depth
        The maximum depth for JSON conversion. Defaults to 10.
    
    .PARAMETER PropertyOrder
        An array specifying the desired order of root-level properties.
    
    .OUTPUTS
        System.String
        Returns the JSON string with properties in the specified order.
    
    .EXAMPLE
        $config = @{ "version" = "1.0"; "description" = "Test" }
        $json = ConvertTo-OrderedJson -InputObject $config -PropertyOrder @("description", "version")
        
        Returns JSON with description first, then version.
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Only reorders root-level properties; nested objects use default ordering
        - Properties not in PropertyOrder are added at the end in default order
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$InputObject,
        [int]$Depth = 10,
        [string[]]$PropertyOrder = @(
            "description",
            "version", 
            "auth",
            "requiredScopes",
            "menuItemsToInclude", 
            "globalSettings",
            "domains"
        )
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Converting to ordered JSON with property order: $($PropertyOrder -join ', ')"
    
    try
    {
        # Create a PSCustomObject with properties in the specified order
        $orderedObject = New-Object PSCustomObject
        
        # First, add properties in the specified order
        foreach ($property in $PropertyOrder)
        {
            if ($InputObject.ContainsKey($property))
            {
                $orderedObject | Add-Member -MemberType NoteProperty -Name $property -Value $InputObject[$property]
                Write-Verbose "[$functionName] Added ordered property: $property"
            }
        }
        
        # Then, add any remaining properties that weren't in the order list
        foreach ($key in $InputObject.Keys)
        {
            if (-not ($orderedObject.PSObject.Properties | Where-Object { $_.Name -eq $key }))
            {
                $orderedObject | Add-Member -MemberType NoteProperty -Name $key -Value $InputObject[$key]
                Write-Verbose "[$functionName] Added remaining property: $key"
            }
        }
        
        # Convert to JSON
        $jsonResult = $orderedObject | ConvertTo-Json -Depth $Depth
        Write-Verbose "[$functionName] Successfully converted to ordered JSON"
        
        return $jsonResult
    }
    catch
    {
        Write-Verbose "[$functionName] Error converting to ordered JSON: $($_.Exception.Message)"
        throw
    }
}