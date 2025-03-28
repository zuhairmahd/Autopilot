function CreateConfiguration()
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
        @{name = 'UpdateOnly'; value = 'false'; description = 'Only check for updates and exit.'; type = 'bool'},
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
                Write-Verbose "Setting config value to 'empty'."
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
                    $value = Read-Host -Prompt "Press enter to keep the current value: ($($config.Value))"
                    if ($value -eq 'none' -or $null -eq $value)
                    {
                        $value = $config.Value
                    }
                    Write-Host "Value: $value"
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
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA+qeLlrPs995Ej
# ZP9/ezb5pctV9Ych20116LQJivzYtKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAIztf3H
# p+2ytw6TAAAAAjO1MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwMzI1MDY1NjExWhcNMjUwMzI4
# MDY1NjExWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# iSM5tT+Jjd+jvxIrUc0mpDf3zr/MwFft3bbflYjOHrAIJxTjcqrTDp2upH+1Ipyu
# 4ejcycNDOp+anmUZjefME5bpNUBx9oRmVq0RcrB65IZeqKmi9GNsPO0e4ohRt5Lp
# 56lRjkFLXRM99oPrg5oZHC1xDRAFfhpkRe+MSCUhlapJbPvp764uNgIckHtnLgVY
# OCJOmeAWt9wpzlzAuQ7Bwb3U472aENOyuKQSl5GNXZ2KkkhhPmVFOUb/usvrObCF
# teCDsQ4lZzXhrTGZjy3PJUVZzUmdKHzAeSz5KMIKE+Q6UC8TRspwEd12thfZFkqK
# Suh38sX0TNZYOyFLIoz/WE7jxiIWrhKSlSzKOcr3vdWtDU1D4PUdE43M+sEl1nuU
# UQeDzFhAKfiurodcj9bqYtbmGUnUdojPPK0opYIOGPvnh7g15YP+838BJL+8HqW1
# dNEkREELeOyOEPeq5Eo8EkJF9Tl5pVa/sCiyDl48s1TK3stv5MZaMqxWF4qKZAkr
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFE3JWjohOo26TUlGpdFZFn4ClUblMB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAINGxW/npLkbDcHm
# sJ+PIc+bl83WKMAURUk/AjHx9VGDIL9VjBtVQdhZtb+N4Qlgq1SXxaX18Pt4/XxQ
# 30NlnBZlL79C6zedA/nihd0rrm4nRVEomdNWufshITLejU3K2i3U/u3Eb4/Ydtbl
# RVU1IMxlbdnHipB4ey1B20gXWri8n+vNbpppcewlX4K4+557t70d68a5wBuaT0/R
# xl1XdNWqwM3Bxfmv5fR2PNrzGNEVvDvmF/ug4cLJRZMe9kZnaMqYTkb5x2S3PDkW
# JcVY7vyrOdSK77hwZlUxhtBMOy43xUwuwm668Ff+idLcCSlx4n6XYklZaJhvqDri
# RGw6ysCcoihT0udQvupcOVz1ezB5fECWuFTH4eHAUrTJZkdyWrXIqmEiqOJpXB3T
# BxXFjQHZZb2C8UUHp4cBeBizvE3kZiBw+MOkvAPXQwHWPeEEvCqp+Tg5m5PWdJWV
# YkNb7Q4SJaJlHZJbXwA47XsHhdKof/E8pL5f07FJUnvkqOp/OP5bl9BzKkARAQUO
# FRADH32Ea2MXwYfPs+kDrFjYlZzPjvyRDERDnbxT/UasJS2HBr2xjgl2FpUtBPYJ
# 6KnJ9hd/iQ+gIWngnK2MUsDh7viQdTFMdbjWp9tmDfwqfG9yerRC/wxngavEI1C1
# NUEWqP4CkdkJR3wWCglQiNRxIUZ8MIIG5zCCBM+gAwIBAgITMwACM7X9x6ftsrcO
# kwAAAAIztTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDMyNTA2NTYxMVoXDTI1MDMyODA2NTYx
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIkjObU/
# iY3fo78SK1HNJqQ3986/zMBX7d2235WIzh6wCCcU43Kq0w6drqR/tSKcruHo3MnD
# Qzqfmp5lGY3nzBOW6TVAcfaEZlatEXKweuSGXqipovRjbDztHuKIUbeS6eepUY5B
# S10TPfaD64OaGRwtcQ0QBX4aZEXvjEglIZWqSWz76e+uLjYCHJB7Zy4FWDgiTpng
# FrfcKc5cwLkOwcG91OO9mhDTsrikEpeRjV2dipJIYT5lRTlG/7rL6zmwhbXgg7EO
# JWc14a0xmY8tzyVFWc1JnSh8wHks+SjCChPkOlAvE0bKcBHddrYX2RZKikrod/LF
# 9EzWWDshSyKM/1hO48YiFq4SkpUsyjnK973VrQ1NQ+D1HRONzPrBJdZ7lFEHg8xY
# QCn4rq6HXI/W6mLW5hlJ1HaIzzytKKWCDhj754e4NeWD/vN/ASS/vB6ltXTRJERB
# C3jsjhD3quRKPBJCRfU5eaVWv7Aosg5ePLNUyt7Lb+TGWjKsVheKimQJKwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRNyVo6ITqNuk1JRqXRWRZ+ApVG5TAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQCDRsVv56S5Gw3B5rCfjyHP
# m5fN1ijAFEVJPwIx8fVRgyC/VYwbVUHYWbW/jeEJYKtUl8Wl9fD7eP18UN9DZZwW
# ZS+/Qus3nQP54oXdK65uJ0VRKJnTVrn7ISEy3o1Nytot1P7txG+P2HbW5UVVNSDM
# ZW3Zx4qQeHstQdtIF1q4vJ/rzW6aaXHsJV+CuPuee7e9HevGucAbmk9P0cZdV3TV
# qsDNwcX5r+X0djza8xjRFbw75hf7oOHCyUWTHvZGZ2jKmE5G+cdktzw5FiXFWO78
# qznUiu+4cGZVMYbQTDsuN8VMLsJuuvBX/onS3AkpceJ+l2JJWWiYb6g64kRsOsrA
# nKIoU9LnUL7qXDlc9XsweXxAlrhUx+HhwFK0yWZHclq1yKphIqjiaVwd0wcVxY0B
# 2WW9gvFFB6eHAXgYs7xN5GYgcPjDpLwD10MB1j3hBLwqqfk4OZuT1nSVlWJDW+0O
# EiWiZR2SW18AOO17B4XSqH/xPKS+X9OxSVJ75Kjqfzj+W5fQcypAEQEFDhUQAx99
# hGtjF8GHz7PpA6xY2JWcz478kQxEQ528U/1GrCUthwa9sY4JdhaVLQT2CeipyfYX
# f4kPoCFp4JytjFLA4e74kHUxTHW41qfbZg38Knxvcnq0Qv8MZ4GrxCNQtTVBFqj+
# ApHZCUd8FgoJUIjUcSFGfDCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFyAwghccAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACM7X9x6ftsrcOkwAAAAIztTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCZN3mRnTHArky6YoIhvjPTSXeZ
# zyNL61EqvU95WJA+2DANBgkqhkiG9w0BAQEFAASCAYCAVXIQ5wjrWCPtgfLUEWca
# bXnyLfSExQ3t8d33lydZygBTOXbvOwu9GAtWLJf/vtlZsSUtYDO2X4vvLtP7CwdW
# XJRIoaZUXJ/PI51vbHEhQiZTmVZHEEGXL0otSgWnLKRYWUqjlhH6xhN9fBsKCbq1
# gIr2lXSrh2VfiJQd7xm0eXk/1+/KNobzy2AWoZJ5ZAVzH8b3UuRF2V2pncfmsOzB
# G0YCBBM3/cSllxoAxBVn8FWRqz0i+qYTNLVqkv+yxwYiINW+Ra7U5FysSP1KQfhN
# ekX5R+ouVuE+00ycZNCeKs4oJDpcPBjGtiOu5YlTN7TWnVQgrmGsbvtVW0PUpt0u
# 5y/M6oXXtY073ehIXQ0JEia1DhQBORbCxL0aGWilfjMAIYTxre9M/chgMPkCNyn4
# i7QebD0E3+a/jRAz6FNrofVhJmMJn13kod2CTD5f7/W80WBiPOPv+x2e6u2N0SlA
# NkQA8mSN+sXyTIrNl1IYgCJ0BCDXGSiZJvWOV1XruxmhghSgMIIUnAYKKwYBBAGC
# NwMDATGCFIwwghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgPQJ36xlrQP+YXJ2gKvX8+tqscBABTd+SMAr/csv+
# 6LECBmfYFHicuBgTMjAyNTAzMjYwNjA5NDIuMTc0WjAEgAIB9KCB4KSB3TCB2jEL
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
# MC8GCSqGSIb3DQEJBDEiBCCDZH7FOkvSOtkKeITDQYXmznpi3e7duln9hcfnd1qS
# DDCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEIBIndkiaVD4+cUJu9zOL6g5l
# YdUEek4rk1FZC9z/ForOMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAARhfkdXrK/drlAAAAAABGMCIE
# IJLNoGvquOzqpuxr8c4fBW+uL/XzzMCU719cPwrRqFa/MA0GCSqGSIb3DQEBCwUA
# BIICABAX/Xcizua0zmhx1TBBbgEF9nazYziTjpfJXUEww7pIwAlPJ9MuWuWBAdB+
# xUj4TmUWmKdgvt3ZauMGJ7EDS+8gnQyTUrPhm6VcuuLPEUX/B4Qr6OtvbDTFNSEa
# xXW5I7BT5O5C8QnfekPTzTNS2V7foUKiNtitSZ8O2/mjwr98ZyVOqsrmW0o/08OE
# uP3UYgOTWcMKRDLlKlt35xecl1YY61wBoJy5D+B7GWGFmeR/HYDbVP7sP19SE773
# 2l3kVgqDz7K5wvKfdHAwSN74JrxdxpVaOdVApJqxpN6kESUWCUCkV62r5dPiCkRS
# Ft8WsjMrSujSUqzvhg7J/1dU9RnRtDKxEZU9Wu0x/ypEn+MB4aCsyJKAO+K6nDEU
# 1LMmG2L+oip6mwl8qGIOsrkonU/Qw1qXhSJPElQxqy8MjC28hnwGLzVQFM7AkBtP
# 2q6Z+LMuzWWRIZnS/8TMwxmlV3Yui3U4OWyib4xT+b+6D2g2ZsewV5cnk8++3CAB
# dcE9Z2gaK/4Q3SwolMKrM68lHZt3at8gNelwKse6QOoeDt0PxTPtKPCp1bOsfCGJ
# hcA6SF5rXuuL7vbN9KEAF9IGvIe+mexqQX8JCLP8wChQH4qqAIgaHLuV5r70YjxV
# uJRFyVa9yS+Kwnu0iiwwIiIJ6fhJ4NdAOBjmH/Lu5qxA3u/e
# SIG # End signature block
