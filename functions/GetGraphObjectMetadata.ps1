#region help
<#PSScriptInfo
.VERSION 1.0.0
.GUID c4205f1e-35d8-4f3a-bc41-a03d7c2c70d3
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Parses OData metadata from Microsoft Graph API responses
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES Microsoft.Graph.Authentication
.SYNOPSIS
Parses the @odata.context from Graph API responses to extract metadata.
.DESCRIPTION
    When Microsoft Graph API returns an object with @odata.context property, this function
    extracts the metadata URL from that context, makes a request to the metadata endpoint,
    and parses the returned information to provide details about available properties,
    methods, filters, and capabilities of the object. This helps in constructing dynamic
    queries and exploring the object's capabilities.
.PARAMETER ApiResponse
    The response object returned from CallGraphAPI function.
.PARAMETER AccessToken
    An optional access token to use for metadata requests. If not provided, the function
    will attempt to extract it from the ApiResponse object if possible.
.EXAMPLE
    $graphResponse = CallGraphAPI -accessToken $token -ResourcePath "users"
    Get-GraphObjectMetadata -ApiResponse $graphResponse
    
    Extracts metadata for the users collection returned from Graph API.
.NOTES
    This function depends on the CallGraphAPI function for making additional API calls to
    retrieve metadata information.
#>
#endregion help

function GetGraphObjectMetadata()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [object]$ApiResponse,
        
        [Parameter(Mandatory = $false)]
        [string]$AccessToken
    )

    #region variables and logs
    Write-Verbose "Starting Get-GraphObjectMetadata function"
    
    # Initialize output containers
    $metadata = @{
        EntityType           = $null
        Properties           = @()
        NavigationProperties = @()
        Operations           = @()
        Functions            = @()
        QueryOptions         = @("filter", "select", "expand", "orderby", "top", "skip", "count")
        FilterOperators      = @("eq", "ne", "gt", "ge", "lt", "le", "and", "or", "not", "contains", "startswith", "endswith")
    }
    #endregion

    #region process response and extract context
    # Check if the response contains OData context
    if ($null -eq $ApiResponse.'@odata.context')
    {
        Write-Verbose "No @odata.context found in the provided API response"
        Write-Host "No @odata.context found in the provided API response. Cannot extract metadata." -ForegroundColor Yellow
        return $null
    }

    # Extract the context URL
    $contextUrl = $ApiResponse.'@odata.context'
    Write-Verbose "Found @odata.context: $contextUrl"
    
    # Parse the context URL to determine the entity type and version
    try 
    {
        # Extract API version from the context URL
        if ($contextUrl -match "https://graph\.microsoft\.com/(v1\.0|beta)/")
        {
            $apiVersion = $matches[1]
            Write-Verbose "API Version detected: $apiVersion"
        }
        else
        {
            $apiVersion = "v1.0" # Default to v1.0 if not found
            Write-Verbose "Could not detect API version, defaulting to: $apiVersion"
        }

        # Extract the entity set name from the context URL
        if ($contextUrl -match '/\$metadata#([^(]+)')
        {
            $entitySetPath = $matches[1]
            
            # Handle special cases like $entity or additional segments
            if ($entitySetPath -match '(.*?)(\(.+\))?$')
            {
                $entitySetName = $matches[1].Trim('/')
                Write-Verbose "Entity set name: $entitySetName"
            }
        }
        else
        {
            Write-Verbose "Could not extract entity set name from context URL"
        }
        
        # Remove any trailing segments
        $entitySetName = $entitySetName -replace '/\$count', ''
        $entitySetName = $entitySetName -replace '\(.+\)', ''
        $entitySetName = $entitySetName.TrimEnd('/')
        
        Write-Verbose "Normalized entity set name: $entitySetName"
        $metadata.EntityType = $entitySetName
    }
    catch 
    {
        Write-Verbose "Error parsing context URL: $_"
        Write-Host "Error parsing the @odata.context URL: $_" -ForegroundColor Red
    }
    #endregion

    #region fetch metadata document
    # Construct the metadata URL
    $metadataUrl = "https://graph.microsoft.com/$apiVersion/`$metadata"
    Write-Verbose "Metadata URL: $metadataUrl"
    
    # Determine the access token to use
    if (-not $AccessToken)
    {
        Write-Verbose "No access token provided, attempting to reuse token from original request"
        # Try to extract the access token if it wasn't provided
        # This is a simplification - in real scenarios you might need to handle this differently
        if ($ApiResponse.PSObject.Properties.Name -contains 'AccessToken')
        {
            $AccessToken = $ApiResponse.AccessToken
            Write-Verbose "Using access token from API response"
        }
        else
        {
            Write-Verbose "No access token available in the response"
            Write-Host "No access token provided. You may not be able to fetch additional metadata." -ForegroundColor Yellow
        }
    }
    
    try 
    {
        # Make a request to the metadata endpoint
        Write-Verbose "Requesting metadata document from $metadataUrl"
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Accept"        = "application/xml"
        }
        
        $metadataResponse = Invoke-RestMethod -Uri $metadataUrl -Headers $headers -Method Get -ErrorAction Stop
        Write-Verbose "Successfully retrieved metadata document"
        
        # The metadata is an XML document that contains the full service definition
        # We need to parse it to find details about our entity
    }
    catch 
    {
        Write-Verbose "Error retrieving metadata: $_"
        Write-Host "Error retrieving metadata: $_" -ForegroundColor Red
        Write-Host "Limited metadata will be available" -ForegroundColor Yellow
        
        # Return partial metadata even if we couldn't fetch the full document
        return $metadata
    }
    #endregion
    
    #region parse metadata XML
    try 
    {
        Write-Verbose "Parsing metadata XML document"
        
        # Find the entity type definition in the metadata
        # This is a simplified approach - full OData metadata parsing is complex
        $namespace = "Microsoft.Graph"
        
        # First, try to find the EntitySet that matches our entity set name
        $entitySetElement = $metadataResponse.Edmx.DataServices.Schema.EntityContainer.EntitySet | 
            Where-Object { $_.Name -eq $entitySetName }
            
        if ($entitySetElement)
        {
            $entityTypeName = $entitySetElement.EntityType -replace "^$namespace\.", ""
            Write-Verbose "Found EntitySet with name '$entitySetName', EntityType: $entityTypeName"
            
            # Now find the corresponding EntityType definition
            $entityTypeElement = $metadataResponse.Edmx.DataServices.Schema.EntityType | 
                Where-Object { $_.Name -eq $entityTypeName }
                
            if ($entityTypeElement)
            {
                Write-Verbose "Found EntityType definition for '$entityTypeName'"
                
                # Extract properties
                if ($entityTypeElement.Property)
                {
                    foreach ($prop in $entityTypeElement.Property)
                    {
                        $propDetails = @{
                            Name     = $prop.Name
                            Type     = $prop.Type
                            Nullable = $prop.Nullable -eq 'true'
                        }
                        $metadata.Properties += $propDetails
                        Write-Verbose "Found property: $($prop.Name) (Type: $($prop.Type))"
                    }
                }
                
                # Extract navigation properties
                if ($entityTypeElement.NavigationProperty)
                {
                    foreach ($navProp in $entityTypeElement.NavigationProperty)
                    {
                        $navDetails = @{
                            Name           = $navProp.Name
                            Type           = $navProp.Type
                            ContainsTarget = $navProp.ContainsTarget -eq 'true'
                        }
                        $metadata.NavigationProperties += $navDetails
                        Write-Verbose "Found navigation property: $($navProp.Name) (Type: $($navProp.Type))"
                    }
                }
            }
        }
        
        # Look for operations (actions and functions) that apply to this entity type
        $operations = $metadataResponse.Edmx.DataServices.Schema.Action + $metadataResponse.Edmx.DataServices.Schema.Function
        foreach ($op in $operations)
        {
            # Check if this operation applies to our entity type
            $paramIsEntityType = $op.Parameter | 
                Where-Object { $_.Type -match "^$namespace\.$entityTypeName\b" -and $_.Name -eq "bindingParameter" }
                
            if ($paramIsEntityType)
            {
                $opDetails = @{
                    Name       = $op.Name
                    Type       = if ($op.LocalName -eq 'Action')
                    {
                        'Action' 
                    }
                    else
                    {
                        'Function' 
                    }
                    Parameters = @()
                }
                
                # Add parameters (excluding binding parameter)
                foreach ($param in $op.Parameter)
                {
                    if ($param.Name -ne "bindingParameter")
                    {
                        $opDetails.Parameters += @{
                            Name     = $param.Name
                            Type     = $param.Type
                            Nullable = $param.Nullable -eq 'true'
                        }
                    }
                }
                
                if ($op.LocalName -eq 'Action')
                {
                    $metadata.Operations += $opDetails
                }
                else 
                {
                    $metadata.Functions += $opDetails    
                }
                
                Write-Verbose "Found $($op.LocalName): $($op.Name)"
            }
        }
    }
    catch 
    {
        Write-Verbose "Error parsing metadata XML: $_"
        Write-Host "Error parsing metadata XML: $_" -ForegroundColor Red
    }
    #endregion
    
    #region enhance with additional info
    # If we have a single entity response, try to extract additional properties from the actual response
    if ($ApiResponse -and -not ($ApiResponse -is [array]) -and -not ($ApiResponse.value -is [array]))
    {
        Write-Verbose "Extracting additional property information from the API response"
        
        $responseProperties = $ApiResponse.PSObject.Properties | 
            Where-Object { $_.Name -notlike '@odata*' } |
            ForEach-Object { $_.Name }
            
        foreach ($propName in $responseProperties)
        {
            if (-not ($metadata.Properties | Where-Object { $_.Name -eq $propName }))
            {
                $propType = if ($ApiResponse.$propName -is [array])
                {
                    "Collection" 
                }
                else
                {
                    $ApiResponse.$propName.GetType().Name 
                }
                
                $metadata.Properties += @{
                    Name         = $propName
                    Type         = $propType
                    Nullable     = $null -eq $ApiResponse.$propName
                    FromResponse = $true
                }
                
                Write-Verbose "Added property from response: $propName (Type: $propType)"
            }
        }
    }
    # If we have a collection response, look at the first item
    elseif ($ApiResponse.value -and $ApiResponse.value.Count -gt 0)
    {
        Write-Verbose "Extracting additional property information from the first item in the collection"
        
        $firstItem = $ApiResponse.value[0]
        $responseProperties = $firstItem.PSObject.Properties | 
            Where-Object { $_.Name -notlike '@odata*' } |
            ForEach-Object { $_.Name }
            
        foreach ($propName in $responseProperties)
        {
            if (-not ($metadata.Properties | Where-Object { $_.Name -eq $propName }))
            {
                $propType = if ($firstItem.$propName -is [array])
                {
                    "Collection" 
                }
                else
                {
                    $firstItem.$propName.GetType().Name 
                }
                
                $metadata.Properties += @{
                    Name         = $propName
                    Type         = $propType
                    Nullable     = $null -eq $firstItem.$propName
                    FromResponse = $true
                }
                
                Write-Verbose "Added property from first collection item: $propName (Type: $propType)"
            }
        }
    }
    #endregion
    
    #region format and return results
    # Organize the results in a user-friendly format
    $formattedResults = [PSCustomObject]@{
        EntityType           = $metadata.EntityType
        Properties           = $metadata.Properties | ForEach-Object {
            [PSCustomObject]@{
                Name         = $_.Name
                Type         = $_.Type
                Nullable     = $_.Nullable
                FromResponse = if ($_.ContainsKey('FromResponse'))
                {
                    $_.FromResponse 
                }
                else
                {
                    $false 
                }
            }
        }
        NavigationProperties = $metadata.NavigationProperties | ForEach-Object {
            [PSCustomObject]@{
                Name           = $_.Name
                Type           = $_.Type
                ContainsTarget = $_.ContainsTarget
            }
        }
        Operations           = $metadata.Operations | ForEach-Object {
            [PSCustomObject]@{
                Name       = $_.Name
                Type       = $_.Type
                Parameters = $_.Parameters | ForEach-Object {
                    [PSCustomObject]@{
                        Name     = $_.Name
                        Type     = $_.Type
                        Nullable = $_.Nullable
                    }
                }
            }
        }
        Functions            = $metadata.Functions | ForEach-Object {
            [PSCustomObject]@{
                Name       = $_.Name
                Type       = $_.Type
                Parameters = $_.Parameters | ForEach-Object {
                    [PSCustomObject]@{
                        Name     = $_.Name
                        Type     = $_.Type
                        Nullable = $_.Nullable
                    }
                }
            }
        }
        QueryOptions         = $metadata.QueryOptions
        FilterOperators      = $metadata.FilterOperators
        Capabilities         = [PSCustomObject]@{
            Filterable     = $metadata.Properties.Count -gt 0
            Selectable     = $true
            Expandable     = $metadata.NavigationProperties.Count -gt 0
            Orderable      = $metadata.Properties.Count -gt 0
            CountSupported = $true
            Searchable     = $metadata.EntityType -in @('users', 'groups', 'sites', 'drives')
        }
    }
    
    Write-Verbose "Metadata extraction complete"
    return $formattedResults
    #endregion
}