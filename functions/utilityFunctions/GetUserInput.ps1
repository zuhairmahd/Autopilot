function GetUserInput()
{
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Prompt
    )
    #Get the function name
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting user input collection" -LogLevel "Debug"
    Write-Verbose "[$functionName] Message: $Message"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Host $Message
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 
    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        Write-Log -LogFile $LogFile -Module $functionName -Message "User input received" -LogLevel "Debug"
        
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $($returnValues.backoutText)."
            Write-Log -LogFile $LogFile -Module $functionName -Message "User pressed Enter to return to previous menu" -LogLevel "Debug"
            return $null # Return null to signal going back
        }
        
        # Validate the input if it's not empty
        $validationResult = validateInput -UserInput $inputItem
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value
        if ($inputResultValid)
        {
            Write-Verbose "[$functionName] Valid $inputType entered: $inputResultValid"
            Write-Verbose "[$functionName] Input result: $inputResult"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Valid input received and validated" -LogLevel "Debug"
            return $inputResult # Return the validated input
        }
        else
        {
            # Beep and show error if validation failed
            [console]::beep(1000, 500)
            # Updated error message
            Write-Host "Invalid $inputType. Please try again or press Enter to return." -ForegroundColor Red 
            Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid input provided - prompting user to try again" -LogLevel "Warning"
            # The loop will continue, prompting the user again
        }
    }
}

