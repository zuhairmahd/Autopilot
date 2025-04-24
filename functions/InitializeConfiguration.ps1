function InitializeConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [switch]$overwrite
    )
    
    #print verbose log of received parameters
    Write-Verbose "Root folder: $RootFolder"
    Write-Verbose "InitFile: $InitFile"
    Write-Verbose "Overwrite: $overwrite"
    
    $initVars = @(
        [ordered] @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; type = 'string'},
        [ordered] @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; devdefault = 'vars.json'; reldefault = 'vars.json'; type = 'string'},
        [ordered] @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; type = 'string'},
        [ordered] @{name = 'maxWaitTime'; value = '60'; description = 'How long to wait before giving up on importing a device.'; devdefault = '60'; reldefault = '60'; type = 'string'},
        [ordered] @{name = 'timeInSeconds'; value = '60'; description = 'How long to wait before initiating another check.'; devdefault = '60'; reldefault = '60'; type = 'string'},
        [ordered] @{name = 'NoUpdateCheck'; value = @('true', 'false'); description = 'skip checking for updates.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'NoAdminCheck'; value = ('true', 'false'); description = 'skip checking for admin rights.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'NoSignatureVerify'; value = @('true', 'false'); description = 'skip verifying the signature of the script.'; devdefault = 'true'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'NoHashVerify'; value = @('true', 'false'); description = 'skip verifying the hash of the script.'; devdefault = 'true'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'NoIntuneCheck'; value = @('true', 'false'); description = 'skip checking whether the device is present in Intune.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'GetDeviceHash'; value = @('true', 'false'); description = 'Gets the hash of the device and exit.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Gitlab'; type = 'array'}, 
        [ordered] @{name = 'Release'; value = @('main', 'auto'); description = 'The release branch to use.'; devdefault = 'main'; reldefault = 'main'; type = 'array'}
    )
    $vars = @()
    $success = $false
    if (-not(Test-Path $InitFile))
    {
        Write-Verbose "Creating configuration file at $InitFile."
        foreach ($var in $initVars)
        {
            $vars += [ordered] @{
                name        = $var.name
                value       = $var.value
                description = $var.description
                devdefault  = $var.devdefault
                reldefault  = $var.reldefault
                type        = $var.type
            }
        }
        $Vars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
    }
    else
    {
        if ($overwrite)
        {
            Write-Verbose "Overwriting configuration file at $InitFile."
            $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
        }
        else
        {
            Write-Host "Initialization file already exists at $InitFile."
            Write-Host "Would you like to overwrite the file?"
            $choice = Read-Host "Overwrite? (y/n)"
            while ($choice -notin ('y', 'n'))
            {
                Write-Host "Invalid input. Please enter 'y' or 'n'."
                [console]::beep(1000, 500)
                $choice = Read-Host "Overwrite? (y/n)"
            }
            if ($choice -eq 'y')
            {
                Write-Verbose "Overwriting initialization file at $InitFile."
                $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
            }
            else
            {
                Write-Host "Initialization file not overwritten."
                return $success
            }
        }
    }
    if (Test-Path $InitFile)
    {
        Write-Host "Initialization file created successfully at $InitFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create initialization file at $InitFile."
    }
    return $success
}

# SIG # Begin signature block
# MII94QYJKoZIhvcNAQcCoII90jCCPc4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC4/D6HXJUb0iRy
# 1pP4CBIRMs5pSz77xvTGCXYZMpKbg6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# nTiOL60cPqfny+Fq8UiuZzGCGpEwghqNAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADdLsJe77QwkkGogAAAAN0uzAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCAmcbZQz/5NpXFj1BN0gbeMMYGB
# s6kUsg8sDU4o3BMzsDANBgkqhkiG9w0BAQEFAASCAYA3TBKP0xzd6Hd2g6pFJkcN
# 9lVdZ9z9wP3oJNvVTtZHsm6GQJRJCfyF5gtTPh3curo3phfA+fAJ+IdMRxRkdXKj
# ALrl/a3JO7ojw0IthMzt8HQFhdwcYIJE266a0U/gZWgakzSXylDzw7VPVuClepX7
# 0dGvE7AeLxXnWHaD47s2uT2GIKwmeQGpMXLkCfL7xUWALt9Sx7LrZcXSNgVB8XaT
# +INKuPDbC/rsPaaRbS52CUwCe4Isv9KAqwLcnoCG7HKwsw6Hu9ulQvnM8wQn/Yc/
# CVJlmJOLMKWEU0ZzS3m6B5IR1BpZeEN8W64BOOBqoqJkabQ2VIY2AfztuynKBxPW
# EawGs4vqutKMpCh2X4Ytf0aqin8ML/UW+fAstP4dXyJTPTxfaOrJVzbPKxGQgpUB
# GAV6Ua+8yDygCg6FSryzk7m4vV3dAFon4+6jfdDfN3WkQ480STY8NVw/4wRy5UIa
# aAxCyeV0bC1cylnOfLdfC2dmI+z1UQihP6VNqdomqC+hghgRMIIYDQYKKwYBBAGC
# NwMDATGCF/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgKF2RfidgDwadILqmdjWQ7TiH4NLG3w0UkORjejK2
# vZ4CBmfnx0CNxBgTMjAyNTA0MjMyMjMzMTUuOTE3WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdEMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
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
# AhMzAAAAS6GxreFZ/Oc0AAAAAABLMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1N1oXDTI1MTExOTE4NDg1N1owgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCdnYqzfzSDLZ8t
# /IcnBhZ/VS77fz7MIUKa1I9mDjnJRNPdVWovmgU5UbARCbLCIIzZj8J0/YDeyJBD
# YFTySXAgaHlDw06rUBcryq2eaxoWfShTHSdlOnyzhDUw8GXGYJT1x/q+nGm6k1or
# uwW2wrYNR86/Q5sr1XYCJlM8yteWaJFvZJGE6vCOPQxni/lEN2qoTrq2ejmpVVMP
# ngkX9IMCyrlxav40gC15WTU7dZ3o19bQs7u+drzbzON0MtKsqa1vDFsHuqvH2q1S
# 21zETmed/llmTK5QaRLLhk5WCd9w1n/Do5gHarg6Jv861uSCqAdMdNnI34fnTsIR
# naEtCGWGu7W1Zd7blHSligBaGALIC61vJzWj1Mb8JxhhmhfPX20d6nB1Jpmm4qIP
# /FW02uCxJSq9Fe8ziedvlg4m1aCqjWX0Q566/i7VieVsOA3rx1xRXeIbADmsxnw3
# 6YlZohsqREsZUMjQZ4e6cCfKAlaO02ca7GizIRn7mNvzHNYc47gQCFEC+YgX2SLv
# w4b6R5Taq43XJ0hfhDwPSPiT60dySjLUIcmDcs2vI878t3WxEl2an9HJCaYPKvV/
# UZ1Ay9HjkSJc3ZqIXvgGlh1VI7kCpPTBayY7RC0IzJl5a7+DM7FcBhei9h1eJ8Ad
# ZszVcUGk+LkF+uqU3GAnjYadJC/x2QIDAQABo4IByzCCAccwHQYDVR0OBBYEFCCZ
# GsUvRVF/zToRWkE3JYWmuHQmMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAMb3YbNgyOUIdvrmh8yK25QWz
# U4kVUvlJmCygDGdnUKokh4ZAMzZu+c7cTlw+hcCH8vbx7zMRbKbLzp1XOXP+/Bvn
# UKynTgEGBkXPEbKwEezCtNwGZm7fAHHh7fAC8GN0R4dEneZBuyvUwjv/RMa3bRCN
# 0IuMTsIpjzwOVivH6lDU8o6dxkE6w+1EhKgImb3iCnGXS1gnotzJ6oa0x3lYMuir
# YOpLFlc54xJR1RncJBKqVqC+2vu31GRaVmBiwVU/bFuYN0o6LVnAPTcu1fMDcn6t
# s5EbW5chgEMFIoUM3tSDMNXoMIQkMQvN3beZpjnLDb4V8OANLd5oXz+bd+p5zW21
# v6odGTBUX/qhjSxBhTbwTPqlV1/Dx95x/6/52PrETq6bQb6t6TAFq4fpXTmRo8uB
# Vj1pkGVljJPDxvi6DyaBZECqlHQws8wM4qDWTk9hTIZrKlK/mvD6J3hR782HLG6W
# JiEuuVSxv+8zsI86ibPK6ywwjlBloH6/+YEtQtS4gIx4D/1xnP7qVfK7FcPtRO4A
# HEw2g+Nm37R+6B+RDime4WvUvxR8FweNjEry0QGtQVvZcEIflDXryIp2UdQIIgW+
# zmUO2b05TulkFPIsiVsgcAYPZjeBuyJkdlhZpYdP0JpYPQiUZTY3hjkum3n/7FnE
# aVhOV+ZdS+0XXVa3A7kxggdDMIIHPwIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAS6GxreFZ/Oc0AAAA
# AABLMA0GCWCGSAFlAwQCAQUAoIIEnDARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MjMyMjMz
# MTVaMC8GCSqGSIb3DQEJBDEiBCCfboqtdbVxtnHLdaEU9VFIi21cucK/UscU3xK4
# Y5tKOTCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEINuJKJ0rsvRcScm4woZm
# CKowMSTh9DWm0OSNAeUABkSnMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAS6GxreFZ/Oc0AAAAAABL
# MIIDXgYLKoZIhvcNAQkQAhIxggNNMIIDSaGCA0UwggNBMIICKQIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# APV6ws6b5FNHUOmEILADVgzql5kzoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 67PjiDAiGA8yMDI1MDQyMzIyMDkxMloYDzIwMjUwNDI0MjIwOTEyWjB0MDoGCisG
# AQQBhFkKBAExLDAqMAoCBQDrs+OIAgEAMAcCAQACAhMDMAcCAQACAhJHMAoCBQDr
# tTUIAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAJ0zYp4+0DpREjsN9nLz
# Mtl8uVlL2lnjpeW/MQiP/+Q/gaFaIpJvEs/HtxXTh6yJBNiya4cKgjjrmkZ/MBVB
# c8p4NI43Or++E70H83KKqbNrzzdCwKmJeQcTf66irjdE+55H5wtHYVstAw7j/tST
# RCRGW85OHUQoBETXwe3oeZ0SYrKZ9Xv0GJnqmrvnSwbSpq/EfpOtCQYzN51Cufm/
# IESlFoMqK5PO72UPW/k2mehvEsEqLWTorHshqYSTXJ2i+oef2L2YcNfBkFasIYUZ
# C7VdX2p4Gp2wDG2CcPIlQIsFM2VpiNL1ukZH2a0zB4nm+GsnjW6XZgKkTC1RZGk/
# xPswDQYJKoZIhvcNAQEBBQAEggIABF4oBzE1rUKGv+efhxFrhIGkSyPVfuQ1759v
# t5EZKs3ZxXDkRv0AsNbuBjSW9sqzpHvz9y2KIzqMZcPcgZUJ+GJMLb7Xwu8X+wnD
# wQNwQiWscveas08mjSkRvPUN/ceF3PBv9LTdx7G4418EoLJhAdjEKGxV+E+tmA4U
# orjZzNtxqgwtYEjp3SuWl66A92KJcZXYMVnYcAO2fzBSqsvT+8GZtm27CwQ+XUHC
# LfGLgXJ7Zcm+N6j3ME1I957mncv5okV+ObHh4j/uk0CN0QYdflrEIeIkdk1rHdXv
# 6hIVYX8OSLr1L/+cbjEHKmZcreW7lWVSj05emZjO19TYR9riAFzTaIDDxMQ2MaBA
# LtgYnlhX+ne1RisADe8ptz5aoo7CfXhkvAk6D9ymD3/65XCJJ/C2hGB2Z34TqA2T
# qDss53Ln6bg7fKxebvmwIWXWgFlLA3lMDuEuzfMhWBves9VZAeOKn+bibhDi6XUB
# 6nvR+7gwYq9bz5cMIFrpBqorlZ0AeN5VYf9V1PLgYWd+JMxac6FBGeU6pux+oeOA
# jh8W1BiduGaa21LUBlbtA97PDXr0qqzso8BStFOEdDUd8ZkGUaoDWs0PRI4Q7ed5
# YjsRZoIL/c5ZSBnU7JaoBe5qQNnNERL5evSVto1DYd/O8kMKZFeYuT2r8qD4RkkT
# F+0DW7o=
# SIG # End signature block
