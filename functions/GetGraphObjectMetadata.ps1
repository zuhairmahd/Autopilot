#region help
<#PSScriptInfo
.VERSION 1.2.0
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
#endregion help

function GetGraphObjectMetadata()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [object]$ApiResponse,
        
        [Parameter(Mandatory = $false)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeSampleQueries = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$RecursionDepth = 3
    )

    #region variables and logs
    Write-Verbose "Starting GetGraphObjectMetadata function with RecursionDepth=$RecursionDepth"
    
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
            $metadata.GraphVersion = $apiVersion
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
            $entitySetName = "Unknown"
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
    
    #region helper functions for metadata processing
    # Function to recursively process complex types
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
        
        # Check if we've already processed this type to prevent circular references
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
        if ($TypeElement.Property)
        {
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
        }
        
        return $complexTypeDetails
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
        
        $samples = @()        # Basic select query
        $selectableProps = @($Properties | Where-Object { $_.Name -notlike '@*' } | Select-Object -First 5 | ForEach-Object { $_.Name })
        if ($selectableProps -and $selectableProps.Count -gt 0)
        {
            $samples += @{
                Name        = "Basic Select"
                Template    = "/$EntityType?`$select=$($selectableProps -join ',')"
                Description = "Retrieves specific fields from $EntityType entities"
            }
        }
        
        # Filter query if we have string properties
        $stringProps = @($Properties | Where-Object { $_.Type -eq 'Edm.String' -and $_.Name -notlike '@*' } | Select-Object -First 3 | ForEach-Object { $_.Name })
        if ($stringProps -and $stringProps.Count -gt 0)
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
        if ($null -ne $NavigationProperties -and @($NavigationProperties).Count -gt 0)
        {
            $navProp = $NavigationProperties[0].Name
            if ($navProp)
            {
                $samples += @{
                    Name        = "Expand Navigation Property"
                    Template    = "/$EntityType?`$expand=$navProp"
                    Description = "Retrieves $EntityType entities with expanded $navProp relationships"
                }
            }
        }
        # Combined query
        if ($null -ne $selectableProps -and $null -ne $stringProps -and 
            ($selectableProps.Count -gt 0) -and ($stringProps.Count -gt 0))
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
            elseif ($propName -notlike '@odata*' -and 
                   ($propName -like '*@odata.context' -or 
                $propName -like '*@odata.nextLink' -or 
                $Entity.$propName -is [hashtable] -or 
                $Entity.$propName -is [PSCustomObject]))
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
    
    # Function to analyze property for complex type detection
    function Get-PropertyTypeInfo
    {
        param (
            [Parameter(Mandatory = $true)]
            [string]$PropertyType,
            
            [Parameter(Mandatory = $false)]
            [string]$Namespace = "Microsoft.Graph"
        )
        
        $typeInfo = @{
            OriginalType = $PropertyType
            IsComplex    = $false
            IsCollection = $false
            IsPrimitive  = $false
            ElementType  = $null
            Namespace    = $Namespace
        }
        
        # Check if it's a collection
        if ($PropertyType -match "^Collection\((.*)\)$")
        {
            $typeInfo.IsCollection = $true
            $innerType = $matches[1]
            $typeInfo.ElementType = $innerType
            
            # Check if the element type is a primitive (Edm.*) or complex type
            if ($innerType -match "^Edm\.")
            {
                $typeInfo.IsPrimitive = $true
            }
            else
            {
                $typeInfo.IsComplex = $true
                # Strip namespace if present
                $typeInfo.ElementType = $innerType -replace "^$Namespace\.", ""
            }
        }
        else
        {
            # Not a collection, check if primitive or complex
            if ($PropertyType -match "^Edm\.")
            {
                $typeInfo.IsPrimitive = $true
            }
            else
            {
                $typeInfo.IsComplex = $true
                # Strip namespace if present
                $typeInfo.ElementType = $PropertyType -replace "^$Namespace\.", ""
            }
        }
        
        return $typeInfo
    }
    #endregion helper functions
    
    #region parse metadata
    try
    {
        Write-Verbose "Parsing metadata XML document"
        
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
                
                # Extract properties with enhanced type analysis
                if ($entityTypeElement.Property)
                {
                    foreach ($prop in $entityTypeElement.Property)
                    {
                        $propTypeInfo = Get-PropertyTypeInfo -PropertyType $prop.Type -Namespace $namespace
                        
                        $propDetails = @{
                            Name         = $prop.Name
                            Type         = $prop.Type
                            Nullable     = $prop.Nullable -eq 'true'
                            IsCollection = $propTypeInfo.IsCollection
                            IsPrimitive  = $propTypeInfo.IsPrimitive
                            IsComplex    = $propTypeInfo.IsComplex
                        }
                        
                        # If complex type, add details about it
                        if ($propTypeInfo.IsComplex)
                        {
                            $complexTypeName = if ($propTypeInfo.IsCollection)
                            {
                                $propTypeInfo.ElementType 
                            }
                            else
                            {
                                $propTypeInfo.ElementType 
                            }
                            
                            # Find the complex type definition
                            $complexTypeElement = $metadataResponse.Edmx.DataServices.Schema.ComplexType | 
                                Where-Object { $_.Name -eq $complexTypeName }
                                
                            if ($complexTypeElement)
                            {
                                $propDetails.ComplexTypeDetails = Get-ComplexTypeDetails -TypeElement $complexTypeElement -TypeName $complexTypeName -CurrentDepth 1 -Namespace $namespace
                            }
                        }
                        
                        # Extract documentation if available
                        if ($prop.Annotation)
                        {
                            $docAnnotation = $prop.Annotation | Where-Object { $_.Term -eq 'Org.OData.Core.V1.Description' }
                            if ($docAnnotation -and $docAnnotation.String)
                            {
                                $propDetails.Documentation = $docAnnotation.String
                            }
                        }
                        
                        $metadata.Properties += $propDetails
                        Write-Verbose "Added property: $($prop.Name) (Type: $($prop.Type), Complex: $($propDetails.IsComplex))"
                    }
                }
                
                # Extract complex types referenced by this entity
                Write-Verbose "Extracting complex types referenced by entity properties"
                $complexTypesReferenced = @()
                
                # Find complex types from property types
                foreach ($prop in $metadata.Properties)
                {
                    if ($prop.IsComplex)
                    {
                        $complexTypeName = if ($prop.IsCollection)
                        { 
                            ($prop.Type -replace "^Collection\((.*)\)$", '$1') -replace "^$namespace\.", "" 
                        }
                        else
                        { 
                            $prop.Type -replace "^$namespace\.", "" 
                        }
                        
                        if ($complexTypeName -notmatch "^Edm\.")
                        {
                            $complexTypesReferenced += $complexTypeName
                        }
                    }
                }
                
                # Process all referenced complex types
                foreach ($complexTypeName in ($complexTypesReferenced | Select-Object -Unique))
                {
                    $complexTypeElement = $metadataResponse.Edmx.DataServices.Schema.ComplexType | 
                        Where-Object { $_.Name -eq $complexTypeName }
                        
                    if ($complexTypeElement)
                    {
                        $complexTypeDetails = Get-ComplexTypeDetails -TypeElement $complexTypeElement -TypeName $complexTypeName -CurrentDepth 1 -Namespace $namespace
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
                
                # Extract navigation properties with enhanced details
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
                            ReturnType = $op.ReturnType
                        }
                        
                        # Add parameters (excluding binding parameter)
                        foreach ($param in $op.Parameter)
                        {
                            if ($param.Name -ne "bindingParameter")
                            {
                                $paramTypeInfo = Get-PropertyTypeInfo -PropertyType $param.Type -Namespace $namespace
                                
                                $paramDetails = @{
                                    Name         = $param.Name
                                    Type         = $param.Type
                                    Nullable     = $param.Nullable -eq 'true'
                                    IsCollection = $paramTypeInfo.IsCollection
                                    IsPrimitive  = $paramTypeInfo.IsPrimitive
                                    IsComplex    = $paramTypeInfo.IsComplex
                                }
                                
                                $opDetails.Parameters += $paramDetails
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
                
                # Add sample queries if requested
                if ($IncludeSampleQueries)
                {
                    Write-Verbose "Generating sample queries for entity type $entityTypeName"
                    try
                    {
                        Write-Verbose "Properties count: $(($metadata.Properties | Measure-Object).Count)"
                        Write-Verbose "NavigationProperties count: $(($metadata.NavigationProperties | Measure-Object).Count)"
                        
                        if ($null -ne $metadata.Properties -and $null -ne $metadata.NavigationProperties)
                        {
                            $metadata.SampleQueries = Get-SampleQueries -EntityType $entityTypeName -Properties $metadata.Properties -NavigationProperties $metadata.NavigationProperties
                            Write-Verbose "Generated $(($metadata.SampleQueries | Measure-Object).Count) sample queries"
                        }
                        else
                        {
                            Write-Verbose "Cannot generate sample queries: Properties or NavigationProperties is null"
                            $metadata.SampleQueries = @()
                        }
                    }
                    catch
                    {
                        Write-Verbose "Error generating sample queries: $($_.Exception.Message)"
                        $metadata.SampleQueries = @()
                    }
                }
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
                    IsComplex    = $ApiResponse.$propName -is [PSCustomObject]
                    IsCollection = $ApiResponse.$propName -is [array]
                }
                
                Write-Verbose "Added property from response: $propName (Type: $propType)"
                
                # If the property is a complex object and not null, analyze its structure
                if ($ApiResponse.$propName -is [PSCustomObject] -and $null -ne $ApiResponse.$propName)
                {
                    $complexObj = $ApiResponse.$propName
                    $complexProps = @()
                    
                    foreach ($subProp in $complexObj.PSObject.Properties)
                    {
                        $complexProps += @{
                            Name         = $subProp.Name
                            Type         = if ($null -eq $subProp.Value)
                            {
                                "Unknown" 
                            }
                            else
                            {
                                $subProp.Value.GetType().Name 
                            }
                            FromResponse = $true
                        }
                    }
                    
                    $metadata.ComplexTypes += @{
                        Name         = "$propName (from response)"
                        Properties   = $complexProps
                        FromResponse = $true
                    }
                    
                    Write-Verbose "Added complex type from response: $propName with $($complexProps.Count) properties"
                }
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
                    IsComplex    = $firstItem.$propName -is [PSCustomObject]
                    IsCollection = $firstItem.$propName -is [array]
                }
                
                Write-Verbose "Added property from response: $propName (Type: $propType)"
                
                # If the property is a complex object and not null, analyze its structure
                if ($firstItem.$propName -is [PSCustomObject] -and $null -ne $firstItem.$propName)
                {
                    $complexObj = $firstItem.$propName
                    $complexProps = @()
                    
                    foreach ($subProp in $complexObj.PSObject.Properties)
                    {
                        $complexProps += @{
                            Name         = $subProp.Name
                            Type         = if ($null -eq $subProp.Value)
                            {
                                "Unknown" 
                            }
                            else
                            {
                                $subProp.Value.GetType().Name 
                            }
                            FromResponse = $true
                        }
                    }
                    
                    $metadata.ComplexTypes += @{
                        Name         = "$propName (from response)"
                        Properties   = $complexProps
                        FromResponse = $true
                    }
                    
                    Write-Verbose "Added complex type from response: $propName with $($complexProps.Count) properties"
                }
            }
        }
    }
    #endregion
    
    #region format and return results
    # Organize the results in a user-friendly format
    $formattedResults = [PSCustomObject]@{
        EntityType            = $metadata.EntityType
        Properties            = $metadata.Properties | ForEach-Object {
            $propObj = [PSCustomObject]@{
                Name         = $_.Name
                Type         = $_.Type
                Nullable     = $_.Nullable
                IsComplex    = if ($_.ContainsKey('IsComplex'))
                {
                    $_.IsComplex 
                }
                else
                {
                    $false 
                }
                IsCollection = if ($_.ContainsKey('IsCollection'))
                {
                    $_.IsCollection 
                }
                else
                {
                    $false 
                }
                FromResponse = if ($_.ContainsKey('FromResponse'))
                {
                    $_.FromResponse 
                }
                else
                {
                    $false 
                }
            }
            
            # Add complex type details if available
            if ($_.ContainsKey('ComplexTypeDetails'))
            {
                $propObj | Add-Member -MemberType NoteProperty -Name 'ComplexTypeDetails' -Value $_.ComplexTypeDetails
            }
            
            # Add documentation if available
            if ($_.ContainsKey('Documentation'))
            {
                $propObj | Add-Member -MemberType NoteProperty -Name 'Documentation' -Value $_.Documentation
            }
            
            $propObj
        }
        NavigationProperties  = $metadata.NavigationProperties | ForEach-Object {
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
        Operations            = $metadata.Operations | ForEach-Object {
            [PSCustomObject]@{
                Name       = $_.Name
                Type       = $_.Type
                ReturnType = $_.ReturnType
                Parameters = $_.Parameters | ForEach-Object {
                    [PSCustomObject]@{
                        Name         = $_.Name
                        Type         = $_.Type
                        Nullable     = $_.Nullable
                        IsCollection = if ($_.ContainsKey('IsCollection'))
                        {
                            $_.IsCollection 
                        }
                        else
                        {
                            $false 
                        }
                        IsComplex    = if ($_.ContainsKey('IsComplex'))
                        {
                            $_.IsComplex 
                        }
                        else
                        {
                            $false 
                        }
                    }
                }
            }
        }
        Functions             = $metadata.Functions | ForEach-Object {
            [PSCustomObject]@{
                Name       = $_.Name
                Type       = $_.Type
                ReturnType = $_.ReturnType
                Parameters = $_.Parameters | ForEach-Object {
                    [PSCustomObject]@{
                        Name         = $_.Name
                        Type         = $_.Type
                        Nullable     = $_.Nullable
                        IsCollection = if ($_.ContainsKey('IsCollection'))
                        {
                            $_.IsCollection 
                        }
                        else
                        {
                            $false 
                        }
                        IsComplex    = if ($_.ContainsKey('IsComplex'))
                        {
                            $_.IsComplex 
                        }
                        else
                        {
                            $false 
                        }
                    }
                }
            }
        }
        ComplexTypes          = $metadata.ComplexTypes | ForEach-Object {
            $complexObj = [PSCustomObject]@{
                Name       = $_.Name
                BaseType   = $_.BaseType
                Properties = $_.Properties | ForEach-Object {
                    $propObj = [PSCustomObject]@{
                        Name     = $_.Name
                        Type     = $_.Type
                        Nullable = $_.Nullable
                    }
                    
                    if ($_.ContainsKey('IsCollection'))
                    {
                        $propObj | Add-Member -MemberType NoteProperty -Name 'IsCollection' -Value $_.IsCollection
                    }
                    
                    if ($_.ContainsKey('ElementType'))
                    {
                        $propObj | Add-Member -MemberType NoteProperty -Name 'ElementType' -Value $_.ElementType
                    }
                    
                    if ($_.ContainsKey('ElementTypeDetails'))
                    {
                        $propObj | Add-Member -MemberType NoteProperty -Name 'ElementTypeDetails' -Value $_.ElementTypeDetails
                    }
                    
                    if ($_.ContainsKey('ComplexTypeDetails'))
                    {
                        $propObj | Add-Member -MemberType NoteProperty -Name 'ComplexTypeDetails' -Value $_.ComplexTypeDetails
                    }
                    
                    if ($_.ContainsKey('Documentation'))
                    {
                        $propObj | Add-Member -MemberType NoteProperty -Name 'Documentation' -Value $_.Documentation
                    }
                    
                    if ($_.ContainsKey('FromResponse'))
                    {
                        $propObj | Add-Member -MemberType NoteProperty -Name 'FromResponse' -Value $_.FromResponse
                    }
                    
                    $propObj
                }
            }
            
            if ($_.ContainsKey('FromResponse'))
            {
                $complexObj | Add-Member -MemberType NoteProperty -Name 'FromResponse' -Value $_.FromResponse
            }
            
            $complexObj
        }
        EnumTypes             = $metadata.EnumTypes | ForEach-Object {
            [PSCustomObject]@{
                Name           = $_.Name
                UnderlyingType = $_.UnderlyingType
                IsFlags        = $_.IsFlags
                Members        = $_.Members | ForEach-Object {
                    [PSCustomObject]@{
                        Name  = $_.Name
                        Value = $_.Value
                    }
                }
            }
        }
        EntityTypeInheritance = [PSCustomObject]@{
            BaseType     = $metadata.EntityTypeInheritance.BaseType
            DerivedTypes = $metadata.EntityTypeInheritance.DerivedTypes
        }
        Annotations           = $metadata.Annotations | ForEach-Object {
            [PSCustomObject]@{
                Term   = $_.Term
                String = $_.String
                Bool   = $_.Bool
                Int    = $_.Int
            }
        }
        QueryOptions          = $metadata.QueryOptions
        FilterOperators       = $metadata.FilterOperators
        GraphVersion          = $metadata.GraphVersion

        Capabilities          = [PSCustomObject]@{
            Filterable             = $null -ne $metadata.Properties -and @($metadata.Properties).Count -gt 0
            Selectable             = $true
            Expandable             = $null -ne $metadata.NavigationProperties -and @($metadata.NavigationProperties).Count -gt 0
            Orderable              = $null -ne $metadata.Properties -and @($metadata.Properties).Count -gt 0
            CountSupported         = $true
            Searchable             = $metadata.EntityType -in @('users', 'groups', 'sites', 'drives') -or ($metadata.QueryOptions -contains 'search')
            SupportsChangeTracking = $false # Initialize to false to avoid null issues
        }
    }

    # Safely determine if change tracking is supported
    try
    {
        Write-Verbose "Checking for change tracking support via annotations..."
        if ($null -ne $metadata.Annotations -and @($metadata.Annotations).Count -gt 0)
        {
            Write-Verbose "Found $(@($metadata.Annotations).Count) annotations to analyze"
            foreach ($annotation in $metadata.Annotations)
            {
                Write-Verbose "Analyzing annotation with Term: $($annotation.Term), Bool: $($annotation.Bool)"
                if ($annotation.Term -eq 'Microsoft.Graph.ChangeTracking' -or 
                    $annotation.Term -like '*ChangeTracking*')
                {
                    Write-Verbose "Found change tracking annotation: $($annotation.Term)"
                    if ($annotation.Bool -eq 'true' -or $annotation.Bool -eq $true)
                    {
                        $formattedResults.Capabilities.SupportsChangeTracking = $true
                        Write-Verbose "Change tracking support detected for entity type: $($metadata.EntityType)"
                        break
                    }
                }
            }
            
            # Additional check for delta capability
            if (-not $formattedResults.Capabilities.SupportsChangeTracking)
            {
                # Check operations for delta function
                $deltaOperation = $metadata.Operations | Where-Object { $_.Name -eq 'delta' } | Select-Object -First 1
                $deltaFunction = $metadata.Functions | Where-Object { $_.Name -eq 'delta' } | Select-Object -First 1
                
                if ($deltaOperation -or $deltaFunction)
                {
                    $formattedResults.Capabilities.SupportsChangeTracking = $true
                    Write-Verbose "Change tracking support detected via delta operation/function for entity type: $($metadata.EntityType)"
                }
            }
            
            if (-not $formattedResults.Capabilities.SupportsChangeTracking)
            {
                Write-Verbose "No change tracking support detected for this entity type"
            }
        }
        else
        {
            Write-Verbose "No annotations found to determine change tracking support"
        }
    }
    catch
    {
        Write-Verbose "Error determining change tracking support: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    }

    # Add sample queries if generated
    if ($IncludeSampleQueries -and $null -ne $metadata.SampleQueries -and @($metadata.SampleQueries).Count -gt 0)
    {
        try
        {
            Write-Verbose "Processing $(($metadata.SampleQueries | Measure-Object).Count) sample queries for output format"
            $sampleQueries = @(
                # Fixed ForEach-Object syntax to use proper script block with explicit scriptblock parameter
                $metadata.SampleQueries | ForEach-Object -Process {
                    if ($null -ne $_ -and $_.Name -and $_.Template -and $_.Description)
                    {
                        [PSCustomObject]@{
                            Name        = $_.Name
                            Template    = $_.Template
                            Description = $_.Description
                        }
                    }
                }
            )
            if ($null -ne $formattedResults -and $sampleQueries.Count -gt 0)
            {
                Write-Verbose "Adding $(($sampleQueries | Measure-Object).Count) formatted sample queries to results"
                $formattedResults | Add-Member -MemberType NoteProperty -Name 'SampleQueries' -Value $sampleQueries
            }
            else
            {
                Write-Verbose "No sample queries to add or formatted results is null"
            }
        }
        catch
        {
            Write-Verbose "Error processing sample queries for output: $($_.Exception.Message)"
        }
    }

    Write-Verbose "Metadata extraction complete with enhanced property and complex type analysis"
    return $formattedResults
    #endregion
}
