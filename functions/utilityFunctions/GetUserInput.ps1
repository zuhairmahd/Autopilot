function GetUserInput()
{
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Prompt,
        [validateSet('userName', 'serialNumber')]
        [string]$InputType,
        $settings = $settings # Use the script-level $settings by default
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Message: $Message"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Verbose "[$functionName] InputType: $InputType"
    Write-Host $Message -ForegroundColor White
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 

    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        Write-Verbose "[$functionName] Entering validation loop"
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $($returnValues.backoutText)."
            return $null # Return null to signal going back
        }
        # Validate the input if it's not empty
        Write-Verbose "[$functionName] Validating input $inputItem as $InputType"
        $validationResult = validateInput -UserInput $inputItem -type $InputType -settings $settings
        Write-Verbose "[$functionName] Validation result: $($validationResult.valid)"
        Write-Verbose "[$functionName] Validation value: $($validationResult.value)"
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value
        if ($inputResultValid)
        {
            Write-Verbose "[$functionName] Valid $inputType entered: $inputResultValid"
            Write-Verbose "[$functionName] Input result: $inputResult"
            return $inputResult # Return the validated input
        }
        else
        {
            # Beep and show error if validation failed
            [console]::beep(1000, 500)
            # Updated error message
            Write-Host "Invalid $inputType. Please try again or press Enter to return." -ForegroundColor Red 
            # The loop will continue, prompting the user again
        }
    }
    Write-Verbose "[$functionName] Exiting GetUserInput function"
}

