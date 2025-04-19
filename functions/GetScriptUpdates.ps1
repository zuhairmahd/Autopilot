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
        'update.cmd',
        'forceupdate.cmd'
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
<<<<<<< HEAD
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
<<<<<<< HEAD:functions/Get-ScriptUpdates.ps1
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBouKy5Z+3nvxxMnfMRLx+p
# fiVow/fgTn6JmJ7mk20IN53pUrDdhyvdehAOjPgB+ITadu13YNITos7SZV0Q6D0O
# FQ8QWXqxfJmMGPxEjv6rr3CgO1kjI/7yWs3ZbuedwBqr3ptWMAnio17/oGCw8QSP
# 57Ac4+Cl5Uc4+hUHjpjpYME3M+oyeadVs+SxwU6N57yyCGazFIHfhFcKbSZFWiP5
# Aukj75eYwzy2veVr0mjbCKXozAyrkkOi771RsiplRdRs0SSmUwND9Kb4G8SauihP
# c6VYn0Okg+ihmlODWuIxugohvQNpoaiVd7CGd9cktzgakcY5IE7zLKmcuDX3bk1W
# jVf5wp2ZYHy8QHD0Oe9hDuoGaYJDuth2q2LOysERUGPJ664mRFaLc1qoLQBJdtLz
# IY+/W7G6CeISebGyrUNKTyhrRnmH93rDx1AcjWFPxPNvENIV/Wz195DYASJlUPCo
# qwRmHe5eMXl1OPnTmkleFhVL76n5mwWvvw4ccmDw7tGRzXJwe1oEnxNomQdCNVYD
# dgcFp+eUYvoqq1W0tE6UaDWzJO4tBQakH03SBlikp3zbGPa/qfDecQmerYZ07kvy
# kSs29NFj0aDnSXfxGk1ozMdY1Kep3bgZ6Yq0hB0pV2JHNSb+4k2kXuc9bELbJULZ
# q/mbjWnxrOxJGZDm4thHBjCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
# AAcwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
=======
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQDR1Gwf3Pm6RbDBW5tsuPFC
# onYeczo92wf9bJAAYrzgJl8idCkEhKE55c0bxLq/ymckcPwQozljjsN9U0frCIsS
# mfqwTw7S8eQoOl7aSWRb989FiQM3prmvF86WP4v8gMXuAneUmDeW43lOuHrowAU6
# WeSAo6cMTF3CPknizW98hj3OGi/uzICJYiLOwBT92MV5DHYGSJm7R1PvI60JtqfO
# B394lc/pcxd4aQAhDirLNLGr27BPs8v+xvrC/qtj/q1wF6sYe/vKy5FehWBjsV79
# gvpPg5Gg5Oh8nooQzUwg5zdNKJAkPe9r34BihkWhCmjiTGGISdiUejVlWzGVYUnZ
# 7jsGBsut7z2Bf2PAw9NEQxkAZGU54lKkOWHUOb6dgahMQrWMsYSoGpyq4YEZWUQI
# i3xEZKadfAE6FCxAbO4sJgpHSj9BL/2crqTA8pvOnWUX8RBuqOwCtZs1qVhdl2CI
# Bv94QTqKUcmj+MVjBEh0V7orZtFzdsI+QSXNz1I3mWkB5uIB8XYqeHSofU0nINpA
# C/rDu/hTUJYF1G3mDhAt1quBvahuGWhflGEc+2as1SEwwbrxAUKdQOqbcBnp57ix
# MiNbrB6JfT1ThHQd+2+YcIsvR0sOy1pHRi52D7r8SX/G5v9n10mlhbqI2PWPq3fM
# N295N96Qh721MVZCwEr7TTCCB1owggVCoAMCAQICEzMAAAAF+3pcMhNh310AAAAA
# AAUwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
>>>>>>> 2.2:functions/GetScriptUpdates.ps1
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTNaFw0yNjA0MTMx
# NzMxNTNaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDSGpl8PzKQpMDoINta
# +yGYGkOgF/su/XfZFW5KpXBA7doAsuS5GedMihGYwajR8gxCu3BHpQcHTrF2o6QB
# +oHp7G5tdMe7jj524dQJ0TieCMQsFDKW4y5I6cdoR294hu3fU6EwRf/idCSmHj4C
# HR5HgfaxNGtUqYquU6hCWGJrvdCDZ0eiK1xfW5PW9bcqem30y3voftkdss2ykxku
# RYFpsoyXoF1pZldik8Z1L6pjzSANo0K8WrR3XRQy7vEd6wipelMNPdDcB47FLKVJ
# Nz/vg/eiD2Pc656YQVq4XMvnm3Uy+lp0SFCYPy4UzEW/+Jk6PC9x1jXOFqdUsvKm
# XPXf83NKhTdCOE92oAaFEjCH9gPOjeMJ1UmBZBGtbzc/epYUWTE2IwTaI7gi5iCP
# tHCx4bC/sj1zE7JoeKEox1P016hKOlI3NWcooZxgy050y0oWqhXsKKbabzgaYhhl
# MGitH8+j2LCVqxNgoWkZmp1YrJick7YVXygyZaQgrWJqAsuAS3plpHSuT/WNRiyz
# JOJGpavzhCzdcv9XkpQES1QRB9D/hG2cjT24UVQgYllX2YP/E5SSxah0asJBJ6bo
# fLbrXEwkAepOoy4MqDCLzGT+Z+WvvKFc8vvdI5Qua7UCq7gjsal7pDA1bZO1AHEz
# e+1JOZ09bqsrnLSAQPnVGOzIrQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRln1HOhWh/L4pFiKrdpzG7Hg0A
# XjBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAEVJ
# YNR3TxfiDkfO9V+sHVKJXymTpc8dP2M+QKa9T+68HOZlECNiTaAphHelehK1Elon
# +WGMLkOr/ZHs/VhFkcINjIrTO9JEx0TphC2AaOax2HMPScJLqFVVyB+Y1Cxw8nVY
# fFu8bkRCBhDRkQPUU3Qw49DNZ7XNsflVrR1LG2eh0FVGOfINgSbuw0Ry8kdMbd5f
# MDJ3TQTkoMKwSXjPk7Sa9erBofY9LTbTQTo/haovCCz82ZS7n4BrwvD/YSfZWQhb
# s+SKvhSfWMbr62P96G6qAXJQ88KHqRue+TjxuKyL/M+MBWSPuoSuvt9JggILMniz
# hhQ1VUeB2gWfbFtbtl8FPdAD3N+Gr27gTFdutUPmvFdJMURSDaDNCr0kfGx0fIx9
# wIosVA5c4NLNxh4ukJ36voZygMFOjI90pxyMLqYCrr7+GIwOem8pQgenJgTNZR5q
# 23Ipe0x/5Csl5D6fLmMEv7Gp0448TPd2Duqfz+imtStRsYsG/19abXx9Zd0C/U8K
# 0sv9pwwu0ejJ5JUwpBioMdvdCbS5D41DRgTiRTFJBr5b9wLNgAjfa43Sdv0zgyvW
# mPhslmJ02QzgnJip7OiEgvFiSAdtuglAhKtBaublFh3KEoGmm0n0kmfRnrcuN2fO
# U5TGOWwBtCKvZabP84kTvTcFseZBlHDM/HW+7tLnMIIHnjCCBYagAwIBAgITMwAA
# AAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQD
# EytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJ
# tFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGc
# gHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8
# JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2Qfz
# ZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4
# Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmP
# f6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZ
# EZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/
# hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL
# 8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4F
# re+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILh
# AV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkr
# BgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYD
# VR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqF
# KhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRp
# dHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3Jp
# dHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9z
# b2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcs
# HQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvI
# UpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2
# RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwIS
# FCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyz
# wdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+
# zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifa
# IMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7
# VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6E
<<<<<<< HEAD:functions/Get-ScriptUpdates.ps1
# nTiOL60cPqfny+Fq8UiuZzGCGpQwghqQAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMQITMwAC2AjO4mUn8OXx6QAAAALYCDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCAooSe6DhKl93evZvmIVA0kJkZF
# k+d2DKhFaYLYf3LPnTANBgkqhkiG9w0BAQEFAASCAYC9Bqnz23WGJcsFH5tz5r6t
# sjP2nvSQNhGgMeu//8odjenpwsvte4iFRl2HILXmxjniAZI8Q/bChct+IBoDSjnr
# 8aUooulMR75qzOBxhD1fOxXfl8E8FOr4ARat3rdfZn5Hfrb7ryv2Hmoywg/ZnDBt
# BurunMwmTj27hToiO/ISxRBCko5SSSABAJqyZw0P9MH42yLkkpWjXW0iPXMcjR7I
# zUXgeZnsW90XQr7aTwPG94ROMqyAlQUY7TiMIieGk6A5TsxZFMGBQ5gYFyUYuUJF
# 0Qgbh3k5tEJ1Y6YzO1t9RwAqjasiUHPuBZN4WYqsg4xiy67jx2QBYJK516nxeRjN
# zvjr3s/2nysuYZkGdjc4x6dNB8f9z9VCMHqvYKr8KctjedKGddSsxrDm+wGYb07m
# DQYzeyUivfMT4zLWSf4hEvRfdWndgy1eagshipmcV09PpuIVq/wm2tX55Q5ndW1v
# ao2C6CtvpdEuZ9cPQ+he9yLbmK5pNebUmuWRe5XjjU2hghgUMIIYEAYKKwYBBAGC
# NwMDATGCGAAwghf8BgkqhkiG9w0BBwKgghftMIIX6QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgXpU9P+4cuiKEVuGv+sVJIFToXPH9fPPJnxsxMuu/
# kOQCBmexiL4zlBgTMjAyNTAyMjgxOTU5MDUuMDQ1WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdBMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
# QSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMzAAAA
# BeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29m
# dCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eX
# M9ETBb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3T
# OYtgoBjxnG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/S
# sah8nWo5hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i
# 5F9YciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx6
# 9uKqKhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3G
# gZwetEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2
# HVJo9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT
# 4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnG
# nsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914Aq
# HOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3E
# Q79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0g
# BE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmg
# d6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3Nv
# ZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYI
# KwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2Vy
# dGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAX4h2x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVj
# JviceW6AF6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGE
# ndSpZ5ZM74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1Cesuf
# U211rLslLKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3a
# d4Xtm7yFM7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P
# 8tHYIFovIP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAo
# dDW8HNtX+cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb
# +H7DRon9TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D
# +mTm8LWVydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN
# 41LGXHeCUMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgH
# APUvIdtoSAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeXMIIFf6ADAgEC
# AhMzAAAAR+OVCzehYN3HAAAAAABHMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1MFoXDTI1MTExOTE4NDg1MFowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3QTAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDocLpu99z/+NeI
# ZmR32GJg2VT/jd96pYLsvNngeH4qXwK1qVmFaXXkkVbxb1fOQJMukYkba3WEc69W
# /Z4BszAuxguThDVlY9sk4ZYkGMgxoq1Z5inUPvj4Qh8xVvlhiAS6Of/uLwDsbsKl
# g2fGpmvztiPSOL9P15k00I4bsl1vlmRSut2tNwJQ5sXpoT7GI/2T2A0GnWbFECKR
# CyGW9rsny9o0LNIUl4NYAd4awGSs6OIzKPpIK1JfK90wXHvaXwGJcN9P8QPRJIHK
# uFoVGzIUG/C0jQC4rQ62yTGvc2sZ4AxTQwflfVBBaiHq8gn/YDHpZileGkB2IQaz
# ZEiEc5Or5Xer9mUDU+2FEe66w8e2WkLXanqxaD5+Zco+E+QdwcTYGo78jFxPDvNr
# aTr5QAgITc4dY/PBC3cYFzcgDyUx2xOVCBvgabqJxj7rXrj4Bhd2S/ZTYOVHhi8c
# DWBaefM8JgiO8GCIIRvlNWng8FKFt09ZfNxmsSdCJlWw3rNAwsBY1xp8pmmv9r2M
# 9rNIRkZ+sh0xd3GuASWs2bOrqBi0aTzgY9b3CxY+/m+RU+UTim5JkmpJM/AIP68/
# S+1NwFqXK5yxTJBIInhoEgdEHi+a2JR2SlV3AkpJa0/B6sZaoEa+zgshIfFa66XB
# mnnsydV4uG7W1INoaNVwxBKDdmqNRwIDAQABo4IByzCCAccwHQYDVR0OBBYEFORU
# dlggOj7vT7m2XvFhSEW8ht1oMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEADSJUQ9XamDh0gkC1XvrhVz6A
# MwGVKuKJA+tklJzBa4UVYP3Y9r1RLU08RYJIjPEkpwiwDWitK58gsZxwNh4Nc4fF
# iQrZUJZ9BInfnodv8WOO83zY8YQdJMcpgBzeYVXiNCedumqFKXj0mMMuWaBynv7w
# wn7FnHJwzLru4jt4VLeef+BycnYwPoMa75LF/9xZo/0TJ371qtBYdbsceKmNhQUT
# D2vIvvPkHTPH/NA2IkLsQ1Am51nzh52WEDzRCoXeld6+/KClnfsEB1/vfR6pYPxw
# ZTvTZ7uh7y8D6g4hDpEcjIses754W2aRpxTPru6n+z2EzkvHF70B/g5oAodmVTUB
# b+pxpu77UHm0TraVodjfXJJNs+h1RjnCu9Miku2KhPmpBrsSne31y3gXstm5vctp
# 1tFox9amTWvhIV88l1EIC3yX+BN9cGKtL65REl/y8yqa2PIW2i18JMRIr4T7liHf
# X0A6sdPsl7GudLyEVHAWsW8NFVzt/vdyRhzMUpsxhPL1qGQgD45Q+3bgTlel5MWl
# WgYG+b+LLUXR5uiybbIswnORTU/jDycNAx8u4c5+14sen5/fmqcrQa316l7WqcQ6
# rOcoxDFym7k2RVuEhZNQ4XNXCKI7kb8PMrRtMbobV0mryd0UlbQUbPsJuN9nUE2A
# DmgnO3bQGyERvppedCExggdGMIIHQgIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAR+OVCzehYN3HAAAA
# AABHMA0GCWCGSAFlAwQCAQUAoIIEnzARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTAyMjgxOTU5
# MDVaMC8GCSqGSIb3DQEJBDEiBCB8iVMNyCKp54L08Yqc/LqfqkB2ZYG1o/zKXDB9
# pEnRYTCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIJNm85ZyhQAGGe9QPhd3
# +xvmMKCvfjHhf8tl6mRICsynMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAR+OVCzehYN3HAAAAAABH
# MIIDYQYLKoZIhvcNAQkQAhIxggNQMIIDTKGCA0gwggNEMIICLAIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3QTAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# ACAF09m+ILyMNydZT7P3lOLNVFzdoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 62yB0zAiGA8yMDI1MDIyODE4NDEyM1oYDzIwMjUwMzAxMTg0MTIzWjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDrbIHTAgEAMAoCAQACAgamAgH/MAcCAQACAhN0MAoC
# BQDrbdNTAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBANl2EnpZzGxJ1lDn
# DUng7kBRiI1qYq/OmTz/VIW9kiTYBjorlBSMjpEB2ncg3RGFZF1F5jWKIUAVHeu+
# Ab2ZDh/T7Tow1Q/BZVZr8crmwPYEa3ELhBQK2WRgcLGNM5OIagZss9HGF3tUpO07
# Ya2HXAR+qNIX0FqO45kv85cJ7qewRtZV88Oej10/uTad5u4RDStusSEq5tmXZ0AO
# jTKmWlLN4AS/QAZaNaCIto/aRegXB+LfkJ07G0ocFVGQvEEfVgk0A7mzM6LkcDZM
# 1GSodCltsjinbp14rE+Iyqmy1T6lpSkfEdeKsqkxPErsTYV1T4Wz4pRpEN9N5Zag
# Kh49z18wDQYJKoZIhvcNAQEBBQAEggIAM2Zt7t3Jo3ka3z+f2Ebxf5VezxpISvB1
# MH9L5QYZeISvougZxp5Cq15MZZKfDVHc6D89dRrVdRhLOpvIg8xq+L/YUrCJBO0k
# JCiIrk5m3gHYIwOHsW7zzihyFivXa2755kkIs89ynTZGkG2V8m/5iemSlESTq7yt
# 8LynaVXjKl+m8lDKU57kkVN3HD+3ijnNE22s9if9BECRkwn2k9eUEm8wkrtnbSix
# I9WQv/SfPHLchB00ZRToF9WBIpYbsFagDQUE/UrGPFJY9fyjgVI3l1ZCwv0X/ir2
# /rEiqQ2B6XNN0lCSMwndqHfckR3j23ko4uNAmvN4zi+lzN2fgXBayfPYFF3xQDTv
# ryvLe4xNu/JLi/vJ/T4U0sem1ekeMT/GBqBTO3IAjg2PsSRgVkCkiyemFgCt8irs
# fTStYMpLmjYehuYB7wuPNZXfTBdMwZBLOgw+Axq9srHIZh+uLlvrYlcuvHRPkhFI
# BY/xoNVYDcx/1w/URjBP0X4DandmcbHPYqzn89q3196xzBm3EZBjU/PxuYenI7ws
# 0BcEWmaGdK5yezX2nTb4NIQp2dyy8s9AJGmFw0oveLhnaPZuRkbHOxIiLyjdmxBG
# Tu3uQAemu1GjRI/qt3M726YR3/EXC33OSyFxVrvHL+6Dgj0LTav7s4AQ0Mx3OMPq
# +eJBXl6kHgM=
=======
# nTiOL60cPqfny+Fq8UiuZzGCGpAwghqMAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwACFjXU2yUrJAjqGQAAAAIWNTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDNFUdlXmVQNyWG+daxqQfbxZ9r
# tOvt8Jurci9SmwI+IDANBgkqhkiG9w0BAQEFAASCAYCDXOi1Kt6+NRWIiOfs0AzM
# CU+3FlAJd1dLRYnoQalCcjYa8XUzUeGuW9YgfSAhP//6etreTpnmFaxMqPTMAIwn
# 9iFLeBGzuMOcp5IsUKuZeq8dmS7R8wpTXVOssfIqPFetBEg1uAXo7UGjIHtC8/PE
# SAsQ/9/9SxmEaRpgazXVBNL4qys6gkcOIhA49olb8JINDJZCAXhsTXApmDgPu8OL
# YGNyvWAQIBkxbBR2yt/+XG1t8oAD+pxrbt9wM6u1P5WWOH3xw5rXgNatfOj2JQG3
# v9CiJoWso2K2HMgkgG9f16VZzItAoYOuPyrFVlEatK+DTe5Ol12NopvB925K/941
# ECGGO+CtJoAQ+pIZ5NO1pPnN1GUJxXwXNXgY3v1wjtqpzKhaT2bELJhvAsJKGBRs
# Ki+IqBqXuiSN0K3j4YRu/8N3IHj0vZhD31z7V+wpbDqiVyZhS3/CkWs3LxWKxH6V
# n3B4p6jIdNMZZQ0JB7RgNgd0448yORH6iaQl9YmlITWhghgQMIIYDAYKKwYBBAGC
# NwMDATGCF/wwghf4BgkqhkiG9w0BBwKgghfpMIIX5QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgUjFnAp8uiqAlZX6xyiA2qTsMlnkDR5pXUbTGgi3b
# 4rYCBmeXbIi0gxgSMjAyNTAzMTYxODI4MzQuMTRaMASAAgH0oIHhpIHeMIHbMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046N0QwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPITCCB4IwggVqoAMCAQICEzMAAAAF
# 5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0
# IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz
# 0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5
# i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9Kx
# qHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLk
# X1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr2
# 4qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaB
# nB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYd
# Umj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPg
# juwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65Kcae
# wEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc
# 6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRD
# v09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB
# gjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAE
# TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3
# oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRl
# JTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggr
# BgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0
# aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4IC
# AQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm
# +Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd
# 1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59T
# bXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3
# he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y
# 0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0
# Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4
# fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6
# ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803j
# UsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5cwggV/oAMCAQIC
# EzMAAABLobGt4Vn85zQAAAAAAEswDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODU3WhcNMjUxMTE5MTg0ODU3WjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdEMDAtMDVFMC1EOTQ3MTUw
# MwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhv
# cml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ2dirN/NIMtny38
# hycGFn9VLvt/PswhQprUj2YOOclE091Vai+aBTlRsBEJssIgjNmPwnT9gN7IkENg
# VPJJcCBoeUPDTqtQFyvKrZ5rGhZ9KFMdJ2U6fLOENTDwZcZglPXH+r6cabqTWiu7
# BbbCtg1Hzr9DmyvVdgImUzzK15ZokW9kkYTq8I49DGeL+UQ3aqhOurZ6OalVUw+e
# CRf0gwLKuXFq/jSALXlZNTt1nejX1tCzu752vNvM43Qy0qyprW8MWwe6q8farVLb
# XMROZ53+WWZMrlBpEsuGTlYJ33DWf8OjmAdquDom/zrW5IKoB0x02cjfh+dOwhGd
# oS0IZYa7tbVl3tuUdKWKAFoYAsgLrW8nNaPUxvwnGGGaF89fbR3qcHUmmabiog/8
# VbTa4LElKr0V7zOJ52+WDibVoKqNZfRDnrr+LtWJ5Ww4DevHXFFd4hsAOazGfDfp
# iVmiGypESxlQyNBnh7pwJ8oCVo7TZxrsaLMhGfuY2/Mc1hzjuBAIUQL5iBfZIu/D
# hvpHlNqrjdcnSF+EPA9I+JPrR3JKMtQhyYNyza8jzvy3dbESXZqf0ckJpg8q9X9R
# nUDL0eORIlzdmohe+AaWHVUjuQKk9MFrJjtELQjMmXlrv4MzsVwGF6L2HV4nwB1m
# zNVxQaT4uQX66pTcYCeNhp0kL/HZAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQUIJka
# xS9FUX/NOhFaQTclhaa4dCYwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk9
# 2yEwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5n
# JTIwQ0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# UHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# CAYGZ4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQAxvdhs2DI5Qh2+uaHzIrblBbNT
# iRVS+UmYLKAMZ2dQqiSHhkAzNm75ztxOXD6FwIfy9vHvMxFspsvOnVc5c/78G+dQ
# rKdOAQYGRc8RsrAR7MK03AZmbt8AceHt8ALwY3RHh0Sd5kG7K9TCO/9ExrdtEI3Q
# i4xOwimPPA5WK8fqUNTyjp3GQTrD7USEqAiZveIKcZdLWCei3MnqhrTHeVgy6Ktg
# 6ksWVznjElHVGdwkEqpWoL7a+7fUZFpWYGLBVT9sW5g3SjotWcA9Ny7V8wNyfq2z
# kRtblyGAQwUihQze1IMw1egwhCQxC83dt5mmOcsNvhXw4A0t3mhfP5t36nnNbbW/
# qh0ZMFRf+qGNLEGFNvBM+qVXX8PH3nH/r/nY+sROrptBvq3pMAWrh+ldOZGjy4FW
# PWmQZWWMk8PG+LoPJoFkQKqUdDCzzAzioNZOT2FMhmsqUr+a8PoneFHvzYcsbpYm
# IS65VLG/7zOwjzqJs8rrLDCOUGWgfr/5gS1C1LiAjHgP/XGc/upV8rsVw+1E7gAc
# TDaD42bftH7oH5EOKZ7ha9S/FHwXB42MSvLRAa1BW9lwQh+UNevIinZR1AgiBb7O
# ZQ7ZvTlO6WQU8iyJWyBwBg9mN4G7ImR2WFmlh0/Qmlg9CJRlNjeGOS6bef/sWcRp
# WE5X5l1L7RddVrcDuTGCB0Mwggc/AgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABLobGt4Vn85zQAAAAA
# AEswDQYJYIZIAWUDBAIBBQCgggScMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MDMxNjE4Mjgz
# NFowLwYJKoZIhvcNAQkEMSIEIHuyomh0nzgGZge2brgt9/SBtIqO3GSGTOLR/0CR
# V1OQMIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQg24konSuy9FxJybjChmYI
# qjAxJOH0NabQ5I0B5QAGRKcwfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABLobGt4Vn85zQAAAAAAEsw
# ggNeBgsqhkiG9w0BCRACEjGCA00wggNJoYIDRTCCA0EwggIpAgEBMIIBCaGB4aSB
# 3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjdEMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUA
# 9XrCzpvkU0dQ6YQgsANWDOqXmTOgZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDr
# gTJsMCIYDzIwMjUwMzE2MTEyMDEyWhgPMjAyNTAzMTcxMTIwMTJaMHQwOgYKKwYB
# BAGEWQoEATEsMCowCgIFAOuBMmwCAQAwBwIBAAICCx0wBwIBAAICEfkwCgIFAOuC
# g+wCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAweh
# IKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAgyURq3RFdtbaZc5JyN20
# xGV5qfNJIXx3w3p3Qi/6Md3w8QCooexbwEujTW9Erd+5FdzCbFER0vHqaAni7U01
# 8glIp4tBts9/2c9Sda76yylO07LpkATt0rLHA6joc9QFLGFlk3eoQm3eBOy0zvKu
# QAssXY+LUGU0tPc7buUx9OklUgazT+sihK0LZzi/hRj9iR/VdNF9vSLt1r4Cq0st
# /z0Q/SrWDakMxCmsSPiWNxwvdlhq+GOK4j4dhea9rwhJfst19lCCrL7H3JRAyPB7
# FszLme8HOk7Rc7vdiLSPm6bpWO7cp6e8fKe4XZko1jSil5u+036OpmmdHX+HSoe0
# 2TANBgkqhkiG9w0BAQEFAASCAgBqGJ3HD1Gwi2Xq+zG3w0Q2pXJ4Nfu7Cj5+HIms
# upRA0jlkRWyQmgsthatgEegFQp9ssqN7uef4AAbmnaZr86yp71sox7KmxVJIr/JO
# r+LC0UdjByHKpH1WtDOymiyC8LxNTsIr406DFwPm625AWArCPfr5d/NFNUGV8vY+
# Sb1thiKF3HN8/iFfZ38V3rQCAXBkg8tAiqi/mDnSzJ3rD+MgRViFmdV/2XClBWlR
# E4PnzEimrhgnXqkOuro1x6MIKG5qD/Ltvw6oLVqWDU1yNpXmdOfBKkduXBBvMRLE
# WPs2tjg8xoyIChCUWoaYHNI7VZOlfVtRNZRcCSOfhuHFyzh4GVdWCUra0SBjsb/D
# SutdKJLsSbSAL2o9nZkJ0maQbgof1Lm06nYKtG4SQEE6cpBUm6ZNFpP6UKBNC548
# KJ3Su6hd3VXRCwGfhIWJdEHCrsttSyC7DqzS+wBiZuIOJ5xb4lY/uT7MRT51sv5b
# 3iJyu1dY54LlHQqZ1XxH/AUwkT/2JtfDwtw9oDptICBeChGPsMXNfX4MKN6FUfz9
# UzeTG5vHSyS1Cfz84YRxQHazMikrlHApa0oAWOxI6epiuZASYE17gB6bDfNoS+WN
# mtrIGMmXLbzZobRLuQnPtNqkxZlb8m+RmXTeFW+IhlKrXlXoQeN+rKyQUgmapn8w
# NZeXxA==
>>>>>>> 2.2:functions/GetScriptUpdates.ps1
# SIG # End signature block
=======
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
>>>>>>> 2.2
