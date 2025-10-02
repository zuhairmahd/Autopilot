function ConvertFrom-UserSelection
{
    <#
    .SYNOPSIS
        [DEPRECATED] Backward compatibility wrapper for ConvertFrom-DirectoryObjectSelection.
    
    .DESCRIPTION
        This function is deprecated and maintained only for backward compatibility.
        It is now a thin wrapper around ConvertFrom-DirectoryObjectSelection.
        
        Please migrate to ConvertFrom-DirectoryObjectSelection for new code:
        ConvertFrom-DirectoryObjectSelection -SelectedValue $SelectedValue -ReturnValues $ReturnValues
        
        This wrapper will be removed in a future version.
    
    .PARAMETER SelectedValue
        The value returned from Show-DirectoryObjectList or similar selection function.
    
    .PARAMETER ReturnValues
        The return values hashtable containing navigation messages.
    
    .OUTPUTS
        Returns either a validated entity identifier string or a navigation return value.
    
    .EXAMPLE
        $result = ConvertFrom-UserSelection -SelectedValue $userChoice -ReturnValues $returnValues
        if ($result -in $returnValues.Values) {
            # Handle navigation
        } else {
            # Use the entity identifier
        }
    
    .NOTES
        DEPRECATED: This function is maintained for backward compatibility only.
        Use ConvertFrom-DirectoryObjectSelection instead.
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
    Write-Verbose "[$functionName] DEPRECATION WARNING: ConvertFrom-UserSelection is deprecated. Please use ConvertFrom-DirectoryObjectSelection instead."
    
    # Call the unified function
    return ConvertFrom-DirectoryObjectSelection -SelectedValue $SelectedValue -ReturnValues $ReturnValues
}
