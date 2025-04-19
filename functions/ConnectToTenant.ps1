<#
.SYNOPSIS
Connects to a Microsoft Graph tenant using client secret or certificate-based authentication.

.DESCRIPTION
The ConnectToTenant function reads configuration details from a JSON file, decrypts the necessary fields, and connects to a Microsoft Graph tenant. It supports both client secret and certificate-based authentication methods. The function validates the presence of required fields in the configuration file and provides verbose output for debugging purposes.

.PARAMETER configFile
The path to the JSON configuration file containing app registration details.

.EXAMPLE
ConnectToTenant -configFile "C:\path\to\config.json"
Connects to the Microsoft Graph tenant using the details provided in the specified configuration file.

.NOTES
Version: 3.0.0
Author: Zuhair Mahmoud
GUID: 7c9e6679-7425-40de-944b-e07fc1f90ae7
Date: April 5, 2025
#>
function ConnectToTenant() {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$configFile
    )
    $success = $false
    Write-Verbose "Reading app registration details from $configFile."
    if ($configFile) {
        $Config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
        $config = DecryptObject -encryptedObject $Config -excludeFields 'domain'
        if ($Config.appId) {
            $clientID = $Config.AppId
        }
        else {
            Write-Error 'A client id must be provided in the config file.'
            exit 1
        }
        if ($config.domain) {
            $domain = $config.domain
        }
        else {
            Write-Host 'No domain was provided.  Defaulting  to Your Company'
            $domain = 'Your Company'
        }
        if ($Config.tenantId) {
            $tenantID = $Config.tenantId
        }
        else {
            Write-Error 'A tenant id must be provided in the config file.'
            exit 1
        }
        if ($Config.AppSecret) {
            $clientSecret = $Config.AppSecret
        }
        elseif ($Config.thumbprint) {
            $thumbprint = $Config.thumbprint
        }
        else {
            Write-Host 'Either a client secret or a certificate thumbprint must be provided in the config file.'
            exit 1
        }
    }
    else {
        Write-Host "The file $configFile does not exist."
        Write-Host 'Please provide a valid config file.'
        exit 1
    }
    if ($clientSecret -and -not $success) {
        Write-Verbose 'Connecting to Microsoft Graph using client secret authentication with the following details:'
        Write-Verbose "Client ID: $clientID"
        Write-Verbose "Tenant ID: $tenantID"
        Write-Verbose "Client Secret: $clientSecret"
        $credentials = New-Object System.Management.Automation.PSCredential ($clientID, (ConvertTo-SecureString $clientSecret -AsPlainText -Force))
        Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credentials -NoWelcome -ErrorAction Stop
        Write-Host "Successfully connected to $domain using a client secret"
        $success = $true
    }
    elseif ($thumbprint -and -not $success) {
        Write-Verbose 'Connecting to Microsoft Graph using certificate authentication with the following details:'
        Write-Verbose "Client ID: $clientID"
        Write-Verbose "Tenant ID: $tenantID"
        Write-Verbose "Certificate Thumbprint: $thumbprint"
        Connect-MgGraph -TenantId $tenantID -ClientId $clientID -CertificateThumbprint $thumbprint -NoWelcome -ErrorAction Stop
        Write-Host "Successfully connected to $domain    using certificate authentication."
        $success = $true
    }
    return $success
}
# SIG # Begin signature block
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB9VUi4tJNXUX7z
# IlRlp4wdYuMvf0Vka44UMAhnukt9b6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAJTLw6Q
# AbyxO+trAAAAAlMvMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwNDA1MDYwNDE3WhcNMjUwNDA8
# MDYwNDE3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# pDL9ztepCuGvrQ+Az3uc39Dg/xRxogU5K4uFHTyEsHpkYagTj3v9DMlra4cxPS5N
# tifxD9lU64xOdcm3cDYyXsQVF7Upj3HoIcQk7vCms3wrTFuoa3RA+HyD9OfQduaE
# kAJ6YsqDGbg2ugwy2mcNjDFYUeAXyuwUp7RtE6ebwrF0CCLuB2GUUVCbuxXJ+NI4
# D+nWKImxvmQ9ox+gEn8tzFuTLjKFqohO6qz/ZGsHbv4yG02uNzwkS3Ed1p5JpiKk
# g8B+qxZ5VKsiyN/6YRGRqLk9q+OYxaz+vR7B+6IAw+GVNMtGJ4j1hC0xJ9ZSUM2w
# bBjha7rgsjqG3iMZkLLRxeaqZMDAhBLwXXn6Xao4wJ0yA1W9F3O2FLXfjEOyaW6j
# YkzRctspNO1Lhwg6vyXlRpVByHQcpIkeIpi6MPzJ1PKrBFPn0L+qu1xog3KIbTQ5
# 47kJmxrfLTG5huoFSCTERBY1V9Cd7mUq8rHiweLuuqEjorbGTsnyNq2ITaLezrT5
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFAJlnZta3B1lqFS+1XvKFjbfJEbAMB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAABThEUkCudwAUfJ
# vSWcK6gVjV4rszARFHl+2xl4e0QOwAVgm8rKZ2uP6ulsDQ3/XA1k/9vV980zluoz
# 2RoVD1e0q8nYZvUCUFVyZyKESPGKqoY5fiBmJ4FpVNUj1+8Na1SLLuNPe3/Ir6yY
# XtuRnIO27kRmOTolF/kMoWZshyQJ/ybUH+gbFgTtcmsKL5TN4teEAKQkSaG+oUzh
# RsPKf3cqwE4R5wzD5Ws7D5CJZW0Bzju7pcdm1yLin68Mj1TgDoGE+WUAdAolJxUl
# e8MvhvqbzL0Rln3TBMvVV1yYet/b+mMvmx5vRX/ncfgOI+wxUD5z+S8hx2p+HlYs
# yqNO99t4w3qKSVta7MJi9Ybcg4+Z4X9WrN1Gh5xPeuiz3leZixi1R3zNjEaR9Rie
# V/oRgPFfbqQ6rrkLD39Me/bW+n7hT4ap8Rmko6wVDyhbX2WTGjY4Un1Sf8fuDkCF
# nizuavx+8qP8mhqw6WLHdgV1XF5AoKXkX6j63KiWXirsBbMaxxl61FujW24+AkCt
# eWnxjCFdF8ZxC4OjLXvIvdaCIGK4VzD6bEPP2yzyAqWbPbTC1y6sJTPAx/MZysI6
# qivU7kvdsiQsju69gTNdohYdEx3N2wwt6SDsQvh8+1yp1NuaDGnPhkRSFDRy4642
# MDc3EsT9r8vkn6YS5hapslnEVmZJMIIG5zCCBM+gAwIBAgITMwACUy8OkAG8sTvr
# awAAAAJTLzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDQwNTA2MDQxN1oXDTI1MDQwODA2MDQx
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAMTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAKQy/c7X
# qQrhr60PgM97nN/Q4P8UcaIFOSuLhR08hLB6ZGGoE497/QzJa2uHMT0uTbYn8Q/Z
# VOuMTnXJt3A2Ml7EFRe1KY9x6CHEJO7wprN8K0xbqGt0QPh8g/Tn0HbmhJACemLK
# gxm4NroMMtpnDYwxWFHgF8rsFKe0bROnm8KxdAgi7gdhlFFQm7sVyfjSOA/p1iiJ
# sb5kPaMfoBJ/Lcxbky4yhaqITuqs/2RrB27+MhtNrjc8JEtxHdaeSaYipIPAfqsW
# eVSrIsjf+mERkai5PavjmMWs/r0ewfuiAMPhlTTLRieI9YQtMSfWUlDNsGwY4Wu6
# 4LI6ht4jGZCy0cXmqmTAwIQS8F15+l2qOMCdMgNVvRdzthS134xDsmluo2JM0XLb
# KTTtS4cIOr8l5UaVQch0HKSJHiKYujD8ydTyqwRT59C/qrtcaINyiG00OeO5CZsa
# 3y0xuYbqBUgkxEQWNVfQne5lKvKx4sHi7rqhI6K2xk7J8jatiE2i3s60+QIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQCZZ2bWtwdZahUvtV7yhY23yRGwDAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8vb25l
# b2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGovCZ/Y
# sHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogqMTfZDozz0
# bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmzYLVZSP7T
# T/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlACU/+8wbIHQf36
# kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUiQTnPcU
# wBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCcn6SEk
# 6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuBXXvn
# ZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KRzUmp
# HQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF912w
# 8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40fLpME
# ydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m3CngY4ZGMfnP
# 6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZMIIHnjCCBYagAwIBAgITMwAAAAeH
# ozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3NvZnQg
# SWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYDVQQG
# EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytN
# aWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJtFL/
# ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGcgHfj
# PF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8JuXW
# JzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2QfzZFmw
# fccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4Gzg2
# Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmPf6KL
# XVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZEZsB
# Rc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/hFMI
# Qa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL8F9g
# n6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4Fre+Z
# Q5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILhAV5Q
# /ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYDVR0g
# BE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4K
# AFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqFKhvK
# GZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlm
# aWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAu
# Y3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRpdHkl
# MjBWZXJpZmllZCUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29t
# L29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGovCZ/YsHVCNSBrQbvMWRsZ3w0FAsc/
# Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogqMTfZDozz0bhmRVy9a4QAD52+MtOFLLz1j
# T/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmzYLVZSP7TT/q42sX53gxUnFXUegEgP73l
# khbQqSpmimc4DjDm8/hPlwGmtlACU/+8wbIHQf36kc2jSNP1DyB8ok3MdL2LUOAG
# aa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUiQTnPcUwBQCv5eAgjUU1mdvjc4jpB3b
# M6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCcn6SEk6ruhKWo8aluvvSEYF4/D8nv+
# aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuBXXvnZMj4Czr0t+Au2GQhO9/tsUcH
# y+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KRzUmpHQW+rHucDAxFKHcVWqiyDMFt
# adWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF912w8D/qTzmYS/7TxTlYJDvJ2PUp
# VXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40fLpMEydI9BGqGE1+46BQMBYRiaUz9
# kcZo8hvvE699XItD/uXph+iBPd6m3CngY4ZGMfnP6Ab2SkEjHxCtGXo6KWeXFETG
# iSYx+UvuXXZMIIHnjCCBYagAwIBAgITMwAAAAeHozSje6WOHAAAAAAABzANBgkqh
# kiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvc
# mBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3NvZnQgSWRlbnRpdHkgVmVyaWZpY2F0a
# W9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMjAwHhcNMjEwNDAxMjAwN
# TIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljc
# m9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytNaWNyb3NvZnQgSUQgVmVyaWZpZ
# WQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AM
# IICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJtFL/ekr4weslKPdnF3cpTeuV8veqt
# mKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGcgHfjPF/nZsOkg7c0mV8hpMT/GvB4u
# hDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8JuXWJzBDoLrmtThX01CE1TCCvH2sZ
# D/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2QfzZFmwfccTKqMAHlrz4B7ac8g9zyxlT
# pkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm
# 1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmPf6KLXVNLz8UaeARo0BatvJ82sLr2g
# qlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZEZsBRc3VT2d/iVd7OTLpSH9yCORV3
# oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/hFMIQa86rcaGMhNsJrhysLNNMeBhi
# MezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL8F9gn6jOy3v7Jm0bbBHjrW5yQW7S3
# 6ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4Fre+ZQ5Od8ouwt59FpBxVOBGfN4vN2
# m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILhAV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCA
# jUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EF
# gQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYDVR0gBE0wSzBJBgRVHSAAMEEwPwYIK
# wYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZX
# Bvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf
# 8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR
# 8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC
# 9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZX
# J0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIHDBggrBgEFBQcBAQSBtj
# CBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHM
# vY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmllZCUyMFJvb3QlMjBD
# ZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MC0GCCsGAQUFBzABhiFod
# HRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADgg
# IBAGovCZ/YsHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogq
# MTfZDozz0bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmz
# YLVZSP7TT/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlACU/+8w
# bIHQf36kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUi
# QTnPcUwBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCc
# n6SEk6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuB
# XXvnZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KRz
# UmpHQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF91
# 2w8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40fLpM
# EydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m3CngY4ZGMfnP
# 6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZMIIHnjCCBYagAwIBAgITMwAAAAeHo
# zSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEeMBwGA1
# UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3NvZnQgSWR
# lbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIw
# MjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYDVQQGEwJVU
# zEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytNaWNyb3
# NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIICIjANBgkqhki
# G9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJtFL/ekr4wesl
# KPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGcgHfjPF/nZsOkg
# 7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8JuXWJzBDoLrmtT
# hX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2QfzZFmwfccTKqMAHlr
# z4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4Gzg2Yc7KR7yhTVNi
# uTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmPf6KLXVNLz8UaeARo0
# BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZEZsBRc3VT2d/iVd7OT
# LpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/hFMIQa86rcaGMhNsJrh
# ysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL8F9gn6jOy3v7Jm0bbBHj
# rW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4Fre+ZQ5Od8ouwt59FpBxVO
# BGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILhAV5Q/ZgCJ0u2+ldFGjcCAw
# EAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADAdBgN
# VHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYDVR0gBE0wSzBJBgRVHSAAMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jc
# y9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHR
# MBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgN
# VHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2Ny
# bC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZ
# XJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIHDBggrBgEFBQcBAQSBtj
# CBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHM
# vY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmllZCUyMFJvb3QlMjBD
# ZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MC0GCCsGAQUFBzABhiFod
# HRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADgg
# IBAGovCZ/YsHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogq
# MTfZDozz0bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmz
# YLVZSP7TT/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlACU/+8w
# bIHQf36kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUi
# QTnPcUwBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCc
# n6SEk6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuB
# XXvnZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KRz
# UmpHQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF91
# 2w8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40fLpM
# EydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m3CngY4ZGMfnP
# 6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZMIIHnjCCBYagAwIBAgITMwAAAAeHo
# zSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEeMBwGA1
# UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3NvZnQgSWR
# lbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIw
# MjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYDVQQGEwJVU
# zEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytNaWNyb3
# NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIICIjANBgkqhki
# G9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJtFL/ekr4wesl
# KPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGcgHfjPF/nZsOkg
# 7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8JuXWJzBDoLrmtT
# hX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2QfzZFmwfccTKqMAHlr
# z4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4Gzg2Yc7KR7yhTVNi
# uTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmPf6KLXVNLz8UaeARo0
# BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZEZsBRc3VT2d/iVd7OT
# LpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/hFMIQa86rcaGMhNsJrh
# ysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL8F9gn6jOy3v7Jm0bbBHj
# rW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4Fre+ZQ5Od8ouwt59FpBxVO
# BGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILhAV5Q/ZgCJ0u2+ldFGjcCAw
# EAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADAdBgN
# VHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYDVR0gBE0wSzBJBgRVHSAAMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jc
# y9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHR
# MBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgN
# VHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2Ny
# bC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZ
# XJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIHDBggrBgEFBQcBAQSBtj
# CBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHM
# vY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmllZCUyMFJvb3QlMjBD
# ZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MC0GCCsGAQUFBzABhiFod
# HRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADgg
# IBAGovCZ/YsHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogq
# MTfZDozz0bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmz
# YLVZSP7TT/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlACU/+8w
# bIHQf36kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUi
# QTnPcUwBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCc
# n6SEk6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuB
# XXvnZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KRz
# UmpHQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF91
# 2w8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40fLpM
# EydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m3CngY4ZGMfnP
# 6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZ