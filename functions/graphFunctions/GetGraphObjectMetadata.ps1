function GetGraphObjectMetadata()
{
    <#
.SYNOPSIS
Parses the @odata.context from Graph API responses to extract metadata.
.DESCRIPTION
    When Microsoft Graph API returns an object with @odata.context property, this function
    extracts the metadata URL from that context, makes a request to the metadata endpoint,
    and parses the returned information to provide details about available properties,
    methods, filters, and capabilities of the object. This helps in constructing dynamic
    queries and exploring the object's capabilities.
    
    Enhanced capabilities include:
    - Better handling of complex types and properties
    - Recursive analysis of nested complex types
    - Improved detection of OData functions and actions
    - Support for OData type hierarchies and inheritance
    - Generation of sample query templates for the entity
    - Detection of collection properties and their element types
.PARAMETER ApiResponse
    The response object returned from CallGraphAPI function.
.PARAMETER AccessToken
    An optional access token to use for metadata requests. If not provided, the function
    will attempt to extract it from the ApiResponse object if possible.
.PARAMETER IncludeSampleQueries
    Include sample query templates for common operations on the entity.
    Default is $true.
.PARAMETER RecursionDepth
    Maximum depth for recursively analyzing nested complex types.
    Default is 3 to prevent excessive processing.
.EXAMPLE
    $graphResponse = CallGraphAPI -accessToken $token -ResourcePath "users"
    GetGraphObjectMetadata -ApiResponse $graphResponse
    
    Extracts metadata for the users collection returned from Graph API.
.EXAMPLE
    $graphResponse = CallGraphAPI -accessToken $token -ResourcePath "groups"
    GetGraphObjectMetadata -ApiResponse $graphResponse -RecursionDepth 4 -IncludeSampleQueries $true
    
    Extracts metadata with deeper complex type analysis and includes sample queries.
.NOTES
    This function depends on the CallGraphAPI function for making additional API calls to
    retrieve metadata information.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNull()]
        [object]$ApiResponse,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [bool]$IncludeSampleQueries = $true,
        [Parameter(Mandatory = $false)]
        [int]$RecursionDepth = 3,
        [Parameter(Mandatory = $false)]
        [ValidateSet('object', 'json')]
        [string]$OutputFormat = 'object',
        [Parameter(Mandatory = $false)]
        [string]$CustomMetadataUrl
    )
    
    $ functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $logFile -module $functionName -Message "Starting GetGraphObjectMetadata function with RecursionDepth=$RecursionDepth" -logLevel "Verbose"
    if (-not $ApiResponse)
    {
        Write-Log -logFile $logFile -module $functionName -Message "ApiResponse parameter is null or empty." -logLevel "Error"
        return $null
    }
    
    # Initialize output containers
    $metadata = @{
        EntityType            = $null
        Properties            = @()
        NavigationProperties  = @()
        Operations            = @()
        Functions             = @()
        ComplexTypes          = @()
        EnumTypes             = @()
        CollectionTypes       = @()
        EntityTypeInheritance = @{
            BaseType     = $null
            DerivedTypes = @()
        }
        Annotations           = @()
        QueryOptions          = @("filter", "select", "expand", "orderby", "top", "skip", "count", "search")
        FilterOperators       = @("eq", "ne", "gt", "ge", "lt", "le", "and", "or", "not", "contains", "startswith", "endswith", "any", "all")
        SampleQueries         = @()
        TypeDefinitions       = @{}
        GraphVersion          = "v1.0"
    }
    
    # Create a script-level variable to track processed types (prevents infinite recursion)
    $script:processedTypes = @{}
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
    if ($CustomMetadataUrl)
    {
        $metadataUrl = $CustomMetadataUrl
        Write-Log -logFile $logFile -module $functionName -Message "Using custom metadata URL: $metadataUrl" -logLevel "Verbose"
    }
    else
    {
        $metadataUrl = "https://graph.microsoft.com/$apiVersion/`$metadata"
        Write-Log -logFile $logFile -module $functionName -Message "Metadata URL: $metadataUrl"
    }
    
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
        Write-Log -logFile $logFile -module $functionName -Message "Requesting metadata document from $metadataUrl"
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Accept"        = "application/xml"
        }
        
        $metadataResponse = Invoke-RestMethod -Uri $metadataUrl -Headers $headers -Method Get -ErrorAction Stop
        Write-Log -logFile $logFile -module $functionName -Message "Successfully retrieved metadata document" -logLevel "Verbose"       
        
        # The metadata is an XML document that contains the full service definition
        # We need to parse it to find details about our entity
    }
    catch 
    {
        Write-Log -logFile $logFile -module $functionName -Message "Error retrieving metadata: $_" -logLevel "Error"
        Write-Log -logFile $logFile -module $functionName -Message "Limited metadata will be available" -logLevel "Warning" 
        # Return partial metadata even if we couldn't fetch the full document
        return $metadata
    }
    #endregion
    
    #region parse metadata XML
    try 
    {
        Write-Verbose "Parsing metadata XML document"
        
        # Add helper functions for processing complex types
        function Get-ComplexTypeDetails
        {
            param (
                [Parameter(Mandatory = $true)]
                [object]$TypeElement,
                
                [Parameter(Mandatory = $true)]
                [string]$TypeName,
                
                [Parameter(Mandatory = $true)]
                [int]$CurrentDepth,
                
                [Parameter(Mandatory = $false)]
                [string]$Namespace = "Microsoft.Graph"
            )
            
            # Check if we've already processed this type
            if ($script:processedTypes.ContainsKey($TypeName))
            {
                Write-Verbose "Type '$TypeName' already processed, returning reference"
                return $script:processedTypes[$TypeName]
            }
            
            # Check recursion depth
            if ($CurrentDepth -gt $RecursionDepth)
            {
                Write-Verbose "Maximum recursion depth reached for type: $TypeName"
                return @{
                    Name            = $TypeName
                    Properties      = @()
                    MaxDepthReached = $true
                }
            }
            
            Write-Verbose "Processing complex type: $TypeName (Depth: $CurrentDepth)"
            
            # Create complex type details
            $complexTypeDetails = @{
                Name       = $TypeName
                Properties = @()
                BaseType   = $null
            }
            
            # Store reference to prevent recursion loops
            $script:processedTypes[$TypeName] = $complexTypeDetails
            
            # Extract base type if any
            if ($TypeElement.BaseType)
            {
                $baseTypeFull = $TypeElement.BaseType
                $baseTypeName = $baseTypeFull -replace "^$Namespace\.", ""
                $complexTypeDetails.BaseType = $baseTypeName
                Write-Verbose "Complex type '$TypeName' inherits from base type: $baseTypeName"
            }
            
            # Extract properties
            foreach ($prop in $TypeElement.Property)
            {
                $propDetails = @{
                    Name          = $prop.Name
                    Type          = $prop.Type
                    Nullable      = $prop.Nullable -eq 'true'
                    Documentation = $null
                }
                
                # Extract property documentation if available
                if ($prop.Annotation)
                {
                    $docAnnotation = $prop.Annotation | Where-Object { $_.Term -eq 'Org.OData.Core.V1.Description' }
                    if ($docAnnotation -and $docAnnotation.String)
                    {
                        $propDetails.Documentation = $docAnnotation.String
                    }
                }
                
                # Identify if this is a complex type reference
                if ($prop.Type -notmatch "^Edm\.")
                {
                    # Handle collection types
                    $isCollection = $prop.Type -match "^Collection\((.*)\)$"
                    if ($isCollection)
                    {
                        $innerTypeName = $matches[1] -replace "^$Namespace\.", ""
                        $propDetails.IsCollection = $true
                        $propDetails.ElementType = $innerTypeName
                        
                        # If it's not a primitive type, try to process it recursively
                        if ($innerTypeName -notmatch "^Edm\.")
                        {
                            $innerTypeElement = $metadataResponse.Edmx.DataServices.Schema.ComplexType | 
                                Where-Object { $_.Name -eq $innerTypeName }
                                
                            if ($innerTypeElement)
                            {
                                $propDetails.ElementTypeDetails = Get-ComplexTypeDetails -TypeElement $innerTypeElement -TypeName $innerTypeName -CurrentDepth ($CurrentDepth + 1) -Namespace $Namespace
                            }
                        }
                    }
                    else
                    {
                        # It's a direct reference to another complex type
                        $referencedTypeName = $prop.Type -replace "^$Namespace\.", ""
                        
                        if ($referencedTypeName -ne $prop.Type)
                        {
                            # Try to find and process the referenced complex type
                            $referencedTypeElement = $metadataResponse.Edmx.DataServices.Schema.ComplexType | 
                                Where-Object { $_.Name -eq $referencedTypeName }
                                
                            if ($referencedTypeElement)
                            {
                                $propDetails.ComplexTypeDetails = Get-ComplexTypeDetails -TypeElement $referencedTypeElement -TypeName $referencedTypeName -CurrentDepth ($CurrentDepth + 1) -Namespace $Namespace
                            }
                        }
                    }
                }
                
                # Add to properties list
                $complexTypeDetails.Properties += $propDetails
            }
            
            return $complexTypeDetails
        }
        
        # Helper function to extract type mappings for query construction
        function Get-TypeMappings
        {
            param (
                [Parameter(Mandatory = $true)]
                [string]$TypeName,
                
                [Parameter(Mandatory = $false)]
                [string]$Namespace = "Microsoft.Graph"
            )
            
            $typeInfo = @{
                Name           = $TypeName
                PrimitiveTypes = @{
                    'Edm.String'         = 'string'
                    'Edm.Int32'          = 'integer'
                    'Edm.Int64'          = 'long integer'
                    'Edm.Boolean'        = 'boolean'
                    'Edm.DateTimeOffset' = 'datetime'
                    'Edm.Date'           = 'date'
                    'Edm.TimeOfDay'      = 'time'
                    'Edm.Guid'           = 'GUID'
                    'Edm.Binary'         = 'binary data'
                    'Edm.Decimal'        = 'decimal number'
                    'Edm.Double'         = 'double-precision number'
                    'Edm.Single'         = 'single-precision number'
                }
            }
            
            # Look up all properties that reference this type
            $entityType = $metadataResponse.Edmx.DataServices.Schema.EntityType | 
                Where-Object { $_.Name -eq $TypeName }
                
            if ($entityType)
            {
                $typeInfo.Properties = @{
                }
                
                foreach ($prop in $entityType.Property)
                {
                    $propType = $prop.Type
                    $isCollection = $propType -match "^Collection\((.*)\)$"
                    
                    if ($isCollection)
                    {
                        $innerType = $matches[1]
                        $typeInfo.Properties[$prop.Name] = @{
                            Type         = $propType
                            IsCollection = $true
                            ElementType  = $innerType
                            Filterable   = $prop.Name -notin @('id', '@odata.type', '@odata.context')
                        }
                    }
                    else
                    {
                        $typeInfo.Properties[$prop.Name] = @{
                            Type         = $propType
                            IsCollection = $false
                            Filterable   = $prop.Name -notin @('id', '@odata.type', '@odata.context')
                        }
                    }
                }
            }
            
            return $typeInfo
        }
        
        # Helper function to generate sample queries
        function Get-SampleQueries
        {
            param (
                [Parameter(Mandatory = $true)]
                [string]$EntityType,
                
                [Parameter(Mandatory = $true)]
                [array]$Properties,
                
                [Parameter(Mandatory = $true)]
                [array]$NavigationProperties
            )
            
            $samples = @()
            
            # Basic select query
            $selectableProps = $Properties | Where-Object { $_.Name -notlike '@*' } | Select-Object -First 5 -ExpandProperty Name
            if ($selectableProps.Count -gt 0)
            {
                $samples += @{
                    Name        = "Basic Select"
                    Template    = "/$EntityType?`$select=$($selectableProps -join ',')"
                    Description = "Retrieves specific fields from $EntityType entities"
                }
            }
            
            # Filter query if we have string properties
            $stringProps = $Properties | Where-Object { $_.Type -eq 'Edm.String' -and $_.Name -notlike '@*' } | Select-Object -First 3 -ExpandProperty Name
            if ($stringProps.Count -gt 0)
            {
                $samples += @{
                    Name        = "Filter by String Property"
                    Template    = "/$EntityType?`$filter=$($stringProps[0]) eq '{value}'"
                    Description = "Filters $EntityType entities by $($stringProps[0]) equality"
                }
                
                $samples += @{
                    Name        = "Filter with startsWith"
                    Template    = "/$EntityType?`$filter=startswith($($stringProps[0]), '{prefix}')"
                    Description = "Filters $EntityType entities where $($stringProps[0]) starts with a specific value"
                }
            }
            
            # Expand navigation property if available
            if ($NavigationProperties.Count -gt 0)
            {
                $navProp = $NavigationProperties[0].Name
                $samples += @{
                    Name        = "Expand Navigation Property"
                    Template    = "/$EntityType?`$expand=$navProp"
                    Description = "Retrieves $EntityType entities with expanded $navProp relationships"
                }
            }
            
            # Combined query
            if ($selectableProps.Count -gt 0 -and $stringProps.Count -gt 0)
            {
                $samples += @{
                    Name        = "Combined Query"
                    Template    = "/$EntityType?`$select=$($selectableProps -join ',')&`$filter=$($stringProps[0]) eq '{value}'&`$orderby=$($selectableProps[0]) asc&`$top=10"
                    Description = "Combined query with select, filter, orderby and top"
                }
            }
            
            # Count query
            $samples += @{
                Name        = "Count Entities"
                Template    = "/$EntityType/`$count"
                Description = "Returns the total count of $EntityType entities"
            }
            
            return $samples
        }
        
        # Find the entity type definition in the metadata
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
                
                # Extract inheritance information
                if ($entityTypeElement.BaseType)
                {
                    $baseTypeFull = $entityTypeElement.BaseType
                    $baseTypeName = $baseTypeFull -replace "^$namespace\.", ""
                    $metadata.EntityTypeInheritance.BaseType = $baseTypeName
                    Write-Verbose "Entity '$entityTypeName' inherits from base type: $baseTypeName"
                }
                
                # Look for derived types (entities that have this entity as their base type)
                $derivedTypes = $metadataResponse.Edmx.DataServices.Schema.EntityType | 
                    Where-Object { $_.BaseType -eq "$namespace.$entityTypeName" }
                
                if ($derivedTypes)
                {
                    foreach ($derivedType in $derivedTypes)
                    {
                        $metadata.EntityTypeInheritance.DerivedTypes += $derivedType.Name
                        Write-Verbose "Found derived type: $($derivedType.Name)"
                    }
                }
                
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
                
                # Extract complex types referenced by this entity
                Write-Verbose "Extracting complex types referenced by entity properties"
                $complexTypesReferenced = @()
                
                # Find complex types from property types
                foreach ($prop in $metadata.Properties)
                {
                    if ($prop.Type -notmatch "^Edm\.")
                    {
                        $complexTypeName = $prop.Type -replace "^Collection\((.*)\)$", '$1' -replace "^$namespace\.", ""
                        if ($complexTypeName -ne $prop.Type)
                        {
                            $complexTypesReferenced += $complexTypeName
                        }
                    }
                }
                
                # Find the complex type definitions
                foreach ($complexTypeName in $complexTypesReferenced | Select-Object -Unique)
                {
                    $complexTypeElement = $metadataResponse.Edmx.DataServices.Schema.ComplexType | 
                        Where-Object { $_.Name -eq $complexTypeName }
                        
                    if ($complexTypeElement)
                    {
                        $complexTypeDetails = @{
                            Name       = $complexTypeName
                            Properties = @()
                        }
                        
                        # Extract properties of the complex type
                        foreach ($prop in $complexTypeElement.Property)
                        {
                            $complexTypeDetails.Properties += @{
                                Name     = $prop.Name
                                Type     = $prop.Type
                                Nullable = $prop.Nullable -eq 'true'
                            }
                        }
                        
                        $metadata.ComplexTypes += $complexTypeDetails
                        Write-Verbose "Added complex type: $complexTypeName with $($complexTypeDetails.Properties.Count) properties"
                    }
                }
                
                # Extract enum types
                Write-Verbose "Extracting enum types referenced by entity properties"
                $enumTypes = $metadataResponse.Edmx.DataServices.Schema.EnumType
                
                foreach ($enumType in $enumTypes)
                {
                    $enumTypeName = $enumType.Name
                    $enumTypeDetails = @{
                        Name           = $enumTypeName
                        UnderlyingType = $enumType.UnderlyingType
                        IsFlags        = $enumType.IsFlags -eq 'true'
                        Members        = @()
                    }
                    
                    # Extract enum members
                    foreach ($member in $enumType.Member)
                    {
                        $enumTypeDetails.Members += @{
                            Name  = $member.Name
                            Value = $member.Value
                        }
                    }
                    
                    $metadata.EnumTypes += $enumTypeDetails
                    Write-Verbose "Added enum type: $enumTypeName with $($enumTypeDetails.Members.Count) members"
                }
                
                # Extract annotations
                Write-Verbose "Extracting annotations for entity type"
                if ($entityTypeElement.Annotation)
                {
                    foreach ($annotation in $entityTypeElement.Annotation)
                    {
                        $annotationDetails = @{
                            Term   = $annotation.Term
                            String = $annotation.String
                            Bool   = $annotation.Bool
                            Int    = $annotation.Int
                        }
                        
                        $metadata.Annotations += $annotationDetails
                        Write-Verbose "Added annotation: $($annotation.Term)"
                    }
                }
                
                # Extract navigation properties from the entity type definition
                Write-Verbose "Extracting navigation properties from entity type definition"
                if ($entityTypeElement.NavigationProperty)
                {
                    foreach ($navProp in $entityTypeElement.NavigationProperty)
                    {
                        $targetType = $navProp.Type -replace "^Collection\((.*)\)$", '$1' -replace "^$namespace\.", ""
                        $isCollection = $navProp.Type -match "^Collection\("
                        
                        $navPropDetails = @{
                            Name             = $navProp.Name
                            Type             = "NavigationProperty"
                            TargetEntityType = $targetType
                            IsCollection     = $isCollection
                            ContainsTarget   = $navProp.ContainsTarget -eq 'true'
                            NavigationPath   = "$entityTypeName/$($navProp.Name)"
                        }
                        
                        # Add partner navigation property if defined
                        if ($navProp.Partner)
                        {
                            $navPropDetails.Partner = $navProp.Partner
                            Write-Verbose "Navigation property $($navProp.Name) has partner: $($navProp.Partner)"
                        }
                        
                        # Add referential constraint if defined
                        if ($navProp.ReferentialConstraint)
                        {
                            $navPropDetails.ReferentialConstraint = @{
                                Property           = $navProp.ReferentialConstraint.Property
                                ReferencedProperty = $navProp.ReferentialConstraint.ReferencedProperty
                            }
                            Write-Verbose "Navigation property $($navProp.Name) has referential constraint"
                        }
                        
                        # Add OnDelete action if defined
                        if ($navProp.OnDelete)
                        {
                            $navPropDetails.OnDelete = $navProp.OnDelete.Action
                            Write-Verbose "Navigation property $($navProp.Name) has OnDelete action: $($navProp.OnDelete.Action)"
                        }
                        
                        # Try to get additional details about the target entity type
                        $targetEntityTypeElement = $metadataResponse.Edmx.DataServices.Schema.EntityType | 
                            Where-Object { $_.Name -eq $targetType }
                            
                        if ($targetEntityTypeElement)
                        {
                            $navPropDetails.TargetEntityDetails = @{
                                Name       = $targetType
                                Properties = @($targetEntityTypeElement.Property | ForEach-Object { $_.Name })
                            }
                            Write-Verbose "Found target entity type details for $targetType with $($navPropDetails.TargetEntityDetails.Properties.Count) properties"
                        }
                        
                        $metadata.NavigationProperties += $navPropDetails
                        Write-Verbose "Added navigation property from metadata: $($navProp.Name) (Target: $targetType, IsCollection: $isCollection)"
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
    
    #region detect navigation properties from response
    # Also detect navigation properties by examining the actual response for links
    Write-Verbose "Looking for navigation properties in the actual response data"
    
    # Function to extract navigation links from an entity
    function Get-NavigationLinksFromEntity
    {
        param (
            [Parameter(Mandatory = $true)]
            [object]$Entity,
            
            [string]$EntityPath = ""
        )
        
        $navLinks = @()
        
        foreach ($propName in $Entity.PSObject.Properties.Name)
        {
            # Look for @odata.navigationLink or @odata.associationLink
            if ($propName -eq "@odata.navigationLink" -or $propName -eq "@odata.associationLink")
            {
                foreach ($linkProp in $Entity.$propName.PSObject.Properties)
                {
                    $navLinks += @{
                        Name = $linkProp.Name
                        Url  = $linkProp.Value
                        Type = $propName
                    }
                    Write-Verbose "Found navigation link in response: $($linkProp.Name) -> $($linkProp.Value)"
                }
            }
            # Also look for any property that looks like a URL to another entity
            elseif ($propName -notlike '@odata*' -and $propName -like '*@odata.context' -or 
                $propName -like '*@odata.nextLink' -or $Entity.$propName -is [hashtable] -or 
                $Entity.$propName -is [PSCustomObject])
            {
                $navLinks += @{
                    Name = $propName
                    Type = "Embedded"
                    Path = if ([string]::IsNullOrEmpty($EntityPath))
                    {
                        $propName 
                    }
                    else
                    {
                        "$EntityPath/$propName" 
                    }
                }
                Write-Verbose "Found potential embedded navigation property in response: $propName"
            }
        }
        
        return $navLinks
    }
    
    # Check for navigation links in single entity response
    if ($ApiResponse -and -not ($ApiResponse -is [array]) -and -not ($ApiResponse.value -is [array]))
    {
        $responseNavLinks = Get-NavigationLinksFromEntity -Entity $ApiResponse
        
        foreach ($navLink in $responseNavLinks)
        {
            # Check if we already have this navigation property from metadata
            $existingNavProp = $metadata.NavigationProperties | Where-Object { $_.Name -eq $navLink.Name }
            
            if (-not $existingNavProp)
            {
                $metadata.NavigationProperties += @{
                    Name             = $navLink.Name
                    Type             = "Unknown"
                    TargetEntityType = "Unknown"
                    IsCollection     = $false  # We can't determine this from just the response
                    FromResponse     = $true
                    NavigationPath   = $navLink.Path
                }
                Write-Verbose "Added navigation property from response: $($navLink.Name)"
            }
        }
    }
    # If we have a collection response, look at the first item
    elseif ($ApiResponse.value -and $ApiResponse.value.Count -gt 0)
    {
        $firstItem = $ApiResponse.value[0]
        $responseNavLinks = Get-NavigationLinksFromEntity -Entity $firstItem
        
        foreach ($navLink in $responseNavLinks)
        {
            # Check if we already have this navigation property from metadata
            $existingNavProp = $metadata.NavigationProperties | Where-Object { $_.Name -eq $navLink.Name }
            
            if (-not $existingNavProp)
            {
                $metadata.NavigationProperties += @{
                    Name             = $navLink.Name
                    Type             = "Unknown"
                    TargetEntityType = "Unknown"
                    IsCollection     = $false  # We can't determine this from just the response
                    FromResponse     = $true
                    NavigationPath   = $navLink.Path
                }
                Write-Verbose "Added navigation property from response: $($navLink.Name)"
            }
        }
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
                # Add null check before calling GetType()
                $propType = if ($ApiResponse.$propName -is [array])
                {
                    "Collection" 
                }
                elseif ($null -eq $ApiResponse.$propName)
                {
                    "Unknown"
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
                # Add null check before calling GetType()
                $propType = if ($firstItem.$propName -is [array])
                {
                    "Collection" 
                }
                elseif ($null -eq $firstItem.$propName)
                {
                    "Unknown"
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
                
                Write-Verbose "Added property from response: $propName (Type: $propType)"
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
            $navPropObj = [PSCustomObject]@{
                Name             = $_.Name
                Type             = $_.Type
                TargetEntityType = if ($_.ContainsKey('TargetEntityType'))
                {
                    $_.TargetEntityType 
                }
                else
                {
                    "Unknown" 
                }
                IsCollection     = if ($_.ContainsKey('IsCollection'))
                {
                    $_.IsCollection 
                }
                else
                {
                    $false 
                }
                ContainsTarget   = if ($_.ContainsKey('ContainsTarget'))
                {
                    $_.ContainsTarget 
                }
                else
                {
                    $false 
                }
                FromResponse     = if ($_.ContainsKey('FromResponse'))
                {
                    $_.FromResponse 
                }
                else
                {
                    $false 
                }
                NavigationPath   = if ($_.ContainsKey('NavigationPath'))
                {
                    $_.NavigationPath 
                }
                else
                {
                    "$($metadata.EntityType)/$($_.Name)" 
                }
            }
            
            # Add additional properties if they exist
            if ($_.ContainsKey('Partner') -and $null -ne $_.Partner)
            {
                $navPropObj | Add-Member -MemberType NoteProperty -Name 'Partner' -Value $_.Partner
            }
            
            if ($_.ContainsKey('ReferentialConstraint') -and $null -ne $_.ReferentialConstraint)
            {
                $navPropObj | Add-Member -MemberType NoteProperty -Name 'ReferentialConstraint' -Value $_.ReferentialConstraint
            }
            
            if ($_.ContainsKey('OnDelete') -and $null -ne $_.OnDelete)
            {
                $navPropObj | Add-Member -MemberType NoteProperty -Name 'OnDelete' -Value $_.OnDelete
            }
            
            if ($_.ContainsKey('TargetEntityDetails') -and $null -ne $_.TargetEntityDetails)
            {
                $navPropObj | Add-Member -MemberType NoteProperty -Name 'TargetEntityDetails' -Value $_.TargetEntityDetails
            }
            
            $navPropObj
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
    
    Write-Log -logFile $logFile -module $functionName -Message "Metadata extraction complete with enhanced navigation properties" -logLevel "Verbose"
    if ($OutputFormat -eq 'json')
    {
        return $formattedResults | ConvertTo-Json -Depth 10
    }
    else
    {
        return $formattedResults
    }
    #endregion
}