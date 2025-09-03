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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Converting user display name: $UserDisplayName" -LogLevel "Verbose"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extracting first name, last name, middle initial and nickname." -LogLevel "Information"
        $lastName = $matches[1].Trim()
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Last name: $lastName" -LogLevel "Information"
        $firstName = $matches[2].Trim()
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "First name: $firstName" -LogLevel "Information"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Middle initial: $middleInitial" -LogLevel "Information"
        }
        else
        {
            $null 
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No middle initial found." -LogLevel "Verbose"
        }
        $nickname = $matches[4]
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Nickname: $nickname" -LogLevel "Information"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Full name with middle initial: $fullName" -LogLevel "Information"
        }
        else
        {
            "$firstName $lastName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Full name without middle initial: $fullName" -LogLevel "Information"
        }
        if ($nickname)
        {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Nickname found: $nickname" -LogLevel "Verbose"
            $currentUser = "$fullName ($nickname)"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user with nickname: $currentUser" -LogLevel "Debug"
        }
        else
        {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No nickname found." -LogLevel "Verbose"
            $currentUser = $fullName
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current user without nickname: $currentUser" -LogLevel "Debug"
        }
    }
    else
    {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No match found for user display name format." -LogLevel "Verbose"
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
