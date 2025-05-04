function normalizeADUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )
    $processedUser = [ordered] @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "Converting user display name: $UserDisplayName"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "Extracting first name, last name, middle initial and nickname."
        $lastName = $matches[1].Trim()
        Write-Verbose "Last name: $lastName"
        $firstName = $matches[2].Trim()
        Write-Verbose "First name: $firstName"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "Middle initial: $middleInitial"
        }
        else
        {
            $null 
            Write-Verbose "No middle initial found."
        }
        $nickname = $matches[4]
        Write-Verbose "Nickname: $nickname"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "Full name with middle initial: $fullName"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "Full name without middle initial: $fullName"
        }
        if ($nickname)
        {
            Write-Verbose "Nickname found: $nickname"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "Current user with nickname: $currentUser"
        }
        else
        {
            Write-Verbose "No nickname found."
            $currentUser = $fullName
            Write-Verbose "Current user without nickname: $currentUser"
        }
    }
    else
    {
        Write-Verbose "No match found for user display name format."
        Write-Verbose "Returning original display name."
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
