function Invoke-FileCertVerification()
{
    <#
    .SYNOPSIS
    Verifies the digital certificate signature of a file.

    .DESCRIPTION
    This function performs comprehensive certificate verification for a digitally signed file.
    It checks the Authenticode signature, validates the certificate is signed by the expected
    organization (Zuhair Mahmoud), verifies the certificate chain roots to Microsoft Identity
    Verification Root, and confirms the root certificate is trusted on the local machine.

    .PARAMETER FilePath
    The path to the file to verify. This parameter is mandatory and must not be null or empty.

    .OUTPUTS
    System.Boolean
    Returns $true if the file signature is valid, properly chained, and trusted.
    Returns $false if verification fails at any stage.

    .EXAMPLE
    if (Invoke-FileCertVerification -FilePath "C:\Downloads\setup.exe") {
        Write-Host "File signature verified successfully"
    } else {
        Write-Host "File signature verification failed"
    }

    .NOTES
    Verifies certificate is:
    - Signed by organization "O=Zuhair Mahmoud"
    - Has Valid Authenticode signature status
    - Chains to "CN=Microsoft Identity Verification Root"
    - Root certificate is trusted in LocalMachine\Root store
    
    Provides detailed logging and console output during verification.
    No [CmdletBinding()] as this is a simple validation function.
    Compatible with PowerShell 5.1.
    #>
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Output "[ACTION] Verifying setup file signature for $FilePath"
    Write-Log -Message ("Verifying setup file signature for $FilePath") -LogFile $LogFile -Module $functionName -LogLevel Information
    try
    {
        $Cert = (Get-AuthenticodeSignature -FilePath $FilePath).SignerCertificate
        $CertStatus = (Get-AuthenticodeSignature -FilePath $FilePath).Status
        Write-Output "[INFO] Certificate status: $CertStatus"
        Write-Log -Message ("Certificate status: $CertStatus") -LogFile $LogFile -Module $functionName -LogLevel Debug
        if ($Cert)
        {
            Write-Output "[INFO] Certificate subject: $($Cert.Subject)"
            Write-Output "[INFO] Certificate issuer: $($Cert.Issuer)"
            Write-Output "[INFO] Certificate valid from: $($Cert.NotBefore) to $($Cert.NotAfter)"
            Write-Log -Message ("Certificate subject: $($Cert.Subject)") -LogFile $LogFile -Module $functionName -LogLevel Debug
            Write-Log -Message ("Certificate issuer: $($Cert.Issuer)") -LogFile $LogFile -Module $functionName -LogLevel Debug
            Write-Log -Message ("Certificate valid from: $($Cert.NotBefore) to $($Cert.NotAfter)") -LogFile $LogFile -Module $functionName -LogLevel Debug
            if ($cert.Subject -match "O=Zuhair Mahmoud" -and $CertStatus -eq "Valid")
            {
                Write-Output "[SUCCESS] Certificate is valid and signed by Zuhair Mahmoud"
                Write-Log -Message ("Certificate is valid and signed by Zuhair Mahmoud") -LogFile $LogFile -Module $functionName -LogLevel Information
                $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
                $chain.Build($cert) | Out-Null
                $RootCert = $chain.ChainElements | ForEach-Object {$_.Certificate} | Where-Object {$PSItem.Subject -match "CN=Microsoft Identity Verification Root"}
                if (-not [string ]::IsNullOrEmpty($RootCert))
                {
                    Write-Output "[SUCCESS] Certificate chain verified to Microsoft Root: $($RootCert.Subject)"
                    Write-Log -Message ("Certificate chain verified to Microsoft Root: $($RootCert.Subject)") -LogFile $LogFile -Module $functionName -LogLevel Information
                    $TrustedRoot = Get-ChildItem -Path "Cert:\\LocalMachine\\Root" -Recurse | Where-Object { $PSItem.Thumbprint -eq $RootCert.Thumbprint}
                    if (-not [string]::IsNullOrEmpty($TrustedRoot))
                    {
                        Write-Output "[SUCCESS] Verified file signed by : $($Cert.Issuer)"
                        Write-Log -Message ("Verified file signed by : $($Cert.Issuer)") -LogFile $LogFile -Module $functionName -LogLevel Information
                        return $True
                    }
                    else
                    {
                        Write-Output "[ERROR] No trust found to root cert - aborting"
                        Write-Log -Message ("No trust found to root cert - aborting") -LogFile $LogFile -Module $functionName -LogLevel Error
                        return $False
                    }
                }
                else
                {
                    Write-Output "[ERROR] Certificate chain not verified to Microsoft - aborting"
                    Write-Log -Message ("Certificate chain not verified to Microsoft - aborting") -LogFile $LogFile -Module $functionName -LogLevel Error
                    return $False
                }
            }
            else
            {
                Write-Output "[ERROR] Certificate not valid or not signed by Microsoft - aborting"
                Write-Log -Message ("Certificate not valid or not signed by Microsoft - aborting") -LogFile $LogFile -Module $functionName -LogLevel Error
                return $False
            }
        }
        else
        {
            Write-Output "[ERROR] Setup file not signed - aborting"
            Write-Log -Message ("Setup file not signed - aborting") -LogFile $LogFile -Module $functionName -LogLevel Error
            return $False
        }
    }
    catch
    {
        Write-Output "[ERROR] Exception during file certificate verification: $($_.Exception.Message)"
        Write-Log -Message ('Exception during file certificate verification: ' + $_.Exception.Message) -LogFile $LogFile -Module $functionName -LogLevel Error
        return $False
    }
}
