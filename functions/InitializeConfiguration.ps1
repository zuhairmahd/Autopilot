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
        [ordered] @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; default = ".\\.secrets\\config.json"; type = 'string'},
        [ordered] @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; devdefault = 'vars.json'; reldefault = 'vars.json'; default = 'vars.json'; type = 'string'},
        [ordered] @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; default = ''; type = 'string'},
        [ordered] @{name = 'maxWaitTime'; value = '60'; description = 'How long to wait before giving up on importing a device.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        [ordered] @{name = 'timeInSeconds'; value = '60'; description = 'How long to wait before initiating another check.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        [ordered] @{name = 'NoUpdateCheck'; value = @('true', 'false'); description = 'skip checking for updates.'; devdefault = 'false'; reldefault = 'false'; default = 'true'; type = 'array'},
        [ordered] @{name = 'NoAdminCheck'; value = ('true', 'false'); description = 'skip checking for admin rights.'; devdefault = 'false'; reldefault = 'false'; default = 'false'; type = 'array'},
        [ordered] @{name = 'NoSignatureVerify'; value = @('true', 'false'); description = 'skip verifying the signature of the script.'; devdefault = 'true'; reldefault = 'false'; default = 'false'; type = 'array'},
        [ordered] @{name = 'NoHashVerify'; value = @('true', 'false'); description = 'skip verifying the hash of the script.'; devdefault = 'true'; reldefault = 'false'; default = 'false'; type = 'array'},
        [ordered] @{name = 'NoIntuneCheck'; value = @('true', 'false'); description = 'skip checking whether the device is present in Intune.'; devdefault = 'false'; reldefault = 'false'; default = 'false'; type = 'array'},
        [ordered] @{name = 'GetDeviceHash'; value = @('true', 'false'); description = 'Gets the hash of the device and exit.'; devdefault = 'false'; reldefault = 'false'; default = 'false'; type = 'array'},
        [ordered] @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Github'; default = 'Github'; type = 'array'}, 
        [ordered] @{name = 'Release'; value = "2.2"; description = 'The release branch to use.'; devdefault = 'main'; reldefault = '2.2'; default = 'main'; type = 'string'}
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
                default     = $var.default
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
# MII6gQYJKoZIhvcNAQcCoII6cjCCOm4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCAmgROVgE9EET5
# FI/WcjuRQ78vh1L6DK1ccee7g9MS6qCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAK37bDk
# J2rwVReZAAAAArftMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwNTAyMDQwMjMxWhcNMjUwNTA1
# MDQwMjMxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# mLDKvezpp90GlH4y8UxkwiXPyCu9X9/KlwPRDinfMYqoL8bmIRiR/oCNHk4ubE3h
# Y7vrG6+YVaMdLwo5qqpslnkirO96zPrc/7cIuwX3zVO8DcK1lJTCezXuyCqPWprx
# FAXnHmpFcCVd0zcEiRSkQlJmk+MsV4wStBCAoBMCCXdKoy0kIGCW8+e8i6/eNRcV
# /Nua6bYXYdP2DXzpjcz0DhfvKwSUkomjCbFEn/vVD7pZaSfbWO7eT4I4CvdktXbj
# vBBEiliD80LOlhb5ra5q2JIiGx4RSr0j9gmBFhfkKJ0XZgun5iPAXj9JoCPUWgFm
# kVHmEWoL4hIZR75s6fQFwQI7CeO9c8LcEcYfdsXe1p2SnevtKwczKJPA5xFjaCcS
# 5kMYUuKHBjSuAiuHPrWuPHhsLsEicaEQvzWtwWBWbpzcD1Qs9LA8cHFazlGPOnVg
# QoqyOTtH+CKQykSVzxXQsiX+S45eGUSgkLS/75g9L+LMjuwAU/2rxdd95QYx1MCP
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFPK3uRlxSoAeQ8fUo4XOe0OO2t3cMB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAIP8BJ2VV+dlL24G
# ROkFMun2kJTkeX/M6kZi12ZxvP1Va3KHP2kqeZ2iva0XylgixGmXOF1hy2/ArrIN
# Fs2TFndLjm32M3QiUgT1UfIna7OfoaTer/Tulc2nUJl1gxpLqc/Cc9L6McV2DgfA
# 2vbbzHVESCQs06Ff/HgSxFCHa/Lnk6PXSZimT/Oi8Zyi2Gk9Skc5Uyu6nnMa/lcR
# sJwMMrIy/9aMLe0EJXwPZ+sBjZ75AzBHzfikcbwx6Fv4kXR14OPhMnKKmGI0CdSH
# DPxhpyARwVNO6Fxx0lCPhP5oZYBkPE+1rd1zWYgcVEUVxmRIUCk/yBCG/vpUxkWD
# 3QDsb1hhhAN8P2yCh8I2NQxSQTXOSSE8277FdVxXGLVF0VxqrsD7TKgPqvuHAOAJ
# 8w7PakXx6Kf4WvA0e1+sQsQKWj/plDAAHkvT9qPgls44Vu73uRSwZ3oxv7FkgxRt
# epPkrV86OZvYn3sC728ECsa/nDhM73fXHBWHMhc1ZI6QrEZMs+LjqHkFVPOR5a+k
# JMz6mhdXPrxfMJS9tsVJIYgFFPZc0ntOdujPak7lzZXkZ9/UWIVV+0pgfehvkcaY
# XO7vD5q37THFOZeBYjEpAG0joiuGKX/FKLb0NfwzZJkt7C5qBeGGkGEHcH/Hqj1H
# 8vk5YupJd0gLsSYP7VfcibfptWILMIIG5zCCBM+gAwIBAgITMwACt+2w5Cdq8FUX
# mQAAAAK37TANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDUwMjA0MDIzMVoXDTI1MDUwNTA0MDIz
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAJiwyr3s
# 6afdBpR+MvFMZMIlz8grvV/fypcD0Q4p3zGKqC/G5iEYkf6AjR5OLmxN4WO76xuv
# mFWjHS8KOaqqbJZ5Iqzvesz63P+3CLsF981TvA3CtZSUwns17sgqj1qa8RQF5x5q
# RXAlXdM3BIkUpEJSZpPjLFeMErQQgKATAgl3SqMtJCBglvPnvIuv3jUXFfzbmum2
# F2HT9g186Y3M9A4X7ysElJKJowmxRJ/71Q+6WWkn21ju3k+COAr3ZLV247wQRIpY
# g/NCzpYW+a2uatiSIhseEUq9I/YJgRYX5CidF2YLp+YjwF4/SaAj1FoBZpFR5hFq
# C+ISGUe+bOn0BcECOwnjvXPC3BHGH3bF3tadkp3r7SsHMyiTwOcRY2gnEuZDGFLi
# hwY0rgIrhz61rjx4bC7BInGhEL81rcFgVm6c3A9ULPSwPHBxWs5Rjzp1YEKKsjk7
# R/gikMpElc8V0LIl/kuOXhlEoJC0v++YPS/izI7sAFP9q8XXfeUGMdTAjwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBTyt7kZcUqAHkPH1KOFzntDjtrd3DAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQCD/ASdlVfnZS9uBkTpBTLp
# 9pCU5Hl/zOpGYtdmcbz9VWtyhz9pKnmdor2tF8pYIsRplzhdYctvwK6yDRbNkxZ3
# S45t9jN0IlIE9VHyJ2uzn6Gk3q/07pXNp1CZdYMaS6nPwnPS+jHFdg4HwNr228x1
# REgkLNOhX/x4EsRQh2vy55Oj10mYpk/zovGcothpPUpHOVMrup5zGv5XEbCcDDKy
# Mv/WjC3tBCV8D2frAY2e+QMwR834pHG8Mehb+JF0deDj4TJyiphiNAnUhwz8Yacg
# EcFTTuhccdJQj4T+aGWAZDxPta3dc1mIHFRFFcZkSFApP8gQhv76VMZFg90A7G9Y
# YYQDfD9sgofCNjUMUkE1zkkhPNu+xXVcVxi1RdFcaq7A+0yoD6r7hwDgCfMOz2pF
# 8ein+FrwNHtfrELEClo/6ZQwAB5L0/aj4JbOOFbu97kUsGd6Mb+xZIMUbXqT5K1f
# Ojmb2J97Au9vBArGv5w4TO931xwVhzIXNWSOkKxGTLPi46h5BVTzkeWvpCTM+poX
# Vz68XzCUvbbFSSGIBRT2XNJ7Tnboz2pO5c2V5Gff1FiFVftKYH3ob5HGmFzu7w+a
# t+0xxTmXgWIxKQBtI6Irhil/xSi29DX8M2SZLewuagXhhpBhB3B/x6o9R/L5OWLq
# SXdIC7EmD+1X3Im36bViCzCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
# AAYwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDH48g/9CHdxhnAu8XL
# q64nh9OneWfsaqzuzyVNXJ+A4lY/VoAHCTb+jF1WN9IdSrgxM9eKUvnuqL98ftid
# 0Qrgqd3e7lx50XCvZodJOnq+X88vV0Av2x+gO82l0bQ39HzgCFg2kFBOGk7j8GrG
# YKCXeIhF+GHagVU66JOINVa9cGDvptyOcecQS1fO8BbAm7RsFTuhFGpB53hVcm0g
# JW35mgpRKOpjnBSWEB3AeH7fUGekE8LMW0pWIunrMS1HI7FF6BqAVT7IuBe++Z3T
# sgM3RLZMti6JmNPD6Rxg62g2AqvuTQLoT1Z/cfiMdq+TYzGoWm2B8vSAv7NtJv5U
# E0qJVPSarNckgmZaarDQr4Pcwp+YJ6vd7cJus/4XlG0JvRdoTS5Fwk9kmNbByIMH
# EEhuQ0XgYvXaGXm/J2AUybNBw26h0rJf//eUsnWrbaugdVLVyC2wuCmNZhmUGWEJ
# Nxcl5nfG5om9dkH2twsJfXk6BcvbW1RTAkIsTbtXkAZnGQ7eLniaBIKzC06ZZTgA
# p38H97cq1e/pcFREq4C157PUSmCWhpnBB6P2Xl031SHxbX0FmD0iUuX7EdFfi8OI
# xYBR//sA17gyhL3wXjmvvogYnSELTYQy4xnEASvBmPSWfRovncTOUxrkkKJE5tvR
# Sgsd8ZJ00mwyDS6PcMBAN1VZMQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBR2nDZ0E9GQfWFfswLrgPSZS6U+
# hTBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGov
# CZ/YsHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogqMTfZD
# ozz0bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmzYLVZ
# SP7TT/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlACU/+8wbIH
# Qf36kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUiQT
# nPcUwBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCcn
# 6SEk6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuB
# XXvnZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KR
# zUmpHQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF
# I912w8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40
# fLpMEydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m3CngY4Z
# GMfnP6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZMIIHnjCCBYagAwIBAgITMwAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFzEwghctAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACt+2w5Cdq8FUXmQAAAAK37TAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCA/k0N5W/gWlfNfEWnHG+w236B2
# riwb/OGPIKZOM5V7+DANBgkqhkiG9w0BAQEFAASCAYB8e06doRqfPtmGKGR1d+kP
# qU+PEiO7WQ0f7MTy2y65fTjmiBHhiIua7YWoocw9S8rzR339OEGGidPrccgcyKwA
# WRp709gliwERTFntNtnE+FXI1Cy3DmpH0Q9AzN1EQq2Ue5DqfSbtHTBsKv7PSOqR
# 3sGX7/1HpfMTA036N2wxSwZ6Uz56rH85Z5SJ3b5Bnf2T9KTUreg5PDos8XwAu2Qo
# 8stwm0Fa3YUVlR0UT7jHiaRrSlGFFc3KrQvaIRb0psldjnQoTQuMR7z92QAv+RJz
# fvD0fS2A82af/mSKVF78uQEM71i9zh2kqwW015hniGqhG1JWjS16DNX4UQ7BeC3C
# MHRoOV8z4LYinxB9D8XjN8VdL7OBdgrDl15LOcjbcArsfE6Og2Ro18dbFNpnwE6a
# vxb5+avDDipSBgMV9Th0ZvR3gioGxTHJVy96Nqe4bR7tSbx+HM1Olh9Ae/i8akgL
# 8C/meXFF/vQmHDWV2DBOG+rb/6/tQhlg4AgRuuGLCYyhghSxMIIUrQYKKwYBBAGC
# NwMDATGCFJ0wghSZBgkqhkiG9w0BBwKgghSKMIIUhgIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBaQYLKoZIhvcNAQkQAQSgggFYBIIBVDCCAVACAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgU6KD+/X2u4FXV2o9fMN+1pftIMOytOnnAFPXH265
# bT0CBmgTYnlS9hgSMjAyNTA1MDMwMjAwMzYuNDRaMASAAgH0oIHppIHmMIHjMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNy
# b3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo0OTFBLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmggg8pMIIHgjCCBWqgAwIB
# AgITMwAAAAXlzw//Zi7JhwAAAAAABTANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQG
# EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9N
# aWNyb3NvZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUg
# QXV0aG9yaXR5IDIwMjAwHhcNMjAxMTE5MjAzMjMxWhcNMzUxMTE5MjA0MjMxWjBh
# MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIw
# MAYDVQQDEylNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAy
# MDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ5851Jj/eDFnwV9Y7UG
# IqMcHtfnlzPREwW9ZUZHd5HBXXBvf7KrQ5cMSqFSHGqg2/qJhYqOQxwuEQXG8kB4
# 1wsDJP5d0zmLYKAY8Zxv3lYkuLDsfMuIEqvGYOPURAH+Ybl4SJEESnt0MbPEoKdN
# ihwM5xGv0rGofJ1qOYSTNcc55EbBT7uq3wx3mXhtVmtcCEr5ZKTkKKE1CxZvNPWd
# GWJUPC6e4uRfWHIhZcgCsJ+sozf5EeH5KrlFnxpjKKTavwfFP6XaGZGWUG8TZaiT
# ogRoAlqcevbiqioUz1Yt4FRK53P6ovnUfANjIgM9JDdJ4e0qiDRm5sOTiEQtBLGd
# 9Vhd1MadxoGcHrRCsS5rO9yhv2fjJHrmlQ0EIXmp4DhDBieKUGR+eZ4CNE3ctW4u
# vSDQVeSp9h1SaPV8UWEfyTxgGjOsRpeexIveR1MPTVf7gt8hY64XNPO6iyUGsEgt
# 8c2PxF87E+CO7A28TpjNq5eLiiunhKbq0XbjkNoU5JhtYUrlmAbpxRjb9tSreDdt
# ACpm3rkpxp7AQndnI0Shu/fk1/rE3oWsDqMX3jjv40e8KN5YsJBnczyWB4JyeeFM
# W3JBfdeAKhzohFe8U5w9WuvcP1E8cIxLoKSDzCCBOu0hWdjzKNu8Y5SwB1lt5dQh
# ABYyzR3dxEO/T1K/BVF3rV69AgMBAAGjggIbMIICFzAOBgNVHQ8BAf8EBAMCAYYw
# EAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFGtpKDo1L0hjQM972K9J6T7ZPdsh
# MFQGA1UdIARNMEswSQYEVR0gADBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAww
# CgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwDwYDVR0TAQH/
# BAUwAwEB/zAfBgNVHSMEGDAWgBTIftJqhSobyhmYBAcnz1AQT2ioojCBhAYDVR0f
# BH0wezB5oHegdYZzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2Vy
# dGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNybDCBlAYIKwYBBQUHAQEEgYcw
# gYQwgYEGCCsGAQUFBzAChnVodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L2NlcnRzL01pY3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9v
# dCUyMENlcnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcnQwDQYJKoZIhvcN
# AQEMBQADggIBAF+Idsd+bbVaFXXnTHho+k7h2ESZJRWluLE0Oa/pO+4ge/XEizXv
# hs0Y7+KVYyb4nHlugBesnFqBGEdC2IWmtKMyS1OWIviwpnK3aL5JedwzbeBF7POy
# g6IGG/XhhJ3UqWeWTO+Czb1c2NP5zyEh89F72u9UIw+IfvM9lzDmc2O2END7MPnr
# cjWdQnrLn1Ntday7JSyrDvBdmgbNnCKNZPmhzoa8PccOiQljjTW6GePe5sGFuRHz
# dFt8y+bN2neF7Zu8hTO1I64XNGqst8S+w+RUdie8fXC1jKu3m9KGIqF4aldrYBam
# yh3g4nJPj/LR2CBaLyD+2BuGZCVmoNR/dSpRCxlot0i79dKOChmoONqbMI8m04uL
# aEHAv4qwKHQ1vBzbV/nG89LDKbRSSvijmwJwxRxLLpMQ/u4xXxFfR4f/gksSkbJp
# 7oqLwliDm/h+w0aJ/U5ccnYhYb7vPKNMN+SZDWycU5ODIRfyoGl59BsXR/HpRGti
# JquOYGmvA/pk5vC1lcnbeMrcWD/26ozePQ/TWfNXKBOmkFpvPE8CH+EeGGWzqTCj
# dAsno2jzTeNSxlx3glDGJgcdz5D/AAxw9Sdgq/+rY7jjgs7X6fqPTXPmaCAJKVHA
# P19oEjJIBwD1LyHbaEgBxFCogYSOiUIr0Xqcr1nJfiWG2GwYe6ZoAF1bMIIHnzCC
# BYegAwIBAgITMwAAAE6jxg4+McN0JwAAAAAATjANBgkqhkiG9w0BAQwFADBhMQsw
# CQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYD
# VQQDEylNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDAe
# Fw0yNTAyMjcxOTQwMTdaFw0yNjAyMjYxOTQwMTdaMIHjMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFu
# ZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0
# OTFBLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGlt
# ZSBTdGFtcGluZyBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQCG35SLumwJbZXe50V9E+kmxeGxDI6BJlO3S+2RwbDkLYOYYhrPBkJa2VRN
# cgFsxgK3oaKeO65tkNFonbXrvDNB/3O3GqHoVQ9bKPBmNFaNdpHyJkKdareQNZHE
# 3GF1pskG3i8fcPChwZyB6XrD/rJNkk4JWLBbtwrR7SBV46ywBe/jYwNFK8LN58uW
# z3frY8TurxSGN1esl29xiG3B235pXjX62uGRAAP4RcQw3ZtkXi7f+oo+4lTO0OhG
# w0K4LkTEMnRfBxMiz/fIhihxB9+pnM/nifV5f272vj5P/WI9WonNjAawO2E22P4X
# cNx0rJMb1FIDSHChUFbM9+hUjF0Ds1V1tXBVy+FIhqsPspQpSXGdJdx9AIsLJ6b6
# NLfb+Mw+Y8Ca5njSJSgXh+RBm31z3pW1RGdp7TAQoD3oAeanpaqPmzH0s/ZUUztn
# OywcmH0LOlDiS9iYYK2aE/oO1jUhGSl0PqOg17o6Yn+V0zHTM1gjjoiZzHHr6WXQ
# 9mmGjhBhV1JudUBNiSyp4v+9XnGYyOg3+AurwV0Ve1k++gWFIHBGtPJGG1uZDdI4
# 5wTxhQEq/Ukp2TRhSkOCfDMkcRAT2Uzd9zF/T8/t2X2ReJkvKMlzAnDphONOjPUU
# kD/W01VlbjkdDB6OehKVACtYVSyn7kg9HRMGxojGsB63pTijQQIDAQABo4IByzCC
# AccwHQYDVR0OBBYEFPDHuoN0qkrS9LcneYsOK78NTWpiMB8GA1UdIwQYMBaAFGtp
# KDo1L0hjQM972K9J6T7ZPdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJT
# QSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBr
# MGkGCCsGAQUFBzAChl1odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2Nl
# cnRzL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENB
# JTIwMjAyMC5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/
# BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2Nz
# L1JlcG9zaXRvcnkuaHRtMAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAEyZz
# K6QhrlqvWToBCnCsj2Y+9Z/yaV/UmGkyv6jqz7CMc3/6r6v/7o9HUwZ38eyltGiN
# WM9gukO/INW/NAFPAETcqCIZk9kljSPJOxS6O6nlkszeG3IA4E0Umihj4llmybRI
# 2woGyJDSd2Uz/YgSQrMWcL+muOWp/QKRtTVf8D/J4ldEQQh/UiB5g+rL9+JcZcx0
# 4Bhn9Z9vPX4Py6EjLCxT2ePht6dCmLuwOX8+teiAZPWVqV0MRxTXEjIP65cGzuuZ
# NJNLEa1JSFpJPu9Z7djYKbBWlotiWKtJrF9Ls1dy2y2lnys4NQd7oKEly8qWYN6T
# 8qZHV4dcK2vYdttkbs48jpsMlou400FATj2Xp8mqWyYQGV5QsTgWjdNG7NVfs1IN
# pojbXvRPAlh2oKvkbbP9YkojwsFpjCn6opUknUjLWElzMnIgilnsXkYwF9EKL0rB
# r9KTKpGHz2ubm5yNN2m/wOiqHdkxBfLn0oVfbEEqmw7HDFtdk0Dm6Mk1IXPMD6fK
# dllno76x/vQFDuoU6GmHjOIzJpjnAAJaR5tgGPhgJPmOeHeg2AOjQRA/gkhBUmpF
# FUajW5DeJjdUjpJaHWYb0aYZhfTrdA7sy7vygcliHx22mP8E7rKxFRh+FuJ9/RZn
# DCL1WzKXjhDWeffsRohcLeYs7mm2YhzfxBUeJXkxggPUMIID0AIBATB4MGExCzAJ
# BgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNV
# BAMTKU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMz
# AAAATqPGDj4xw3QnAAAAAABOMA0GCWCGSAFlAwQCAQUAoIIBLTAaBgkqhkiG9w0B
# CQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIKAjs5C2yCRBkODsuCWO
# RqihsWy/mjwiTeNTTw5DGpbIMIHdBgsqhkiG9w0BCRACLzGBzTCByjCBxzCBoAQg
# b7Kn0+8oBR2w3v0490Ap9uSRw7lIYMrTT0W+u/+WShcwfDBlpGMwYTELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABO
# o8YOPjHDdCcAAAAAAE4wIgQgQMoxWKuv7nD0EQMSr47cuzBFLymeZOpOSgrZIPbL
# VKMwDQYJKoZIhvcNAQELBQAEggIAGut3BVhlXWeT/Ori0us5JBufJZKW5KDLlI75
# pdul4gbENUpXum3BkpwJ/sQwcw9oniVNBQ9xr2nBiPdq7ksRzzM5Juy17puotEZc
# Ah/V6hGQ3dGosR2XEg00nEgykbJOl9rTmEV6WI+ezlugvACbwCfkAPEAtOn3BJzj
# dOQDeJpTNvvC1qIuKJJ/KgrzTLM4t4fYiTa14+dEKd7oUV+7U3saNtRBOmI0IDwl
# N2mR1A9VHEio3Y9sMqZmsKPQ0oIi/M17V4p5eT1mTNQjX5e6M+ynoXEy99+j5S5W
# H3Iu5TbEOYDmplqzyYEZYVzZhxecZrQLyUIDmTzb21SUZgyIPeDwohm58xviNiKn
# 1JTR5yXj6ZoDNmwfn9d9kseryfVZ0f6l2Q9Wuh9TViXu8nLmfwzzR6bLDuE3Mukz
# ibIRSZGqqDhNhCkp46Rl07S7LUbc9H/FGff3w3xfg3npxrm9iGx7R+tc91AZOTZY
# 3MpWo+N9t2Zpn2ndKI4mwQEkv/loPkmU/4VDJ5G1z5C5Rt0iy3DIGFvJjqBnoFvm
# M3g2y/C0/o3HNRjaaYQ6/iHDh3ezBEWIHSOIMu7JQb7qCxfh5HzMoGr7Mm3zgL1M
# W/xFBbaypheCBbpPMbzaS5UIsya5w/vj2mFP5SuNTaGQ/vKZ6kLvUTbSIYj57A7v
# 9KtYANE=
# SIG # End signature block
