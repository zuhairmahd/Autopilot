function CreateFullConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [string]$ConfigurationFile = "$folder\vars.json"
    )
    #print verbose log of received parameters
    Write-Verbose "Folder: $Folder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    
    $valuesToEdit = @(
        @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; type = 'string'},
        @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; type = 'string'},
        @{name = 'Name'; value = 'localhost'; description = "The name of the device to configure."; type = 'string'},
        @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; type = 'string'},
        @{name = 'AssignedUser'; value = ''; description = "the user to assign the autopilot device to."; type = 'string'},
        @{name = 'check'; value = 'false'; description = "Check the status of the device."; type = 'bool'},
        @{name = 'NoModuleCheck'; value = 'false'; description = 'skip checking for installed powershell modules.'; type = 'bool'},
        @{name = 'NoUpdateCheck'; value = 'false'; description = 'skip checking for updates.'; type = 'bool'},
        @{name = 'UpdateOnly'; value = 'false'; description = 'Only check for updates and exit.'; type = 'static'},
        @{name = 'NoAdminCheck'; value = 'false'; description = 'skip checking for admin rights.'; type = 'bool'},
        @{name = 'NoSignatureVerify'; value = 'false'; description = 'skip verifying the signature of the script.'; type = 'bool'},
        @{name = 'NoHashVerify'; value = 'false'; description = 'skip verifying the hash of the script.'; type = 'bool'},
        @{name = 'GetDeviceHash'; value = 'false'; description = 'Gets the hash of the device and exit.'; type = 'bool'},
        @{name = 'Redeploy'; value = 'false'; description = 'Check the deployment status of the device.'; type = 'bool'},
        @{name = 'SerialNumber'; value = ''; description = 'The serial number of the device to check.'; type = 'string'},
        @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; type = 'array'}, 
        @{name = 'Release'; value = @('main', 'auto'); description = 'The release branch to use.'; type = 'array'}
    )
    $success = $false
    
    # Load parameters from the configuration file if it exists
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Host " Loading configuration values from $ConfigurationFile."
        $configData = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
        Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    }
    else
    {
        Write-Host "No configuration file found at $ConfigurationFile."
        Write-Host "Creating new configuration file."
    }
    
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
            Write-Verbose "Key name: $($config.Name)"
            Write-Verbose "Key value: $($config.Value)"
            Write-Verbose "Key type: $($configType)"
            Write-Verbose "Key description: $($configDescription)"
            switch ($configType)
            {
                'string'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Description: $($configDescription)"
                    $value = Read-Host -Prompt "Press enter to keep the current value: ($configValue)"
                    if ($value -eq '' -or $null -eq $value)
                    {
                        $value = $config.Value
                    }
                    Write-Host "New value: $value"
                    $config.Value = $value
                }
                'bool'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Press enter to keep the current value: $($config.Value)"
                    Write-Host "Description: $($configDescription)"
                    $choices = @(
                        @{number = 1; choice ='true' },
                        @{number = 2; choice = 'false' }
                    )
                    ForEach ($choice in $choices) 
                    { 
                        Write-Host "[$($choice.number)] $($choice.choice)"
                        if ($choice.choice -eq $config.Value)
                        {
                            Write-Verbose "There is a match"
                            $currentlySelected = $choice.number
                        }
                    }                        
                    $value =  Read-Host -Prompt "Choice: [$currentlySelected])"
                    while ($value -ne '1' -and $value -ne '2' -and $value -ne '')
                    {
                        Write-Host "Invalid choice."
                        [console]::beep(500,300)
                        $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    }
                    if ($value -eq '')
                    {
                        $value = $config.Value
                    }
                    else 
                    {
                    $value = $choices | Where-Object { $_.number -eq [int]$value } | Select-Object -ExpandProperty choice
                    }
                    Write-Host "Value: $value"
                    $config.Value = [bool]$value
                }
                'array'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Press enter to keep the current value: $($config.Value)"
                    Write-Host "Description: $($configDescription)"
                    foreach ($item in $configValue)
                    {
                        Write-Host "[$($configValue.IndexOf($item)+1)] $item"
                        if ($config.Value -contains $item)
                        {
                            $currentlySelected = $configValue.IndexOf($item)+1
                        }
                    }
                    $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    while ($value -lt 1 -or $value -gt $configValue.Count -and $value -ne '')
                    {
                        Write-Host "Invalid choice."
                        [console]::beep(500,300)
                        $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    }
                    if ($value -eq '')
                    {
                        $value = $config.Value
                    }
                    else
                    {
                        $value = $configValue[$value-1]
                    }
                    Write-Host "Value: $value"
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
    $configData | ConvertTo-Json | Set-Content -Path $ConfigurationFile
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
# MII94wYJKoZIhvcNAQcCoII91DCCPdACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDjfOVBKUBCaokp
# ylsnfWdRPZOa2dJXUCWYUMI39glLT6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAMhOMx6
# uxRP6IfpAAAAAyE4MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwMzI4MDYzOTQ1WhcNMjUwMzMx
# MDYzOTQ1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# telPbF1c/Z3bR7ZgxLv8x9ceHiNgsLA3waTMd4FPGy4wEqw5MVvpNw9qvRQ3/MkS
# L+Arzdw02sf3V9LP1wVx1rKJjm+4sTvbtuRXHbAkyakzJxJdZnLYwSHCnchSncVa
# 3noIsPw5a4y8w5Go9uxbKdk4moxRpaJbk7rqQOIOicbsMzOPc4+nG1GGuKjYM3hM
# SLa/V4ZSOPejqo2dd93AND5IKf+Hl8dsI2ZqF9aPcg0YVbRuZ7XepMa+bg9Zq8m7
# 8nrAi2f4JrKcIH5lIkHJITse3C+94FW7IfmhtQ3cIlLo4tP4JFMFKZ4E5qELER+v
# OSBgJ6qfPNh+ayfySnnd9YyJ/VUHYo9YXZd9aV3pCgk4jA0ujXEc6lLYQBZqSBmk
# JuWVAi/wSMJqVKQvVBte1EcsBMw2WwLZnYqpYHI1AbmK3Cdw5hnaXSKj92YaMqbq
# WyDQIASq+PLVRwXD1B+5pipCaFTHnFVVCducRcOtm2/j9kdf8WBxjvqLj7o0fwt7
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFFd37/NEhYZBwUr4r/cZmn/HvuAXMB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAEjYPwuT4vxwHeed
# sFcCRD/ye2CS3S+syW8peFce5U1G2m5v01zNe7z3N7lo4Py7gD/w5GcoVlwSWqJa
# 9MGRBZubsXAcBL8qHVaEnW7Qe5kderc3D48Ou12lVVaF8CRcfkzoa7/aPygzWJmE
# vagdawsPhp5ulxA8d0DiPOfI1nJbehw3fp8T4GCq2GRcV1aAqmcqHuv3HowjGnmk
# 1fMpj0ux+tLAP6GhFzuuFqTcO0vjHEND6aV4uEyp1Fauash/JpkiMn9uM/h5+KWv
# Ajz7892J2H6tsceD5mH1xYJ88dKTlfPiw2hTB6yoPUtbs1no1hhN1cMiu9depjCb
# fcxrOnIuq57pPKsBIfjwgTFKVE8IRZunzK5r6WOeO86N9z006R1mQyWpRhB1MDYl
# YqpJ9Xt3DRDCFZQoGZCw0Hb2zwHweCDIf2yYI0/mKyppWmuTGIqMYc4SgBglzR3V
# OI5dplZohdWKpauOaYAlznfyE4jaCY09SyFiK8EM4y9NxRb05iNUc8d+c8C+jscL
# lHBIv4NiHEkBXxP/mNmBV64+UCxqTwvgprlINXBa+97TauOW/a7QFeBH7MZP4O0Z
# t2Fy/YGu3AlUS8dJCSovoqRtxU0+Bmqe0Ch+UbG/QzVo4UjDkjMAhv9Qub9rIXuA
# /H/F2rg9LNGORgKLzsWCypwQilh9MIIG5zCCBM+gAwIBAgITMwADITjMersUT+iH
# 6QAAAAMhODANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDMyODA2Mzk0NVoXDTI1MDMzMTA2Mzk0
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBALXpT2xd
# XP2d20e2YMS7/MfXHh4jYLCwN8GkzHeBTxsuMBKsOTFb6TcPar0UN/zJEi/gK83c
# NNrH91fSz9cFcdayiY5vuLE727bkVx2wJMmpMycSXWZy2MEhwp3IUp3FWt56CLD8
# OWuMvMORqPbsWynZOJqMUaWiW5O66kDiDonG7DMzj3OPpxtRhrio2DN4TEi2v1eG
# Ujj3o6qNnXfdwDQ+SCn/h5fHbCNmahfWj3INGFW0bme13qTGvm4PWavJu/J6wItn
# +CaynCB+ZSJBySE7HtwvveBVuyH5obUN3CJS6OLT+CRTBSmeBOahCxEfrzkgYCeq
# nzzYfmsn8kp53fWMif1VB2KPWF2XfWld6QoJOIwNLo1xHOpS2EAWakgZpCbllQIv
# 8EjCalSkL1QbXtRHLATMNlsC2Z2KqWByNQG5itwncOYZ2l0io/dmGjKm6lsg0CAE
# qvjy1UcFw9QfuaYqQmhUx5xVVQnbnEXDrZtv4/ZHX/FgcY76i4+6NH8LewIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRXd+/zRIWGQcFK+K/3GZp/x77gFzAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBI2D8Lk+L8cB3nnbBXAkQ/
# 8ntgkt0vrMlvKXhXHuVNRtpub9NczXu89ze5aOD8u4A/8ORnKFZcElqiWvTBkQWb
# m7FwHAS/Kh1WhJ1u0HuZHXq3Nw+PDrtdpVVWhfAkXH5M6Gu/2j8oM1iZhL2oHWsL
# D4aebpcQPHdA4jznyNZyW3ocN36fE+BgqthkXFdWgKpnKh7r9x6MIxp5pNXzKY9L
# sfrSwD+hoRc7rhak3DtL4xxDQ+mleLhMqdRWrmrIfyaZIjJ/bjP4efilrwI8+/Pd
# idh+rbHHg+Zh9cWCfPHSk5Xz4sNoUwesqD1LW7NZ6NYYTdXDIrvXXqYwm33Mazpy
# Lque6TyrASH48IExSlRPCEWbp8yua+ljnjvOjfc9NOkdZkMlqUYQdTA2JWKqSfV7
# dw0QwhWUKBmQsNB29s8B8HggyH9smCNP5isqaVprkxiKjGHOEoAYJc0d1TiOXaZW
# aIXViqWrjmmAJc538hOI2gmNPUshYivBDOMvTcUW9OYjVHPHfnPAvo7HC5RwSL+D
# YhxJAV8T/5jZgVeuPlAsak8L4Ka5SDVwWvve02rjlv2u0BXgR+zGT+DtGbdhcv2B
# rtwJVEvHSQkqL6KkbcVNPgZqntAoflGxv0M1aOFIw5IzAIb/ULm/ayF7gPx/xdq4
# PSzRjkYCi87FgsqcEIpYfTCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGpMwghqPAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMQITMwADITjMersUT+iH6QAAAAMhODAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCa4dgQsqBEYuxSm88jxYlqF2j8
# pYtfrxqm5OAZ7v0SwDANBgkqhkiG9w0BAQEFAASCAYBPo9JfR0TSKD2HyVACY2mX
# 8eOxEvwhjc9FH7kiGnUMcf8et1rJaxz/ivSt9rd/aX6nRErHO8R9+mWWcfmjfdRx
# ny/R4mNsnZ4LsrV5xhqUwfJYBx8xhuX+KkpZlPHMnQAaD8+F/FL8G83S13ojqQXE
# X8RO/sMdYYf5IZmR3XFY7sxRaA+KoCQgTm2EGL7Y+uAmYVczTCXuY8a2OHLlDP0F
# //npDzREnX21h1Xklq6GS5NqGcktXjEPVcJUj/OxthuczX8u1AufgE0j5tJvseWQ
# qK2JDrx3AptcYbU7GyC6a9hdHSDehHdDJMGO9bYG8oFs/QggPchNX+M4A7LFBhk2
# Spb2e8zW4Ly0d+mf3Iy1Nsh2ja58hLDAHAXlrhe6EOPMT+YQqdXIVOVOIZ27iSA/
# 0y8RpkpVFe9a/5l23q+YqvKwArY5GEYtFXXpSno7q+kztC+MNLzm+n3KNXxK5gUD
# mrYUkjPxdsWgjLtflFe0ykc43ku0wY6p1ECJYMcsCbmhghgTMIIYDwYKKwYBBAGC
# NwMDATGCF/8wghf7BgkqhkiG9w0BBwKgghfsMIIX6AIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgp9wjIQcPXiWO4P4Gw3yZq8RUH1IvTVrMdtUZ9kBy
# 0VQCBmfcmewnUxgSMjAyNTAzMjkwNDU3MTguOTJaMASAAgH0oIHhpIHeMIHbMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046N0EwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
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
# EzMAAABH45ULN6Fg3ccAAAAAAEcwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODUwWhcNMjUxMTE5MTg0ODUwWjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdBMDAtMDVFMC1EOTQ3MTUw
# MwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhv
# cml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOhwum733P/414hm
# ZHfYYmDZVP+N33qlguy82eB4fipfArWpWYVpdeSRVvFvV85Aky6RiRtrdYRzr1b9
# ngGzMC7GC5OENWVj2yThliQYyDGirVnmKdQ++PhCHzFW+WGIBLo5/+4vAOxuwqWD
# Z8ama/O2I9I4v0/XmTTQjhuyXW+WZFK63a03AlDmxemhPsYj/ZPYDQadZsUQIpEL
# IZb2uyfL2jQs0hSXg1gB3hrAZKzo4jMo+kgrUl8r3TBce9pfAYlw30/xA9Ekgcq4
# WhUbMhQb8LSNALitDrbJMa9zaxngDFNDB+V9UEFqIeryCf9gMelmKV4aQHYhBrNk
# SIRzk6vld6v2ZQNT7YUR7rrDx7ZaQtdqerFoPn5lyj4T5B3BxNgajvyMXE8O82tp
# OvlACAhNzh1j88ELdxgXNyAPJTHbE5UIG+BpuonGPuteuPgGF3ZL9lNg5UeGLxwN
# YFp58zwmCI7wYIghG+U1aeDwUoW3T1l83GaxJ0ImVbDes0DCwFjXGnymaa/2vYz2
# s0hGRn6yHTF3ca4BJazZs6uoGLRpPOBj1vcLFj7+b5FT5ROKbkmSakkz8Ag/rz9L
# 7U3AWpcrnLFMkEgieGgSB0QeL5rYlHZKVXcCSklrT8HqxlqgRr7OCyEh8VrrpcGa
# eezJ1Xi4btbUg2ho1XDEEoN2ao1HAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQU5FR2
# WCA6Pu9PubZe8WFIRbyG3WgwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk9
# 2yEwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5n
# JTIwQ0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# UHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# CAYGZ4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQANIlRD1dqYOHSCQLVe+uFXPoAz
# AZUq4okD62SUnMFrhRVg/dj2vVEtTTxFgkiM8SSnCLANaK0rnyCxnHA2Hg1zh8WJ
# CtlQln0Eid+eh2/xY47zfNjxhB0kxymAHN5hVeI0J526aoUpePSYwy5ZoHKe/vDC
# fsWccnDMuu7iO3hUt55/4HJydjA+gxrvksX/3Fmj/RMnfvWq0Fh1uxx4qY2FBRMP
# a8i+8+QdM8f80DYiQuxDUCbnWfOHnZYQPNEKhd6V3r78oKWd+wQHX+99Hqlg/HBl
# O9Nnu6HvLwPqDiEOkRyMix6zvnhbZpGnFM+u7qf7PYTOS8cXvQH+DmgCh2ZVNQFv
# 6nGm7vtQebROtpWh2N9ckk2z6HVGOcK70yKS7YqE+akGuxKd7fXLeBey2bm9y2nW
# 0WjH1qZNa+EhXzyXUQgLfJf4E31wYq0vrlESX/LzKprY8hbaLXwkxEivhPuWId9f
# QDqx0+yXsa50vIRUcBaxbw0VXO3+93JGHMxSmzGE8vWoZCAPjlD7duBOV6XkxaVa
# Bgb5v4stRdHm6LJtsizCc5FNT+MPJw0DHy7hzn7Xix6fn9+apytBrfXqXtapxDqs
# 5yjEMXKbuTZFW4SFk1Dhc1cIojuRvw8ytG0xuhtXSavJ3RSVtBRs+wm432dQTYAO
# aCc7dtAbIRG+ml50ITGCB0YwggdCAgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABH45ULN6Fg3ccAAAAA
# AEcwDQYJYIZIAWUDBAIBBQCgggSfMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MDMyOTA0NTcx
# OFowLwYJKoZIhvcNAQkEMSIEIEKZgHUgZUZXJ+5a/4Si8QqdCXKD5QV2H4HC2Qlm
# gRHnMIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQgk2bzlnKFAAYZ71A+F3f7
# G+YwoK9+MeF/y2XqZEgKzKcwfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABH45ULN6Fg3ccAAAAAAEcw
# ggNhBgsqhkiG9w0BCRACEjGCA1AwggNMoYIDSDCCA0QwggIsAgEBMIIBCaGB4aSB
# 3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjdBMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUA
# IAXT2b4gvIw3J1lPs/eU4s1UXN2gZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDr
# kaRKMCIYDzIwMjUwMzI4MjI0MjE4WhgPMjAyNTAzMjkyMjQyMThaMHcwPQYKKwYB
# BAGEWQoEATEvMC0wCgIFAOuRpEoCAQAwCgIBAAICDtICAf8wBwIBAAICEp0wCgIF
# AOuS9coCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQAC
# AwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEASoBDYRoHrj8tEAc+
# 6ZoG0wi7hC9BFzcLpJvMJE6jJtsa0fmTR6np1POEK1Pl/wwXgp0Z0dhF5cOoUMmn
# y3Sb0PiN7NS0/0ZeG5ezciTscVTvzC9kppSQOdd6/j5U0gYIA1uxx6ItFvZQs02/
# XNWJhptpWckNYZ1sU9F29DeOu2WLt6/JXMeqNcs6bHwJyoPL9G6md7xhzSf4GWZs
# NNtv2BwSA945qUCYkH24CqQIzvpfOiP3O9WsFXbBxGvXipvu58htIYK1xWGmjK8V
# lgJymd+prLBnvPhA3WE9ybvHS8bbReMbwYHrNuzTemUUAYm903QBTb/7irZLu9k7
# AXi7hTANBgkqhkiG9w0BAQEFAASCAgC/wKtAZVGW0EA+da5Ki6QONOFqrKB4JNjv
# q9c5DeR195yXKAq/UWy/WGAgqx+JzPzfqL7O6EAQMA6POpW1fWXRimxUGq/rXG7i
# osuIMdCdJWbqKtiBXByL7Tf3HIh2LttLWL3NqV7RCJIbWJ1G0rtQg2zjwkXrVxgb
# 2XUI2GD69X5tLxOe+LOJ2EQN5SEr1CZBpbiKapYQkFFOcvaJwWmvtLS7HUzqsZpP
# IQQ6G+jL1rWge7L2/NDzq2IQZOgBs323Krd2njyXx9L+q0KYD5U5YPnxoX9z4x2X
# JkAX6mMkfpRploeYwM0hmRzOiet2lfgUHe25TXy/c834FXEUv7+SBDwYJ3B1U4T/
# EMyV1zaudRnc95uHV5voaX6cxNtXmc3m1vXuXk+0Hl809fsXAs3w9tX7CdxjD/Io
# U1I8Rz5B4WhGSzQufyEUVaJnD1M3ZJ4CLetxKJSoqzKdS/im2SC+W+BsZa97UD+n
# rfu+Ckp4WAjVVWG/PKn0HYgua2+HZrHWiBfCWK0XT1NNihQeI6NSUxgfThw+yqp5
# qf6zZjf2CNG4zFkP1ALNoZ97VUD4uKbro4vkiQ5CmK3eO9wr9CkyLY2WWqRoCznd
# 0wzclJ050bnfJjcnzeCJB1LMBbYjaMNXN++GO1D8eUA+pAWIOHPZyoTGVrAHb+VS
# ecrW8h9bcQ==
# SIG # End signature block
