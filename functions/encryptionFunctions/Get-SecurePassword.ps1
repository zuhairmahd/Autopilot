function Get-SecurePassword()
{
    <#
    .SYNOPSIS
    Prompts the user for a secure password with confirmation.
    
    .DESCRIPTION
    This function prompts the user to enter a password securely, with an optional confirmation prompt.
    The password is returned as a SecureString for security.
    
    .PARAMETER Message
    The message to display to the user when prompting for the password.
    
    .PARAMETER RequireConfirmation
    If specified, the user will be prompted to confirm their password.
    
    .PARAMETER MinLength
    The minimum length required for the password (default: 8).
    
    .OUTPUTS
    Returns the password as a SecureString.
    
    .EXAMPLE
    $password = Get-SecurePassword -Message "Enter your password" -RequireConfirmation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$RequireConfirmation,
        [int]$MinLength = 8
    )
    
    $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $LogFile -Module $functionName -Message "Starting secure password prompt. RequireConfirmation: $RequireConfirmation, MinLength: $MinLength" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Prompting user for secure password"
    
    $attemptCount = 0
    do
    {
        $attemptCount++
        $validPassword = $true
        Write-Log -LogFile $LogFile -Module $functionName -Message "Password prompt attempt $attemptCount" -LogLevel "Debug"
        
        $password = Read-Host -Prompt $Message -AsSecureString
        
        # Convert to plain text temporarily for validation
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
        
        # Validate password length
        if ($plainPassword.Length -lt $MinLength)
        {
            Write-Host "Password must be at least $MinLength characters long. Please try again." -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $functionName -Message "Password validation failed: insufficient length" -LogLevel "Warning"
            $validPassword = $false
            continue
        }
        
        # Confirm password if required
        if ($RequireConfirmation)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting for password confirmation" -LogLevel "Debug"
            $confirmPassword = Read-Host -Prompt "Confirm password" -AsSecureString
            $plainConfirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
            
            if ($plainPassword -ne $plainConfirmPassword)
            {
                Write-Host "Passwords do not match. Please try again." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $functionName -Message "Password confirmation failed: passwords do not match" -LogLevel "Warning"
                $validPassword = $false
                continue
            }
            
Write-Log -LogFile $LogFile -Module $functionName -Message "Password confirmation successful" -LogLevel "Information"
        }
        
        # Clear plain text passwords from memory
        $plainPassword = $null
        if ($plainConfirmPassword)
        {
            $plainConfirmPassword = $null
        }
        
    } while (-not $validPassword)
    
    Write-Verbose "[$functionName] Password obtained successfully"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Secure password obtained successfully after $attemptCount attempts" -LogLevel "Information"
    return $password
}

