function DisplayNumericMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$choices,
        [string]$banner = "Please press the number of your choice and press enter.",
        [string]$Prompt = "Please select an option",
        $errorMessage = "Invalid selection. Please try again."
    )
    #Print a verbose message with received    
    Write-Verbose "[$functionName] Received parameters: $($choices | Out-String)"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Verbose "[$functionName] ErrorMessage: $errorMessage"

    $functionName = $MyInvocation.MyCommand.Name
    # Display the menu options
    Write-Host $banner -ForegroundColor Green
    for ($i = 0; $i -lt $choices.Count; $i++)
    {
        Write-Host "$($i + 1). $($choices[$i])"
    }
    Write-Host "0. Exit"
    # Prompt for user input
    $selection = Read-Host -Prompt $Prompt
    # Validate the selection
    while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -gt $choices.Count)
    {
        Write-Host $errorMessage -ForegroundColor Red
        #beep
        [console]::beep(1000, 500)
        $selection = Read-Host -Prompt $Prompt
    }
    if ($selection -ne 0)
    {
        # Return the selected choice
        return $choices[[int]$selection - 1]
    }
    else
    {
        Write-Verbose "[$functionName] Exiting script."
        return $selection
    }
}
