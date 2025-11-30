function normalizeADUserDisplayName()
{
    <#
    .SYNOPSIS
    Normalizes and parses an Active Directory user display name into components.

    .DESCRIPTION
    This function parses an AD user display name in the format "Lastname, Firstname Middle (nickname)"
    and converts it to "Firstname Middle Lastname (nickname)". It extracts and returns individual
    components (first name, last name, middle initial, nickname) in a hashtable. If the input
    doesn't match the expected format, it returns the original display name.

    .PARAMETER UserDisplayName
    The Active Directory user display name to parse and normalize. This parameter is mandatory.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with keys: FullName, FirstName, LastName, MiddleInitial, Nickname.

    .EXAMPLE
    $userInfo = normalizeADUserDisplayName -UserDisplayName "Doe, John A. (Johnny)"
    # Returns: FullName="John A. Doe (Johnny)", FirstName="John", LastName="Doe", MiddleInitial="A.", Nickname="Johnny"
    
    $userInfo = normalizeADUserDisplayName -UserDisplayName "Smith, Jane"
    # Returns: FullName="Jane Smith", FirstName="Jane", LastName="Smith", MiddleInitial=$null, Nickname=$null

    .NOTES
    Handles various formats:
    - "Lastname, Firstname"
    - "Lastname, Firstname Middle"
    - "Lastname, Firstname M."
    - "Lastname, Firstname (Nickname)"
    - "Lastname, Firstname M. (Nickname)"
    
    Returns original display name if format doesn't match expected pattern.
    Uses regular hashtable for PowerShell 5.1 compatibility.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )    $functionName = $MyInvocation.MyCommand.Name
    # PowerShell 5.1 compatible - using regular hashtable
    $processedUser = @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "[$functionName] Converting user display name: $UserDisplayName"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "[$functionName] Extracting first name, last name, middle initial and nickname."
        $lastName = $matches[1].Trim()
        Write-Verbose "[$functionName] Last name: $lastName"
        $firstName = $matches[2].Trim()
        Write-Verbose "[$functionName] First name: $firstName"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "[$functionName] Middle initial: $middleInitial"
        }
        else
        {
            $null 
            Write-Verbose "[$functionName] No middle initial found."
        }
        $nickname = $matches[4]
        Write-Verbose "[$functionName] Nickname: $nickname"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "[$functionName] Full name with middle initial: $fullName"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "[$functionName] Full name without middle initial: $fullName"
        }
        if ($nickname)
        {
            Write-Verbose "[$functionName] Nickname found: $nickname"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "[$functionName] Current user with nickname: $currentUser"
        }
        else
        {
            Write-Verbose "[$functionName] No nickname found."
            $currentUser = $fullName
            Write-Verbose "[$functionName] Current user without nickname: $currentUser"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No match found for user display name format."
        Write-Verbose "[$functionName] Returning original display name."
        $currentUser = $UserDisplayName
    }
    #Add what we got the the processedUser hashtable
    $processedUser.Add('FullName', $currentUser)
    $processedUser.Add('FirstName', $firstName)
    $processedUser.Add('LastName', $lastName)
    $processedUser.Add('MiddleInitial', $middleInitial)
    $processedUser.Add('Nickname', $nickname)
    return $processedUser
}

