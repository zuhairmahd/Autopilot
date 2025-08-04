function Write-SafeLog()
{
    param($Message, $LogLevel = "Information")
    if ($script:LogFile -and (Get-Command Write-Log -ErrorAction SilentlyContinue))
    {
        Write-Log -Message $Message -LogFile $script:LogFile -Module $functionName -LogLevel $LogLevel
    }
    Write-Verbose "[$functionName] $Message"
}

