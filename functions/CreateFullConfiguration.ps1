<#
.SYNOPSIS
Creates a full configuration file by combining initialization and existing configuration data.

.DESCRIPTION
The CreateFullConfiguration function ensures that both the initialization file (init.json) and the configuration file (vars.json) exist.
It reads the initialization file to load configuration properties and prompts the user to update or confirm values for each property.
The updated configuration is saved back to the configuration file.

.PARAMETER RootFolder
The root folder containing the initialization file and where the configuration file will be created.

.PARAMETER DestinationFolder
The folder where the configuration file will be created. Defaults to the root folder.

.PARAMETER ConfigurationFile
The path to the configuration file to be created or updated. Defaults to "vars.json" in the destination folder.

.PARAMETER InitFile
The path to the initialization file. Defaults to "init.json" in the root folder.

.EXAMPLE
CreateFullConfiguration -RootFolder "C:\Project"
Ensures the initialization and configuration files exist in the "C:\Project" folder and updates the configuration file.

.NOTES
Version: 3.0.0
Author: [Your Name]
#>

function CreateFullConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [string]$InitFile = "$RootFolder\init.json"
    )
    
    #region Variables and logs
    Write-Verbose "Destination folder: $DestinationFolder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    Write-Verbose "RootFolder: $RootFolder"
    Write-Verbose "InitFile: $InitFile"
    $success = $false
    if (-not(Test-Path -Path $InitFile))
    {
        Write-Host "No init file found at $InitFile."
        Write-Host "Creating init file at $InitFile."
        if (InitializeConfiguration -RootFolder $RootFolder -InitFile $InitFile)
        {
            Write-Host "Init file created successfully."
        }
        else
        {
            Write-Host "Failed to create init file."
            return $success
        }
    }
    Write-Verbose "Reading init file at $InitFile."
    $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    $configData = @()
    #endregion
    
    #region Load parameters from the configuration file if it exists
    if (-not(Test-Path -Path $ConfigurationFile))
    {
        Write-Host "No configuration file found at $ConfigurationFile."
        Write-Host "Creating configuration file at $ConfigurationFile."
        if (CreateConfiguration -RootFolder $RootFolder)
        {
            Write-Host "Configuration file created successfully."
        }
        else
        {
            Write-Host "Failed to create configuration file."
            return $success
        }
    }
    Write-Host " Loading configuration values from $ConfigurationFile."
    $configData = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
    Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    #endregion
    
    #itterate over the configuration data and prompt the user to choose a value
    foreach ($config in $configData.PSObject.Properties)
    {
        Write-Verbose "Configuration: $($config.Name) = $($config.Value)"
        if ($valuesToEdit.name -contains $config.Name)
        {
            $configType = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).type
            $configDescription = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).description
            $configValue = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).value
            if ($configValue -eq '')
            {
                Write-Verbose "Config value is empty."
                Write-Verbose "Setting config value to 'none'."
                $configValue = 'none'
            }
            Write-Verbose "Stored Key name: $($config.Name)"
            Write-Verbose "Stored Key value: $($config.Value)"
            Write-Verbose "Possible Key values: $configValue"
            Write-Verbose "Key description: $configDescription"
            Write-Verbose "Key type: $configType"
            switch ($configType)
            {
                'string'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Description: $($configDescription)"
                    $value = Read-Host -Prompt "Press enter to keep the current value: ($($config.Value))"
                    if ($value -eq '' -or $null -eq $value)
                    {
                        $value = $config.Value
                    }
                    Write-Host "New value: $value"
                    Write-Verbose "Changing the value of $($config.Name) from $($config.Value) to $value"
                    $config.Value = $value
                }
                'array'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Press enter to keep the current value: $($config.Value)."
                    Write-Host "Description: $($configDescription)"
                    foreach ($item in $configValue)
                    {
                        Write-Host "[$($configValue.IndexOf($item)+1)] $item"
                        if ($config.Value -contains $item)
                        {
                            $currentlySelected = $configValue.IndexOf($item) + 1
                            Write-Verbose "The currently selected value is $currentlySelected"
                        }
                    }
                    $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    while ($value -lt 1 -or $value -gt $configValue.Count -and $value -ne '')
                    {
                        Write-Host "Invalid choice."
                        [console]::beep(500, 300)
                        $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    }
                    if ($value -eq '')
                    {
                        $value = $config.Value
                    }
                    else
                    {
                        $value = $configValue[$value - 1]
                    }
                    Write-Host "Value: $value"
                    Write-Verbose "Changing the value of $($config.Name) from $($config.Value) to $value"
                    $config.Value = $value
                }
                'static'
                {
                    Write-Verbose "This is a static value and cannot be changed."
                    Write-Host "Value: $($config.Value)"
                }
            }
        }
    } # Closing brace for foreach loop
    #Print all the new configuration data but only in verbose mode.
    Write-Verbose "New configuration data:"
    $configData.PSObject.Properties | ForEach-Object {
        Write-Verbose "$($_.Name) = $($_.Value)"
    }
    #Save the new configuration data to the configuration file
    Write-Verbose "Saving configuration to $ConfigurationFile."
    $configData | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    Write-Verbose "Configuration saved to $ConfigurationFile."
    Write-Verbose "Checking if configuration file exists."
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "Configuration saved to $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Verbose "Failed to save configuration to $ConfigurationFile."
    }
    return $success
}


# SIG # Begin signature block
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAUlp9P0LkL6UgH
# CtMn4weAknjIJbEp12t7fFttMNM7IqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBALqrKW8f
# DF2V1UqAVHelOjRsgBzRwCPxeEstthYcH7KMzb37j4STlS1O3Mz1CRndhmJKpGa0
# FN5A/Ll79j6T5umG1PhVUHPPvuGX45sBxTqW8m1k659FswwC71XaV5S4K1N1ib5E
# j7nPDHxTXkf2dU5SmchrPB99dTwur0WkZzEGbnZbhH00fC03mjc8a0BtARFeQF4Q
# PX18XSDVU7dgVOJJDHAw/FpgtCYq+VFncTIw4K58FdAROhyRuUiOyQ0P/bsSZcqc
# jfxn6hkRxPE1hT9CPP8JvceuMQA3+sGIoZmUppIc2ldu2E1oXoqlKa8wSr03mPyc
# TgSd/4JE8rE7BpGusApTjhS98cFcvFnuIVwGWXKdoD1MM95bUYxP5Nxya6F7m5l9
# +XjvYScowXPZs4rl6zyBO2Ke8AaOiVn1JN2cTfzL2WocS9x2oH/XxpYu/8FP4DAq
# 6/q1xBl4WpNYFIzDghQfuPggPgY2dCjkDt+oi7KspFxGSwBxhcwq62nkKwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRvZ0Eu5ioLdv1ZEHsjpEvJjbqx/jAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQB6Eajp2sKaZS/3dYOYfCMU
# 5GLagT4u/veDzQ4OAeNK7epbfOeSmmyGuLFm8L4oOzbVBuETjpRkVj+jrGQ32h0F
# 7AGxAvbIgVhgrKMhifOVdoCzzJvFGcC4K668QJGRX2XeJJp+xCQ33BN7ASomntFy
# EYVIf8f6cL6atLT3jBJeDFHCCSGcqtRY2H9OG9X0DlhsGoC+x+dQpw0Yj71ojs9b
# VcKMjh8oq8l9ZxnCMe+IHMw7bXXIEbWjpaHGCJOQkcJgSA+Ow4w/VPeopqBNeWsm
# I0cZWOHqJOfwkquIJdMg0dQ7+bbpM5WoW4ySPTIbnwP2M+azu3Eis84fn7SG3Qfb
# P8Gl+w9N2J8V19sqHTUGBont5pgxW79305NUHKdNoz/qFK5zu8LaScYUV+QQPYn+
# bNoGju2/YBI7wzT2zrU6aPKxhuhaGESTf2Cla+bS9+UUAmj8O7g7QyP9NnKYD30/
# dROGC1wUtK2pSGaIy6OjQnIkOWm0OsSmHLrhCIn9FuNHwSovwRUqJQxewTGJi/To
# Dk+u56OC8WGBBp9yZajiFsnnA+64WDv7UDEoLn4bj17m86dU6C5+3AMPQv6Abg/L
# 9WqrcfGwTN+ggDSH0cwuCkOue2oQGC+u6GbwPGp9wUuJ4NAnBEEdEwxbYkEtLAJQ
# 7zJaR8MJiF7WINj+ctMAvDCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
# AAcwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC398ADKAfFuj6PEDTi
# E0jxvP4Spta9K711GABrCMJlq7VjnghBqXkCuklaLxwiPRYD6anCLHyJNGC6r0kQ
# tm9MyjZnVToC0TVOfea+rebLBn1J7FV36s85Ov651roZWDAsDzQuFF/zYC+tLDGZ
# mkIf+VpPTx2fv4a3RxdhU0ok5GbWFKsCOMNCJnUmKr9KqIOgc3o8aZPmFcqzbYTv
# 0x4VZgHjLRSU2pbRnYs825ryTStsRF2I1L6dM//GwRJlSetubJdloe9zIQpgrzlY
# HPdKvoS3xWVt2J3+mMGlwcj4fK2hpQAYTqtJaqaHv9oRl4MNSTP24wo4ZqwiBid6
# dSTkTRvZT/9tCoO/ep2GP1QlhYAM1gL/eLeLFxbVUQtpT7BOpdPEsAV6UKL+VEdK
# NpaKkN4T9NsFvTNMKIudz2eY6Nk8qW60w2Gj3XDGjiK1wmgiTZs+i3234BX5TA1o
# NEhtwRpBoHJyX2lxjBaZ/RsnggWf8KZgxUbV6QIHEHLJE2QWQea4xctfo8xdy94T
# jqMyv2zILczwkdF11HjNWN38XEGdLkc6ujemDpK24Q+yGunsj8qTVxMbzI5aXxqp
# /o4l4BXIbiXIn1X5nEKViZpTnK+0pgqTUUsGcQF8NbD5QDNBXS9wunoBXHYVzyfS
# +mjK52vdLBmZyQm7PtH5Lv0HMwIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTog8Qz19yfDJx2mgqm1N+Hpl5Y
# 7jBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+
# 60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72
# gRwBkkOIaMRbK3Mxq8PoGKHecRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE0
# 4dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7oh
# qfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJb
# DDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV
# +4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgN
# ZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJe
# S7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+H
# LeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2Agdd
# ynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8Xngsb
# raLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAA
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
# dHklMjBWZXJpZmllZCUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUy
# MDIwMjAuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8vb25lb2NzcC5taWNyb3NvZnQu
# Y29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+60si2TAtOng1+H32+tulKwvw
# 3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72gRwBkkOIaMRbK3Mxq8PoGKHe
# cRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE04dmItRC2asXhXojG1QWO8GeK
# Npn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7ohqfdA3diZt197DNK+dCYpuSJO
# JsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJbDDXRt+U54EqqRvdJoI1BPPye
# yFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV+4vgA4YK2g1085avH28FlNcB
# V1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgNZDhpSgJFdywF5GGxyWTuRVc/
# 7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJeS7AILZnhdx/IyM8OGplgA8YZ
# NQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+HLeyfvNQeAgL9iw5MzFW4xCL9
# uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2AgddynYXQ4dxXB7cqcRdrySrMwN+
# tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8XngsbraLp9+FMJ6gVP1n2ltSjaDGX
# JMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAAAAeHozSje6WOHAAAAAAABzAN
# BgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3NvZnQgSWRlbnRpdHkgVmVyaWZp
# Y2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMjAwHhcNMjEwNDAx
# MjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJtFL/ekr4weslKPdnF3cpTeuV
# 8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGcgHfjPF/nZsOkg7c0mV8hpMT/
# GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8JuXWJzBDoLrmtThX01CE1TCC
# vH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2QfzZFmwfccTKqMAHlrz4B7ac8g9
# zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4Gzg2Yc7KR7yhTVNiuTGH5h4e
# B9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmPf6KLXVNLz8UaeARo0BatvJ82
# sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZEZsBRc3VT2d/iVd7OTLpSH9y
# CORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/hFMIQa86rcaGMhNsJrhysLNN
# MeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL8F9gn6jOy3v7Jm0bbBHjrW5y
# QW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4Fre+ZQ5Od8ouwt59FpBxVOBGf
# N4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILhAV5Q/ZgCJ0u2+ldFGjcCAwEA
# AaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADAdBgNV
# HQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYDVR0gBE0wSzBJBgRVHSAAMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9j
# cy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNV
# HRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGE
# BgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3Ql
# MjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIHDBggrBgEFBQcB
# AQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmllZCUyMFJv
# b3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MC0GCCsGAQUF
# BzABhiFodHRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcN
# AQEMBQADggIBAHf+60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4d
# lTE0b6s15lr5HO72gRwBkkOIaMRbK3Mxq8PoGKHeRYWwhbhoaHiAHif+lE955Wsri
# LUsbuMneQ8tGE04dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNCscE
# VYcYNuSbH7I7ohqfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdGw85
# 8WCfOEtWpl0TJbDDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4/ZIS
# kEXtGiUQLeWWV+4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY0WfqR
# UJzkF10zvGgNZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wHoUM7hu
# Ua4auiAynJeS7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150JqG248w
# OAHJ8+LG+HLeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+
# Pl8n2AgddynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U40OZa3rUw
# tC8XngsbraLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8Y
