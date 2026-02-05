function GetUserInput()
{
    <#
    .SYNOPSIS
    Prompts the user for validated input with support for cancellation.

    .DESCRIPTION
    This function displays a message and prompt to the user, then validates their input
    according to the specified input type (userName, serialNumber, or groupName). It
    continuously prompts until valid input is received or the user presses Enter to cancel.
    The function provides visual and audio feedback for invalid input.

    .PARAMETER Message
    The informational message to display to the user before prompting for input.

    .PARAMETER Prompt
    The prompt text to display when requesting input.

    .PARAMETER InputType
    The type of input to validate. Valid values: 'userName', 'serialNumber', 'groupName'.

    .PARAMETER settings
    The settings object containing validation parameters. Defaults to script-level $settings.

    .OUTPUTS
    System.String or $null
    Returns the validated user input as a string, or $null if the user presses Enter to cancel.

    .EXAMPLE
    $userName = GetUserInput -Message "Enter user information" -Prompt "User name" -InputType "userName"
    $serial = GetUserInput -Message "Enter device serial" -Prompt "Serial number" -InputType "serialNumber"

    .NOTES
    Pressing Enter without input returns $null to signal cancellation.
    Invalid input triggers a beep sound and error message.
    Uses validateInput function for validation logic.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Prompt,
        [validateSet('userName', 'serialNumber', 'groupName')]
        [string]$InputType,
        $settings = $settings # Use the script-level $settings by default
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Message: $Message"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Verbose "[$functionName] InputType: $InputType"
    Write-Log -logFile $logFile -module $functionName -Message "Prompting user for $InputType input" -logLevel "Information"
    Write-Host $Message -ForegroundColor White
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu."

    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        Write-Verbose "[$functionName] Entering validation loop"
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        Write-Log -logFile $logFile -module $functionName -Message "User entered: '$inputItem'"
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $($returnValues.backoutText)."
            Write-Log -logFile $logFile -module $functionName -Message "User pressed Enter. Returning to previous menu." -logLevel "Information"
            return $null # Return null to signal going back
        }
        # Validate the input if it's not empty
        Write-Verbose "[$functionName] Validating input $inputItem as $InputType"
        $validationResult = validateInput -UserInput $inputItem -type $InputType -settings $settings
        Write-Verbose "[$functionName] Validation result: $($validationResult.valid)"
        Write-Verbose "[$functionName] Validation value: $($validationResult.value)"
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value
        Write-Log -logFile $logFile -module $functionName -Message "Validation result: $inputResultValid; Value: $inputResult"
        if ($inputResultValid)
        {
            Write-Verbose "[$functionName] Valid $inputType entered: $inputResultValid"
            Write-Verbose "[$functionName] Input result: $inputResult"
            Write-Log -logFile $logFile -module $functionName -Message "Valid $inputType entered: $inputResult"
            return $inputResult # Return the validated input
        }
        else
        {
            # Beep and show error if validation failed
            [console]::beep(1000, 500)
            # Updated error message
            Write-Host "Invalid $inputType. Please try again or press Enter to return." -ForegroundColor Red
            Write-Log -logFile $logFile -module $functionName -Message "Invalid $inputType entered. Prompting user again." -logLevel "Warning"
            # The loop will continue, prompting the user again
        }
    }
    Write-Verbose "[$functionName] Exiting GetUserInput function"
    Write-Log -logFile $logFile -module $functionName -Message "Exiting GetUserInput function" -logLevel "Information"
}

