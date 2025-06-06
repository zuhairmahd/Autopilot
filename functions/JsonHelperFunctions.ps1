# PowerShell 5.1 Compatible JSON Helper Functions
# These functions provide better JSON serialization for nested objects in PowerShell 5.1

function ConvertTo-JsonCompatible
{
    <#
    .SYNOPSIS
    Converts PowerShell objects to JSON with improved PowerShell 5.1 compatibility for nested objects.
    
    .DESCRIPTION
    This function provides better JSON serialization for nested objects in PowerShell 5.1 by:
    - Pre-processing nested objects to ensure proper formatting
    - Using ordered hashtables to maintain property order
    - Handling arrays and complex nested structures properly
    - Adding formatting improvements for better readability
    
    .PARAMETER InputObject
    The object to convert to JSON
    
    .PARAMETER Depth
    Maximum depth of nested objects to serialize (default: 10)
    
    .PARAMETER Compress
    Output JSON in compressed format (no formatting)
    
    .PARAMETER EscapeHandling
    How to handle special characters (Default, EscapeNonAscii, EscapeHtml)
    
    .EXAMPLE
    $settings | ConvertTo-JsonCompatible -Depth 10 | Set-Content -Path "settings.json"
    
    .NOTES
    Compatible with PowerShell 5.1 and addresses known nested object formatting issues.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject,
        
        [int]$Depth = 10,
        
        [switch]$Compress,
        
        [ValidateSet('Default', 'EscapeNonAscii', 'EscapeHtml')]
        [string]$EscapeHandling = 'Default'
    )
    
    begin
    {
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Starting JSON conversion with depth: $Depth"
    }
    
    process
    {
        try
        {
            # Handle null input
            if ($null -eq $InputObject)
            {
                Write-Verbose "[$functionName] Input object is null, returning null"
                return 'null'
            }
            
            # Pre-process the object to ensure PowerShell 5.1 compatibility
            $processedObject = ConvertTo-NestedHashtable -InputObject $InputObject -MaxDepth $Depth
            
            # Use the built-in ConvertTo-Json with processed object
            $jsonParams = @{
                InputObject = $processedObject
                Depth       = $Depth
            }
            
            if ($Compress)
            {
                $jsonParams.Compress = $true
            }
            
            Write-Verbose "[$functionName] Converting processed object to JSON"
            $result = ConvertTo-Json @jsonParams
            
            # Additional formatting improvements for PowerShell 5.1
            if (-not $Compress)
            {
                $result = Format-JsonOutput -JsonString $result
            }
            
            Write-Verbose "[$functionName] JSON conversion completed successfully"
            return $result
        }
        catch
        {
            Write-Error "[$functionName] Failed to convert object to JSON: $($_.Exception.Message)"
            Write-Verbose "[$functionName] Error details: $($_.Exception)"
            throw
        }
    }
}

function ConvertTo-NestedHashtable
{
    <#
    .SYNOPSIS
    Converts complex PowerShell objects to nested hashtables for better JSON serialization.
    
    .DESCRIPTION
    This function recursively converts PSCustomObjects, arrays, and other complex types
    to hashtables, which serialize more reliably to JSON in PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        
        [int]$MaxDepth = 10,
        
        [int]$CurrentDepth = 0
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Prevent infinite recursion
    if ($CurrentDepth -ge $MaxDepth)
    {
        Write-Verbose "[$functionName] Maximum depth ($MaxDepth) reached, returning string representation"
        return $InputObject.ToString()
    }
    
    # Handle different object types
    switch ($InputObject.GetType().FullName)
    {
        'System.Management.Automation.PSCustomObject'
        {
            Write-Verbose "[$functionName] Converting PSCustomObject at depth $CurrentDepth"
            $hashtable = [ordered]@{}
            
            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hashtable[$property.Name] = ConvertTo-NestedHashtable -InputObject $property.Value -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
            }
            
            return $hashtable
        }
        
        { $_.StartsWith('System.Collections.Hashtable') -or $_.StartsWith('System.Collections.Specialized.OrderedDictionary') }
        {
            Write-Verbose "[$functionName] Converting Hashtable/OrderedDictionary at depth $CurrentDepth"
            $newHashtable = [ordered]@{}
            
            foreach ($key in $InputObject.Keys)
            {
                $newHashtable[$key] = ConvertTo-NestedHashtable -InputObject $InputObject[$key] -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
            }
            
            return $newHashtable
        }
        
        { $_.StartsWith('System.Object[]') -or $_.StartsWith('System.Collections') }
        {
            Write-Verbose "[$functionName] Converting Array/Collection at depth $CurrentDepth"
            $newArray = @()
            
            foreach ($item in $InputObject)
            {
                $newArray += ConvertTo-NestedHashtable -InputObject $item -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
            }
            
            return $newArray
        }
        
        default
        {
            # For primitive types (string, int, bool, etc.), return as-is
            Write-Verbose "[$functionName] Returning primitive type: $($InputObject.GetType().FullName)"
            return $InputObject
        }
    }
}

function Format-JsonOutput
{
    <#
    .SYNOPSIS
    Improves JSON formatting for better readability and consistency.
    
    .DESCRIPTION
    This function applies additional formatting improvements to JSON output,
    particularly useful for PowerShell 5.1 where formatting can be inconsistent.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonString
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Applying JSON formatting improvements"
    
    try
    {
        # Ensure consistent line endings
        $formatted = $JsonString -replace "`r`n", "`n" -replace "`r", "`n"
        
        # Fix any double-encoded escapes that might occur in PowerShell 5.1
        $formatted = $formatted -replace '\\\\', '\'
        
        # Ensure proper spacing around colons and commas (if not compressed)
        $formatted = $formatted -replace ':\s*', ': '
        $formatted = $formatted -replace ',\s*', ',`n'
        
        Write-Verbose "[$functionName] JSON formatting completed"
        return $formatted
    }
    catch
    {
        Write-Warning "[$functionName] Failed to format JSON, returning original: $($_.Exception.Message)"
        return $JsonString
    }
}

function Save-JsonToFile
{
    <#
    .SYNOPSIS
    Safely saves JSON content to a file with PowerShell 5.1 compatibility.
    
    .DESCRIPTION
    This function provides a reliable way to save JSON content to files,
    handling encoding and error scenarios appropriately.
    
    .PARAMETER JsonContent
    The JSON string content to save
    
    .PARAMETER FilePath
    The path where to save the JSON file
    
    .PARAMETER Encoding
    Text encoding to use (default: UTF8)
    
    .PARAMETER Force
    Overwrite existing files without prompting
    
    .EXAMPLE
    $settings | ConvertTo-JsonCompatible | Save-JsonToFile -FilePath "settings.json" -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$JsonContent,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [string]$Encoding = 'UTF8',
        
        [switch]$Force
    )
    
    begin
    {
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Preparing to save JSON to: $FilePath"
    }
    
    process
    {
        try
        {
            # Validate JSON content
            if ([string]::IsNullOrWhiteSpace($JsonContent))
            {
                throw "JSON content is null or empty"
            }
            
            # Test if the JSON is valid by attempting to parse it
            try
            {
                $null = ConvertFrom-Json -InputObject $JsonContent -ErrorAction Stop
                Write-Verbose "[$functionName] JSON validation successful"
            }
            catch
            {
                Write-Warning "[$functionName] JSON validation failed, but proceeding: $($_.Exception.Message)"
            }
            
            # Create directory if it doesn't exist
            $directory = Split-Path -Path $FilePath -Parent
            if ($directory -and -not (Test-Path -Path $directory))
            {
                Write-Verbose "[$functionName] Creating directory: $directory"
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
            
            # Save the file
            $setContentParams = @{
                Path     = $FilePath
                Value    = $JsonContent
                Encoding = $Encoding
                Force    = $Force
            }
            
            Set-Content @setContentParams
            
            Write-Verbose "[$functionName] JSON successfully saved to: $FilePath"
            return $true
        }
        catch
        {
            Write-Error "[$functionName] Failed to save JSON to file '$FilePath': $($_.Exception.Message)"
            Write-Verbose "[$functionName] Save error details: $($_.Exception)"
            return $false
        }
    }
}

function Test-JsonContent
{
    <#
    .SYNOPSIS
    Tests if a string contains valid JSON content.
    
    .DESCRIPTION
    This function validates JSON content and provides detailed error information
    if the JSON is malformed.
    
    .PARAMETER JsonString
    The JSON string to validate
    
    .PARAMETER ShowErrors
    Display detailed error information if validation fails
    
    .EXAMPLE
    if (Test-JsonContent -JsonString $jsonData -ShowErrors) {
        Write-Host "JSON is valid"
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonString,
        
        [switch]$ShowErrors
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Validating JSON content"
    
    try
    {
        $null = ConvertFrom-Json -InputObject $JsonString -ErrorAction Stop
        Write-Verbose "[$functionName] JSON validation successful"
        return $true
    }
    catch
    {
        if ($ShowErrors)
        {
            Write-Error "[$functionName] JSON validation failed: $($_.Exception.Message)"
        }
        else
        {
            Write-Verbose "[$functionName] JSON validation failed: $($_.Exception.Message)"
        }
        return $false
    }
}

# Export functions for use in other scripts
Export-ModuleMember -Function ConvertTo-JsonCompatible, Save-JsonToFile, Test-JsonContent
