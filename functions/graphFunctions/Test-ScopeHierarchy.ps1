function Test-ScopeHierarchy
{
    <#
    .SYNOPSIS
        Tests whether available Microsoft Graph scopes satisfy a required scope using hierarchy rules.
    
    .DESCRIPTION
        Evaluates if an available scope satisfies a required scope by understanding Microsoft Graph 
        permission hierarchies. Higher-privilege scopes (e.g., ReadWrite) satisfy lower-privilege 
        requirements (e.g., Read). Broader scopes (e.g., .All) satisfy narrower requirements.
        
        Scope naming pattern: {Resource}.{Operation}.{Constraint}
        - Resource: The Microsoft Graph resource (User, Device, Mail, etc.)
        - Operation: The action (Read, ReadWrite, Manage, etc.)
        - Constraint: The scope limitation (All, Selected, OwnedBy, Shared, or none)
        
        Hierarchies:
        - Operations: Read < ReadWrite < Manage
        - Constraints: (none) < OwnedBy < Selected < Shared < All
        - Special: ReadBasic < Read
    
    .PARAMETER RequiredScope
        The scope that is required for functionality to work.
    
    .PARAMETER AvailableScopes
        Array of scopes that are currently available in the access token.
    
    .EXAMPLE
        Test-ScopeHierarchy -RequiredScope "Device.Read.All" -AvailableScopes @("Device.ReadWrite.All")
        Returns $true because Device.ReadWrite.All includes Device.Read.All capabilities
    
    .EXAMPLE
        Test-ScopeHierarchy -RequiredScope "User.ReadWrite.All" -AvailableScopes @("User.Read.All")
        Returns $false because User.Read.All does not include write capabilities
    
    .OUTPUTS
        Boolean indicating whether the requirement is satisfied
    #>
    
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequiredScope,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$AvailableScopes
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking if required scope '$RequiredScope' is satisfied by available scopes"
    
    # Early return if no available scopes
    if ($AvailableScopes.Count -eq 0)
    {
        Write-Verbose "[$functionName] No available scopes - requirement cannot be satisfied"
        return $false
    }
    
    # Define operation hierarchy (higher index = more privileges)
    $operationHierarchy = @{
        'Read'      = 1
        'ReadBasic' = 0  # ReadBasic < Read
        'ReadWrite' = 2
        'Manage'    = 3
        'Create'    = 2  # Create typically equivalent to ReadWrite
        'Delete'    = 2
    }
    
    # Define constraint hierarchy (higher index = broader scope)
    $constraintHierarchy = @{
        'None'     = 0  # User's own resources
        'OwnedBy'  = 1  # Resources owned by the app
        'Selected' = 2  # Selected resources
        'Shared'   = 3  # Shared resources
        'All'      = 4  # All resources in organization
    }
    
    # Parse the required scope into components
    $requiredParts = $RequiredScope -split '\.'
    if ($requiredParts.Count -lt 2)
    {
        Write-Verbose "[$functionName] Invalid required scope format: $RequiredScope"
        # Fall back to exact match for non-standard formats
        return $AvailableScopes -contains $RequiredScope
    }
    
    $requiredResource = $requiredParts[0]
    
    # Extract operation and constraint from remaining parts
    $requiredOperation = $null
    $requiredConstraint = 'None'
    
    if ($requiredParts.Count -eq 2)
    {
        # Format: Resource.Operation
        $requiredOperation = $requiredParts[1]
    }
    elseif ($requiredParts.Count -ge 3)
    {
        # Format: Resource.Operation.Constraint or Resource.ReadWrite.Constraint
        $requiredOperation = $requiredParts[1]
        $requiredConstraint = $requiredParts[2..($requiredParts.Count - 1)] -join '.'
    }
    
    # Map constraint to hierarchy value
    $requiredConstraintLevel = if ($constraintHierarchy.ContainsKey($requiredConstraint))
    {
        $constraintHierarchy[$requiredConstraint]
    }
    else
    {
        4  # Assume .All if unknown
    }
    
    # Map operation to hierarchy value
    $requiredOperationLevel = if ($operationHierarchy.ContainsKey($requiredOperation))
    {
        $operationHierarchy[$requiredOperation]
    }
    else
    {
        Write-Verbose "[$functionName] Unknown operation '$requiredOperation' - using level 1"
        1  # Default to Read level
    }
    
    Write-Verbose "[$functionName] Required scope parsed: Resource='$requiredResource', Operation='$requiredOperation'($requiredOperationLevel), Constraint='$requiredConstraint'($requiredConstraintLevel)"
    
    # Check each available scope to see if it satisfies the requirement
    foreach ($availableScope in $AvailableScopes)
    {
        # Case-insensitive comparison
        if ($availableScope -ieq $RequiredScope)
        {
            Write-Verbose "[$functionName] Exact match found: $availableScope"
            return $true
        }
        
        # Parse available scope
        $availableParts = $availableScope -split '\.'
        if ($availableParts.Count -lt 2)
        {
            continue  # Skip invalid scopes
        }
        
        $availableResource = $availableParts[0]
        
        # Resource must match (case-insensitive)
        if ($availableResource -ine $requiredResource)
        {
            continue
        }
        
        # Extract available operation and constraint
        $availableOperation = $null
        $availableConstraint = 'None'
        
        if ($availableParts.Count -eq 2)
        {
            $availableOperation = $availableParts[1]
        }
        elseif ($availableParts.Count -ge 3)
        {
            $availableOperation = $availableParts[1]
            $availableConstraint = $availableParts[2..($availableParts.Count - 1)] -join '.'
        }
        
        # Map available constraint and operation to hierarchy values
        $availableConstraintLevel = if ($constraintHierarchy.ContainsKey($availableConstraint))
        {
            $constraintHierarchy[$availableConstraint]
        }
        else
        {
            4  # Assume .All if unknown
        }
        
        $availableOperationLevel = if ($operationHierarchy.ContainsKey($availableOperation))
        {
            $operationHierarchy[$availableOperation]
        }
        else
        {
            1  # Default to Read level
        }
        
        Write-Verbose "[$functionName] Checking available scope: Resource='$availableResource', Operation='$availableOperation'($availableOperationLevel), Constraint='$availableConstraint'($availableConstraintLevel)"
        
        # Check if available scope satisfies requirement
        # Available operation must be >= required operation
        # Available constraint must be >= required constraint
        if ($availableOperationLevel -ge $requiredOperationLevel -and 
            $availableConstraintLevel -ge $requiredConstraintLevel)
        {
            Write-Verbose "[$functionName] Requirement satisfied by '$availableScope' (Op: $availableOperationLevel >= $requiredOperationLevel, Constraint: $availableConstraintLevel >= $requiredConstraintLevel)"
            return $true
        }
    }
    
    Write-Verbose "[$functionName] No available scope satisfies the requirement '$RequiredScope'"
    return $false
}
