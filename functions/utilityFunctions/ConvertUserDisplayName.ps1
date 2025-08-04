function ConvertUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )
    $functionName = $MyInvocation.MyCommand.Name
    $processedUser = [ordered] @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "[$functionName] Converting user display name: $UserDisplayName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Converting user display name: $UserDisplayName" -LogLevel "Verbose"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "[$functionName] Extracting first name, last name, middle initial and nickname."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extracting first name, last name, middle initial and nickname." -LogLevel "Information"
        $lastName = $matches[1].Trim()
        Write-Verbose "[$functionName] Last name: $lastName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Last name: $lastName" -LogLevel "Information"
        $firstName = $matches[2].Trim()
        Write-Verbose "[$functionName] First name: $firstName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "First name: $firstName" -LogLevel "Information"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "[$functionName] Middle initial: $middleInitial"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Middle initial: $middleInitial" -LogLevel "Information"
        }
        else
        {
            $null 
            Write-Verbose "[$functionName] No middle initial found."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No middle initial found." -LogLevel "Information"
        }
        $nickname = $matches[4]
        Write-Verbose "[$functionName] Nickname: $nickname"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Nickname: $nickname" -LogLevel "Information"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "[$functionName] Full name with middle initial: $fullName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Full name with middle initial: $fullName" -LogLevel "Information"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "[$functionName] Full name without middle initial: $fullName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Full name without middle initial: $fullName" -LogLevel "Information"
        }
        if ($nickname)
        {
            Write-Verbose "[$functionName] Nickname found: $nickname"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Nickname found: $nickname" -LogLevel "Information"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "[$functionName] Current user with nickname: $currentUser"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user with nickname: $currentUser" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] No nickname found."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No nickname found." -LogLevel "Information"
            $currentUser = $fullName
            Write-Verbose "[$functionName] Current user without nickname: $currentUser"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user without nickname: $currentUser" -LogLevel "Information"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No match found for user display name format."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No match found for user display name format." -LogLevel "Information"
        Write-Verbose "[$functionName] Returning original display name."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning original display name." -LogLevel "Information"
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
