function Write-SafeLog()
{
    <#
    .SYNOPSIS
    Safely writes log messages with fallback to verbose output.

    .DESCRIPTION
    This helper function attempts to write log messages using Write-Log if a script-level
    LogFile variable is available. If Write-Log is not available or no LogFile is configured,
    it falls back to Write-Verbose. This ensures logging continues even when the logging
    infrastructure is not fully initialized.

    .PARAMETER Message
    The log message to write.

    .PARAMETER LogLevel
    The severity level of the message. Default is "Information".

    .OUTPUTS
    None. Writes log entry or verbose output.

    .EXAMPLE
    Write-SafeLog "Configuration initialized"
    Write-SafeLog "Warning: Missing configuration value" -LogLevel "Warning"

    .NOTES
    Used during First Run Wizard when logging may not be fully configured.
    Requires $script:LogFile and $functionName variables in scope for full logging.
    Compatible with PowerShell 5.1.
    #>
    param($Message, $LogLevel = "Information")
    if ($script:LogFile)
    {
        Write-Log -Message $Message -LogFile $script:LogFile -Module $functionName -LogLevel $LogLevel
    }
    Write-Verbose "[$functionName] $Message"
}

