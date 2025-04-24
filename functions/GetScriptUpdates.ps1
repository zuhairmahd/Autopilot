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
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB9hnpx5V/YOiJQ
# d3kMcCMKFDunjLaXbPVLi2z2ABHHCaCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAN0uwl7
# vtDCSQaiAAAAA3S7MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDIzMDQ0NDU1WhcNMjUwNDI2
# MDQ0NDU1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# h/5tCSWKbPKt8F93wvLZlP5AAfdF3mukm8z0mBQtyMLGXK+NWnLO8fvV0ge5eUjI
# A9wcMLEcX2TvQCW7IyvihQMgHy1L6uzT9xKUmyQI9kJGEXpw64rtKAgDlJqD6GgA
# WnyhOzNcHRfgN0HNTai/MezVyct6AF9SxZn1XinCOhUbBx1wTZTvScxwTEqe43HU
# ZIVJ40G32BYnBeOoSXYAO0ZK4b+mxStrfB9II8lQ3tdTxu524cM+qaIF23QUnhBa
# asuCBhne2rFQuaQnY++/GvWc+ZdkR1d4eoV4zyt9d+mzYHNZ9JNOI4XWn78S2rKd
# gsL9xWj1YKAD1mhVFuuBKMIXktSaSDXiPdhGWSQcaTYbchw2OI0Peb3Xf50WD9qD
# GAPcYdjtB0vugl/dx5YJOLBfqiIxXeVg6TEsgSQTRDQdBaKDjHma/gXRJIsQw5KP
# mJMHaAZ5dEDoVuXbDev27Yvv4VV95giO3wLUx2iOsC1qDenBWiFyWPe4WovyDvxF
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFCmIHt4RADaTywJxAromEjAGzJZjMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAFXeJOg62AhYTxzF
# Yip4wYPtqc/tDdCid07e6FTg2jM84hJXep5mqbcU8VtqDNTqVODwDy1dFGRmHAdu
# 3F4o2Hkb0W4QVFAZsHR9yd+BQTJGDBFv+i23cHJ+qODBTZ6rh1NOMRGSuH6k3lX7
# nsI0/WQXbff/5XsSqpO9/d0+2VwWmeujUSCQf48tY7PsXBH+4rPOe3U9NW0/HXiI
# adefC8/N9UltDmQ4by+CtRmra3nBkIEAPRmFC1ERfq3JMPAJ4yJ3ddzakrjO0w56
# JyW7yeawoSB3iX8due4vRy2rDIfFWsKrcIKEqBZItd3ZTDIuLXbpQD/tZxocQPIx
# Eg6Wy5XRMlKxgQmxVP8IIsmz9InLM1qjhAtGgIv+kx+iisyg1qvojhnGnJohaZbq
# 2XH5Nx84JnfOfTAZ0mfEuSnuZA7IvCtaL66lP6Q1TikBAIGUa5wwk6cL0GGFGcI4
# p/Lr9n34HsCuJp4Qu/d6IaHMwA0s4YJnwH/bJctKJYO5VhV5MEVDU2QgeVkAkQ5G
# EIKOIBA1SR+fC87xg9dmbFjmAHqA3wkNgL1DVijsPpMXByQnkP3IqFFlDrP+rlBz
# WBv7814VxOszcciIgYPGI24asSBGXE6oQyAKkmTfTthhzNdgT5JxpNrgBwFEuUle
# mnqxm4/T9GIubTff34taJzANNNJVMIIG5zCCBM+gAwIBAgITMwADdLsJe77QwkkG
# ogAAAAN0uzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyMzA0NDQ1NVoXDTI1MDQyNjA0NDQ1
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIf+bQkl
# imzyrfBfd8Ly2ZT+QAH3Rd5rpJvM9JgULcjCxlyvjVpyzvH71dIHuXlIyAPcHDCx
# HF9k70AluyMr4oUDIB8tS+rs0/cSlJskCPZCRhF6cOuK7SgIA5Sag+hoAFp8oTsz
# XB0X4DdBzU2ovzHs1cnLegBfUsWZ9V4pwjoVGwcdcE2U70nMcExKnuNx1GSFSeNB
# t9gWJwXjqEl2ADtGSuG/psUra3wfSCPJUN7XU8buduHDPqmiBdt0FJ4QWmrLggYZ
# 3tqxULmkJ2Pvvxr1nPmXZEdXeHqFeM8rfXfps2BzWfSTTiOF1p+/EtqynYLC/cVo
# 9WCgA9ZoVRbrgSjCF5LUmkg14j3YRlkkHGk2G3IcNjiND3m913+dFg/agxgD3GHY
# 7QdL7oJf3ceWCTiwX6oiMV3lYOkxLIEkE0Q0HQWig4x5mv4F0SSLEMOSj5iTB2gG
# eXRA6Fbl2w3r9u2L7+FVfeYIjt8C1MdojrAtag3pwVohclj3uFqL8g78RQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQpiB7eEQA2k8sCcQK6JhIwBsyWYzAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBV3iToOtgIWE8cxWIqeMGD
# 7anP7Q3QondO3uhU4NozPOISV3qeZqm3FPFbagzU6lTg8A8tXRRkZhwHbtxeKNh5
# G9FuEFRQGbB0fcnfgUEyRgwRb/ott3ByfqjgwU2eq4dTTjERkrh+pN5V+57CNP1k
# F233/+V7EqqTvf3dPtlcFpnro1EgkH+PLWOz7FwR/uKzznt1PTVtPx14iGnXnwvP
# zfVJbQ5kOG8vgrUZq2t5wZCBAD0ZhQtREX6tyTDwCeMid3Xc2pK4ztMOeiclu8nm
# sKEgd4l/HbnuL0ctqwyHxVrCq3CChKgWSLXd2UwyLi126UA/7WcaHEDyMRIOlsuV
# 0TJSsYEJsVT/CCLJs/SJyzNao4QLRoCL/pMfoorMoNar6I4ZxpyaIWmW6tlx+Tcf
# OCZ3zn0wGdJnxLkp7mQOyLwrWi+upT+kNU4pAQCBlGucMJOnC9BhhRnCOKfy6/Z9
# +B7AriaeELv3eiGhzMANLOGCZ8B/2yXLSiWDuVYVeTBFQ1NkIHlZAJEORhCCjiAQ
# NUkfnwvO8YPXZmxY5gB6gN8JDYC9Q1Yo7D6TFwckJ5D9yKhRZQ6z/q5Qc1gb+/Ne
# FcTrM3HIiIGDxiNuGrEgRlxOqEMgCpJk307YYczXYE+ScaTa4AcBRLlJXpp6sZuP
# 0/RiLm0339+LWicwDTTSVTCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
# AAQwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTJaFw0yNjA0MTMx
# NzMxNTJaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDhzqDoM6JjpsA7AI9s
# GVAXa2OjdyRRm5pvlmisydGnis6bBkOJNsinMWRn+TyTiK8ElXXDn9v+jKQj55cC
# pprEx3IA7Qyh2cRbsid9D6tOTKQTMfFFsI2DooOxOdhz9h0vsgiImWLyTnW6locs
# vsJib1g1zRIVi+VoWPY7QeM73L81GZxY2NqZk6VGPFbZxaBSxR1rNIeBEJ6TztXZ
# sz/Xtv6jxZdRb3UimCBFqyaJnrlYQUdcpvKGbYtuEErplaZCgV4T4ZaspYIYr+r/
# hGJNow2Edda9a/7/8jnxS07FWLcNorV9DpgvIggYfMPgKa1ysaK/G6mr9yuse6cY
# 0Hv/9Ca6XZk/0dw6Zj9qm2BSfBP7bSD8DfuIN+65XDrJLYujT+Sn+Nv4ny8TgUyo
# iLDEYHIvjzY8xUELep381sVBrwyaPp6exT4cSq/1qv4BtwrC6ZtmokkqZCsZpI11
# Z+TY2h2BxY6aruPKFvHBk6OcuPT9vCexQ1w0B7T2/6qKjPJBB6zwDdRc9xFBvwb5
# zTJo7YgKJ9ZMrvJK7JQnzyTWa03bYI1+1uOK2IB5p+hn1WaGflF9v5L8rlqtW9Nw
# u6S3k91MNDGXnnsQgToD7pcUGl2yM7OQvN0SHsQuTw9U8yNB88KAq0nzhzXt93YL
# 36nEXWURBQVdj9i0Iv42az1xZQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBQkRZmhd5AqfMPKg7BuZBaEKvgs
# ZzBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGct
# OF2Vsw0iiR0q3NJryKj6kQ73kJzdU7Jj+FCwghx0zKTaEk7Mu38zVZd9DISUOT9C
# 3IvNfrdN05vkn6c7y3SnPPCLtli8yI2oq8BA7nSww4mfdPeEI+mnE02GgYVXHPZT
# KJDhva86tywsr1M4QVdZtQwk5tH08zTBmwAEiG7iTpVUvEQN7QZJ5Bf9kTs8d9OD
# jgu5+3ggqpiae/UK6iyneCUVixV6AucxZlRnxS070XxAKICi4liEvk6UKSyANv29
# 78dCEsWd6V+Dp1C5sgWyoH0iUKidgoln8doxm9i0DvL0Q5ErhzGW9N60JcAdrKJJ
# cfS54T9P3bBUbRyy/lV1TKPrJWubba+UpgCRcg0q8M4Hz6ziH5OBKGVRrYAK7YVa
# fsnOVNJumTQgTxES5iaS7IT8FOST3dYMzHs/Auefgn7l+S9uONDTw57B+kyGHxK4
# 91AqqZnjQjhbZTIkowxNt63XokWKZKoMKGCcIHqXCWl7SB9uj3tTumult8EqnoHa
# TZ/tj5ONatBg3451w87JAB3EYY8HAlJokbeiF2SULGAAnlqcLF5iXtKNDkS5rpq2
# Mh5WE3Qp88sU+ljPkJBT4kLYfv3Hh387pg4VH1ph7nj8Ia6nt1FQh8tK/X+PQM9z
# oSV/djJbGWhaPzJ5jeQetkVoCVEzCEBfI9DesRf3MIIHnjCCBYagAwIBAgITMwAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFyAwghccAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADdLsJe77QwkkGogAAAAN0uzAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCYsUzrWktVZdNg520vB0kIi51D
# QbertSUDICNskG0ohjANBgkqhkiG9w0BAQEFAASCAYA+k7+EVr47BdyOv18ZM0ty
# EeRa8lrL9bhjZA+uS0Pm0SQxnv2odhaNQp+VkqcSpMdFJ5q5V+tOZ1VLpBHPViU2
# 59XZ3xakg2Q9qcJ4IqOoUrxKGrZMTDOAxSmffda7615BZP/0rQOOjz6W7FmSZxA/
# JYkr+p3+wC0iwd1a923UM+vi40I8QDg0h5oGBtrDb8bmMGjhoiZp9iF11BOyCfo/
# D40fuHdLKJFJc0FwPi6pEDN27aKiI1ebPYYuFvov44NOLfVKoLOtHhwd4ckMfSsN
# 1sY6a/DT8L9e6qMHoLEIhqmPW2MVrz5/SvQuJoMs/xbuIcCqYJVt72Rc21Z4Xzfc
# q5uCaUrygK1yqk0+aVkppKO8XN7LTEtMqB0+lRS6544mPDjDBkhKNXp9jM5CCmmn
# fdPeSI5s6cGCmRCeuv/mUoZK5Za/8ocgjky9wuYm/b4z9et6PjSUGNAZs1YhUTJQ
# qH+fBc9mGig/z4wiRgihjYS9VxrCS7jbQH8QN0x5Jk6hghSgMIIUnAYKKwYBBAGC
# NwMDATGCFIwwghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgfv5YswDa1XynhwjjqRjKnc+AYk7DQYnJ3WeZYGh/
# DhkCBmgHqYiNchgTMjAyNTA0MjMyMjM2MjAuNTk3WjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046M0RBNS05NjNCLUUxRjQxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPIDCCB4IwggVqoAMCAQICEzMAAAAF
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
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5YwggV+oAMCAQIC
# EzMAAABGF+R1esr92uUAAAAAAEYwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODQ5WhcNMjUxMTE5MTg0ODQ5WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046M0RBNS05NjNCLUUxRjQxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsJV86I/zDS9QX51f
# oIOHdH2bptR3VCYnUjU3A86Ryb5iAah+euswWHFdE8je/t6jpyY6aE8eiQTIDWJy
# +QZk1/R65l9FnTTC3++LuzbQUrgA9rH+p9qlFK8+4vH+69CYmYsSiZ5LwP9WpCx6
# aUDAwroNaAtAGI3e+d2+b8tb1nax1xPYS+9QWXuQwquf+CwZ8vGjkGZc743sIDjZ
# ImZvkn3LZCY4fS8XZA5auRLxhOmFNLgt+1xe6pB7yJLA9vl4AT9JRDH5jyaNnyPR
# cCAPWDF+yiCDRDOTmOp5Lyq8jPbOWyui1eM+PDWKYiNcbx9eWA6bPtfZxwrSjFU2
# XQeHGIQNHVaie3QLuFXMVMA9QBHDMVmyDkdc+jhZFWPRl+aB/JNe3fbd+T1n59F7
# sVuEhv64poLRYKRP7IUbMuZzAmx8ngnVtB3taZa2EKk7Ehz9p/5c9gwoCJZ8frrz
# y1X+fiRv9XdYvy3cGwtlh+lBBCcmSJd2tGMDOK3c6Efj+HTvSP9qFjsVwmKhcrWH
# QsvZYxC1MG8i4640XXbXkfEE8awn2nSqSnxWOgJPxzWT1B2gD2pN22jiL1e0PGsa
# Nw1kMtom9811eoTDzbdb/dKb/qvXWkHcFM1K4HG8E4Xa0YVh8JUSFYNrEeuvBz5+
# P/JfYpBqJKy+oAJlcTbMBGfWsAsCAwEAAaOCAcswggHHMB0GA1UdDgQWBBQRNtDU
# r3awumenJukTxj/GG6iK8TAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBABSFuS/oBs1+IMh6K0t92Cl7ivYg
# vdYmU6Zt9MfxHRxulPDQLtqorcsY2VaujA6t9NILKRtJ7cy2KlYY35Lu4jcxO/JO
# rTYBQq/cLxpCB3ivkNkQDvf7OUfK4TQvpcsDgfuiuWYtJHztGoFV3+zZNjuheg/Q
# BMzS4oxvnDnuRH9heZeGbFUpCxQiOYxCwvq+CpzWY7p3Pqr40s9g5DbF364xYcpP
# iu7+1O/iRWfJGefMhbsRF9HMQyqSS8YjYfzgwji9lMWJIcnyNwEdBIX8V/UGR1YM
# cmcJ2r0d+Rcai0ohk3gCbCu2Dd2yMcrj+ngnJ5F/EzHabvZDw/e7B5zO6aNFEA64
# 2je3rb4iw8Z2sdp3pnbyVtwXsDixaw9Z0p3e2R3Txjwd6Fkwmivf918EBES4t14/
# h2XPPUT+dDbe4e/txuqKtpF2DYnSPYlnfoC/pb5EGR/WEyHwQi1o77l71FFFPgLx
# SNNFLaq73ayHaghWqhPRx0IEn13kOd8S1nTAs7VD/2JzF4icTQZHOlBNqcf6Ovvy
# 1yQyKcCF0eB0qHS35H7DUJehRaydcbDmBkh73BZB/N/PUZlL6469TQW3XrHOAbuJ
# KMft3GmzmXNc5vPRvtUUS9rUXhc0jJWEhjt4ip9xhl5kIkZhZQW9wqW1FUM/n4MV
# TH3i9I+C5ikH09YyMYID1DCCA9ACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEYX5HV6yv3a5QAAAAAA
# RjANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCCc0CGrb8RcMd+jpoj1q1yjIMZEeGzKKYe73D+sO4Jg
# OjCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEIBIndkiaVD4+cUJu9zOL6g5l
# YdUEek4rk1FZC9z/ForOMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAARhfkdXrK/drlAAAAAABGMCIE
# INTYHIveKQSa5Ou3G1cW7I5Mt+CUJHe2Udof3J4IQx9BMA0GCSqGSIb3DQEBCwUA
# BIICAHEfsAR+JxoyBs0caYXFsL3XvaBCxIUXc5WiOEeIxXBLO4h48AA9NOKuBlRQ
# BCbgNVK+FcoQ3mX1yPyUQgC1dElT9+NtDvuV6qNmvMcw/Kq/8Xupe4H8cS2glCC3
# KpxdA6+KB63aJ38gjJt80GpCmXyuElxZ08IO+Lqq2kmGEK+d7sUT6fFN5OXgxrHv
# h4qtJI36ow4mn2dK2K4CuUsP7WZsl4bcAFb19D7Ce6WvrnwUf7HZL1nBaBIq6hJD
# U6VJuE5NPG7LujxJ85pJhjZOIqkAbn64PCefdZGwNHPIUvMXxzallp6u8+wp3/ol
# CI+prs47he1KwBfnhbY0b9EYImHmt3umBt6Zvf6ml5RfGnwiCjgIzycgVTfsQ7pu
# 0SmWPI/yIubQJF/0Qlc84BfoPDxU2brf9Rp0mUXscLPt6zkkaaKMhdBFfh3jBK15
# e7SSLGLqHVx37yW5HCwNq5ONa2EGZqz0Q3bCK8zCW6nyVa7fmDtVzcRBBhitGLQR
# zKaf0upUwHHNQjKEgYhNHKX8Z4/Ojfhod/y/frG1mR/xDmpDYqdtHYGBrjv4uvyb
# ZYw1yObH60+Wvvgs49HeBqPnacoy7n4J+IaFxpS5jxzJKdRrTsLv9WisR6mk6OXe
# LUdu7D4lr8dBNcRAnRRpfMHtBlqvQ9xCARZZB8FIwOmX7+dv
# SIG # End signature block
