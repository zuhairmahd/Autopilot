<#
.SYNOPSIS
Creates a configuration file based on an initialization file and configuration type.

.DESCRIPTION
The CreateConfiguration function reads an initialization file (init.json) to generate a configuration file (vars.json).
It supports two configuration types: 'Dev' and 'Release'. If the initialization file does not exist, it attempts to create one.

.PARAMETER RootFolder
The root folder containing the initialization file and where the configuration file will be created.

.PARAMETER InitFile
The path to the initialization file. Defaults to "init.json" in the root folder.

.PARAMETER DestinationFolder
The folder where the configuration file will be created. Defaults to the root folder.

.PARAMETER ConfigurationFile
The path to the configuration file to be created. Defaults to "vars.json" in the destination folder.

.PARAMETER ConfigurationType
The type of configuration to create. Valid values are 'Dev' and 'Release'. Defaults to 'Release'.

.EXAMPLE
CreateConfiguration -RootFolder "C:\Project" -ConfigurationType Dev
Creates a development configuration file in the "C:\Project" folder.

.EXAMPLE
CreateConfiguration -RootFolder "C:\Project"
Creates a release configuration file in the "C:\Project" folder.

.NOTES
Version: 3.0.0
Author: [Your Name]
#>

function CreateConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [ValidateSet('dev', 'release', 'default')]
        [string]$ConfigurationType = 'release'
    )
    
    #region Variables and logs
    Write-Verbose "Root folder: $Folder"
    Write-Verbose "Init file: $InitFile"
    Write-Verbose "Destination folder: $DestinationFolder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    Write-Verbose "ConfigurationType: $ConfigurationType"
    $success = $false
    if (Test-Path -Path $InitFile)
    {
        Write-Verbose "Found init file at $InitFile."
        $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    }
    else
    {
        Write-Host "No init file found at $InitFile."
        Write-Host "Creating init file at $InitFile."
        if (InitializeConfiguration -RootFolder $RootFolder)
        {
            Write-Host "Init file created successfully."
            $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
        }
        else
        {
            Write-Host "Failed to create init file."
            return $success
        }
    }
    $data = @{}
    #endregion
    
    Write-Verbose "Found $($valuesToEdit.PSCustomObject.Count) properties."
    #Iterate over the ValuesToEdit and create the config data
    foreach ($value in $valuesToEdit)
    {
        Write-Verbose "Processing property name: $($value.Name)"
        switch ($ConfigurationType)
        {
            'release'
            {
                Write-Verbose "Name: $($value.Name)"
                Write-Verbose "Release Value: $($value.reldefault)"
                $Data += [ordered] @{$value.Name = $value.relDefault}
            }
            'dev'
            {
                Write-Verbose "Name: $($value.Name)"
                Write-Verbose "Dev Value: $($value.devdefault)"
                $Data += [ordered] @{$value.Name = $value.devdefault}
            }
            'default'
            {
                Write-Verbose "Name: $($value.Name)"
                Write-Verbose "Default Value: $($value.default)"
                $Data += [ordered] @{$value.Name = $value.default}
            }
        }
    }
    Write-Verbose "Config data: $($Data | ConvertTo-Json -Depth 10)"
    #write the config data to the configuration file
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    #Check to make sure it was written.
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "Configuration file created successfully at $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create configuration file at $ConfigurationFile."
        $success = $false
    }
    #Return the success status
    return $success
}

# SIG # Begin signature block
# MII6ggYJKoZIhvcNAQcCoII6czCCOm8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDyILSMgOQnOsAo
# zb/Cq138AsuvpZnhJ1CftI+wd17sUqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# nTiOL60cPqfny+Fq8UiuZzGCFzIwghcuAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACt+2w5Cdq8FUXmQAAAAK37TAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCARk/5tzwPDk7UPdqhAe45Hvr/J
# milQwsyaILb3rXdjJDANBgkqhkiG9w0BAQEFAASCAYAARM8XXwlnJciESyKuPUS3
# nYvAT4SpWrsmDE0RRppU4NavtxrQ3gKCw8ZX6p8qRWubUFXCoEA3DIX8MPeUMMAd
# SgiRFqWbuF9TipuKhQ/QPRUshBEEuDS6zfP/GVbDhM2/3JPV59nLpb4fAKqI6K7c
# euelDxfzbqQ4jLqG9ztb9I23nIeJ8wkNosYIfEuC4e4Q9UJr2bfVYDNWCYQQbWdL
# 1crvJ2oQCCJ1jfnHy33SOGk5B5ZDmCHNWP3ISM4zfuIYQmezs1cpmlbuQ9JWJndu
# ZLOjwo1qANk1JKsDew84beRbPt6EHNQTo9S2lQDsmhLv22sUxyOkNcCRXDaokFb0
# /1JSwU2hdovILenxoP8tRPEDiAFHQr7X+579RMitc9qB8FBV8I9GMkywjl20s3F0
# pLBs/ufoCSJdaZMJXShYZ14W9sC3x730YOXEYPSP3TTRm69be+WAn3+g2kq3N1Be
# jM1/OyBy/BGIo4EVf1cFc1K3A80rBfVg/S3NXA4WB0WhghSyMIIUrgYKKwYBBAGC
# NwMDATGCFJ4wghSaBgkqhkiG9w0BBwKgghSLMIIUhwIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBagYLKoZIhvcNAQkQAQSgggFZBIIBVTCCAVECAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgi1IidjYaQhuaGZu9yr+fSMO0tFGWTa8iztkMU07s
# PZsCBmgTbVDV5RgTMjAyNTA1MDMwMjAwMzQuOTMyWjAEgAIB9KCB6aSB5jCB4zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWlj
# cm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046N0IxQS0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPKTCCB4IwggVqoAMC
# AQICEzMAAAAF5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/
# TWljcm9zb2Z0IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRl
# IEF1dGhvcml0eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVow
# YTELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEy
# MDAGA1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIw
# MjAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1
# BiKjHB7X55cz0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJA
# eNcLAyT+XdM5i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCn
# TYocDOcRr9KxqHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1
# nRliVDwunuLkX1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wo
# k6IEaAJanHr24qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSx
# nfVYXdTGncaBnB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVu
# Lr0g0FXkqfYdUmj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBI
# LfHNj8RfOxPgjuwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3
# bQAqZt65KcaewEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnh
# TFtyQX3XgCoc6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXU
# IQAWMs0d3cRDv09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1Ud
# HwR9MHsweaB3oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3Js
# L01pY3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENl
# cnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGH
# MIGEMIGBBggrBgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJv
# b3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3
# DQEBDAUAA4ICAQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs1
# 74bNGO/ilWMm+Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezz
# soOiBhv14YSd1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD5
# 63I1nUJ6y59TbXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR
# 83RbfMvmzdp3he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AW
# psod4OJyT4/y0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOL
# i2hBwL+KsCh0Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGy
# ae6Ki8JYg5v4fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URr
# YiarjmBprwP6ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kw
# o3QLJ6No803jUsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlR
# wD9faBIySAcA9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB58w
# ggWHoAMCAQICEzMAAABPNLUHwSuXVPwAAAAAAE8wDQYJKoZIhvcNAQEMBQAwYTEL
# MAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAG
# A1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAw
# HhcNMjUwMjI3MTk0MDE5WhcNMjYwMjI2MTk0MDE5WjCB4zELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxh
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046
# N0IxQS0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRp
# bWUgU3RhbXBpbmcgQXV0aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAwmCmWsbLOhC6M+J3M2a5zVASVviz0eHoMWN9nSJIMMZE7eUVXBLho750
# BXaRbMzpkw9S7nEIIf+0tYhKlWKtYc7LTBw9545MjU8wy7D+MYaCijPU3wqFWSEY
# ORHDOZVqWnx5z9JBLOK5jgKfo+XHaOnybcQ7hw1K/Weq/Vjf4OcnPCKexj5y1ZeU
# QlrdHN2VFwPp74e4FFcFRT9SEyGk7VhRA2UWE7bYKo03KW0KhhcOmLMLU+nbV+Ty
# 45hgw7JENaAmVZwQb/wxYRtAXh0bXjZ+kUjJX56wNY8yffl0HcnBntuBsm//ojmc
# 04axiOqPM3de78WQBi4EvP5dgRej3K+2tabV/KUSXnYS7ulvxyYja7z1M+ohPSBJ
# 2r2jwvQNlPvEAszkSrebqvXu6XadryLxctreIt8DMQ97WuP+iDdIdVmhyIe9sXNG
# SN4WguzK39J0ZwzAQF7X3a+VYnU5cij/8BdBuFxb5q+DPlMzI89Z4kSePOA2tmPL
# hysQkGsdz6DVu51G8GaPzX7B4UwGS14vT8CRnNV6oIekipZDgF5icbpGdzk/xp4V
# AQPCD/Dt3uEhXBstOjUvWZGP53FWBRi9wD3EwniGrKyP4D0ii8oHdNDlHYAicNFo
# JGQ1jJqYW/wEae+mA1DzDkmLLtT5gcwrVIpKjifmNyxAaltCpSECAwEAAaOCAcsw
# ggHHMB0GA1UdDgQWBBS/otO37Pxmnnm2R0jR7odURuo3MDAfBgNVHSMEGDAWgBRr
# aSg6NS9IY0DPe9ivSek+2T3bITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBS
# U0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0w
# azBpBggrBgEFBQcwAoZdaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# ZXJ0cy9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBD
# QSUyMDIwMjAuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9j
# cy9SZXBvc2l0b3J5Lmh0bTAIBgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBADaz
# NodUNiVhVdK51WV2Eb3iPz2XW3rf76Cy27kqn+0xGmIO5s/xg3l7YSXaEorO8JXo
# HyhhLpt+nQBTry4Ih9hpSGAXJzFQjBhONVLm4wTiO6bu8F+zrodhYrNMMiEgFpDE
# C5WiKrm7c9NZYdzs006V7g1itVPft98AnKxp/BvqBqX3BKltnWBawJN7jEA4a62B
# Vtvb7ywY25ygTcgjLDIAfkRt182R7rd8UA6jH5WQ93berfIxgWVRWXeQcExKR6al
# b8oaWg1iaOHcYRHWOsNODID2qz1yJSQDyFzuU21mIHHh2OkwnID9wto1s1tRKxdj
# /o9cF28cE/o1acqKEkCU6ImvXgzijlJCRCelKEcHAhyeIt9uhBWQ7jmKPyryPaem
# DKMY/WvGcluH6FCASD1Q0Bykq3jiaJqEi5E7McCiejaPhw8fqaEh6kITMVFmIX9X
# cz2pH+XHWjXHi+lCcatjUf18UalP6QKoocMR29d0EDOvmrerIo0h8ORR3+IT3Iz6
# qCsqwOvJx15Tm0Z4HEH7SDRd9dUUaaJFPJ1pQT8SNyvksCzi7d3mKwNy7VhK/D3o
# +1a6pnGksw5HhgJzM2y795gD9UB1aJtwYglsa1J/eKiVAjrANqGxLEXvOUdXIEIO
# bQJqgTPbMU0V5oEzG5F3KjBIsWLOW86SlxZ3d/FkMYID1DCCA9ACAQEweDBhMQsw
# CQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYD
# VQQDEylNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAIT
# MwAAAE80tQfBK5dU/AAAAAAATzANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcN
# AQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBMYnyuTij8sAO6o0kf
# RJF9Iqe1tKzOXdguMeeMbW5ieTCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAE
# IEFmK0YPkh60cq0douR9sQ12gnOMVyDQNoCykuAvguoOMHwwZaRjMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAA
# TzS1B8Erl1T8AAAAAABPMCIEIEG747zVXs7N3/NMBVB40swdhYqa1MSCjQzFCOC5
# gwUPMA0GCSqGSIb3DQEBCwUABIICAKB2/tWzQ4OzQJ08jhT2nddlApCynl2GImjt
# xN2ccKhCB93nRxHDBQiJPoI0Bkt9Cqi1EeFMw5q7YkFgrHcn5MocK2A+O1AbJ/a+
# +3rL67wW63egkYLRWTGut4MsaATFHECvedQTu4BWMEddQnPCDNu2wocsVcsWdEER
# /xAax9E1LT1v51ANxeJeGlYi7wGx5pjyM7ThxCsXZuMPeNHJ3gDxikKIZyw3hkM9
# YgsO8dQkF4S9UvHGfhjCvwTRYqN2RIX10jXbBlYvuQEy2/Mo5lxrivz+kNd3JGSh
# xjgYjRoF7RD8TY889VcgdlpfVOrJ9N5I9N9pmnl8EI9jsHCYMiDEs/M1XbxpfXi8
# Jg1T7sRCXb6LT6ssfRI90K9+gzXuiRADgWczyEbjEPn8Qv+w4v4qcKaoOukdDgT1
# VV5Q5oVW3R25FNdv+khHD7Cxebz3jxRd4NGObY0W4+e7avz9FpYmlLqkE1S5JOft
# UU4NRlkUtYARvX/3lAQEwi8mtCsesbiMqA5DQaO0pjcLVUkBP3pORfzi83dlYN8u
# wJFTFI7zPl0iQMikxNgZ3nywZmQne8LnaoGuARWj0MkkKeHMVoF+C9r4EAq959SM
# 8Bzu46nONg/x0BqY8+SK0lOSeMuZE9C2y1WqDoEK4JX68D9bOw55rNWUlnPcBtQF
# 0forAY31
# SIG # End signature block
