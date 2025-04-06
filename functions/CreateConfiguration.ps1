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
        [ValidateSet('Dev', 'Release')]
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
# MII9XwYJKoZIhvcNAQcCoII9UDCCPUwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAezm1nHFevn66k
# TK9kM84Cv9B4Yun/QD8f4LKtYF/a0aCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAM1skIm
# 5t4Y5itQAAAAAzWyMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwNDA0MDYwODQxWhcNMjUwNDA3
# MDYwODQxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# uqspbx8MXZXVSoBUd6U6NGyAHNHAI/F4Sy22FhwfsozNvfuPhJOVLU7czPUJGd2G
# YkqkZrQU3kD8uXv2PpPm6YbU+FVQc8++4ZfjmwHFOpbybWTrn0WzDALvVdpXlLgr
# U3WJvkSPuc8MfFNeR/Z1TlKZyGs8H311PC6vRaRnMQZudluEfTR8LTeaNzxrQG0B
# EV5AXhA9fXxdINVTt2BU4kkMcDD8WmC0Jir5UWdxMjDgrnwV0BE6HJG5SI7JDQ/9
# uxJlypyN/GfqGRHE8TWFP0I8/wm9x64xADf6wYihmZSmkhzaV27YTWheiqUprzBK
# vTeY/JxOBJ3/gkTysTsGka6wClOOFL3xwVy8We4hXAZZcp2gPUwz3ltRjE/k3HJr
# oXubmX35eO9hJyjBc9mziuXrPIE7Yp7wBo6JWfUk3ZxN/MvZahxL3Hagf9fGli7/
# wU/gMCrr+rXEGXhak1gUjMOCFB+4+CA+BjZ0KOQO36iLsqykXEZLAHGFzCrraeQr
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFG9nQS7mKgt2/VkQeyOkS8mNurH+MB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAHoRqOnawpplL/d1
# g5h8IxTkYtqBPi7+94PNDg4B40rt6lt855KabIa4sWbwvig7NtUG4ROOlGRWP6Os
# ZDfaHQXsAbEC9siBWGCsoyGJ85V2gLPMm8UZwLgrrrxAkZFfZd4kmn7EJDfcE3sB
# Kiae0XIRhUh/x/pwvpq0tPeMEl4MUcIJIZyq1FjYf04b1fQOWGwagL7H51CnDRiP
# vWiOz1tVwoyOHyiryX1nGcIx74gczDttdcgRtaOlocYIk5CRwmBID47DjD9U96im
# oE15ayYjRxlY4eok5/CSq4gl0yDR1Dv5tukzlahbjJI9MhufA/Yz5rO7cSKzzh+f
# tIbdB9s/waX7D03YnxXX2yodNQYGie3mmDFbv3fTk1Qcp02jP+oUrnO7wtpJxhRX
# 5BA9if5s2gaO7b9gEjvDNPbOtTpo8rGG6FoYRJN/YKVr5tL35RQCaPw7uDtDI/02
# cpgPfT91E4YLXBS0ralIZojLo6NCciQ5abQ6xKYcuuEIif0W40fBKi/BFSolDF7B
# MYmL9OgOT67no4LxYYEGn3JlqOIWyecD7rhYO/tQMSgufhuPXubzp1ToLn7cAw9C
# /oBuD8v1aqtx8bBM36CANIfRzC4KQ657ahAYL67oZvA8an3BS4ng0CcEQR0TDFti
# QS0sAlDvMlpHwwmIXtYg2P5y0wC8MIIG5zCCBM+gAwIBAgITMwADNbJCJubeGOYr
# UAAAAAM1sjANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDQwNDA2MDg0MVoXDTI1MDQwNzA2MDg0
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAMTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEFAAOCAY8AMIIBigKCAYEAuqspbx8M
# XZXVSoBUd6U6NGyAHNHAI/F4Sy22FhwfsozNvfuPhJOVLU7czPUJGd2GYkqkZrQU
# 3kD8uXv2PpPm6YbU+FVQc8++4ZfjmwHFOpbybWTrn0WzDALvVdpXlLgrU3WJvkSP
# uc8MfFNeR/Z1TlKZyGs8H311PC6vRaRnMQZudluEfTR8LTeaNzxrQG0BEV5AXhA9
# fXxdINVTt2BU4kkMcDD8WmC0Jir5UWdxMjDgrnwV0BE6HJG5SI7JDQ/9uxJlypyN
# /GfqGRHE8TWFP0I8/wm9x64xADf6wYihmZSmkhzaV27YTWheiqUprzBKvTeY/JxO
# BJ3/gkTysTsGka6wClOOFL3xwVy8We4hXAZZcp2gPUwz3ltRjE/k3HJroXubmX35
# eO9hJyjBc9mziuXrPIE7Yp7wBo6JWfUk3ZxN/MvZahxL3Hagf9fGli7/wU/gMCrr
# +rXEGXhak1gUjMOCFB+4+CA+BjZ0KOQO36iLsqykXEZLAHGFzCrraeQrAgMBAAGj
# ggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNVHSUENDAy
# BgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuBvfqFXPmA
# 7xswHQYDVR0OBBYEFG9nQS7mKgt2/VkQeyOkS8mNurH+MB8GA1UdIwQYMBaAFOiD
# xDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIwVmVyaWZp
# ZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSBmDCBlTBk
# BggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0
# cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAx
# LmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0LmNvbS9v
# Y3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0
# bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAHoRqOnawpplL/d1g5h8IxTk
# YtqBPi7+94PNDg4B40rt6lt855KabIa4sWbwvig7NtUG4ROOlGRWP6OsZDfaHQXs
# AbEC9siBWGCsoyGJ85V2gLPMm8UZwLgrrrxAkZFfZd4kmn7EJDfcE3sBKiae0XIR
# hUh/x/pwvpq0tPeMEl4MUcIJIZyq1FjYf04b1fQOWGwagL7H51CnDRiPvWiOz1tV
# woyOHyiryX1nGcIx74gczDttdcgRtaOlocYIk5CRwmBID47DjD9U96imoE15ayYj
# RxlY4eok5/CSq4gl0yDR1Dv5tukzlahbjJI9MhufA/Yz5rO7cSKzzh+ftIbdB9s/
# waX7D03YnxXX2yodNQYGie3mmDFbv3fTk1Qcp02jP+oUrnO7wtpJxhRX5BA9if5s
# 2gaO7b9gEjvDNPbOtTpo8rGG6FoYRJN/YKVr5tL35RQCaPw7uDtDI/02cpgPfT91
# E4YLXBS0ralIZojLo6NCciQ5abQ6xKYcuuEIif0W40fBKi/BFSolDF7BMYmL9OgO
# T67no4LxYYEGn3JlqOIWyecD7rhYO/tQMSgufhuPXubzp1ToLn7cAw9C/oBuD8v1
# aqtx8bBM36CANIfRzC4KQ657ahAYL67oZvA8an3BS4ng0CcEQR0TDFtiQS0sAlDv
# MlpHwwmIXtYg2P5y0wC8
