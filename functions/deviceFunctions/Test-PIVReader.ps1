function Test-PIVReader()
{
    <#
    .SYNOPSIS
    Tests and enumerates certificates from a PIV/Smart Card reader.

    .DESCRIPTION
    This function queries connected smart card readers and enumerates X.509 certificates stored on the smart card.
    It uses the Microsoft Base Smart Card Crypto Provider and CryptoAPI (advapi32.dll and crypt32.dll) to access
    the smart card certificate store. The function provides detailed logging of the enumeration process and can
    optionally display certificate details.

    .PARAMETER displayCerts
    When specified, displays detailed information about each certificate found on the smart card, including:
    - Subject
    - Issuer
    - Thumbprint
    - NotBefore date
    - NotAfter date
    - HasPrivateKey status

    .EXAMPLE
    Test-PIVReader
    Tests the PIV reader and displays the count of certificates found without showing certificate details.

    .EXAMPLE
    Test-PIVReader -displayCerts
    Tests the PIV reader and displays detailed information about all certificates found on the smart card.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with the following keys:
    - Success: Boolean indicating if the operation was successful
    - Certificates: Array of X509Certificate2 objects found on the smart card
    - ErrorMessage: String containing error details if the operation failed

    .NOTES
    Author: Autopilot Team
    Requires: Smart card reader hardware and appropriate drivers
    Dependencies: advapi32.dll, crypt32.dll, Write-Log function
    
    The function performs the following operations:
    1. Detects connected smart card readers
    2. Acquires cryptographic context from the Microsoft Base Smart Card Crypto Provider
    3. Retrieves the certificate store handle from the smart card
    4. Enumerates all certificates in the store
    5. Converts native certificate contexts to X509Certificate2 objects
    6. Properly releases all handles and contexts

    .LINK
    https://docs.microsoft.com/en-us/windows/win32/api/wincrypt/
    #>
    [CmdletBinding()                            ]
    param(
        [switch]$displayCerts
    )

    function Get-SCUserStore()
    {
        [CmdletBinding()]
        param()

        $functionName = $MyInvocation.MyCommand.Name
        Write-Log -LogFile $logFile -Module $functionName -Message "Starting smart card certificate store enumeration" -LogLevel "Information"
        Write-Verbose "[$functionName] Starting smart card certificate store enumeration"

        $providerName = "Microsoft Base Smart Card Crypto Provider"
        Write-Log -LogFile $logFile -Module $functionName -Message "Using cryptographic provider: $providerName" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Using cryptographic provider: $providerName"
        # Import CryptoAPI from advapi32.dll and crypt32.dll
        $signature = @"
[DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
[return : MarshalAs(UnmanagedType.Bool)]
public static extern bool CryptGetProvParam(IntPtr hProv,uint dwParam,byte[] pbProvData,ref uint pdwProvDataLen,uint dwFlags);
[DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
[return : MarshalAs(UnmanagedType.Bool)]
public static extern bool CryptDestroyKey(IntPtr hKey);
[DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
[return : MarshalAs(UnmanagedType.Bool)]
public static extern bool CryptAcquireContext(ref IntPtr hProv,string pszContainer,string pszProvider,uint dwProvType,uint dwFlags);
[DllImport("advapi32.dll", CharSet=CharSet.Auto)]
[return : MarshalAs(UnmanagedType.Bool)]
public static extern bool CryptGetUserKey(IntPtr hProv,uint dwKeySpec,ref IntPtr phUserKey);
[DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool CryptGetKeyParam(IntPtr hKey,uint dwParam,byte[] pbData,ref uint pdwDataLen,uint dwFlags);
[DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
[return : MarshalAs(UnmanagedType.Bool)]
public static extern bool CryptReleaseContext(IntPtr hProv,uint dwFlags);
[DllImport("crypt32.dll", SetLastError=true)]
[return : MarshalAs(UnmanagedType.Bool)]
public static extern bool CertCloseStore(IntPtr hCertStore,uint dwFlags);
[DllImport("crypt32.dll", SetLastError=true)]
public static extern IntPtr CertEnumCertificatesInStore(IntPtr hCertStore,IntPtr pPrevCertContext);
[DllImport("crypt32.dll", SetLastError=true)]
[return : MarshalAs(UnmanagedType.Bool)]
public static extern bool CertFreeCertificateContext(IntPtr pCertContext);
"@

        Write-Log -LogFile $logFile -Module $functionName -Message "Loading CryptoAPI P/Invoke signatures" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Loading CryptoAPI P/Invoke signatures"

        # Check if type already exists to avoid Add-Type error on subsequent calls
        $CryptoAPI = [CryptoAPI.advapiUtils] -as [Type]
        if (-not $CryptoAPI)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "CryptoAPI type not found, creating new type definition" -LogLevel "Debug"
            $CryptoAPI = Add-Type -member $signature -Name advapiUtils -Namespace CryptoAPI -PassThru
            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully created CryptoAPI type definitions" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Successfully created CryptoAPI type definitions"
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "CryptoAPI type already exists, reusing existing definition" -LogLevel "Verbose"
            Write-Verbose "[$functionName] CryptoAPI type already exists, reusing existing definition"
        }
        # Set some constants for CryptoAPI
        Write-Log -LogFile $logFile -Module $functionName -Message "Initializing CryptoAPI constants" -LogLevel "Debug"
        $AT_KEYEXCHANGE = 1
        $AT_SIGNATURE = 2
        $PROV_RSA_FULL = 1
        $KP_CERTIFICATE = 26
        $PP_ENUMCONTAINERS = 2
        $PP_CONTAINER = 6
        $PP_USER_CERTSTORE = 42
        $CRYPT_FIRST = 1
        $CRYPT_NEXT = 2
        $CRYPT_SILENT = 0x00000040  # Use CRYPT_SILENT instead of CRYPT_VERIFYCONTEXT

        Write-Log -LogFile $logFile -Module $functionName -Message "CryptoAPI constants initialized successfully" -LogLevel "Debug"

        [System.IntPtr]$hProvParent = [System.IntPtr]::Zero

        Write-Log -LogFile $logFile -Module $functionName -Message "Attempting to acquire cryptographic context for provider: $providerName" -LogLevel "Information"
        Write-Verbose "[$functionName] Attempting to acquire cryptographic context for provider: $providerName"

        # Try to acquire context without CRYPT_VERIFYCONTEXT (use 0 or CRYPT_SILENT)
        # First try without any flags to access the default container
        Write-Log -LogFile $logFile -Module $functionName -Message "First attempt: Acquiring context with no flags (default container)" -LogLevel "Verbose"
        $contextRet = $CryptoAPI::CryptAcquireContext([ref]$hProvParent, $null, $providerName, $PROV_RSA_FULL, 0)
        if (-not $contextRet)
        {
            $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Write-Log -LogFile $logFile -Module $functionName -Message "First attempt failed with error code: $lastError. Trying with CRYPT_SILENT flag" -LogLevel "Warning"
            Write-Verbose "[$functionName] First attempt failed with error code: $lastError. Trying with CRYPT_SILENT flag"
            # If that fails, try with CRYPT_SILENT to suppress UI
            Write-Log -LogFile $logFile -Module $functionName -Message "Second attempt: Acquiring context with CRYPT_SILENT flag" -LogLevel "Verbose"
            $contextRet = $CryptoAPI::CryptAcquireContext([ref]$hProvParent, $null, $providerName, $PROV_RSA_FULL, $CRYPT_SILENT)
        }
        if (-not $contextRet)
        {
            $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $errorMessage = "Failed to acquire cryptographic context. Error code: $lastError"
            Write-Log -LogFile $logFile -Module $functionName -Message $errorMessage -LogLevel "Error"
            Write-Error "[$functionName] $errorMessage"
            return @{
                Success      = $false
                Certificates = @()
                ErrorMessage = $errorMessage
            }
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully acquired cryptographic context. Handle: $hProvParent" -LogLevel "Information"
        Write-Verbose "[$functionName] Successfully acquired cryptographic context. Handle: $hProvParent"
        try
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Beginning certificate enumeration process" -LogLevel "Information"
            Write-Verbose "[$functionName] Beginning certificate enumeration process"
            # Get PP_CONTAINER (container name)
            Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving container name (PP_CONTAINER)" -LogLevel "Verbose"
            [Uint32]$containerLen = 0
            [byte[]]$containerData = $null
            $GetProvParamRet = $CryptoAPI::CryptGetProvParam($hProvParent, $PP_CONTAINER, $containerData, [ref]$containerLen, 0)
            if ($containerLen -gt 0)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Container name length: $containerLen bytes" -LogLevel "Debug"
                $containerData = New-Object byte[] $containerLen
                $GetProvParamRet = $CryptoAPI::CryptGetProvParam($hProvParent, $PP_CONTAINER, $containerData, [ref]$containerLen, 0)
                # PP_CONTAINER returns ANSI string - use Default/ASCII encoding and trim nulls
                $keyContainer = [System.Text.Encoding]::Default.GetString($containerData).TrimEnd([char]0)
                Write-Log -LogFile $logFile -Module $functionName -Message "Default User Key Container: $keyContainer" -LogLevel "Information"
                Write-Verbose "[$functionName] Default User Key Container: $keyContainer"
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "No container name returned (length was 0)" -LogLevel "Warning"
            }

            # Get PP_USER_CERTSTORE (certificate store handle)
            Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving certificate store handle (PP_USER_CERTSTORE)" -LogLevel "Verbose"
            [Uint32]$storeLen = 0
            [byte[]]$storeData = $null
            $GetProvParamRet = $CryptoAPI::CryptGetProvParam($hProvParent, $PP_USER_CERTSTORE, $storeData, [ref]$storeLen, 0)
            Write-Log -LogFile $logFile -Module $functionName -Message "Certificate store data length: $storeLen bytes" -LogLevel "Debug"
            if ($storeLen -le 0)
            {
                $warnMessage = "No certificate store returned from smart card (length: $storeLen)"
                Write-Log -LogFile $logFile -Module $functionName -Message $warnMessage -LogLevel "Warning"
                Write-Warning "[$functionName] $warnMessage"
                return @{
                    Success      = $false
                    Certificates = @()
                    ErrorMessage = $warnMessage
                }
            }
            Write-Log -LogFile $logFile -Module $functionName -Message "Allocating buffer and retrieving certificate store data" -LogLevel "Verbose"
            $storeData = New-Object byte[] $storeLen
            $GetProvParamRet = $CryptoAPI::CryptGetProvParam($hProvParent, $PP_USER_CERTSTORE, $storeData, [ref]$storeLen, 0)

            Write-Log -LogFile $logFile -Module $functionName -Message "Certificate store data retrieved successfully" -LogLevel "Verbose"

            # Handle pointer size correctly for 32-bit and 64-bit processes
            $pointerSize = [System.IntPtr]::Size
            Write-Log -LogFile $logFile -Module $functionName -Message "Process pointer size: $pointerSize bytes ($($pointerSize * 8)-bit)" -LogLevel "Debug"

            [System.IntPtr]$hCertStore = [System.IntPtr]::Zero
            if ([System.IntPtr]::Size -eq 8)
            {
                # 64-bit process - read 8 bytes
                Write-Log -LogFile $logFile -Module $functionName -Message "64-bit process detected, reading 8 bytes for store handle" -LogLevel "Debug"
                if ($storeData.Length -ge 8)
                {
                    $hCertStore = [System.IntPtr]::new([System.BitConverter]::ToInt64($storeData, 0))
                    Write-Log -LogFile $logFile -Module $functionName -Message "Certificate store handle extracted: $hCertStore" -LogLevel "Verbose"
                }
                else
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Insufficient data length for 64-bit pointer: $($storeData.Length) bytes" -LogLevel "Error"
                }
            }
            else
            {
                # 32-bit process - read 4 bytes
                Write-Log -LogFile $logFile -Module $functionName -Message "32-bit process detected, reading 4 bytes for store handle" -LogLevel "Debug"
                if ($storeData.Length -ge 4)
                {
                    $hCertStore = [System.IntPtr]::new([System.BitConverter]::ToInt32($storeData, 0))
                    Write-Log -LogFile $logFile -Module $functionName -Message "Certificate store handle extracted: $hCertStore" -LogLevel "Verbose"
                }
                else
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Insufficient data length for 32-bit pointer: $($storeData.Length) bytes" -LogLevel "Error"
                }
            }

            if ($hCertStore -eq [System.IntPtr]::Zero)
            {
                $errorMessage = "Failed to obtain certificate store handle (handle is zero)"
                Write-Log -LogFile $logFile -Module $functionName -Message $errorMessage -LogLevel "Error"
                Write-Error "[$functionName] $errorMessage"
                return @{
                    Success      = $false
                    Certificates = @()
                    ErrorMessage = $errorMessage
                }
            }

            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully obtained certificate store handle: $hCertStore" -LogLevel "Information"
            Write-Verbose "[$functionName] Successfully obtained certificate store handle: $hCertStore"

            # Enumerate certificates from the store
            Write-Log -LogFile $logFile -Module $functionName -Message "Starting certificate enumeration from store" -LogLevel "Information"
            Write-Verbose "[$functionName] Starting certificate enumeration from store"

            $certificates = @()
            [System.IntPtr]$pCertContext = [System.IntPtr]::Zero
            $certCount = 0

            while ($true)
            {
                $pCertContext = $CryptoAPI::CertEnumCertificatesInStore($hCertStore, $pCertContext)

                if ($pCertContext -eq [System.IntPtr]::Zero)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Certificate enumeration completed. No more certificates in store." -LogLevel "Verbose"
                    break
                }

                $certCount++
                Write-Log -LogFile $logFile -Module $functionName -Message "Found certificate #$certCount. Context pointer: $pCertContext" -LogLevel "Verbose"

                # Convert native cert context to X509Certificate2
                try
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Converting certificate #$certCount to X509Certificate2 object" -LogLevel "Debug"
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pCertContext)
                    $certificates += $cert
                    Write-Log -LogFile $logFile -Module $functionName -Message "Successfully converted certificate #$certCount. Subject: $($cert.Subject), Thumbprint: $($cert.Thumbprint)" -LogLevel "Information"
                    Write-Verbose "[$functionName] Certificate #$certCount - Subject: $($cert.Subject)"
                }
                catch
                {
                    $errorMessage = "Failed to convert certificate #$certCount`: $_"
                    Write-Log -LogFile $logFile -Module $functionName -Message $errorMessage -LogLevel "Warning"
                    Write-Warning "[$functionName] $errorMessage"
                }
            }

            # Note: CertEnumCertificatesInStore automatically frees the last context when it returns NULL
            # So we don't need to call CertFreeCertificateContext on the last one
            Write-Log -LogFile $logFile -Module $functionName -Message "Certificate contexts automatically freed by enumeration API" -LogLevel "Debug"

            # Don't close the store here - it's managed by the CSP context
            # CertCloseStore should only be called if we explicitly opened it
            Write-Log -LogFile $logFile -Module $functionName -Message "Certificate store remains open (managed by CSP context)" -LogLevel "Debug"

            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully enumerated $($certificates.Count) certificate(s) from smart card" -LogLevel "Information"
            Write-Verbose "[$functionName] Successfully enumerated $($certificates.Count) certificate(s) from smart card"

            return @{
                Success      = $true
                Certificates = $certificates
                ErrorMessage = $null
            }

        }
        finally
        {
            # Always release the context
            Write-Log -LogFile $logFile -Module $functionName -Message "Entering cleanup (finally block)" -LogLevel "Verbose"
            if ($hProvParent -ne [System.IntPtr]::Zero)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Releasing cryptographic context handle: $hProvParent" -LogLevel "Verbose"
                $ReleaseContextRet = $CryptoAPI::CryptReleaseContext($hProvParent, 0)
                if ($ReleaseContextRet)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Successfully released cryptographic context" -LogLevel "Information"
                    Write-Verbose "[$functionName] Successfully released cryptographic context"
                }
                else
                {
                    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    Write-Log -LogFile $logFile -Module $functionName -Message "Failed to release cryptographic context. Error code: $lastError" -LogLevel "Warning"
                    Write-Warning "[$functionName] Failed to release cryptographic context. Error code: $lastError"
                }
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "No cryptographic context to release (handle was zero)" -LogLevel "Debug"
            }
            Write-Log -LogFile $logFile -Module $functionName -Message "Function execution completed" -LogLevel "Information"
        }
    }
    
    # Get certificates from smart card
    $result = Get-SCUserStore

    if ($result.Success -and $result.Certificates.Count -gt 0)
    {
        if ($displayCerts)
        {
            Write-Host "Smart Card Reader:" ((Get-WmiObject win32_PnPSignedDriver | Where-Object {$_.deviceID -like "*smartcard*"}).devicename)
            Write-Host ""
            Write-Host "Found $($result.Certificates.Count) certificate(s) on smart card"
            Write-Host ""
            
            Write-Host "=== Certificates on Smart Card ===      "
            foreach ($cert in $result.Certificates)
            {
                Write-Host "Subject: $($cert.Subject)"
                Write-Host "Issuer: $($cert.Issuer)"
                Write-Host "Thumbprint: $($cert.Thumbprint)"
                Write-Host "NotBefore: $($cert.NotBefore)"
                Write-Host "NotAfter: $($cert.NotAfter)"
                Write-Host "HasPrivateKey: $($cert.HasPrivateKey)"
                Write-Host "---"
            }
            Write-Host "=== End of Certificates ===      "
        }
    }
    else
    {
        Write-Host "No certificates found on smart card"
        if ($result.ErrorMessage)
        {
            Write-Host "Error: $($result.ErrorMessage)"
        }
    }

    return $result
}


