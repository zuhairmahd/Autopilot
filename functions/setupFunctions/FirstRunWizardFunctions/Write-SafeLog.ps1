function Write-SafeLog()
{
    param($Message, $LogLevel = "Information")
    if ($script:LogFile)
    {
        Write-Log -Message $Message -LogFile $script:LogFile -Module $functionName -LogLevel $LogLevel
    }
    Write-Verbose "[$functionName] $Message"
}

