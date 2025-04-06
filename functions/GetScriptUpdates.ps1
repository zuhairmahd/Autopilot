<#
.SYNOPSIS
Updates scripts by downloading the latest versions from a specified URI.

.DESCRIPTION
The GetScriptUpdates function takes a list of scripts to update, along with URIs for the script source, version, and hash. It verifies the integrity of the scripts and downloads updates if necessary.

.PARAMETER scriptsToUpdate
A PSCustomObject containing the scripts to be updated.

.PARAMETER scriptURI
The base URI where the scripts are hosted.

.PARAMETER ScriptRoot
The root directory where the scripts are stored locally.

.PARAMETER scriptVersionURL
The URL to check for the latest script versions.

.PARAMETER scriptHashURL
The URL to check for the latest script hashes.

.EXAMPLE
GetScriptUpdates -scriptsToUpdate $scripts -scriptURI "https://example.com/scripts" -ScriptRoot "C:\Scripts" -scriptVersionURL "https://example.com/versions" -scriptHashURL "https://example.com/hashes"
Downloads and updates the specified scripts.

.NOTES
Version: 3.0.0
Author: Zuhair Mahmoud
GUID: 123e4567-e89b-12d3-a456-426614174000
#>
Function GetScriptUpdates()
{
    [cmdletbinding()]
    param
    (
        [PSCustomObject]$scriptsToUpdate,
        [string]$scriptURI,
        [string]$ScriptRoot,
        [string]$scriptVersionURL,
        [string]$scriptHashURL
    )
    Write-Verbose "Received ScriptRoot: $ScriptRoot"
    Write-Verbose "Received ScriptURL: $scriptURI"
    Write-Verbose "Received ScriptVersionURL: $scriptVersionURL"
    Write-Verbose "Received ScriptHashURL: $scriptHashURL"
    $functionsList = @(
        'ConnectToTenant',
        'Get-decryptedObject',
        'Get-DeviceHash',
        'Get-DeviceInfo',
        'Get-requiredModules',
        'Get-ScriptIntegrity',
        'Get-ScriptUpdates',
        'Get-SignatureStatus',
        'Get-USBDriveLetter',
        'Send-DeviceCommand',
        'Test-ScriptUpdates',
        'Restart-Device',
        'Verify-EnrollmentStatus'
    )
    $CMDList = @(
        'check.cmd',
        'GetHash.cmd',
        'register.cmd',
        'update.cmd'
    )
    $success = $false
    $headers = @{ 'Accept' = 'application/octet-stream' }

    Write-Verbose "The script URI is $scriptURI"
    Write-Verbose "The scripts to update are $($scriptsToUpdate | ConvertTo-Json -Depth 5)"
    Write-Host 'Updating scripts ...'
    $index = 0
    foreach ($key in $scriptsToUpdate.Keys)
    {
        $index++
        Write-Verbose "Processing script $index of $($scriptsToUpdate.Count)"
        if ($key -in $functionsList)
        {
            Write-Verbose "The script $key is a function"
            $scriptPath = $ScriptRoot + '\functions\' + $key + '.ps1'
            $updateURL = $scriptURI + '/functions/' + $key + '.ps1'
            Write-Verbose "The script path is $scriptPath"
            Write-Verbose "The update URL is $updateURL"
        }
        elseif ($key -in $CMDList)
        {
            Write-Verbose "The script $key is a CMD script"
            $scriptPath = $ScriptRoot + '\' + $key
            $updateURL = $scriptURI + '/' + $key
            Write-Verbose "The script path is $scriptPath"
            Write-Verbose "The update URL is $updateURL"
        }
        else 
        {
            Write-Verbose "The script $key is a script"
            $scriptPath = $ScriptRoot + '\' + $key + '.ps1'
            $updateURL = $scriptURI + '/' + $key + '.ps1'
            Write-Verbose "The script path is $scriptPath"
            Write-Verbose "The update URL is $updateURL"
        }
        Write-Host "Updating $key to version $($scriptsToUpdate[$key])." 
        Write-Host "Fetching from $updateURL and copying to $scriptPath"
        try
        {
            $response = Invoke-WebRequest -Uri $updateURL -OutFile $scriptPath -Method Get -PassThru -UseBasicParsing -Headers $headers
            $StatusCode = $Response.StatusCode
            Write-Verbose "The status code is $StatusCode"
            if ($StatusCode -eq 200)
            {
                $success = $true
                Write-Host "Successfully updated $key to version $($scriptsToUpdate[$key])."
            }
            else
            {
                Write-Host "Could not update $key."
                Write-Host "The server returned Status code: $StatusCode"
            }
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }
        Write-Verbose "The status code is $StatusCode"
    }
    if ($success)
    {
        Write-Host "Refreshing updated script version from $scriptVersionURL"
        try
        {
            $response = Invoke-WebRequest -Uri $scriptVersionURL -OutFile $ScriptRoot\version.json -Method Get -PassThru -UseBasicParsing -Headers $headers
            $StatusCode = $Response.StatusCode  
            Write-Verbose "The status code is $StatusCode"
            if ($StatusCode -eq 200)
            {
                Write-Host "The script version file in $ScriptRoot\version.json has been refreshed successfully."
            }
            else
            {
                Write-Host 'Could not refresh the script version file.'
                Write-Host "The server returned Status code: $StatusCode"
            }
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }   
        Write-Host "Refreshing updated hashes from $scriptHashURL"
        try
        {
            $response = Invoke-WebRequest -Uri $scriptHashURL -OutFile $ScriptRoot\hashes.json -Method Get -PassThru -UseBasicParsing -Headers $headers
            $StatusCode = $Response.StatusCode
            Write-Verbose "The status code is $StatusCode"
            if ($StatusCode -eq 200)
            {
                Write-Host "The script hashes file in $ScriptRoot\hashes.json has been refreshed successfully."
            }
            else
            {
                Write-Host 'Could not refresh the script hashes file.'
                Write-Host "The server returned Status code: $StatusCode"
            }
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }
    }
    return $success
}
# SIG # Begin signature block
# MII94AYJKoZIhvcNAQcCoII90TCCPc0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCASNTUZHUfu3XbT
# RQ6Cg0wndOC6UWIzSZ2OfsFYxIKsyKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAIWNdTb
# JSskCOoZAAAAAhY1MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDIwHhcNMjUwMzE2MDc0MTQwWhcNMjUwMzE5
# MDc0MTQwWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# pu6hJOAq+sF+JW9rzXiUakJkH235E56S7RNMT6nNz2grTqCnsU7fUm9pTyq4IokN
# EQJEfwMRosWUxL2MHIZt+1R7ZIR10Vxl8Sdc6S63bwPHrHmkmZkpGo4PPQ/QZzQf
# AiPJaHr+fX/w2qgG3c30ZI/2fqzQhrLfrsHd0dsCBk9mZvvD9ybLmBFtuqO1t3YP
# JvTgB9VPKTDz8pDys49Lnari55kfONyUNYX5XESV9v7hrrWZvtkVoRu+TGesoTAJ
# h2DQEg9WA+C8XguHgFshW0IFBBNg/zJw1XzJsPUS1k2RP5Tg5fujHWQc9Yee9GaZ
# cnxlbe5RCZD+i5dmznNfZ40n8wALJXqXuVJUMLQEWhwuP8Wb1sXY7kzktT4+Evtr
# yYbTulPM00Z9zP0yW03Xv/o31noiPgmMApeGRKvEuaI96Y+iHSRNwF1JyoWIC4Nx
# g8cT77RJ/cIQiogkE3CD5Jxt/t8974Z64s4Fu59arYfsi9NBdGHsHOFZOCgM7f8B
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFCaHptHwgja7xZRNT70fO07j55hWMB8GA1UdIwQY
# MBaAFGWfUc6FaH8vikWIqt2nMbseDQBeMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBANHUbB/c+bpFsMFb
# m2y48UKidh5zOj3bB/1skABivOAmXyJ0KQSEoTnlzRvEur/KZyRw/BCjOWOOw31T
# R+sIixKZ+rBPDtLx5Cg6XtpJZFv3z0WJAzemua8XzpY/i/yAxe4Cd5SYN5bjeU64
# eujABTpZ5ICjpwxMXcI+SeLNb3yGPc4aL+7MgIliIs7AFP3YxXkMdgZImbtHU+8j
# rQm2p84Hf3iVz+lzF3hpACEOKss0savbsE+zy/7G+sL+q2P+rXAXqxh7+8rLkV6F
# YGOxXv2C+k+DkaDk6HyeihDNTCDnN00okCQ972vfgGKGRaEKaOJMYYhJ2JR6NWVb
# MZVhSdnuOwYGy63vPYF/Y8DD00RDGQBkZTniUqQ5YdQ5vp2BqExCtYyxhKganKrh
# gRlZRAiLfERkpp18AToULEBs7iwmCkdKP0Ev/ZyupMDym86dZRfxEG6o7AK1mzWp
# WF2XYIgG/3hBOopRyaP4xWMESHRXuitm0XN2wj5BJc3PUjeZaQHm4gHxdip4dKh9
# TScg2kAL+sO7+FNQlgXUbeYOEC3Wq4G9qG4ZaF+UYRz7ZqzVITDBuvEBQp1A6ptw
# GennuLEyI1usHol9PVOEdB37b5hwiy9HSw7LWkdGLnYPuvxJf8bm/2fXSaWFuojY
# 9Y+rd8w3b3k33pCHvbUxVkLASvtNMIIG5zCCBM+gAwIBAgITMwACFjXU2yUrJAjq
# GQAAAAIWNTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAyMB4XDTI1MDMxNjA3NDE0MFoXDTI1MDMxOTA3NDE0
# MFowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAKbuoSTg
# KvrBfiVva814lGpCZB9t+ROeku0TTE+pzc9oK06gp7FO31JvaU8quCKJDRECRH8D
# EaLFlMS9jByGbftUe2SEddFcZfEnXOkut28Dx6x5pJmZKRqODz0P0Gc0HwIjyWh6
# /n1/8NqoBt3N9GSP9n6s0Iay367B3dHbAgZPZmb7w/cmy5gRbbqjtbd2Dyb04AfV
# Tykw8/KQ8rOPS52q4ueZHzjclDWF+VxElfb+4a61mb7ZFaEbvkxnrKEwCYdg0BIP
# VgPgvF4Lh4BbIVtCBQQTYP8ycNV8ybD1EtZNkT+U4OX7ox1kHPWHnvRmmXJ8ZW3u
# UQmQ/ouXZs5zX2eNJ/MACyV6l7lSVDC0BFocLj/Fm9bF2O5M5LU+PhL7a8mG07pT
# zNNGfcz9MltN17/6N9Z6Ij4JjAKXhkSrxLmiPemPoh0kTcBdScqFiAuDcYPHE++0
# Sf3CEIqIJBNwg+Scbf7fPe+GeuLOBbufWq2H7IvTQXRh7BzhWTgoDO3/AQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQmh6bR8II2u8WUTU+9HztO4+eYVjAfBgNVHSMEGDAWgBRl
# n1HOhWh/L4pFiKrdpzG7Hg0AXjBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8vb25l
# b2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBANHUbB/c
# +bpFsMFbm2y48UKidh5zOj3bB/1skABivOAmXyJ0KQSEoTnlzRvEur/KZyRw/BCj
# OWOOw31TR+sIixKZ+rBPDtLx5Cg6XtpJZFv3z0WJAzemua8XzpY/i/yAxe4Cd5SY
# N5bjeU64eujABTpZ5ICjpwxMXcI+SeLNb3yGPc4aL+7MgIliIs7AFP3YxXkMdgZI
# mbtHU+8jrQm2p84Hf3iVz+lzF3hpACEOKss0savbsE+zy/7G+sL+q2P+rXAXqxh7
# +8rLkV6FYGOxXv2C+k+DkaDk6HyeihDNTCDnN00okCQ972vfgGKGRaEKaOJMYYhJ
# 2JR6NWVbMZVhSdnuOwYGy63vPYF/Y8DD00RDGQBkZTniUqQ5YdQ5vp2BqExCtYyx
# hKganKrhgRlZRAiLfERkpp18AToULEBs7iwmCkdKP0Ev/ZyupMDym86dZRfxEG6o
# 7AK1mzWpWF2XYIgG/3hBOopRyaP4xWMESHRXuitm0XN2wj5BJc3PUjeZaQHm4gHx
# dip4dKh9TScg2kAL+sO7+FNQlgXUbeYOEC3Wq4G9qG4ZaF+UYRz7ZqzVITDBuvEB
# Qp1A6ptwGennuLEyI1usHol9PVOEdB37b5hwiy9HSw7LWkdGLnYPuvxJf8bm/2fX
# SaWFuojY9Y+rd8w3b3k33pCHvbUxVkLASvtNMIIG5zCCBM+gAwIBAgITMwACFjXU
# 2yUrJAjqGQAAAAIWNTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQg
# SUQgVmVyaWZpZWQgQ1MgRU9DIENBIDAyMB4XDTI1MDMxNjA3NDE0MFoXDTI1MDMx
# OTA3NDE0MFowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYD
# VQQHEwlBcmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQD
# Ew5adWhhaXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGB
# AKbuoSTgKvrBfiVva814lGpCZB9t+ROeku0TTE+pzc9oK06gp7FO31JvaU8quCKJ
# DRECRH8DEaLFlMS9jByGbftUe2SEddFcZfEnXOkut28Dx6x5pJmZKRqODz0P0Gc0
# HwIjyWh6/n1/8NqoBt3N9GSP9n6s0Iay367B3dHbAgZPZmb7w/cmy5gRbbqjtbd2
# Dyb04AfVTykw8/KQ8rOPS52q4ueZHzjclDWF+VxElfb+4a61mb7ZFaEbvkxnrKEw
# CYdg0BIPVgPgvF4Lh4BbIVtCBQQTYP8ycNV8ybD1EtZNkT+U4OX7ox1kHPWHnvRm
# mXJ8ZW3uUQmQ/ouXZs5zX2eNJ/MACyV6l7lSVDC0BFocLj/Fm9bF2O5M5LU+PhL7
# a8mG07pTzNNGfcz9MltN17/6N9Z6Ij4JjAKXhkSrxLmiPemPoh0kTcBdScqFiAuD
# cYPHE++0Sf3CEIqIJBNwg+Scbf7fPe+GeuLOBbufWq2H7IvTQXRh7BzhWTgoDO3/
# AQIDAQABo4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYD
# VR0lBDQwMgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVr
# gb36hVz5gO8bMB0GA1UdDgQWBBQmh6bR8II2u8WUTU+9HztO4+eYVjAfBgNVHSME
# GDAWgBRln1HOhWh/L4pFiKrdpzG7Hg0AXjBnBgNVHR8EYDBeMFygWqBYhlZodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUy
# MFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEE
# gZgwgZUwZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvY2VydHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMFJvb3QlMjBDZXJ0
# aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MC0GCCsGAQUFBzABhiFodHRw
# Oi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIB
# ANHUbB/c+bpFsMFbm2y48UKidh5zOj3bB/1skABivOAmXyJ0KQSEoTnlzRvEur/K
# ZyRw/BCjOWOOw31TR+sIixKZ+rBPDtLx5Cg6XtpJZFv3z0WJAzemua8XzpY/i/yA
# xe4Cd5SYN5bjeU64eujABTpZ5ICjpwxMXcI+SeLNb3yGPc4aL+7MgIliIs7AFP3Y
# xXkMdgZImbtHU+8jrQm2p84Hf3iVz+lzF3hpACEOKss0savbsE+zy/7G+sL+q2P+
# rXAXqxh7+8rLkV6FYGOxXv2C+k+DkaDk6HyeihDNTCDnN00okCQ972vfgGKGRaEK
# aOJMYYhJ2JR6NWVbMZVhSdnuOwYGy63vPYF/Y8DD00RDGQBkZTniUqQ5YdQ5vp2B
# qExCtYyxhKganKrhgRlZRAiLfERkpp18AToULEBs7iwmCkdKP0Ev/ZyupMDym86d
# ZRfxEG6o7AK1mzWpWF2XYIgG/3hBOopRyaP4xWMESHRXuitm0XN2wj5BJc3PUjeZ
# aQHm4gHxdip4dKh9TScg2kAL+sO7+FNQlgXUbeYOEC3Wq4G9qG4ZaF+UYRz7ZqzV
# ITDBuvEBQp1A6ptwGennuLEyI1usHol9PVOEdB37b5hwiy9HSw7LWkdGLnYPuvxJ
# f8bm/2fXSaWFuojY9Y+rd8w3b3k33pCHvbUxVkLASvtN
